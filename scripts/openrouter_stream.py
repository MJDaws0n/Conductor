#!/usr/bin/env python3
"""Stream OpenRouter chat-completion deltas to stdout.

Conductor keeps provider/session/tool control in Novus. This helper handles
SSE parsing because current Novus process APIs do not expose incremental pipe
reads from child processes.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def fail(message: str) -> int:
    print(f"Error: {message}", file=sys.stderr)
    return 1


def stream(args: argparse.Namespace) -> int:
    payload_path = Path(args.payload)
    key = Path(args.key_file).read_text(encoding="utf-8").strip()
    payload = json.loads(payload_path.read_text(encoding="utf-8"))
    payload["stream"] = True

    req = urllib.request.Request(
        args.url,
        data=json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "HTTP-Referer": "https://github.com/MJDaws0n/Conductor",
            "X-Title": "Conductor",
        },
        method="POST",
    )

    parts: list[str] = []
    try:
        with urllib.request.urlopen(req, timeout=args.timeout) as resp:
            for raw_line in resp:
                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if not data or data == "[DONE]":
                    continue
                try:
                    event = json.loads(data)
                except json.JSONDecodeError:
                    continue
                choices = event.get("choices") or []
                if not choices:
                    continue
                delta = choices[0].get("delta") or choices[0].get("message") or {}
                content = delta.get("content") or ""
                if content:
                    print(content, end="", flush=True)
                    parts.append(content)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        return fail(f"HTTP {exc.code} - {detail}")
    except Exception as exc:
        return fail(str(exc))

    text = "".join(parts).strip()
    Path(args.out).write_text(text, encoding="utf-8")
    print("", flush=True)
    if not text:
        return fail("OpenRouter stream completed without assistant content")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--payload", required=True)
    parser.add_argument("--key-file", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--url", default="https://openrouter.ai/api/v1/chat/completions")
    parser.add_argument("--timeout", type=float, default=120.0)
    return stream(parser.parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
