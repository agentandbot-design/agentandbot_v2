defmodule AgentbotWeb.ActivityLogController do
  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.ActivityLog

  def index(conn, params) do
    date = parse_date(params["date"])
    activities = ActivityLog.list_by_date(date)
    render(conn, :index, activities: activities, date: date)
  end

  def show(conn, %{"id" => id}) do
    activity = ActivityLog.get!(id)
    render(conn, :show, activity: activity)
  end

  def create(conn, %{"activity_log" => activity_params}) do
    params = Map.put_new(activity_params, "created_by", "ilkerkaan")

    case ActivityLog.create(params) do
      {:ok, activity} ->
        conn
        |> put_status(:created)
        |> render(:show, activity: activity)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "activity_log" => activity_params}) do
    activity = ActivityLog.get!(id)

    case ActivityLog.update(activity, activity_params) do
      {:ok, activity} ->
        render(conn, :show, activity: activity)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    activity = ActivityLog.get!(id)

    case ActivityLog.delete(activity) do
      {:ok, _} ->
        send_resp(conn, :no_content, "")

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Silinemedi"})
    end
  end

  def update_status(conn, %{"id" => id, "status" => status}) do
    case ActivityLog.update_status(id, status) do
      {:ok, activity} ->
        render(conn, :show, activity: activity)

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Statü güncellenemedi"})
    end
  end

  def sync_google(conn, %{"id" => id}) do
    activity = AgentbotCore.Modules.ActivityLog.get!(id)

    case ActivityLog.sync_to_google(activity) do
      {:ok, activity} ->
        render(conn, :show, activity: activity)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Google sync başarısız: #{inspect(reason)}"})
    end
  end

  defp parse_date(nil), do: Date.utc_today()
  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end
end
