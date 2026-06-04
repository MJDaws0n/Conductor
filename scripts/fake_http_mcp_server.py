#!/usr/bin/env python3
"""Small streamable-HTTP style MCP server used by smoke tests."""

from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


def result_for(method: str, params: dict | None) -> dict:
    if method == "initialize":
        return {
            "protocolVersion": "2025-06-18",
            "capabilities": {"tools": {}, "resources": {}, "prompts": {}},
            "serverInfo": {"name": "fake-http-mcp", "version": "0.1.0"},
        }
    if method == "tools/list":
        return {
            "tools": [
                {
                    "name": "echo",
                    "description": "Echo input over HTTP",
                    "inputSchema": {"type": "object", "properties": {"msg": {"type": "string"}}},
                }
            ]
        }
    if method == "resources/list":
        return {"resources": []}
    if method == "prompts/list":
        return {"prompts": []}
    if method == "tools/call":
        params = params or {}
        args = params.get("arguments") or {}
        return {"content": [{"type": "text", "text": args.get("msg", "")}], "isError": False}
    return {}


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        data = json.loads(self.rfile.read(length) or b"{}")
        if "id" not in data:
            self.send_response(202)
            self.end_headers()
            return
        body = json.dumps(
            {"jsonrpc": "2.0", "id": data.get("id"), "result": result_for(data.get("method", ""), data.get("params"))},
            separators=(",", ":"),
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: object) -> None:
        return


def main() -> int:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 39087
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
