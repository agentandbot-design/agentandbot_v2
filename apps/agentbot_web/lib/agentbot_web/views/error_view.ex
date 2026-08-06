defmodule AgentbotWeb.ErrorView do
  @moduledoc """
  Hata görünümü.
  """

  def render("404.json", _assigns) do
    %{errors: %{detail: "Bulunamadı"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Sunucu hatası"}}
  end
end
