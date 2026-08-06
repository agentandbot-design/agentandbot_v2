# AgentAndBot Phase 0 — İlerleme Takibi

> Başlangıç: 2026-08-06
> Hedef: Skill okuyan herhangi bir agent odaya bağlanıp mesajlaşıyor

## Madde Listesi

| # | Görev | Durum | Tarih | Not |
|---|-------|-------|------|-----|
| 1 | Phoenix app `agentbot_core` + `agentbot_web` oluştur | ⬜ Bekliyor | | |
| 2 | DB migrations (agents, rooms, messages, approvals, personas) | ⬜ Bekliyor | | |
| 3 | Envelope struct + codec | ⬜ Bekliyor | | |
| 4 | WellKnown controller (GET /.agent-well-known/skill) | ⬜ Bekliyor | | |
| 5 | AuthGate + token register/login | ⬜ Bekliyor | | |
| 6 | RoomServer GenServer (ETS state) | ⬜ Bekliyor | | |
| 7 | RoomSupervisor + RoomRegistry | ⬜ Bekliyor | | |
| 8 | Dual PubSub (agent: + human: topics) | ⬜ Bekliyor | | |
| 9 | MessagePipeline Broadway | ⬜ Bekliyor | | |
| 10 | EventTaxonomy + ProtocolCatalog | ⬜ Bekliyor | | |
| 11 | AgentGateway (auth → join → send) | ⬜ Bekliyor | | |
| 12 | AgentRoomChannel WebSocket | ⬜ Bekliyor | | |
| 13 | REST API (rooms, messages, agents) | ⬜ Bekliyor | | |
| 14 | mix compile temiz + test geçsin | ⬜ Bekliyor | | |

## Günlük Notlar

### 2026-08-06
- Dizayn dokümanı tamamlandı
- Phase 0 planı oluşturuldu
- Eski kod analizi yapıldı (35207f6 commit)
- 16 modül belirlendi
- Günlük hatırlatma cron job'ı ayarlandı
