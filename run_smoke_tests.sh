#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
http_pid=""
cleanup() {
  if [ -n "${http_pid:-}" ]; then
    kill "$http_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

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
grep -q "deepseek" <<<"$out"
grep -q "openrouter" <<<"$out"
out="$("$bin" models deepseek --home "$(mktemp -d)")"
grep -q "deepseek/deepseek-v4-pro" <<<"$out"
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
grep -q "provider=deepseek" <<<"$out"
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

skill_dir="$(mktemp -d)"
cat >"$skill_dir/SKILL.md" <<'EOF'
---
name: smoke-skill
description: Smoke skill
---
Always include smoke skill context.
EOF
out="$("$bin" skill add "$skill_dir/SKILL.md" --home "$home")"
grep -q "Skill added" <<<"$out"
out="$("$bin" skill context --home "$home")"
grep -q "smoke skill context" <<<"$out"
out="$("$bin" skill disable smoke-skill --home "$home")"
grep -q "Skill disabled" <<<"$out"

codex_home="$(mktemp -d)"
mkdir -p "$codex_home/skills/imported-skill"
cat >"$codex_home/skills/imported-skill/SKILL.md" <<'EOF'
---
name: imported-skill
description: Imported smoke skill
---
Imported skill instructions.
EOF
out="$("$bin" skill import-codex --codex-home "$codex_home" --home "$home")"
grep -q "added=1" <<<"$out"
out="$("$bin" skill context --home "$home")"
grep -q "Imported skill instructions" <<<"$out"

chmod +x "$repo_root/scripts/mcp_stdio_bridge.py" "$repo_root/scripts/fake_mcp_server.py" "$repo_root/scripts/fake_http_mcp_server.py"
out="$("$bin" mcp add --name fake --command "python3 $repo_root/scripts/fake_mcp_server.py" --home "$home")"
grep -q "MCP server added" <<<"$out"
out="$("$bin" mcp tools fake --home "$home")"
grep -q "echo" <<<"$out"
out="$("$bin" mcp call fake echo '{"msg":"hi"}' --home "$home")"
grep -q "hi" <<<"$out"

http_port="$((39000 + (RANDOM % 1000)))"
python3 "$repo_root/scripts/fake_http_mcp_server.py" "$http_port" &
http_pid="$!"
sleep 0.2
out="$("$bin" mcp add --name fake-http --url "http://127.0.0.1:$http_port/mcp" --transport streamable-http --home "$home")"
grep -q "MCP server added" <<<"$out"
out="$("$bin" mcp tools fake-http --home "$home")"
grep -q "echo" <<<"$out"
out="$("$bin" mcp call fake-http echo '{"msg":"http-hi"}' --home "$home")"
grep -q "http-hi" <<<"$out"

cat >"$codex_home/config.toml" <<EOF
[mcp_servers.imported_fake]
command = "python3"
args = ["$repo_root/scripts/fake_mcp_server.py"]

[mcp_servers.imported_fake.env]
SMOKE_IMPORT = "1"

[mcp_servers.imported_http]
url = "http://127.0.0.1:$http_port/mcp"
transport = "streamable-http"
EOF
out="$("$bin" mcp import-codex --codex-home "$codex_home" --home "$home")"
grep -q "added=2" <<<"$out"
out="$("$bin" mcp tools imported_fake --home "$home")"
grep -q "echo" <<<"$out"
out="$("$bin" mcp tools imported_http --home "$home")"
grep -q "echo" <<<"$out"

out="$("$bin" orchestrate "control test" --home "$home")"
grep -q "session:" <<<"$out"
state="$("$bin" control state --home "$home")"
event_id="$(grep -o 'event-[0-9][0-9]*-[0-9][0-9]*' <<<"$state" | head -n1)"
test -n "$event_id"
if "$bin" control ask-user "bad role" --role reviewer --home "$home" >/tmp/conductor-smoke-denied.txt 2>&1; then
  echo "reviewer ask-user unexpectedly succeeded" >&2
  exit 1
fi
grep -q "orchestrator-only" /tmp/conductor-smoke-denied.txt
out="$("$bin" control ask-user "continue?" --role orchestrator --home "$home")"
grep -q "QUESTION" <<<"$out"
out="$("$bin" control compact "control test $event_id" --role orchestrator --home "$home")"
grep -q "Compaction saved" <<<"$out"
out="$("$bin" env CONDUCTOR_COMPACT_AFTER_CHARS 1 --home "$home")"
grep -q "Stored env" <<<"$out"
out="$("$bin" control compact-auto --role orchestrator --home "$home")"
grep -q "Auto compaction saved" <<<"$out"

out="$("$bin" mcp add --name conductor-control --command "$bin mcp serve-conductor --home $home" --home "$home")"
grep -q "MCP server added" <<<"$out"
out="$("$bin" mcp tools conductor-control --home "$home")"
grep -q "conductor.ask_user" <<<"$out"
out="$("$bin" mcp call conductor-control conductor.record_decision "{\"role\":\"reviewer\",\"text\":\"mcp decision\"}" --home "$home")"
grep -q "decision recorded" <<<"$out"

echo "Smoke tests passed."
