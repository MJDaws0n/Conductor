#!/usr/bin/env python3
"""MCP stdio communicator for Conductor control.

This file owns transport only. Tool schema, policy checks, role dispatch,
context writes, and compaction checks are implemented by the Conductor Novus
binary via `conductor mcp conductor-*-json` entrypoints.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys


def run_json(conductor: str, home: str, subcommand: str, *extra: str) -> object:
    cmd = [conductor, "mcp", subcommand, *extra, "--home", home]
    out = subprocess.check_output(cmd, text=True)
    return json.loads(out)


def reply(msg_id, result) -> None:
    print(json.dumps({"jsonrpc": "2.0", "id": msg_id, "result": result}, separators=(",", ":")), flush=True)


def error(msg_id, code: int, message: str) -> None:
    print(json.dumps({"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}}, separators=(",", ":")), flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--conductor", required=True)
    parser.add_argument("--home", required=True)
    args = parser.parse_args()

    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            msg = json.loads(line)
            msg_id = msg.get("id")
            method = msg.get("method")
            if method == "initialize":
                reply(
                    msg_id,
                    {
                        "protocolVersion": "2025-06-18",
                        "capabilities": {"tools": {}, "resources": {}, "prompts": {}},
                        "serverInfo": {"name": "conductor-control", "version": "0.1.0"},
                    },
                )
            elif method == "notifications/initialized":
                continue
            elif method == "shutdown":
                reply(msg_id, None)
            elif method == "exit":
                return 0
            elif method == "tools/list":
                reply(msg_id, run_json(args.conductor, args.home, "conductor-tools-json"))
            elif method == "resources/list":
                reply(msg_id, run_json(args.conductor, args.home, "conductor-resources-json"))
            elif method == "prompts/list":
                reply(msg_id, run_json(args.conductor, args.home, "conductor-prompts-json"))
            elif method == "tools/call":
                params = msg.get("params") or {}
                tool = params.get("name", "")
                tool_args = json.dumps(params.get("arguments") or {}, separators=(",", ":"))
                reply(msg_id, run_json(args.conductor, args.home, "conductor-call-json", tool, tool_args))
            else:
                error(msg_id, -32601, f"method not found: {method}")
        except Exception as exc:
            error((json.loads(line).get("id") if line.strip().startswith("{") else None), -32000, str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
