defmodule AgentbotCore.Modules.Sync.GithubAdapter do
  @moduledoc """
  GitHub Issues adapter'ı.

  Push: task → issue (yoksa create, varsa update). summary → issue body.
  Pull: webhook payload veya REST listeleme. Sub-issues native karşılık.
  technical_context ve sync_metadata dışa asla taşınmaz.

  Config (sync_targets.config):
    %{"repo" => "owner/name", "labels" => ["agentandbot"], "status_map" => %{...}}
  """

  @behaviour AgentbotCore.Modules.Sync.Adapter

  @github_base "https://api.github.com"

  @impl true
  def id, do: "github"

  @impl true
  def capabilities, do: %{outbound: true, inbound: true}

  @impl true
  def push(state, task, opts) do
    config = Keyword.get(opts, :config, %{})
    repo = Map.get(config, "repo") || raise ArgumentError, "github adapter: config.repo gerekli"
    token = github_token()

    status_map =
      Map.get(config, "status_map") ||
        AgentbotCore.Modules.Sync.SyncTarget.default_status_map("github")

    body =
      task.summary ||
        String.slice(task.description || task.title || "", 0, 280)

    ext_id = get_in(state, ["issue", "number"]) || external_id_from_task(task)

    cond do
      task.summary == nil and (task.description || "") == "" ->
        {:skip, "özet yok — issue body boş olur"}

      ext_id == nil ->
        create_issue(repo, token, task, body, status_map)

      true ->
        update_issue(repo, token, ext_id, task, body, status_map)
    end
  end

  @impl true
  def pull(state, since, opts) do
    config = Keyword.get(opts, :config, %{})
    repo = Map.get(config, "repo") || raise ArgumentError, "github adapter: config.repo gerekli"
    token = github_token()

    q =
      "repo:#{repo} is:issue sort:updated-desc" <>
        if(since, do: " updated:>=#{Date.to_string(DateTime.to_date(since))}", else: "")

    with {:ok, %Req.Response{status: 200, body: issues}} <-
           Req.get("#{@github_base}/search/issues",
             params: [q: q, per_page: 50],
             headers: auth_headers(token)
           ) do
      {:ok, Enum.map(issues["items"] || [], &issue_to_change/1),
       Map.put(state, "last_pull", DateTime.to_iso8601(DateTime.utc_now()))}
    else
      {:ok, %Req.Response{status: s}} -> {:ok, [], Map.put(state, "last_error", "HTTP #{s}")}
      err -> {:ok, [], Map.put(state, "last_error", inspect(err, limit: 100))}
    end
  end

  @impl true
  def decode(%{"issue" => issue}) do
    %{
      "title" => issue["title"],
      "summary" => first_paragraph(issue["body"]),
      "status" => gh_state_to_ab(issue["state"], gh_labels(issue)),
      "external_url" => issue["html_url"]
    }
  end

  def decode(_), do: :ignore

  # --- yardımcılar ---

  defp create_issue(repo, token, task, body, status_map) do
    payload = %{
      "title" => task.title,
      "body" => body,
      "labels" => ["agentandbot"]
    }

    case Req.post("#{@github_base}/repos/#{repo}/issues",
           json: payload,
           headers: auth_headers(token)
         ) do
      {:ok, %Req.Response{status: 201, body: issue}} ->
        sync_labels(repo, token, issue["number"], task.status, status_map)

        {:ok, Integer.to_string(issue["number"]),
         %{"issue" => %{"number" => issue["number"], "url" => issue["html_url"]}}}

      {:ok, %Req.Response{status: s, body: b}} ->
        {:error, "HTTP #{s}: #{inspect(b, limit: 200)}"}

      err ->
        {:error, inspect(err, limit: 200)}
    end
  end

  defp update_issue(repo, token, number, task, body, status_map) do
    gh_state =
      case Map.get(status_map, task.status, "open") do
        "closed" -> "closed"
        _ -> "open"
      end

    payload = %{"title" => task.title, "body" => body, "state" => gh_state}

    case Req.patch("#{@github_base}/repos/#{repo}/issues/#{number}",
           json: payload,
           headers: auth_headers(token)
         ) do
      {:ok, %Req.Response{status: 200, body: issue}} ->
        sync_labels(repo, token, number, task.status, status_map)

        {:ok, Integer.to_string(number),
         %{"issue" => %{"number" => number, "url" => issue["html_url"]}}}

      {:ok, %Req.Response{status: s, body: b}} ->
        {:error, "HTTP #{s}: #{inspect(b, limit: 200)}"}

      err ->
        {:error, inspect(err, limit: 200)}
    end
  end

  defp sync_labels(repo, token, number, ab_status, status_map) do
    gh_label = Map.get(status_map, ab_status, "open")

    # ponytail: tek durum label'ı — history label setleri GitHub'ın replace endpoint'iyle temiz yazılır
    Req.put("#{@github_base}/repos/#{repo}/issues/#{number}/labels",
      json: ["agentandbot", gh_label],
      headers: auth_headers(token)
    )
  end

  defp issue_to_change(issue) do
    %{
      "system" => "github",
      "external_id" => Integer.to_string(issue["number"]),
      "decoded" => decode(%{"issue" => issue})
    }
  end

  defp gh_state_to_ab("open", _), do: "in_progress"
  defp gh_state_to_ab("closed", _), do: "completed"

  defp gh_labels(issue), do: Enum.map(issue["labels"] || [], & &1["name"])

  defp first_paragraph(nil), do: nil

  defp first_paragraph(body),
    do: body |> String.split("\n\n") |> List.first() |> String.slice(0, 280)

  defp external_id_from_task(task) do
    case get_in(task.sync_metadata || %{}, ["github", "external_id"]) do
      nil -> nil
      id when is_binary(id) -> id
      id -> to_string(id)
    end
  end

  defp github_token do
    System.get_env("GITHUB_SYNC_TOKEN") || raise ArgumentError, "GITHUB_SYNC_TOKEN env gerekli"
  end

  defp auth_headers(token),
    do: [{"authorization", "Bearer #{token}"}, {"accept", "application/vnd.github+json"}]
end
