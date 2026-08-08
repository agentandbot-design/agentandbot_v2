# Human Gateway Design

## Vizyon

İnsan nerede olursa olsun (Discord, Telegram, Web, Email) agentandbot'a ulaşır:
- Derdini söyler → task oluşur → executor bulunur → artifact döner → insana teslim edilir.

## Mimari

```
Discord ──┐
Telegram ─┤──► Human Gateway ──► POST /api/request ──► Core Loop
Web ──────┤    (adapter'lar)                            │
Email ────┘                                               ▼
                                                    Artifact ──► adapter ──► insana geri
```

## Adapter Pattern

Her kanal (Discord, Telegram, Web) bir adapter'dır:
- Gelen mesajı `need` text'ine çevirir
- `POST /api/request` ile core loop'a besler
- Artifact tamamlandığında kanala mesaj gönderir

## Öncelik Sırası

1. **Web** ✅ (yapıldı — LiveView dashboard + POST /api/request)
2. **Telegram** (Hermes Agent zaten Telegram'da — bot token ile bağlanabilir)
3. **Discord** (Nostrum ile)
4. **Email** (sonra)

## Telegram Adapter

Hermes Agent'ın Telegram entegrasyonu zaten var. AgentAndBot'a bağlamak için:
- Hermes bir cron/trigger ile AgentAndBot API'yi poll eder
- Veya doğrudan Hermes'e "AgentAndBot skill" yükle
- Kullanıcı Telegram'dan yazar → Hermes POST /api/request yapar → sonuç Telegram'a döner

## Discord Adapter (Nostrum)

```elixir
defmodule AgentbotWeb.Gateways.Discord do
  use Nostrum.Consumer

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    # Mesajı /api/request'e besle
    TaskController.human_request(conn, %{need: msg.content, name: msg.author.username})
    # Artifact tamamlanınca Discord'a yanıt
  end
end
```
