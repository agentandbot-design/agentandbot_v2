# config

## Purpose

Elixir configuration files per environment (dev, test, prod, runtime).

## Ownership

- `config.exs` — Base config for all environments
- `dev.exs` — Dev: DB connection to `core-postgres`, debug logging
- `test.exs` — Test: in-memory or test DB
- `prod.exs` — Production defaults
- `runtime.exs` — Runtime config (env vars, deployment)

## Local Contracts

- DB hostname: `core-postgres` (Docker network)
- DB credentials: `postgres/postgres` for dev
- Endpoint: port 4000, ip `{0,0,0,0}`
- PubSub server: `AgentbotWeb.PubSub`

## Child DOX Index

- No child AGENTS.md files needed.
