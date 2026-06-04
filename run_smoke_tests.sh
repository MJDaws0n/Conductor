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
grep -q "Conductor is the AI coding-agent wrapper" <<<"$out"
grep -q "Do not document Conductor" <<<"$out"
grep -q "Thinking: Streaming model response" <<<"$out"
out="$("$bin" tool run list_files "$repo_root" --home "$home")"
grep -q "src" <<<"$out"
build_project="$(mktemp -d)"
out="$("$bin" run "Please work in $build_project folder, and build a python app for a login / signup terminal application. It should store user creds, have usernames, passwords, and settings so that stuff can be changed, and passwords should be hashed. Admin accounts can see users in tables and edit delete them." --home "$(mktemp -d)")"
grep -q "## Orchestrator" <<<"$out"
grep -q "## Code Designer" <<<"$out"
grep -q "## Coder" <<<"$out"
grep -q "## Reviewer" <<<"$out"
grep -q "Wrote $build_project/app.py" <<<"$out"
test -f "$build_project/app.py"
test -f "$build_project/README.md"
app_check="$(python3 "$build_project/app.py" --self-test)"
grep -q "SELF_TEST_OK" <<<"$app_check"
portfolio_project="$(mktemp -d)"
out="$("$bin" run "Please work in $portfolio_project to build a stunning html + css + js website, it should just be a single paged website with tabs. It's a portfolio for MJDawson, a developer, whoes github is mjdaws0n. You can add placeholder information." --home "$(mktemp -d)")"
grep -q "Thinking: Interpreting" <<<"$out"
grep -q "## Orchestrator" <<<"$out"
grep -q "Wrote $portfolio_project/index.html" <<<"$out"
test -f "$portfolio_project/index.html"
test -f "$portfolio_project/styles.css"
test -f "$portfolio_project/script.js"
grep -q "mjdaws0n" "$portfolio_project/index.html"
grep -q "styles.css" "$portfolio_project/index.html"
grep -q "script.js" "$portfolio_project/index.html"
todo_project="$(mktemp -d)"
out="$("$bin" run "Work in $todo_project please folder. Build a Python command-line application that lets users manage a personal to-do list. The app should be split into logical modules." --home "$(mktemp -d)")"
grep -q "## Orchestrator" <<<"$out"
grep -q "## Code Designer" <<<"$out"
grep -q "Wrote $todo_project/main.py" <<<"$out"
test -f "$todo_project/main.py"
test -f "$todo_project/tasks.py"
test -f "$todo_project/storage.py"
test -f "$todo_project/cli.py"
test -f "$todo_project/README.md"
todo_check="$(python3 "$todo_project/main.py" --self-test)"
grep -q "SELF_TEST_OK" <<<"$todo_check"
todo_chat_project="$(mktemp -d)"
out="$(printf '%s\n' \
  "Work in $todo_chat_project please folder. Build a Python command-line application that lets users manage a personal to-do list. The app should be split into logical modules:" \
  "" \
  "- main.py: entry point that parses commands and delegates work." \
  "" \
  "- tasks.py: defines a Task class and functions to add, list, edit, and delete tasks." \
  "" \
  "- storage.py: handles saving and loading tasks from a local sqlite database (tasks(id, title, description, due_date, completed))." \
  "" \
  "- cli.py: contains helper functions for prompting users and displaying task lists." \
  "" \
  "- README.md: provides install/run instructions and a description of each module." \
  "" \
  "Users should be able to add tasks with titles, descriptions, and optional due dates; list upcoming and completed tasks; mark tasks as completed; edit or delete tasks; and exit the program. Store data persistently via sqlite so the tasks are available on the next run." \
  "/exit" | "$bin" chat --home "$(mktemp -d)")"
grep -q "Wrote $todo_chat_project/main.py" <<<"$out"
if grep -q "You: - main.py" <<<"$out"; then
  echo "chat paste continuation was treated as a separate prompt" >&2
  exit 1
fi
todo_chat_check="$(python3 "$todo_chat_project/main.py" --self-test)"
grep -q "SELF_TEST_OK" <<<"$todo_chat_check"
out="$("$bin" orchestrate "write a test" --home "$home")"
grep -q "## Orchestrator" <<<"$out"
grep -q "## Code Designer" <<<"$out"
grep -q "## Reviewer" <<<"$out"
grep -q "credits=0" <<<"$out"
out="$("$bin" session list --home "$home")"
grep -q "write a test" <<<"$out"
resume_home="$(mktemp -d)"
out="$("$bin" run "resume smoke prompt" --home "$resume_home")"
sid="$(awk '/session:/ {print $2}' <<<"$out" | tail -n1)"
test -n "$sid"
out="$(printf '/exit\n' | "$bin" resume "$sid" --home "$resume_home")"
grep -q "session: $sid" <<<"$out"
grep -q "Chat history" <<<"$out"
grep -q "You: resume smoke prompt" <<<"$out"
grep -q "Conductor:" <<<"$out"
grep -q "Goodbye." <<<"$out"
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
