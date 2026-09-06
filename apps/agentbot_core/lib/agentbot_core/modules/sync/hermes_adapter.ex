defmodule AgentbotCore.Modules.Sync.HermesAdapter do
  @moduledoc """
  Hermes Kanban adapter'ı — CLI wrapper üzerinden.

  Push: task → `hermes kanban create/edit` (ab_id haritalaması body'de taşınır,
  mevcut agentandbot-kanban-sync deseninin aynısı).
  Pull: `hermes kanban list --json` poll'u; ab_id → task eşleşmesi.

  Config:
    %{"kanban_bin" => "/usr/local/bin/hermes", "board" => "sap",
      "status_map" => %{...}}
  """

  @behaviour AgentbotCore.Modules.Sync.Adapter

  @impl true
  def id, do: "hermes"

  @impl true
  def capabilities, do: %{outbound: true, inbound: true}

  @impl true
  def push(state, task, opts) do
    config = Keyword.get(opts, :config, %{})
    kanban = Map.get(config, "kanban_bin", "hermes")
    status_map = Map.get(config, "status_map") || AgentbotCore.Modules.Sync.SyncTarget.default_status_map("hermes")
    body = build_body(task)
    hermes_id = get_in(state, ["hermes_id"]) || hermes_id_from_task(task)

    args =
      if hermes_id do
        ["kanban", "edit", hermes_id, "--body", body]
      else
        ["kanban", "create", task.title, "--body", body] ++ initial_status_args(status_map, task)
      end

    case cmd(kanban, args) do
      {output, 0} ->
        id = hermes_id || extract_id(output)
        {:ok, id, Map.put(state, "hermes_id", id)}

      {output, code} ->
        {:error, "exit #{code}: #{String.slice(output, 0, 300)}"}
    end
  end

  @impl true
  def pull(state, _since, opts) do
    config = Keyword.get(opts, :config, %{})
    kanban = Map.get(config, "kanban_bin", "hermes")

    case cmd(kanban, ["kanban", "list", "--json"]) do
      {output, 0} ->
        cards = parse_json(output)

        changes =
          cards
          |> Enum.map(&card_to_change/1)
          |> Enum.reject(&(&1 == nil))

        {:ok, changes, Map.put(state, "last_pull", DateTime.to_iso8601(DateTime.utc_now()))}

      {output, code} ->
        {:ok, [], Map.put(state, "last_error", "exit #{code}: #{String.slice(output, 0, 200)}")}
    end
  end

  @impl true
  def decode(%{"card" => card}) do
    with {:ok, ab_id} <- fetch_ab_id(card) do
      %{
        "ab_id" => ab_id,
        "title" => card["title"],
        "summary" => first_line(card["body"]),
        "status" => Map.get(reverse_status_map(), card["status"], card["status"])
      }
    else
      _ -> :ignore
    end
  end

  def decode(_), do: :ignore

  # --- yardımcılar ---

  defp build_body(task) do
    summary = task.summary || String.slice(task.description || "", 0, 280)
    "#{summary}\n\nab_id:#{task.id}"
  end

  defp initial_status_args(status_map, task) do
    case Map.get(status_map, task.status, "todo") do
      "running" -> ["--initial-status", "running"]
      "blocked" -> ["--initial-status", "blocked"]
      _ -> []
    end
  end

  defp extract_id(output) do
    case Regex.run(~r/\bt_[0-9a-f]{8}\b/, output) do
      [id] -> id
      _ -> nil
    end
  end

  defp hermes_id_from_task(task) do
    case get_in(task.sync_metadata || %{}, ["hermes", "external_id"]) do
      nil -> nil
      id when is_binary(id) -> id
      id -> to_string(id)
    end
  end

  defp fetch_ab_id(card) do
    body = card["body"] || ""

    case Regex.run(~r/^ab_id:(\d+)$/m, body) do
      [_, id] -> {:ok, id}
      _ -> {:error, :no_ab_id}
    end
  end

  defp card_to_change(card) do
    case fetch_ab_id(card) do
      {:ok, ab_id} ->
        %{"system" => "hermes", "external_id" => card["id"], "ab_id" => ab_id, "decoded" => decode(%{"card" => card})}

      _ -> nil
    end
  end

  defp first_line(nil), do: nil
  defp first_line(body), do: body |> String.split("\n") |> List.first() |> String.slice(0, 280)

  defp reverse_status_map do
    AgentbotCore.Modules.Sync.SyncTarget.default_status_map("hermes")
    |> Enum.into(%{}, fn {ab, h} -> {h, ab} end)
  end

  defp parse_json(output) do
    case Jason.decode(output) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  defp cmd(bin, args) do
    # ponytail: System.cmd — port limitleri yok, sync iş yükü küçük
    System.cmd(bin, args, stderr_to_stdout: true, timeout: 30_000)
  end
end