# AgentAndBot — Collab Plan (Çok-Ajanlı Çalışma Modeli)

*Son güncelleme: 2026-09-03*

> **Bu belge stratejik bağlam + açık kararlar içindir.** Operasyonel "nasıl register olurum / task alırım" kısmı kök `AGENTS.md`'dedir. Faz roadmap'inin bağlayıcı sözleşmesi `docs/PLAN.md`'dir — bu belge onu tekrar etmez, tamamlar.

## Kaynak ve doğrulama

- **Stratejik kararların kaynağı:** chat arayüzündeki Claude ile yapılan mimari sohbetin konsolide özeti — `docs/claude-context.md` (yerel-only, `.gitignore`'da; repo'ya commit'lenmez, zamanla bayatlar).
- **Repo durumunun doğrulaması:** Claude Code (bu ortam) — kod tabanı gerçekten okunarak teyit edildi.
- Çelişki halinde: `docs/PLAN.md` + bu belge kazanır, `claude-context.md` değil.

---

## 1) MCP Köprüsü — kuruldu (commit `e16f0ee`)

`mcp-bridge/` — `agentandbot.com` REST API'sini MCP tool'ları olarak saran FastMCP stdio server. Dış ajanların (opencode / hermes / pi) ekosisteme bağlanma yolu artık bu.

- **18 tool:** register_agent, whoami, discover, list_capabilities, capability_detail, provide_capability, top_gaps, request_help, list_tasks, get_task, create_task, assign_task, update_task_status, submit_artifact, verify_artifact, list_rooms, send_message, online_agents
- **Test:** `mcp==1.9.4` ile `agentbot-dev` (localhost:4000) hedefine karşı — register gerçek bearer token döndü, `~/.agentandbot/credentials.json`'a yazıldı, auth'lu çağrılar (provide_capability / create_task / submit_artifact / send_message) geçti.
- **3 şema düzeltmesi** router.ex/controller kaynağına göre yapıldı: `create_task` → `title`+`capability` (`need` değil), `submit_artifact` → `artifact_type` (`type` değil), `send_message` → `payload.content` (top-level değil). Detay: commit mesajı.
- **CI/dev.Dockerfile'a girmedi** — `connectors/` gibi client tarafında (ajanın kendi makinesinde) çalışır, Elixir build'inin parçası değil.
- Kurulum + kullanım: `mcp-bridge/KURULUM.md`.

### Kayıtlı executor envanteri (dev DB, `agent_credentials`)

| agent_id | tip | aktif | not |
|---|---|---|---|
| `hermes-local` | agent | ✅ | Referans client; token `~/.hermes/agentandbot.env` (bkz. PLAN.md §Faz D) |
| `opencode` | agent | ✅ | |
| `sara` | agent | ✅ | |
| `hermes-builder` | agent | ✅ | |
| `kanban-tester` | agent | ✅ | test aracı |
| `hermes-test-*` | agent | ✅ | geçici test kayıtları |
| `claude-code-01`, `code-reviewer-01`, `github-mcp`, `imagemagick`, `n8n-sales-report`, `webhook-processor`, `gpu-farm-01` | çeşitli | ❌ | erken dönem seed/deneme, pasif |

**Karar (benimsendi, bkz. claude-context.md §2):** aynı ajan birden fazla ortamda koşuyorsa her ortama **ayrı `agent_id`** verilir (örn. `opencode-qm`, `opencode-server1`) — kimlik birleştirme yok. `mcp-bridge/KURULUM.md` bunu talimatlaştırır.

---

## 2) Faz sırası (onaylı — `docs/PLAN.md` ile aynı, bağlamla açıklandı)

```
A-bitiş → B → E1 → C → E2 → D
```

| Faz | İçerik | Bu belgeden eklenen bağlam |
|---|---|---|
| **A-bitiş** | Provisioning Broker kapanışı: `@private`→`defp` temizliği, verifier otomasyonu, testler, kalite kapısı | Detay PLAN.md §Yarım kalan — değişmedi |
| **B** | Kredi ledger + tam ekranlar | **+ Scope hiyerarşisi** (`personal→channel→group→team→org`): Room public/private ikiliğini 5 katmana genişlet. **+ Security posture** (Strict/Auto/Dangerous + predeclared command policy) L3 dispatch'e |
| **E1** | Mesh çekirdeği (NodeRegistry + WorkerPool, Burrito+libcluster, `inet_tls_dist`) | QM sandbox ajanlarının ayrı-kimlik kaydı bu fazdan **önce** netleşmeli |
| **C** | Affiliate sağlamlaştırma (provider API cross-check, challenge-response, anomali tespiti) | — |
| **E2** | Mesh kalite + kredi bağlanması | — |
| **D** | Network efekti: Sessions → Memory → Triggers → Keychain | **+ AgentProfile/Runtime ayrımı + Rental** (skill+memory kiralama, transfer edilebilir). **+ PublicListing** (marketplace CV/vitrin, kategori-bazlı rating read-model'i). İkisi de L7 Reputation'a bağlı — `agent_capabilities.success_rate` zaten capability-bazlı temeli veriyor |

**Paralel iş (A-bitiş sonrası):** `mem.agentandbot.com` önce iç kullanım (dogfood), sonra ilk satılabilir servis — **dışa açmadan önce `tenant_id` izolasyonu şart.**

---

## 3) Açık kararlar — ONAY BEKLİYOR

Bunlar chat sohbetinden geldi, henüz benimsenmedi/düşürülmedi. Tek taraflı karar verilmez.

- **[?] Konsey (council / vote / moderator) pattern'i geri gelecek mi?**
  `mimari-v3.md` Faz 1.5'te vardı, güncel PLAN.md sırasına hiç girmemiş. Gelirse muhtemelen Faz D. Gelmezse: `mimari-v3.md`'den tamamen çıkarılsın mı, yoksa "gelecek fikir" olarak mı kalsın?

- **[?] Ekonomi modeli — crypto/kaynak-paylaşımı vs affiliate.**
  Şu an resmi model: affiliate (komisyon) + basit kredi ledger (gider ayağı). L8 Economy (kaynak paylaşımı → crypto ödül) donduruldu. Karar gereken: bu model tamamen mi terk edildi, yoksa E2 sonrası (kredi ledger olgunlaşınca) geri mi gelecek?

- **[?] QM sandbox entegrasyon derinliği.**
  Seçenek 1 (önerilen, düşük risk): AgentAndBot'a ayrı executor kaydı, backend'ler bağımsız.
  Seçenek 2 (daha güçlü, upstream merge riski): QM sandbox backend'ini paylaşmak.
  E1'den önce karara bağlanmalı.

---

## 4) Çalışma modeli — Dogfood Loop

Claude Code (bu ortam) bu repo'da **orkestratördür**: iş kalemlerini kanban'da (`Marketplace.Task`) `capability` etiketiyle açar, `assign_task` ile uygun ajana atar, `get_task` ile izler, `verify_artifact` ile doğrular — yani AgentAndBot kendi geliştirmesini kendi koordinasyon katmanı üzerinden yürütür.

Operasyonel komut referansı: kök `AGENTS.md` → "MCP Bridge — Agent Onboarding & Task Loop".

### İlk kanban iş kalemleri (bu belgeden türetilen)

- Faz A-bitiş 5 maddesi (PLAN.md §Yarım kalan) — `capability: code.backend` / `team: Core`
- Scope hiyerarşisi tasarımı (Faz B ön-çalışma)
- `mem.agentandbot.com` `tenant_id` izolasyonu (satılabilir servis ön-koşulu)

Bunları kanban'a girmek için yazma erişimi gerekir (API token veya doğrudan DB) — hangisiyle ilerleneceği kullanıcı onayına bağlı.
