defmodule AgentbotCore.Test.DataCase do
  @moduledoc """
  Test data case — her test için izole DB sandbox.

  Anti-Crash Manifesto: Kara kutu kod yok. Her şema ve iş mantığı test edilmeli.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias AgentbotCore.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import AgentbotCore.Test.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(AgentbotCore.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
