defmodule AgentbotWeb.AgentManifestModal do
  @moduledoc """
  Agent manifest modal — JSON pretty-print + kopyala butonu
  """

  use Phoenix.LiveComponent

  alias AgentbotCore.Modules.Security.AgentCredential

  @impl true
  def update(%{agent_id: id}, socket) do
    manifest = AgentCredential.find_manifest(id)
    pretty =
      case manifest do
        nil -> "{\n  \"error\": \"manifest bulunamadı\"\n}"
        m -> Jason.encode!(m, pretty: true, indent: 2)
      end

    {:ok,
     socket
     |> assign(:agent_id, id)
     |> assign(:manifest, manifest)
     |> assign(:pretty, pretty)}
  end

  @impl true
  def handle_event("copy", _, socket) do
    {:noreply,
     socket
     |> push_event("copy_to_clipboard", %{text: socket.assigns.pretty})
     |> put_flash(:info, "Manifest JSON kopyalandı")}
  end

  def handle_event("close", _, socket) do
    send(socket.parent_pid, :close_manifest)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ab-modal-backdrop" phx-click="close" phx-target={@myself}>
      <div class="ab-modal" phx-click-away="close" phx-target={@myself}>
        <header class="ab-modal__head">
          <h2>📄 Manifest — <%= @agent_id %></h2>
          <button phx-click="close" phx-target={@myself} class="ab-modal__close">✕</button>
        </header>

        <div class="ab-modal__body">
          <%= if @manifest do %>
            <pre class="ab-json"><%= @pretty %></pre>
          <% else %>
            <div class="ab-empty">Bu agent kayıtlı değil veya manifest yok.</div>
          <% end %>
        </div>

        <footer class="ab-modal__foot">
          <button phx-click="copy" phx-target={@myself} class="ab-btn">
            📋 JSON Kopyala
          </button>
          <a
            href={"/api/agents/#{@agent_id}/manifest"}
            target="_blank"
            class="ab-btn ab-btn--secondary"
          >
            Ham JSON ↗
          </a>
        </footer>
      </div>
    </div>
    """
  end
end