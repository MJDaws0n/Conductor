#!/usr/bin/env bash
set -euo pipefail

bin="./build/linux_x86_64/conductor"
if [ ! -x "$bin" ]; then
  bin="./build/linux_amd64/main"
fi
if [ ! -x "$bin" ]; then
  bin="./build/linux_arm64/main"
fi

out="$(CONDUCTOR_HOME="$(mktemp -d)" "$bin" version)"
grep -q "Conductor" <<<"$out"
out="$(CONDUCTOR_HOME="$(mktemp -d)" "$bin" providers)"
grep -q "openrouter-placeholder" <<<"$out"
out="$(CONDUCTOR_HOME="$(mktemp -d)" "$bin" models openrouter-placeholder)"
grep -q "conductor-dev" <<<"$out"
home="$(mktemp -d)"
out="$(CONDUCTOR_HOME="$home" "$bin" run "write a test")"
grep -q "Placeholder AI response" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" session list)"
grep -q "write a test" <<<"$out"
out="$(CONDUCTOR_HOME="$(mktemp -d)" "$bin" generate)"
grep -q "Conductor API" <<<"$out"
home="$(mktemp -d)"
out="$(CONDUCTOR_HOME="$home" "$bin" status)"
grep -q "agent=conductor-agent" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" permission deny bash)"
grep -q "bash = deny" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" permission list)"
grep -q "bash = deny" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" agent create --name reviewer --description "reviews code")"
grep -q "Agent created" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" agent use reviewer)"
grep -q "Active agent: reviewer" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" tools)"
grep -q "permission=deny" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" doctor)"
grep -q "Conductor doctor" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" init)"
grep -q "Conductor state ready" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" palette /agent)"
grep -q "/agent use" <<<"$out"
out="$(CONDUCTOR_HOME="$home" "$bin" palette /permission)"
grep -q "/permission deny" <<<"$out"

echo "Smoke tests passed."
