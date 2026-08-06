defmodule AgentbotWeb.WellKnownController do
  @moduledoc """
  WellKnown discovery endpoint'leri — ajan keşfi için.

  GET /.agent-well-known/skill      → yetenek kartı
  GET /.agent-well-known/agent.json → ajan kartı
  GET /.agent-well-known/protocols → protokol listesi
  """

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Protocol.WellKnown

  @doc "Yetenek kartı döndürür — A2A uyumlu discovery"
  def skill(conn, _params) do
    card = WellKnown.skill_card()
    json(conn, card)
  end

  @doc "Ajan kartı döndürür"
  def agent(conn, _params) do
    card = WellKnown.agent_card()
    json(conn, card)
  end

  @doc "Desteklenen protokoller listesi"
  def protocols(conn, _params) do
    protocols = WellKnown.protocol_list()
    json(conn, %{protocols: protocols})
  end
end
