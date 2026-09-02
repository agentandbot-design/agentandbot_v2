defmodule AgentbotWeb.MemStatus do
  @moduledoc """
  mem.agentandbot.com canlı durum istemcisi.

  Dashboard'daki "Ortak Hafıza" kartı için /health'i çeker.
  Servis erişilemezse `:offline` döner — sayfa kırılmaz.
  """

  @timeout 3_000

  @type t ::
          %{
            status: String.t(),
            version: String.t(),
            chunks: non_neg_integer(),
            credentials: non_neg_integer(),
            embedder_configured: boolean(),
            embedder_model: String.t() | nil,
            checked_at: DateTime.t()
          }
          | :offline

  @spec fetch() :: t()
  def fetch do
    base_url = base_url()

    case Req.get(base_url <> "/health", receive_timeout: @timeout, retry: false) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        %{
          status: body["status"],
          version: body["version"],
          chunks: get_in(body, ["stats", "chunks"]) || 0,
          credentials: get_in(body, ["stats", "credentials"]) || 0,
          embedder_configured: get_in(body, ["embedder", "configured"]) || false,
          embedder_model: get_in(body, ["embedder", "model"]),
          checked_at: DateTime.utc_now()
        }

      _ ->
        :offline
    end
  rescue
    _ -> :offline
  catch
    _, _ -> :offline
  end

  @doc "Public URL — karttaki bağlantı için."
  def public_url do
    config()[:public_url]
  end

  defp base_url do
    config()[:base_url]
  end

  defp config do
    Application.get_env(:agentbot_web, :mem_service, [])
  end
end
