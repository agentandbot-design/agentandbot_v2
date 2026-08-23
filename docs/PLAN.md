# AgentAndBot — Master Plan: Provisioning Broker + Mesh

*Son güncelleme: 2026-08-23 — Faz A çekirdeği tamamlandı, A-bitiş sırada*

> **Bu dosya çalışma sözleşmesidir.** Başka bir agent "devam" komutu aldığında
> bu dosyayı okuyip kaldığı yerden sürdürür. Tamamlanan maddeler işaretlenir,
> yarım kalanlar ⚠️ ile belirtilir.

---

## Vizyon

**AB koordinasyon katmanıdır, execution değil.** Agent'lar her yerde koşar;
AB bulandır, eşleştirir, doğrular, attribüte eder. Agent'lar ve QM AB'de
çalışmaz — AB sadece özellikleri söyler, agent kendi hesabında açar.

**Gelir modeli (iki ayaklı ekonomi):**
- **Affiliate** (gelir ayağı): agent kendi fly.io/aws hesabını AB referral
  link'i ile açar → komisyon
- **Kredi** (gider ayağı): AB API/koordinasyon kullanımı kredi tüketir
  (mimari-v3 credit ledger planıyla uyumlu)

**QM'den alınan:** menü seti değil, **sözleşme/verify/attribution disiplini**
(deployment directory contract, check→doctor→up→check --live kapı sırası,
immutable pins, approvals-tighten).

## Döngü (AB'nin kalbi)

```
Gap → Recipe → Deploy (agent'ın KENDİ hesabında) → Verify → Fulfilled → Attribution
```

QM'nin menü felsefesi kopyalanmaz; AB'nin bu döngüsü önce mükemmelleştirilir,
ekranlar döngünün etrafında kademeli eklenir.

---

## Tamamlanan — Faz A çekirdeği ✅

- **Migrations (5):** `provisioning_providers`, `provisioning_recipes`,
  `provisioning_deployments`, `referral_events`,
  `capability_gaps.suggested_recipe_id` — hepsi koştu
- **Core:** `AgentbotCore.Modules.Provisioning` (context) + Provider/Recipe/
  Deployment/ReferralEvent schemaları + `DeploymentVerifier` GenServer
  (application tree'de kayıtlı)
- **API:** `GET /api/gaps/:id/recipes`, `GET /api/recipes/:id` (referral link +
  attribution issue), `POST /api/deployments` (auth), `GET /api/deployments/:id`,
  `POST /api/deployments/:id/verify` — router'da kayıtlı, derlendi
- **Seed:** fly.io provider + pong recipe
  (`apps/agentbot_core/priv/repo/seeds/050_provisioning_seeds.exs`)
- **Mock E2E GEÇTİ:** gap→recipe→deploy→live→capability→fulfilled
- **Dashboard:** Deployment/Referral stat kartları + döngü widget'ı

### Seed çalıştırma
```bash
docker exec agentbot-dev bash -c "cd /app/apps/agentbot_core && mix run -e 'Code.require_file(\"priv/repo/seeds/050_provisioning_seeds.exs\"); AgentbotCore.Repo.Seeds.ProvisioningSeeds.run()'"
```

---

## ⚠️ Yarım kalan — Faz A-bitiş (~yarım gün) — SIRADAKİ ADIM

1. **Temizlik:** `@private` → `defp` (geçersiz attribute, 9 yer):
   - `apps/agentbot_core/lib/agentbot_core/modules/provisioning.ex:219,227,239`
   - `apps/agentbot_core/lib/agentbot_core/modules/provisioning/deployment_verifier.ex:61,67`
   - `apps/agentbot_web/lib/agentbot_web/controllers/provisioning_controller.ex:130,146,173,178`
   - Kullanılmayan alias'lar: `Provider` (controller), `AgentCredential` (context)
   - Not: root AGENTS.md `--warnings-as-errors` gerektirir — bu temizlik onun önkoşulu
2. **Verifier otomasyonu:** health OK → `live` → **otomatik**
   `register_capability_from_deployment` + gap fulfill +
   `referral_event("deployment_verified")`. Şu an `update_deployment_status(id,"live")`
   sadece status güncelliyor; capability/gap/referral manuel çağrılıyor —
   otomatik olmalı (DeploymentVerifier `handle_info` success dalında).
3. **Testler:** provisioning unit + controller + verifier state machine;
   mock E2E scriptini `apps/agentbot_core/test/provisioning_loop_test.exs`
   olarak taşı (kaynak: repo içine kopyalandı →
   `scripts/provisioning_e2e_mock.exs`; ExUnit test'ine dönüştürülecek)
4. **Gap ekranı:** dashboard'daki gap kartına recipe önerisi + referral link
   derin linki
5. **Kapı:** `mix compile --warnings-as-errors` + `mix test` + `mix credo --strict`
   yeşil → **Faz A kanıtlanmış**

---

## Onaylı sıra

```
A-bitiş → B → E1 → C → E2 → D
```

### Faz B — Kredi + Ekranlar
- Kredi ledger (gider ayağı; basit başlar: kullanım event'i → bakiye)
- Gaps/Recipes/Deployments tam ekranlar (QM görsel dili, DaisyUI dark, Bauhaus)
- Sidebar iskeleti devreye girer
- Admin v1: provider'lar, deployment sağlık özeti
- Affiliate bu fazda manuel/basit (referral_events kaydı var, eşleme elle)

### Faz E1 — Mesh çekirdeği (~1 hafta)
- `AgentbotCore.Modules.Mesh`: NodeRegistry (tip, kalite skoru, capability
  beyanı) + WorkerPool behaviour (full: sabit protokol / dispatch; üst katman
  scheduler ikisini aynı arayüzden görür)
- Full node şablonu: **Burrito** release + libcluster (hub'a **outbound**
  bağlanır — NAT dostu, hub-spoke; mesh v2) + sabit `AgentbotWorker` GenServer
- Güvenlik: `inet_tls_dist` zorunlu (default erl_dist plaintext!), dist portları
  pinli (`inet_dist_listen_min/max`), `-mode embedded`, dinamik kod yükleme
  kapalı, **raw `:erpc.call` YOK** (sabit job protokolü — arbitrary RCE'yi
  "sabit protokol"e indirger)
- Kayıt: mevcut `/api/resources/provide` endpoint'i (yeni endpoint yok)
- **v1 iş: artifact seed/store** — chunk + sha256, idempotent, sandbox yok,
  "konuşma geçicidir, artifact kalıcıdır" vizyonuyla birebir uyumlu

### Faz C — Affiliate sağlamlaştırma
- Provider API entegrasyonu (fly.io referral/kullanım verisiyle cross-check)
- Challenge-response nonce doğrulama (deploy edilen endpoint imzalayıp döner)
- Tek-kullanım + TTL'lı attribution code, agent'a kriptografik bağlama
- Anomali tespiti (aynı hesap/IP, tekrarlı deploy pattern'leri)

### Faz E2 — Mesh kalite + kredi (B'ye bağımlı)
- Join'de throughput/latency ölçümü → `executor_resources` skoru
- Eşik altındakiler worker pool'a hiç girmez (tüketici modu)
- Katkı = kredi event'i (credit ledger'e yazar)
- Circuit breaker %60 kuralı mesh node'larına uygulanır

### Faz D — Network efekti özellikleri (en son)
- Sırasıyla: Sessions (multi-agent koordinasyon) → Memory (shared context) →
  Triggers (cron/webhook → agent sandbox'ına push, AB çalıştırmaz) → Keychain
- Hermes referans client `ab-provision` skill'i (`hermes-local` zaten register'lı,
  token: `~/.hermes/agentandbot.env`)

### Donduruldu (v1 dışı)
- Lite/tarayıcı node'lar (WebRTC) — E-fazları kanıtlanınca ayrı karar
- WASM sandbox, gossip work-stealing, blockchain settlement
- LLM relay + transcode işleri (E1'den sonra aynı WorkerPool behaviour'a)
- Mimari-v3'teki Seed/Contribution Pool'un mesh varyantı — affiliate modeli öncelikli

---

## Kritik teknik notlar

- **DB kolonları `timestamp(0)`** — Ecto `:utc_datetime` mikro saniye üretir,
  insert patlar. Deployment'ta timestamps manuel set ediliyor:
  `DateTime.utc_now() |> DateTime.truncate(:second)` + changeset'te `put_change`
- **Test/derleme:** `sudo docker exec agentbot-dev bash -c "cd /app && mix test"`
  (host'ta Elixir yok). DB: `core-postgres`, database `agentbot_dev`,
  user/pass postgres/postgres
- **Kod yolu:** `/mnt/data/agentandbot_com` (umbrella: `apps/agentbot_core`,
  `apps/agentbot_web`), dev container: `agentbot-dev`
- **Compile gate:** `mix compile --warnings-as-errors` sıfır warning şart
  (AGENTS.md) — @private temizliği bitmeden commit yapma
- **Quality gate:** `mix compile --warnings-as-errors && mix credo --strict && mix test`
- Bu sunucuda QM de koşuyor (`qm-core` container, restart loop'unda) — AB ile
  ilgisi yok, karıştırma

## Agent devri

Başka agent'a devredilirken:
```
/mnt/data/agentandbot_com/docs/PLAN.md dosyasını oku,
"Faz A-bitiş" bölümünün 1. maddesinden devam et.
```
- E2E mock script repo içinde: `scripts/provisioning_e2e_mock.exs`
  (çalıştırma: `docker cp` + `mix run` — madde 3'te ExUnit'e dönüşecek)
