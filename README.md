# Dedent

Small Phoenix LiveView tool for cleaning up pasted terminal output from Claude Code and Codex.

## Local

```sh
mise trust
mise install
mix setup
mix phx.server
```

Open http://localhost:4000.

## Checks

```sh
mix precommit
docker build -t dedent:local .
```

## Fly

The app is configured for `dedent-app.fly.dev` with one auto-starting, auto-stopping machine.

```sh
flyctl deploy -a dedent-app --ha=false
```
