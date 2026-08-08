defmodule AgentbotWebTest do
  use ExUnit.Case, async: true

  test "well_known skill_card doğru JSON döndürür" do
    alias AgentbotCore.Modules.Protocol.WellKnown

    card = WellKnown.skill_card()

    assert card.name == "AgentAndBot"
    assert card.tagline != nil
    assert is_list(card.quickstart)
    assert is_map(card.api)
    assert is_list(card.executor_types)
    assert card.principle =~ "Don't make everything an agent"
  end
end
