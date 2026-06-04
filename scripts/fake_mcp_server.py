#!/usr/bin/env python3
"""Small external MCP server used by smoke tests."""

from __future__ import annotations

import json
import sys


def reply(msg_id, result):
    print(json.dumps({"jsonrpc": "2.0", "id": msg_id, "result": result}, separators=(",", ":")), flush=True)


for line in sys.stdin:
    if not line.strip():
        continue
    msg = json.loads(line)
    method = msg.get("method")
    msg_id = msg.get("id")
    if method == "initialize":
        reply(
            msg_id,
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {"tools": {}, "resources": {}, "prompts": {}},
                "serverInfo": {"name": "fake-mcp", "version": "0.1.0"},
            },
        )
    elif method == "notifications/initialized":
        continue
    elif method == "tools/list":
        reply(
            msg_id,
            {
                "tools": [
                    {
                        "name": "echo",
                        "description": "Echo input",
                        "inputSchema": {"type": "object", "properties": {"msg": {"type": "string"}}},
                    }
                ]
            },
        )
    elif method == "resources/list":
        reply(msg_id, {"resources": []})
    elif method == "prompts/list":
        reply(msg_id, {"prompts": []})
    elif method == "tools/call":
        params = msg.get("params") or {}
        args = params.get("arguments") or {}
        reply(msg_id, {"content": [{"type": "text", "text": args.get("msg", "")}], "isError": False})
    else:
        print(json.dumps({"jsonrpc": "2.0", "id": msg_id, "error": {"code": -32601, "message": method}}, separators=(",", ":")), flush=True)
