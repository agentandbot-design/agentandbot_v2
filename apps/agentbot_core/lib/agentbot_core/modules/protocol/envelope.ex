defmodule AgentbotCore.Modules.Protocol.Envelope do
  @moduledoc """
  Ajan iletişim zarfı (Envelope).

  Tüm mesajlaşma, ajan girişi ve güvenlik kontrolleri
  bu struct üzerinden yapılır. MCP/A2A uyumlu zarf formatı.
  """

  @enforce_keys [:type, :sender, :payload]
  defstruct [
    :id,
    :type,
    :sender,
    :recipient,
    :payload,
    :timestamp,
    :room_id,
    :metadata,
    :signature,
    :content_type
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t(),
          sender: String.t(),
          recipient: String.t() | nil,
          payload: map() | nil,
          timestamp: DateTime.t() | nil,
          room_id: String.t() | nil,
          metadata: map() | nil,
          signature: String.t() | nil,
          content_type: String.t() | nil
        }

  @doc """
  Yeni bir zarf oluşturur. Timestamp otomatik atanır.
  """
  @spec new(keyword()) :: t()
  def new(attrs) when is_list(attrs) do
    attrs = Keyword.put(attrs, :id, generate_id())
    attrs = Keyword.put(attrs, :timestamp, DateTime.utc_now())

    attrs =
      Keyword.put(attrs, :content_type, Keyword.get(attrs, :content_type, "application/json"))

    attrs = Keyword.put(attrs, :metadata, Keyword.get(attrs, :metadata, %{}))

    struct!(__MODULE__, attrs)
  end

  @doc """
  Zarfa imza ekler (Ed25519 henüz yok, placeholder).
  """
  @spec sign(t(), String.t()) :: t()
  def sign(%__MODULE__{} = envelope, _private_key) do
    # Not: Ed25519 implementasyonu gelecek phase'de
    %{envelope | signature: "pending_ed25519"}
  end

  @doc """
  Zarf imzasını doğrular (Ed25519 henüz yok).
  """
  @spec verify_signature?(t(), String.t()) :: boolean()
  def verify_signature?(%__MODULE__{signature: nil}, _public_key), do: false
  def verify_signature?(%__MODULE__{signature: "pending_ed25519"}, _public_key), do: true
  def verify_signature?(_envelope, _public_key), do: false

  @doc """
  Zarfyı JSON'a serialize eder.
  """
  @spec to_json(t()) :: String.t()
  def to_json(%__MODULE__{} = envelope) do
    envelope
    |> Map.from_struct()
    |> Jason.encode!()
  end

  @doc """
  JSON'dan zarf deserialize eder.
  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, term()}
  def from_json(json) when is_binary(json) do
    with {:ok, map} <- Jason.decode(json) do
      atom_map = for {k, v} <- map, into: %{}, do: {String.to_atom(k), v}
      {:ok, struct(__MODULE__, atom_map)}
    end
  end

  # Benzersiz ID üretici
  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  end
end
