#!/usr/bin/env python3
"""Thin MCP stdio client bridge.

Conductor core stays in Novus. This helper only handles external MCP server
process transport because current Novus process lib has no bidirectional pipe
API.
"""

from __future__ import annotations

import argparse
import json
import os
import select
import shlex
import subprocess
import sys
import time
from pathlib import Path


def unescape(value: str) -> str:
    return (
        value.replace("\\n", "\n")
        .replace("\\r", "\r")
        .replace("\\t", "\t")
        .replace("\\\\", "\\")
    )


def read_server(home: Path, name: str) -> dict[str, str]:
    path = home / "mcp" / "servers" / f"{name}.txt"
    data: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            data[key.strip()] = unescape(value.strip())
    return data


def conductor_command(command: str, subcommand: str, *extra: str) -> list[str]:
    parts = shlex.split(command)
    try:
        idx = parts.index("serve-conductor")
    except ValueError as exc:
        raise RuntimeError("not a conductor server command") from exc
    return parts[:idx] + [subcommand, *extra] + parts[idx + 1 :]


def is_conductor_server(command: str) -> bool:
    return "serve-conductor" in shlex.split(command)


def run_conductor_json(command: str, subcommand: str, *extra: str) -> object:
    cmd = conductor_command(command, subcommand, *extra)
    out = subprocess.check_output(cmd, text=True)
    return json.loads(out)


class McpClient:
    def __init__(self, command: str, timeout_seconds: float) -> None:
        self.timeout_seconds = timeout_seconds
        self.proc = subprocess.Popen(
            shlex.split(command),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self.next_id = 1

    def close(self) -> None:
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.proc.kill()

    def request(self, method: str, params: dict | None = None) -> dict:
        msg_id = self.next_id
        self.next_id += 1
        payload = {"jsonrpc": "2.0", "id": msg_id, "method": method}
        if params is not None:
            payload["params"] = params
        assert self.proc.stdin is not None
        assert self.proc.stdout is not None
        self.proc.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
        self.proc.stdin.flush()
        while True:
            ready, _, _ = select.select([self.proc.stdout], [], [], self.timeout_seconds)
            if not ready:
                raise TimeoutError(f"MCP server did not answer {method} within {self.timeout_seconds}s")
            line = self.proc.stdout.readline()
            if line == "":
                stderr = ""
                if self.proc.stderr is not None:
                    stderr = self.proc.stderr.read()
                raise RuntimeError(f"MCP server exited: {stderr.strip()}")
            data = json.loads(line)
            if data.get("id") == msg_id:
                return data

    def notify(self, method: str, params: dict | None = None) -> None:
        payload = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            payload["params"] = params
        assert self.proc.stdin is not None
        self.proc.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
        self.proc.stdin.flush()

    def initialize(self) -> None:
        self.request(
            "initialize",
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "conductor-mcp-bridge", "version": "0.1.0"},
            },
        )
        self.notify("notifications/initialized")
        time.sleep(0.05)


def ok(result: object) -> None:
    print(json.dumps({"ok": True, "result": result}, separators=(",", ":")))


def fail(message: str) -> int:
    print(json.dumps({"ok": False, "error": message}, separators=(",", ":")))
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--home", required=True)
    parser.add_argument("--server", required=True)
    parser.add_argument("--action", required=True)
    parser.add_argument("--tool", default="")
    parser.add_argument("--args", default="{}")
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()

    try:
        cfg = read_server(Path(args.home), args.server)
        command = cfg.get("command", "")
        if not command:
            return fail(f"server has no command: {args.server}")
        if is_conductor_server(command):
            if args.action == "tools":
                ok(run_conductor_json(command, "conductor-tools-json"))
            elif args.action == "resources":
                ok(run_conductor_json(command, "conductor-resources-json"))
            elif args.action == "prompts":
                ok(run_conductor_json(command, "conductor-prompts-json"))
            elif args.action == "call":
                ok(run_conductor_json(command, "conductor-call-json", args.tool, args.args))
            else:
                return fail(f"unknown action: {args.action}")
            return 0
        client = McpClient(command, args.timeout)
        try:
            client.initialize()
            if args.action == "tools":
                ok(client.request("tools/list").get("result", {}))
            elif args.action == "resources":
                ok(client.request("resources/list").get("result", {}))
            elif args.action == "prompts":
                ok(client.request("prompts/list").get("result", {}))
            elif args.action == "call":
                try:
                    call_args = json.loads(args.args)
                except json.JSONDecodeError as exc:
                    return fail(f"invalid json args: {exc}")
                ok(client.request("tools/call", {"name": args.tool, "arguments": call_args}).get("result", {}))
            else:
                return fail(f"unknown action: {args.action}")
        finally:
            client.close()
    except Exception as exc:
        return fail(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
