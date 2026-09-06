# Kanban Universal Sync + Dual View

AgentAndBot kanban'ı görev verisinin **tek kanonik kaynağı** (single source of truth) olur;
GitHub Issues, Hermes Kanban ve diğer ajanlar opt-in adapter'larla senkronize olur.
Tek veri modeli, iki görünüm: **insan** (özet) ve **agent** (tam detay).

## İlkeler

1. **Tek model, çok projeksiyon.** `tasks` tablosu tek; insan/agent görünümü render/filter katmanı.
2. **AgentAndBot kazanır.** Çift yönlü senkronda çakışmada AB tarafı yazılır, dış sistem üzerine yazar.
3. **Opt-in her şey.** Hiçbir entegrasyon varsayılan açık değil; her biri board/project bazında config.
4. **Yeni ajan = yeni adapter config'i.** Kod yazmadan, manifest ile eklenir.
5. **Dışa insan-görünümü alanları gider.** `summary` dış sistemlere taşınır;
   `technical_context` ve subtask detayları AB'de kalır (field_map ile override edilebilir).

## Veri Modeli (tasks tablosu — eklentiler)

| Alan | Tip | Görünüm | Açıklama |
|---|---|---|---|
| `summary` | text | insan | Tek satır insan-okur özet (ajan üretir) |
| `technical_context` | jsonb | agent | Bağımlılıklar, log/commit ref'leri, dosyalar, teknik notlar |
| `updated_by` | string | agent | Son güncelleyici (`human:ilker`, `agent:hermes`, `sync:github`) |
| `sync_metadata` | jsonb | agent | `{system, external_id, last_synced_at, sync_direction, field_map}` dizisi |
| `sync_state` | string | internal | `in_sync` \| `dirty` \| `conflict` — outbound sync motorunun durumu |

Mevcut alanlar aynen: `parent_id` (subtasks), `events` (audit), `priority`, `team`, `tags`.

## SyncAdapter Arayüzü

```elixir
defmodule AgentbotCore.Modules.Sync.Adapter do
  @moduledoc """
  Universal sync adapter behaviour. Yeni sistem eklemek = bu behaviour'ı
  implemente eden bir modül + `sync_targets` tablosunda bir config satırı.
  """

  @type task :: AgentbotCore.Modules.Marketplace.Task.t()

  @callback id() :: String.t()                    # "github", "hermes", ...
  @callback capabilities() :: %{outbound: boolean(), inbound: boolean()}

  # Outbound: AB -> dış sistem
  @callback push(adapter_state :: map(), task :: task(), opts :: keyword()) ::
              {:ok, external_id :: String.t(), new_state :: map()}
              | {:error, term()}
              | {:skip, reason :: String.t()}

  # Inbound: dış sistem -> AB (poll veya webhook payload)
  @callback pull(state :: map(), since :: DateTime.t() | nil, opts :: keyword()) ::
              {:ok, [inbound_change :: map()], new_state :: map()}

  # Inbound değişikliği AB alanlarına çevir (conflict resolver'dan önce)
  @callback decode(inbound_change :: map()) ::
              %{optional(atom()) => term()} | :ignore
end
```

## Sync Mimarisi

```
Task write (UI / API / agent)
   │
   ├─ TaskEvent log (audit)
   ├─ PubSub broadcast (LiveView)
   └─ SyncEngine.mark_dirty(task_id)          ← her yazma sync_state=dirty yapar
        │
        (Oban worker, 30sn debounce)
        │
   SyncEngine.run(task_id)
        ├─ for target in active_targets(task) │  adapter.push(...)
        ├─ sonuç: external_id + last_synced_at → sync_metadata'e yaz
        ├─ hata: sync_state=conflict + SyncLog'a yaz
        └─ hepsi başarılı: sync_state=in_sync
```

**Inbound** (faz 2, çift yönlü açılınca):
- Webhook (GitHub) veya periyodik poll (Hermes kanban CLI wrapper)
- `decode` → conflict check (`updated_at` + `updated_by` karşılaştır) → AB kazanır
  kuralı: dış değişiklik ancak AB'de task `dirty` değilse uygulanır
- Uygulanan her inbound değişiklik `source_type: "sync:<system>"` ile event log'a düşer

## Field Map (varsayılan)

| AB alanı | GitHub | Hermes |
|---|---|---|
| `title` | issue title | kart title |
| `summary` | issue body (ilk paragraf) | kart body ilk satırı |
| `status` | issue state + label | kart status |
| `assignee` | assignee login | assignee profile |
| `subtasks` | sub-issues (native) | child kartlar (parent ile) |
| `technical_context` | **dışa taşınmaz** | **dışa taşınmaz** |
| `sync_metadata` | **dışa taşınmaz** | **dışa taşınmaz** |

Status eşleme çiftleri config'de (`sync_targets.status_map`):
GitHub: `open→open, assigned/in_progress→progress, review→review, completed→closed, failed→closed`
Hermes: birebir AB durumları.

## Görünüm Katmanı

İnsan görünümü = render filter; agent görünümü = tam serializasyon.

```elixir
# JSON API — iki projeksiyon, tek kaynak
GET /api/kanban/tasks            → human view (summary, status, assignee, progress)
GET /api/kanban/tasks/:id?view=agent → agent view (tam obje + subtasks + technical_context)
GET /api/kanban/tasks?view=agent → agent view (ajanlar programatik erişim)
```

## SyncLog (çakışma/transfer logu)

`sync_logs` tablosu: `task_id, system, direction, outcome, fields, detail, inserted_at`.
Her push/pull bir satır. Conflict resolution uygulanınca `outcome: "ab_won"` / `"external_applied"`.
