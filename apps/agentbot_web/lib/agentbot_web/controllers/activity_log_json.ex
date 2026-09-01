defmodule AgentbotWeb.ActivityLogJSON do
  def index(%{activities: activities, date: date}) do
    %{
      date: Date.to_string(date),
      count: length(activities),
      activities: Enum.map(activities, &data/1)
    }
  end

  def show(%{activity: activity}) do
    %{data: data(activity)}
  end

  def error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp data(activity) do
    %{
      id: activity.id,
      date: Date.to_string(activity.date),
      title: activity.title,
      content: activity.content,
      tags: activity.tags,
      status: activity.status,
      category: activity.category,
      google_doc_id: activity.google_doc_id,
      google_doc_url: activity.google_doc_url,
      synced_at: activity.synced_at,
      created_by: activity.created_by,
      inserted_at: activity.inserted_at,
      updated_at: activity.updated_at
    }
  end

  defp translate_error({msg, opts}) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
