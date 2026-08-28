defmodule AgentbotWeb.PlatformLive do
  @moduledoc """
  AgentAndBot ekosistemi ve alt alan adlarinin anlasilir haritasi.
  Insanlar ve agent'lar icin ortak kaynak.
  """

  use AgentbotWeb, :live_view

  alias AgentbotWeb.MemStatus

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:mem_status, MemStatus.fetch())
     |> assign(:mem_public_url, MemStatus.public_url())}
  end
end
