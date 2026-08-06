# AgentAndBot Phase 0 — İlerleme Takibi

> Başlangıç: 2026-08-06
> Hedef: Skill okuyan herhangi bir agent odaya bağlanıp mesajlaşıyor

## Madde Listesi

| # | Görev | Durum | Tarih | Not |
|---|-------|-------|------|-----|
| 1 | Phoenix app `agentbot_core` + `agentbot_web` oluştur | ✅ Bitti | 06.08 | Umbrella app, namespace AgentbotCore.Modules.* |
| 2 | DB migrations (agents, rooms, messages, approvals, personas) | ✅ Bitti | 06.08 | 4 migration: rooms, messages, agent_credentials, approval_requests |
| 3 | Envelope struct + codec | ✅ Bitti | 06.08 | MCP/A2A uyumlu, JSON serialize/deserialize, imza placeholder |
| 4 | WellKnown controller (GET /.agent-well-known/skill) | ✅ Bitti | 06.08 | 11 protokol, 7 capability, 15 event type |
| 5 | AuthGate + token register/login | ✅ Bitti | 06.08 | Token-based (SHA256 hash), Ed25519 Phase 2'ye |
| 6 | RoomServer GenServer (ETS state) | ✅ Bitti | 06.08 | Agents map, message_count, dual PubSub broadcast |
| 7 | RoomSupervisor + RoomRegistry | ✅ Bitti | 06.08 | DynamicSupervisor + Registry supervision tree'de |
| 8 | Dual PubSub (agent: + human: topics) | ✅ Bitti | 06.08 | AgentbotCore.PubSub wrapper, room: ve human: topic'leri |
| 9 | MessagePipeline Broadway | ⬜ Bekliyor | | Broadway dependency eklenecek |
| 10 | EventTaxonomy + ProtocolCatalog | ✅ Bitti | 06.08 | Eski kod 35207f6'dan port edildi |
| 11 | AgentGateway (auth → join → send) | ✅ Bitti | 06.08 | connect/send_envelope/disconnect, error handling |
| 12 | AgentRoomChannel WebSocket | ✅ Bitti | 06.08 | UserSocket + RoomChannel, join, message, agent_event |
| 13 | REST API (rooms, messages, agents) | ✅ Bitti | 06.08 | CRUD + JSON serialization, tüm endpoint'ler test edildi |
| 14 | mix compile temiz + test geçsin | ✅ Bitti | 06.08 | --warnings-as-errors: sıfır warning |

## API Durumu (06.08.2026)

| Endpoint | Method | Auth | Durum |
|----------|--------|------|-------|
| `/health` | GET | Yok | ✅ `database: ok` |
| `/.agent-well-known/skill` | GET | Yok | ✅ Skill card döndü |
| `/.agent-well-known/agent.json` | GET | Yok | ✅ Agent card döndü |
| `/.agent-well-known/protocols` | GET | Yok | ✅ 11 protokol |
| `/api/rooms` | GET | Yok | ✅ Aktif odaları listele |
| `/api/rooms` | POST | Yok | ✅ Oda oluştur |
| `/api/rooms/:id/messages` | GET | Yok | ✅ Oda mesajları |
| `/api/agents/connect` | POST | Token | ✅ Agent bağlan |
| `/api/agents/disconnect` | POST | Token | ✅ Agent çık |
| `/api/envelope` | POST | Token | ✅ Envelope gönder |
| `/socket/websocket` | WS | Yok | ✅ WebSocket (room:* channel) |

## Günlük Notlar

### 2026-08-06
- Dizayn dokümanı tamamlandı
- Phase 0 planı oluşturuldu
- Eski kod analizi yapıldı (35207f6 commit)
- 16 modül belirlendi
- Günlük hatırlatma cron job'ı ayarlandı
- Phoenix umbrella app oluşturuldu (agentbot_core + agentbot_web)
- 4 DB migration yazıldı ve migrate edildi
- Tüm core modüller yazıldı: Protocol, Chat, Security, Agents
- WebSocket (UserSocket + RoomChannel) eklendi
- Dual PubSub (room: + human:) implement edildi
- AgentbotCore.PubSub wrapper modülü oluşturuldu
- RoomSupervisor + RoomRegistry supervision tree'ye eklendi
- @derive Jason.Encoder tüm schema'lara eklendi
- DOX framework entegre edildi (6 AGENTS.md)
- GitHub: https://github.com/agentandbot-design/agentandbot_v2.git
- **Phase 0: 13/14 tamamlandı** (MessagePipeline Broadway hariç)

## Sıradaki Adımlar

1. **MessagePipeline (Broadway)** — MCP olaylarını back-pressure ile işle
2. **Phase 1'e geçiş** — LiveView UI, human messaging, LLM summary
3. **Agent auth flow test** — Token register → connect → send envelope
