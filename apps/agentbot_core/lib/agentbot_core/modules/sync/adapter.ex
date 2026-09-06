defmodule AgentbotCore.Modules.Sync.Adapter do
  @moduledoc """
  Universal sync adapter behaviour.

  Yeni bir sistem eklemek = yeni bir adapter modülü + `sync_targets` tablosunda
  bir config satırı. Kod yazmadan, manifest ile eklenir.

  ## Sözleşme

  - `id/0` — adapter kimliği ("github", "hermes", ...). `sync_targets.system` ile eşleşir.
  - `capabilities/0` — outbound (AB → dış) ve inbound (dış → AB) desteği.
  - `push/3` — dirty task'ı dış sisteme yazar. Başarıda external_id + yeni state döner.
  - `pull/3` — dış sistemdeki değişiklikleri çeker (poll veya webhook sonrası).
  - `decode/1` — inbound değişikliği AB alan haritasına çevirir.

  Adapter'lar stateless'dır; kalıcı durum `sync_targets.state`'te yaşar.
  """

  @type task :: AgentbotCore.Modules.Marketplace.Task.t()
  @type external_id :: String.t()
  @type adapter_state :: map()

  @callback id() :: String.t()
  @callback capabilities() :: %{outbound: boolean(), inbound: boolean()}

  @callback push(adapter_state :: adapter_state(), task :: task(), opts :: keyword()) ::
              {:ok, external_id(), adapter_state()}
              | {:error, term()}
              | {:skip, String.t()}

  @callback pull(adapter_state :: adapter_state(), since :: DateTime.t() | nil, opts :: keyword()) ::
              {:ok, [map()], adapter_state()}

  @callback decode(inbound_change :: map()) :: %{optional(atom()) => term()} | :ignore
end
