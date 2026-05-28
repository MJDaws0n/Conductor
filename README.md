# Conductor

Conductor is a CLI-only Novus/Nox rebuild target for Kilo Code-style workflows. It is designed as a terminal-first agent app in the same broad family as Copilot CLI, Codex CLI, Claude Code, Aider, and Kilo/OpenCode.

The current implementation is a Novus-native terminal shell with placeholder AI API behavior. The placeholder controller lives in `src/ai_api.nov` so OpenRouter support can be wired in later without changing the command surface.

Run `conductor` with no arguments, or `conductor chat`, to open the fullscreen-style terminal agent shell. Type normal requests to send a placeholder AI turn, or use slash commands such as `/help`, `/agent`, `/model`, `/permissions`, `/tools`, `/sessions`, `/status`, and `/exit`.

The current TUI uses safe line-based input and redraws the whole screen on each turn. It shows slash suggestions when you enter `/`, `/agent`, `/permission`, `/model`, and related prefixes. True live tab-completion while typing would need a raw-mode terminal input library for Novus, so it is intentionally not hacked in yet.

## Build

```sh
nox update
novus main.nov
```

On Linux x86_64 the binary is emitted at:

```sh
./build/linux_x86_64/conductor
```

## Test

```sh
novus tests/test_conductor.nov
./build/linux_x86_64/conductor_tests
./run_smoke_tests.sh
```

## Commands

```text
conductor run [message..]
conductor chat
conductor models [provider] [--verbose]
conductor providers
conductor agent create|list|use|show|current|delete
conductor permission list|allow|deny|ask|reset
conductor mcp list|add
conductor session list|delete
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
conductor palette [slash-prefix]
```

## Interactive shell

```text
+----------------------------------------------------------------------------------------------+
| Conductor fullscreen terminal agent                                      v0.1.0   |
+--------------------------------------------------------+-------------------------------------+
| Active agent: conductor-agent                          | Shortcuts                           |
| Active model: openrouter-placeholder/conductor-dev     | /help      command palette          |
| State: placeholder AI API                              | /agent     manage agents            |
+--------------------------------------------------------+-------------------------------------+
conductor> /agent
conductor> /agent use reviewer
conductor> Explain this project structure
conductor> /exit
```

Available slash-command groups:

```text
/help
/status
/model [provider/model]
/models [provider]
/providers
/agent list|create|use|show
/permissions
/permission allow|deny|ask|reset
/tools
/sessions
/init
/doctor
/clear
/exit
```

Suggestion previews are also available non-interactively:

```sh
conductor palette /agent
conductor palette /permission
```

Local state is stored in `.conductor/` by default. Set `CONDUCTOR_HOME` to use another data directory.
