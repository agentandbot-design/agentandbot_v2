defmodule AgentbotCore.Modules.Marketplace.TaskView do
  @moduledoc """
  Task'in iki projeksiyonu — tek kaynak, iki görünüm katmanı.

  - `human/1` — insan görünümü: başlık, özet, durum, atanan, ilerleme. Alt işler
    ve teknik detaylar YOK (UI'da "detayları göster" ile genişletilir).
  - `agent/1` — agent görünümü: tüm alanlar, subtasks, technical_context,
    sync durumu. Programatik (JSON API) erişim için.

  Görünüm seçimi render/filter katmanıdır; veri modelinde insan/agent ayrımı yoktur.
  """

  alias AgentbotCore.Modules.Marketplace.Task

  @human_fields [
    :id,
    :title,
    :summary,
    :status,
    :priority,
    :assigned_to,
    :team,
    :tags,
    :deadline_at,
    :updated_at,
    :updated_by
  ]

  @doc "İnsan görünümü — subtask sayısı progress olarak özetlenir"
  def human(%Task{} = task, children \\ []) do
    base = Map.take(task, @human_fields)

    base
    |> Map.put(:summary, task.summary || first_line(task.description))
    |> Map.put(:subtask_progress, subtask_progress(children))
  end

  @doc "Agent görünümü — tam serializasyon + subtasks + technical_context"
  def agent(%Task{} = task, children \\ []) do
    %{
      id: task.id,
      title: task.title,
      summary: task.summary,
      description: task.description,
      status: task.status,
      priority: task.priority,
      assigned_to: task.assigned_to,
      capability: task.capability,
      team: task.team,
      visibility: task.visibility,
      tags: task.tags,
      input: task.input,
      parent_id: task.parent_id,
      subtasks: Enum.map(children, &agent_subtask/1),
      technical_context: task.technical_context || %{},
      sync_state: task.sync_state,
      sync_metadata: task.sync_metadata || %{},
      updated_by: task.updated_by,
      external_url: task.external_url,
      source_type: task.source_type,
      inserted_at: task.inserted_at,
      updated_at: task.updated_at
    }
  end

  defp agent_subtask(child) do
    %{
      id: child.id,
      title: child.title,
      summary: child.summary || first_line(child.description),
      status: child.status,
      assigned_to: child.assigned_to,
      technical_context: child.technical_context || %{}
    }
  end

  defp subtask_progress([]), do: nil
  defp subtask_progress(nil), do: nil

  defp subtask_progress(children) do
    done = Enum.count(children, &(&1.status in ["completed", "failed"]))
    %{done: done, total: length(children)}
  end

  defp first_line(nil), do: nil
  defp first_line(text), do: text |> String.split("\n") |> List.first() |> String.slice(0, 280)
end
