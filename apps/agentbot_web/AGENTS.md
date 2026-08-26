# agentbot_web

## Purpose

HTTP/WebSocket layer — Phoenix endpoint, router, controllers, channels, and plugs. Depends on agentbot_core for all business logic.

## Ownership

- `lib/agentbot_web/endpoint.ex` — Phoenix endpoint (parsers, session, router plug)
- `lib/agentbot_web/router.ex` — All route definitions
- `lib/agentbot_web/controllers/` — REST controllers (health, well_known, agent, envelope, room, error)
- `lib/agentbot_web/channels/` — WebSocket channels (room_channel)
- `lib/agentbot_web/plugs/` — AuthPlug (token verification), QmSsoPlug (QM ortak giriş)
- `lib/agentbot_web/views/` — ErrorView for JSON error rendering

## Local Contracts

- **No scope alias**: `scope "/api" do` — NOT `scope "/api", AgentbotWeb do` (causes double namespace `AgentbotWeb.AgentbotWeb.*`)
- **Controller macro**: `use Phoenix.Controller, formats: [json: AgentbotWeb.ErrorView]` — NOT `namespace: AgentbotWeb` (Phoenix 1.8)
- **Auth**: AuthPlug reads `Authorization: Bearer <token>` header, validates via `AuthGate.authenticate/1`
- **404 catch-all**: `match :*, "/*path", AgentbotWeb.ErrorController, :not_found` — NOT `"*"`
- **JSON only**: All endpoints return JSON. No HTML views except ErrorView for error rendering
- **QmSsoPlug**: `portal_session` cookie'sini doğrulup `conn.assigns.current_account` atar (:browser ve :account pipeline'larında). Cookie yoksa istek anonim devam eder
- **Çoklu Set-Cookie**: Plug aynı isimli başlığı tekilleştirir; iki ayrı cookie silme başlığı gerekiyorsa `register_before_send` içinde resp_headers elle güncellenir (bkz. AccountController.logout/2)

## Work Guidance

### API routes
- `GET /health` — no auth
- `GET /.agent-well-known/skill` — no auth, agent discovery
- `POST /api/agents/connect` — auth required
- `POST /api/envelope` — auth required
- `GET /api/rooms` — no auth (public API)
- `POST /api/rooms` — no auth (public API)
- `GET /me` — QM ortak giriş durumu (JSON; 401 + login_url anonimse)
- `POST /auth/logout` — paylaşılan portal_session cookie'sini siler (Domain'li + hostsuz)

### Adding a new controller
1. Create in `controllers/`
2. `use AgentbotWeb, :controller`
3. Add route in `router.ex` (no scope alias)
4. Return JSON via `json(conn, ...)`

## Verification

- `curl http://localhost:4000/health` → `database: ok`
- `curl http://localhost:4000/.agent-well-known/skill` → skill card with protocols + capabilities

## Child DOX Index

- No child AGENTS.md files needed. Controllers are self-documenting via @moduledoc.
