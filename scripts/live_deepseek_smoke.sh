#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bin="./build/darwin_arm64/conductor"
if [ ! -x "$bin" ]; then bin="./build/linux_x86_64/conductor"; fi
if [ ! -x "$bin" ]; then bin="./build/linux_amd64/main"; fi
if [ ! -x "$bin" ]; then bin="./build/linux_arm64/main"; fi
if [ ! -x "$bin" ]; then
  echo "Conductor binary not found; run novus main.nov first." >&2
  exit 1
fi

if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "OPENROUTER_API_KEY is required." >&2
  exit 1
fi

home="$(mktemp -d)"
cleanup() {
  rm -rf "$home"
}
trap cleanup EXIT

"$bin" status --home "$home" >/dev/null
key_file="$home/openrouter.key"
printf '%s' "$OPENROUTER_API_KEY" >"$key_file"
cat >"$home/providers/deepseek.txt" <<EOF
name=deepseek
kind=openrouter
connection=file:$key_file
provider_only=deepseek
EOF

"$bin" env CONDUCTOR_TEST_MODE 0 --home "$home" >/dev/null
"$bin" env CONDUCTOR_OPENROUTER_TEST 0 --home "$home" >/dev/null
"$bin" env OPENROUTER_MOCK 0 --home "$home" >/dev/null
"$bin" env CONDUCTOR_OPENROUTER_LIVE 1 --home "$home" >/dev/null
"$bin" env CONDUCTOR_OPENROUTER_MAX_TOKENS "${CONDUCTOR_OPENROUTER_MAX_TOKENS:-800}" --home "$home" >/dev/null
"$bin" env CONDUCTOR_OPENROUTER_REASONING_EFFORT "${CONDUCTOR_OPENROUTER_REASONING_EFFORT:-minimal}" --home "$home" >/dev/null

if [ -f "$HOME/.codex/skills/caveman/SKILL.md" ]; then
  "$bin" skill add "$HOME/.codex/skills/caveman/SKILL.md" --home "$home" >/dev/null
fi

out="$("$bin" run --provider deepseek --model deepseek/deepseek-v4-pro --home "$home" \
  'Use caveman full. Design small offline app: kanban plus pomodoro plus habit streaks. Return file plan, state model, 4 tests. <=120 words.')"

grep -q "session:" <<<"$out"
if grep -q "mocked=true" <<<"$out"; then
  echo "Live smoke stayed in mocked mode." >&2
  exit 1
fi
if grep -q "Error:" <<<"$out"; then
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out"
