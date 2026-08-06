defmodule AgentbotWebTest do
  use ExUnit.Case, async: true

  test "well_known skill_card doğru JSON döndürür" do
    alias AgentbotCore.Modules.Protocol.WellKnown

    card = WellKnown.skill_card()

    assert card["@context"] != nil
    assert card.agent.name == "AgentAndBot"
    assert is_list(card.agent.capabilities)
    assert is_list(card.event_taxonomy)
  end
end
