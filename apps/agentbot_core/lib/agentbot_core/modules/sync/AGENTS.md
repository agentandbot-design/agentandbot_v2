# sync

## Purpose

Universal kanban sync — AgentAndBot tek kaynak (source of truth), dış sistemler yansıma.
GitHub Issues + Hermes Kanban adapter'ları; opt-in, `sync_targets` tablosuyla config'lenir.

## Ownership

- `adapter.ex` — SyncAdapter behaviour (yeni sistem = yeni adapter modülü + sync_targets satırı)
- `sync.ex` — motor: mark_dirty → Oban → run; apply_inbound (AB kazanır kuralı)
- `sync_log.ex` — her push/pull işleminin şeffaflık kaydı (ab_won/external_applied)
- `sync_target.ex` — board/project bazlı config: direction (off/outbound/inbound/two_way), trigger, field_map
- `github_adapter.ex` — Issues push/pull; summary → issue body; technical_context dışa taşınmaz
- `hermes_adapter.ex` — hermes kanban CLI wrapper; ab_id haritalaması body'de

## Local Contracts

- **Dışa insan-görünümü alanları gider**: title/summary/status/assignee/subtasks. `technical_context` ve `sync_metadata` asla dışarı çıkmaz.
- **Çakışma**: AB kazanır. Dış değişiklik yalnız `sync_state == "in_sync"` iken uygulanır; dirty/conflict'te reddedilir ve SyncLog'a "ab_won" düşer.
- **Adapter'lar stateless**: kalıcı durum `sync_targets.state`'te.
- **Yeni adapter**: `@adapters` map'ine ekle (sync.ex) — config tablodan okunur.
- **find_by_external_id**: order_by desc updated_at + limit 1 — duplicate external_id'lerde en güncel kazanır.

## Dual View

`Marketplace.TaskView` — tek task objesi, iki projeksiyon: `human/2` (özet + progress, teknik detay yok) ve `agent/2` (tam serializasyon). API: `?view=agent` parametresi (default human).

## Verification

- `MIX_ENV=test mix test apps/agentbot_core/test/agentbot_core/modules/sync_test.exs`
- `mix compile --warnings-as-errors`

## Child DOX Index

- No child AGENTS.md files needed.
