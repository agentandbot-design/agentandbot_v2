defmodule AgentbotWeb.TaskController do
  @moduledoc """
  Task API — oluştur, keşfet, delege et, tamamla.

  Discover → Delegate → Collaborate → Verify
  """

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Marketplace.{Artifact, Task}
  alias AgentbotCore.Modules.Security.AgentCredential

  @doc "Tüm task'ları listele (filtre: status, capability)"
  def index(conn, params) do
    tasks =
      case params do
        %{"status" => status} when status != "" -> Task |> where_status(status)
        %{"capability" => cap} when cap != "" -> Task.list_open_by_capability(cap)
        _ -> Task |> order_all()
      end

    json(conn, %{tasks: tasks})
  end

  defp where_status(query, status) do
    import Ecto.Query
    query |> where([t], t.status == ^status) |> order_by([t], desc: t.inserted_at) |> AgentbotCore.Repo.all()
  end

  defp order_all(_query) do
    import Ecto.Query
    AgentbotCore.Modules.Marketplace.Task
    |> order_by([t], desc: t.inserted_at)
    |> AgentbotCore.Repo.all()
  end

  @doc "Task oluştur (human veya agent)"
  def create(conn, params) do
    created_by = Map.get(conn.assigns, :agent_id, "human")

    case Task.create(%{
      room_id: params["room_id"],
      created_by: created_by,
      capability: params["capability"],
      title: params["title"],
      description: params["description"],
      input: params["input"] && Jason.encode!(params["input"]),
      priority: params["priority"] || 0
    }) do
      {:ok, task} ->
        conn |> put_status(201) |> json(%{task: task})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
    end
  end

  @doc "Task detayı + artifact'ları"
  def show(conn, %{"id" => id}) do
    task = Task.get!(id)
    artifacts = Artifact.list_by_task(id)
    json(conn, %{task: task, artifacts: artifacts})
  end

  @doc "Capability'ye sahip agent'ları bul (Discovery)"
  def discover(conn, %{"capability" => capability}) do
    agents = AgentCredential.find_by_capability(capability)

    json(conn, %{
      capability: capability,
      agents: Enum.map(agents, &strip_sensitive/1),
      count: length(agents)
    })
  end

  def discover(conn, _params) do
    conn |> put_status(400) |> json(%{error: "capability parametresi zorunlu"})
  end

  @doc "Task'ı agent'a ata (Delegation)"
  def assign(conn, %{"task_id" => task_id, "agent_id" => agent_id}) do
    case Task.assign(task_id, agent_id) do
      {:ok, task} ->
        json(conn, %{task: task, status: "assigned"})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "Atama başarısız"})
    end
  end

  @doc "Agent task durumunu güncelle"
  def update_status(conn, %{"task_id" => task_id, "status" => status}) do
    case Task.update_status(task_id, status) do
      {:ok, task} ->
        json(conn, %{task: task})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "Durum güncellenemedi"})
    end
  end

  @doc "Agent artifact submit (task çıktısı)"
  def submit_artifact(conn, params) do
    produced_by = Map.get(conn.assigns, :agent_id, "unknown")

    case Artifact.create(%{
      task_id: params["task_id"],
      room_id: params["room_id"],
      produced_by: produced_by,
      artifact_type: params["artifact_type"] || "report",
      title: params["title"],
      content: params["content"],
      metadata: params["metadata"] && Jason.encode!(params["metadata"])
    }) do
      {:ok, artifact} ->
        # Task'ı tamamlandı olarak işaretle
        Task.update_status(params["task_id"], "completed")

        conn |> put_status(201) |> json(%{artifact: artifact, status: "produced"})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
    end
  end

  @doc "Artifact'ı doğrula (human verification)"
  def verify_artifact(conn, %{"id" => artifact_id}) do
    verified_by = Map.get(conn.assigns, :agent_id, "human")

    case Artifact.verify(artifact_id, verified_by) do
      {:ok, artifact} ->
        json(conn, %{artifact: artifact, status: "verified"})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "Doğrulama başarısız"})
    end
  end

  # Helpers

  defp strip_sensitive(agent) do
    %{
      agent_id: agent.agent_id,
      agent_name: agent.agent_name,
      capabilities: agent.capabilities,
      protocols: agent.protocols,
      description: agent.description
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
