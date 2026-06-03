#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
bin="./build/linux_x86_64/conductor"
if [ ! -x "$bin" ]; then
  bin="./build/linux_amd64/main"
fi
if [ ! -x "$bin" ]; then
  bin="./build/darwin_arm64/conductor"
fi
if [ ! -x "$bin" ]; then
  bin="./build/linux_arm64/main"
fi
bin="$repo_root/${bin#./}"

out="$("$bin" version --home "$(mktemp -d)")"
grep -q "Conductor" <<<"$out"
out="$("$bin" providers --home "$(mktemp -d)")"
grep -q "openrouter" <<<"$out"
out="$("$bin" models openrouter --home "$(mktemp -d)")"
grep -q "deepseek" <<<"$out"
home="$(mktemp -d)"
out="$("$bin" run "write a test" --home "$home")"
grep -q "mocked=true" <<<"$out"
grep -q "credits=0" <<<"$out"
out="$("$bin" orchestrate "write a test" --home "$home")"
grep -q "## orchestrator" <<<"$out"
grep -q "## reviewer" <<<"$out"
grep -q "credits=0" <<<"$out"
out="$("$bin" session list --home "$home")"
grep -q "write a test" <<<"$out"
out="$("$bin" generate --home "$(mktemp -d)")"
grep -q "Conductor API" <<<"$out"
home="$(mktemp -d)"
out="$("$bin" status --home "$home")"
grep -q "agent=conductor-agent" <<<"$out"
out="$("$bin" permission deny bash --home "$home")"
grep -q "bash = deny" <<<"$out"
out="$("$bin" permission list --home "$home")"
grep -q "bash = deny" <<<"$out"
out="$("$bin" agent use reviewer --home "$home")"
grep -q "Active agent: reviewer" <<<"$out"
out="$("$bin" context add spec "test context" --home "$home")"
grep -q "Context added" <<<"$out"
out="$("$bin" context show --home "$home")"
grep -q "test context" <<<"$out"
out="$("$bin" tools --home "$home")"
grep -q "permission=deny" <<<"$out"
out="$("$bin" doctor --home "$home")"
grep -q "Conductor doctor" <<<"$out"
project="$(mktemp -d)"
out="$(cd "$project" && "$bin" init --home "$home")"
grep -q "Conductor state ready" <<<"$out"

echo "Smoke tests passed."
