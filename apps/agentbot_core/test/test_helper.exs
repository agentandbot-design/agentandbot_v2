# Test helper — Anti-Crash Manifesto: Testsiz kod canlıya çıkmaz
{_, _} = Application.ensure_all_started(:postgrex)
{_, _} = Application.ensure_all_started(:ecto_sql)

# Sandbox repo — her test izole
Ecto.Adapters.SQL.Sandbox.mode(AgentbotCore.Repo, :manual)

ExUnit.configure(exclude: [:pending])
ExUnit.start()
