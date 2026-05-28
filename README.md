# Conductor

Conductor is a CLI-only Novus/Nox rebuild target for Kilo Code-style workflows. It is designed as a terminal-first agent app in the same broad family as Copilot CLI, Codex CLI, Claude Code, Aider, and Kilo/OpenCode.

The current implementation is a Novus-native terminal shell with placeholder AI API behavior. The placeholder controller lives in `src/ai_api.nov` so OpenRouter support can be wired in later without changing the command surface.

Run `conductor` with no arguments, or `conductor chat`, to open the normal terminal shell. Type requests to send a placeholder AI turn, or use slash commands such as `/help`, `/agent`, `/model`, `/permissions`, `/tools`, `/sessions`, `/status`, and `/exit`.

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
```

## Interactive shell

```text
Conductor terminal agent shell
agent=conductor-agent  model=openrouter-placeholder/conductor-dev
Type /help for commands or just type a prompt.
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

Local state is stored in `.conductor/` by default. Set `CONDUCTOR_HOME` to use another data directory.

OpenRouter & providers

- Configure an OpenRouter API key in your environment: `export OPENROUTER_API_KEY="sk_..."`
- Or add a provider: `conductor providers add myopen openrouter env:MY_OPENROUTER_KEY` and then `conductor providers use myopen`.
- Encrypted local keys supported via `gpg:/path/to/key.gpg` (Conductor will run `gpg --decrypt` to read the key).
- OS keyring supported via `keyring:<name>` (Conductor will try libsecret's `secret-tool lookup conductor <name>` on Linux, or `security find-generic-password -s conductor -a <name> -w` on macOS).
  - Store on Linux (libsecret):
    ```sh
    secret-tool store conductor mykey
    # then paste the secret when prompted
    ```
  - Store on macOS:
    ```sh
    security add-generic-password -s conductor -a mykey -w "THE_SECRET"
    ```
- Preference: environment variables are recommended for automation and CI.

Tools & auto-run

- AI responses that include lines starting with `TOOL: <tool> <args>` will auto-execute allowed tools (subject to permissions).
- Run tools manually: `conductor tool run bash "ls -la"`.
- Audit log: `.conductor/audit.log` records executed tool actions.
