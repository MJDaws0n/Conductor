# Conductor

Conductor is a CLI-only Novus/Nox terminal agent for coding, planning, tool use, and local session management.

The app runs in OpenRouter test mode by default. Test mode is deterministic, uses no network call, and spends no OpenRouter credits. Live OpenRouter calls require an explicit opt-in flag plus an API key. The default production provider is `deepseek`, pinned to OpenRouter model `deepseek/deepseek-v4-pro` and routed only to the official DeepSeek provider.

## Build

```sh
./scripts/bootstrap_deps.sh
novus main.nov
```

On macOS ARM64 the binary is emitted at:

```sh
./build/darwin_arm64/conductor
```

On Linux x86_64 the binary is emitted at:

```sh
./build/linux_x86_64/conductor
```

## Test

```sh
./scripts/bootstrap_deps.sh
novus tests/test_conductor.nov
./build/darwin_arm64/conductor_tests
./run_smoke_tests.sh
./scripts/prod_check.sh
```

Use the platform-specific test binary under `build/` if you are not on macOS ARM64.

## OpenRouter

Default mode is safe for local development and CI:

```sh
conductor run "write a test"
```

Expected response includes:

```text
mocked=true
credits=0
```

To make a real OpenRouter request:

```sh
conductor env OPENROUTER_API_KEY "sk_..."
conductor env CONDUCTOR_OPENROUTER_LIVE 1
conductor env CONDUCTOR_OPENROUTER_MAX_TOKENS 2048
conductor env CONDUCTOR_OPENROUTER_REASONING_EFFORT minimal
conductor run "summarize this repo"
```

Force test mode even if live flags exist:

```sh
conductor env CONDUCTOR_OPENROUTER_TEST 1
```

Run an optional low-cost live smoke against DeepSeek V4 Pro:

```sh
OPENROUTER_API_KEY="sk_..." ./scripts/live_deepseek_smoke.sh
```

Live `run` and `chat` calls stream OpenRouter tokens to the terminal and still save the final response into the local session.

Provider keys can be configured with Conductor-stored environment values, files, GPG, or OS keyrings:

```sh
conductor providers use deepseek
conductor providers add --name myopen --kind openrouter --conn env:MY_OPENROUTER_KEY
conductor env MY_OPENROUTER_KEY "sk_..."
conductor providers use myopen
```

## Commands

```text
conductor run [message..]
conductor chat
conductor orchestrate [task..]
conductor models [provider] [--verbose]
conductor providers
conductor agent create|list|use|show|current|delete
conductor context show|add|file|clear
conductor env [NAME [VALUE]]
conductor permission list|allow|deny|ask|reset
conductor skill add|import-codex|list|show|enable|disable|context
conductor mcp add|import-codex|list|show|remove|tools|resources|prompts|call|serve-conductor
conductor control state|record-decision|ask-user|end-chat|dispatch-role|compact
conductor session list|delete|resume|cleanup
conductor config check|path
conductor status
conductor tools
conductor doctor
conductor init
conductor stats
conductor import <file>
conductor export [file]
conductor serve [--port N]
conductor generate
conductor version
conductor help
```

## Interactive Shell

```text
Conductor terminal agent shell
agent=conductor-agent  model=deepseek/deepseek-v4-pro
Type /help for commands or just type a prompt.
conductor> /agent use reviewer
conductor> /context add spec Use project tests before final answers
conductor> Explain this project structure
conductor> /exit
```

Seeded specialist agents:

```text
orchestrator
designer
coder
reviewer
```

Local state is stored in `.conductor/` by default. Add `--home /path/to/data` to use another data directory.

## Skills, MCP, And Roles

Conductor supports Codex-style `SKILL.md` files:

```sh
conductor skill add /path/to/SKILL.md
conductor skill import-codex --codex-home ~/.codex
conductor skill list
conductor skill context
```

Enabled skills are injected into role prompts. The skill registry and prompt assembly live in Novus.

External MCP wire communication uses a tiny Python bridge because the current Novus process library does not expose long-lived bidirectional child-process pipes. Conductor-owned MCP behavior, tool schema, policy checks, agent dispatch, and the Conductor MCP server loop stay in Novus:

```sh
conductor mcp add --name fake --command "python3 scripts/fake_mcp_server.py"
conductor mcp add --name remote --url "http://127.0.0.1:39087/mcp" --transport streamable-http
conductor mcp import-codex --config ~/.codex/config.toml
conductor mcp tools fake
conductor mcp call fake echo '{"msg":"hi"}'
conductor mcp serve-conductor
```

`conductor mcp serve-conductor` runs a Novus stdio MCP server from the Conductor binary. Its tools expose session state, role dispatch, user questions, chat end, compaction, decision logging, and skill activation.

`mcp add` and `mcp import-codex` support stdio MCP servers plus URL-based `streamable-http` or `sse` entries. For Codex config imports, Conductor reads `command`, `args`, `[mcp_servers.NAME.env]`, `url`, and `transport`.

Role controls are policy gated:

```sh
conductor control ask-user "Need approval?" --role orchestrator
conductor control compact "original prompt excerpt plus event-id" --role orchestrator
```

Only `orchestrator` can ask the user, end chat, dispatch roles, or compact context. Other roles record a `policy_denied` event. Each role gets separate local context under the session directory, while the session event ledger records dispatches, role input/output, decisions, and policy events.

Compaction is evidence checked. A compaction must be created by `orchestrator`, include the original prompt excerpt, and cite at least one real event id from the session ledger. The saved compaction includes original prompt, summary, and cited evidence.

Automatic compaction is also evidence checked. Set `CONDUCTOR_COMPACT_AFTER_CHARS` for early testing; production default is roughly the 1M-token range:

```sh
conductor env CONDUCTOR_COMPACT_AFTER_CHARS 2000
conductor control compact-auto --role orchestrator
```

## Tools

- AI responses that include lines starting with `TOOL: <tool> <args>` execute allowed tools subject to permissions.
- Run tools manually: `conductor tool run bash "ls -la"`.
- Audit log: `.conductor/audit.log` records tool actions.
