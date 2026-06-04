#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

find_binary() {
  local name="$1"
  local candidate
  for candidate in \
    "./build/linux_x86_64/$name" \
    "./build/linux_amd64/$name" \
    "./build/darwin_arm64/$name" \
    "./build/linux_arm64/$name"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if [ "$name" = "conductor" ]; then
    for candidate in \
      "./build/linux_x86_64/main" \
      "./build/linux_amd64/main" \
      "./build/darwin_arm64/main" \
      "./build/linux_arm64/main"; do
      if [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  fi
  return 1
}

if ! command -v novus >/dev/null 2>&1; then
  echo "novus not found in PATH" >&2
  exit 1
fi

PYTHONPYCACHEPREFIX="${PYTHONPYCACHEPREFIX:-/tmp/conductor-pyc}" python3 -m py_compile \
  scripts/mcp_stdio_bridge.py \
  scripts/fake_mcp_server.py \
  scripts/fake_http_mcp_server.py

if command -v nox >/dev/null 2>&1; then
  bash scripts/bootstrap_deps.sh
elif [ ! -d lib/std ]; then
  echo "nox not found and bundled lib/std is missing" >&2
  exit 1
fi

novus tests/test_conductor.nov
test_bin="$(find_binary conductor_tests)"
"$test_bin"

novus main.nov
app_bin="$(find_binary conductor)"
out="$("$app_bin" doctor --home "$(mktemp -d)")"
grep -q "active provider: deepseek" <<<"$out"
out="$("$app_bin" models deepseek --home "$(mktemp -d)")"
grep -q "deepseek/deepseek-v4-pro" <<<"$out"

bash run_smoke_tests.sh

key_prefix="sk-or-v1"
if grep -R \
  --exclude-dir=.git \
  --exclude-dir=build \
  --exclude-dir=.conductor \
  --exclude='*.o' \
  --exclude='*.s' \
  --exclude='conductor' \
  --exclude='conductor_tests' \
  "$key_prefix-" .; then
  echo "OpenRouter key material found in repository files" >&2
  exit 1
fi

echo "Production checks passed."
