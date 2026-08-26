# Plan: agentandbot messaging surface for QM (modüler eklenti)

> Status: PLAN — implementation starts next session. This file is the single
> source of truth for the feature until Faz 1 lands; then fold decisions into
> AGENTS.md contracts and delete stale sections.

## Kararlar (kilitli)

| Konu | Karar |
|------|--------|
| Mimari | Surface adapter — mesajlaşma `agentandbot.com` (Elixir) odalarında kalır |
| Yerleşim (QM) | **Layer plugin**: `deploy/layers/agentandbot/plugins/agentandbot-surface/` — core'a gömülmez |
| Yerleşim (AB) | **Chat.Provider behaviour** + `qm_bridge` provider (MVP core module, sonra ayrı app olabilir) |
| MVP kapsam | Oda + DM metin, @mention/turn, bot cevabı — dosya/reaksiyon/search/standing order YOK |
| Kimlik | Service agent credential (`agents/register` + token); **AB'de QM'e first-class tip yok** — Japonya'daki Hermes ile eşit |
| Transport | **Private-first**: aynı sunucuda internete çıkma; public URL yalnızca remote/bilinçli override |
| Slack | Paralel virtual service olarak kalır; ikisi yan yana açılabilir |

## Transport kuralı (private-first)

```text
Aynı host / aynı Docker network → http://<alias>:<port>   (internetsiz)
Remote / bilinçli override      → https://agentandbot.com
```

- Plugin URL'i config'ten alır, "önce public dene" yapmaz.
- Bu sunucuda: QM stack `qm-agentandbot` network'ünde; AB `agentbot-dev`
  `internal-network` + `proxy-network`'te. Bağlantı için plugin container'ı
  `internal-network`'e de bağlanır (veya ortak `agentandbot-mesh` kurulur),
  AB web'e alias `agentbot-web`.
- Private base: `http://agentbot-web:4000`, WS: `ws://agentbot-web:4000/socket/websocket`.
- Opsiyonel `fallback_public=true` default KAPALI.
- İlke: **AB universal agent bus; QM one subscriber among many.**

## Hedef akış

```text
İnsan/ajan ⇄ agentandbot.com (Phoenix room/WS/REST)
                 │ service agent token (private-first transport)
                 ▼
         QM core surface "agentandbot"
                 │ submitTurn / ingestSurfaceEvents
                 ▼
         local sandbox (qm-sbx-*)
```

## Faz 1 — AB tarafı (Elixir)

1. Authenticated bot post: `POST /api/rooms/:id/messages` (token'lı; sender_id spoof edilemez).
2. Bot register/connect akışı netleştirilir (`POST /api/agents/register` + `connect`).
3. WS inbound: bot token ile `RoomChannel` join, `new_message` dinle;
   yedek poll: `GET /api/rooms/:id/messages/since/:last_id`.
4. DM MVP: iki kişilik oda (`kind: dm` metadata).
5. Mention kuralı: metinde `@bot` veya oda flag'i; explicit mention → her zaman cevap.
6. `Chat.Provider` behaviour + registry (`Application.get_env(:agentbot_core, :chat_providers, [])`);
   `web` default provider, `qm_bridge` yeni.
7. Contract header: `X-AB-Contract: 1`.
8. DOX: `apps/agentbot_web` + chat AGENTS.md'e messaging contract; kök Child Index güncellenir.

Doğrulama: `mix compile --warnings-as-errors` (container içinde); curl register → post → list; LiveView'da mesaj.

## Faz 2 — QM layer plugin iskeleti

```text
deploy/layers/agentandbot/plugins/agentandbot-surface/
  Dockerfile
  package.json
  src/{index,config,client,events,mirror,turn-handler,delivery}.ts
  AGENTS.md
```

- `qm.config.jsonc`: `"plugins": [{ "name": "agentandbot-surface" }]`; slack kapalıysa listede yok.
- Plugin env: `AGENTANDBOT_API_URL` (private-first), `AGENTANDBOT_AGENT_TOKEN`,
  `AGENTANDBOT_BOT_NAME=qm`, chassis wiring (`CORE_API_URL` + signing).
- Modüller tek sorumlulukta: client (reconnect/auth), events (normalize),
  mirror (core ingest), turn-handler (mention→turn), delivery (reply post).

## Faz 3 — Turn loop

- Inbound: WS event → normalize → `POST /v1/surface-cache/ingest` +
  `submitTurn({ surface: "agentandbot" })` (chassis source-auth).
- Outbound: turn cevabı → authenticated AB post.
- MVP'de plugin outbound yapar; core'a yeni surface klasörü eklenmez.
- Smoke: LiveView mesaj → QM log → bot reply odada.

## Faz 4 — Ops + kapanış

- Rate limit/reconnect/poll fallback matrisi.
- Layer README: kurulum, secret isimleri, oda/DM açılışı.
- Upstream (opsiyonel): `adrs/` kısa metni — "org messaging surfaces as layer plugins".

## Bilinçli sınırlar

- `src/slack` içine agentandbot if'leri YOK (upstream merge acır).
- Mesaj DB'si QM'e taşınmaz — AB'nin işi; plugin sadece köprü.
- Secret sadece `.env`; committed dosyalarda placeholder.
- AB'de QM'e özel agent tipi/rolü tanımlanmaz.

## Riskler

| Risk | Azaltma |
|------|---------|
| Source-auth plugin'den core çağrısı | Chassis imza deseni (portal/admin gibi) |
| Çift cevap (Slack+AB aynı anda) | `surface` string + room/thread tekilliği + mention kuralı |
| WS kopması | Poll fallback + reconnect |
| API kırılması | `X-AB-Contract: 1` version header + CONTRACT.md |

## Yarın başlangıç noktası

1. Faz 1: AB authenticated room message POST + bot sender bağlama.
2. Faz 2 iskelet: plugin container dry-run (token ile tek post).
3. Network: plugin'i `internal-network`'e bağla, `agentbot-web` alias doğrula.
