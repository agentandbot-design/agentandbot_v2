# DOX framework

- DOX is a highly performant AGENTS.md hierarchy installed in this repository
- Agent must follow DOX instructions across any edits
- This is AgentAndBot — an Elixir/Phoenix "Discord for Agents" platform

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it

## Project Identity

- **What**: AgentAndBot (agentbot_v2) — multi-agent coordination & messaging platform
- **Stack**: Elixir 1.19.5 / OTP 27 / Phoenix 1.8 / Ecto / PostgreSQL
- **Architecture**: Umbrella app (`apps/agentbot_core` + `apps/agentbot_web`)
- **Namespace convention**: `AgentbotCore.Modules.*` for Elixir modules, `AgentAndBot.*` as brand/protocol namespace
- **Dev environment**: Docker container `agentbot-dev` (elixir:1.19.5-otp-27), DB: `core-postgres`
- **GitHub**: https://github.com/agentandbot-design/agentandbot_v2.git

## Global Rules

- **Compile gate**: `mix compile --warnings-as-errors` must pass with zero warnings before any commit
- **Ecto schemas**: See `apps/agentbot_core/lib/agentbot_core/modules/` child AGENTS.md for schema pitfalls
- **Namespace**: Never use `GovernanceCore.*` (legacy). Always `AgentbotCore.Modules.*`
- **Self-reference**: Use `%__MODULE__{}` not `%ModuleName{}` inside the same module
- **Ecto field types**: `:string` not `:text` in schemas. `null: false` goes in migrations, not schemas
- **No Elixir on host**: All mix commands run inside `sudo docker exec agentbot-dev bash -c "cd /app && ..."`
- **Git author**: `Ilker Kaan İpcioğlu <ilkerkaanipcioglu@gmail.com>`

## Read Before Editing

1. Read this root AGENTS.md
2. Identify every file or folder you expect to touch
3. Walk from the repository root to each target path
4. Read every AGENTS.md found along each route
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:

- purpose, scope, ownership, or responsibilities
- durable structure, contracts, workflows, or operating rules
- required inputs, outputs, permissions, constraints, side effects, or artifacts
- user preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

## Hierarchy

- Root AGENTS.md (this file) is the DOX rail: project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index
- Child AGENTS.md files own domain-specific instructions and their own Child DOX Index
- Each parent explains what its direct children cover and what stays owned by the parent
- The closer a doc is to the work, the more specific and practical it must be

## Child Doc Shape

- Create a child AGENTS.md when a folder becomes a durable boundary with its own purpose, rules, responsibilities, workflow, materials, or quality standards

Default section order: Purpose, Ownership, Local Contracts, Work Guidance, Verification, Child DOX Index

## Style

- Keep docs concise, current, and operational
- Document stable contracts, not diary entries
- Put broad rules in parent docs and concrete details in child docs
- Prefer direct bullets with explicit names
- Do not duplicate rules across many files unless each scope needs a local version
- Delete stale notes instead of explaining history

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and any affected parents or children
3. Refresh every affected Child DOX Index
4. Remove stale or contradictory text
5. Run existing verification when relevant
6. Report any docs intentionally left unchanged and why

## User Preferences

- User communicates in Turkish — prefer Turkish for informal/chat messages
- User prefers practical action over lengthy explanations
- Security is a priority (server was previously hacked)

## Verification — Anti-Crash Manifesto

**Quality Gate (her commit/PR'da zorunlu):**
```bash
mix compile --warnings-as-errors  # Sıfır warning
mix credo --strict                 # Sıfır warning
mix test                           # Sıfır failure
```

**CI/CD Pipeline (`.github/workflows/ci.yml`):**
- PostgreSQL 15 service container
- Elixir 1.19.5 / OTP 27
- Otomatik: deps.get → format check → compile → ecto.migrate → credo → test

**Test Coverage (34 test, 0 failure):**
- `EnvelopeTest` — struct oluşturma, JSON round-trip, imza
- `RoomTest` — changeset validation, CRUD, JSON serialization
- `MessageTest` — changeset, create, list_by_room, ordering
- `AuthGateTest` — register/authenticate flow, token failures, capability check

**Test Kuralları:**
- Yeni özellik = yeni test. Test'siz kod main'e merge edilmez.
- DB testleri `AgentbotCore.Test.DataCase` ile sandbox modunda
- `mix test` her test için izole DB kullanır

## Child DOX Index

- `apps/agentbot_core/AGENTS.md` — Core domain: protocol, chat, security, agents modules
- `apps/agentbot_web/AGENTS.md` — Web layer: controllers, router, channels, plugs
- `docs/AGENTS.md` — Architecture docs, design references, phase progress
- `config/AGENTS.md` — Elixir config files per environment
- `docker/AGENTS.md` — Docker dev container setup and compose files
