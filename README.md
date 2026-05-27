# Conductor

Conductor is a CLI-only Novus/Nox rebuild target for Kilo Code-style workflows.

The current implementation is a Novus-native command shell with placeholder AI API behavior. The placeholder controller lives in `src/ai_api.nov` so OpenRouter support can be wired in later without changing the command surface.

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
conductor models [provider] [--verbose]
conductor providers
conductor agent create|list
conductor mcp list|add
conductor session list|delete
conductor config check|path
conductor stats
conductor import <file>
conductor export [file]
conductor serve [--port N]
conductor generate
conductor version
conductor help
```

Local state is stored in `.conductor/` by default. Set `CONDUCTOR_HOME` to use another data directory.
