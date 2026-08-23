# agentbot_core

## Purpose

Core domain logic of AgentAndBot — protocol envelopes, chat rooms, agent gateway, security, and PubSub. No HTTP/WebSocket layer here (that's agentbot_web).

## Ownership

- This is the business rule layer. All domain modules live under `lib/agentbot_core/modules/`.
- `lib/agentbot_core/application.ex` — OTP supervisor tree (Repo + PubSub)
- `lib/agentbot_core/repo.ex` — Ecto repository
- `lib/agentbot_core/pubsub.ex` — Phoenix.PubSub wrapper

## Local Contracts

- **Namespace**: `AgentbotCore.Modules.{Protocol,Chat,Security,Agents}`
- **PubSub**: Always use `AgentbotCore.PubSub.broadcast/3` — never call `Phoenix.PubSub` directly
- **Schemas**: Ecto schemas use `:string` (not `:text`). Validation goes in changesets, not field definitions
- **Self-reference**: Use `__MODULE__` not bare module name inside the same module
- **belongs_to**: Never declare `field :room_id, :id` when `belongs_to :room, Room` exists (auto-generates `room_id`)

## Work Guidance

### Adding a new schema
1. Create migration in `priv/repo/migrations/`
2. Create schema module in `modules/<domain>/`
3. Use `__MODULE__` for self-references in queries
4. Run `mix ecto.migrate` inside container

### Module domains
- `modules/protocol/` — Envelope struct, WellKnown discovery, EventTaxonomy, ProtocolCatalog
- `modules/chat/` — Room, Message, ApprovalRequest, RoomServer, RoomSupervisor, RoomRegistry
- `modules/security/` — AuthGate, AgentCredential, CapabilityCheck
- `modules/registry/` — Capability, AgentCapability, CapabilityGap, ExecutorResource, McpServer

## Verification

- `mix compile --warnings-as-errors` from `/app` inside container
- `mix ecto.migrate` — all migrations apply

## Child DOX Index

- No child AGENTS.md files needed yet. Module-level docs are in `lib/agentbot_core/modules/` source files via @moduledoc.
