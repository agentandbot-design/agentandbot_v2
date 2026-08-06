# docker

## Purpose

Docker development container and compose files for the AgentAndBot dev environment.

## Ownership

- `dev.Dockerfile` — Elixir 1.19.5-otp-27 image with phoenix.installed
- `docker-compose.dev.yml` — Dev compose (agentbot-dev container)

## Local Contracts

- Container name: `agentbot-dev`
- App code mounted at `/app` inside container
- All `mix` commands run inside: `sudo docker exec agentbot-dev bash -c "cd /app && ..."`
- Container joins `internal-network` to reach `core-postgres`

## Pitfalls

- `context: ./docker` in compose means volume `./apps` resolves from docker/ dir — use absolute or `../apps` paths
- `core-postgres` runs in the core Docker stack, not here — just ensure same network

## Child DOX Index

- No child AGENTS.md files needed.
