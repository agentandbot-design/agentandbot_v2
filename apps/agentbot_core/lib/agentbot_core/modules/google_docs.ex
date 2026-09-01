defmodule AgentbotCore.Modules.GoogleDocs do
  @moduledoc """
  Google Docs senkronizasyon modülü.
  Activity log'larını Google Docs'a yazar.
  """

  require Logger

  @google_drive_api "https://www.googleapis.com/drive/v3/files"
  @google_docs_api "https://docs.googleapis.com/v1/documents"

  @doc """
  Activity log'u Google Docs'a senkronize eder.
  Yeni doc oluşturur ve içeriği yazar.
  """
  def sync_activity(activity_log) do
    token = get_token()
    with {:ok, doc_id} <- create_doc(token, activity_log.title),
         {:ok, _} <- write_content(token, doc_id, activity_log),
         {:ok, url} <- get_doc_url(token, doc_id) do
      {:ok, doc_id, url}
    else
      {:error, reason} ->
        Logger.error("Google Docs sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Mevcut bir Google Doc'u günceller.
  """
  def update_doc(doc_id, activity_log) do
    token = get_token()
    clear_content(token, doc_id)
    write_content(token, doc_id, activity_log)
  end

  @doc """
  Google Doc'u siler.
  """
  def delete_doc(doc_id) do
    token = get_token()
    url = "#{@google_drive_api}/#{doc_id}"
    headers = [{"Authorization", "Bearer #{token}"}]

    case Req.delete(url, headers: headers) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: code}} -> {:error, "HTTP #{code}"}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp get_token do
    "/home/ubuntu/.hermes/google_token.json"
    |> File.read!()
    |> Jason.decode!()
    |> Map.get("access_token")
  end

  defp create_doc(token, title) do
    body = %{
      name: title,
      mimeType: "application/vnd.google-apps.document"
    }

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post(@google_drive_api, json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"id" => doc_id}}} ->
        {:ok, doc_id}

      {:ok, %{status: 200, body: response}} ->
        case response do
          %{"id" => doc_id} -> {:ok, doc_id}
          _ -> {:error, "Invalid response: #{inspect(response)}"}
        end

      {:ok, %{status: code}} ->
        {:error, "HTTP #{code}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_content(token, doc_id, activity_log) do
    url = "#{@google_docs_api}/#{doc_id}:batchUpdate"

    date_str = Date.to_string(activity_log.date)
    tags = activity_log.tags || ""
    status = String.upcase(activity_log.status || "DRAFT")
    category = String.upcase(activity_log.category || "SAP")

    content = """
    📋 SAP DANIŞMANLIK GÜNLÜĞÜ
    ============================

    📅 Tarih: #{date_str}
    📝 Başlık: #{activity_log.title}
    🏷️ Kategori: #{category}
    📊 Durum: #{status}
    🔖 Etiketler: #{tags}

    ─────────────────────────────
    İÇERİK
    ─────────────────────────────

    #{activity_log.content || "İçerik yok."}

    ─────────────────────────────
    Otomatik oluşturuldu: #{DateTime.utc_now() |> DateTime.to_string()}
    Platform: e-any.online / AgentAndBot
    """

    # Google Docs batchUpdate format
    requests = [
      %{
        insertText: %{
          location: %{
            index: 1
          },
          text: content
        }
      }
    ]

    body = %{requests: requests}

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post(url, json: body, headers: headers) do
      {:ok, %{status: 200}} -> {:ok, doc_id}
      {:ok, %{status: code, body: response}} -> {:error, "HTTP #{code}: #{inspect(response)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp clear_content(_token, _doc_id) do
    # TODO: Implement content clearing for updates
    :ok
  end

  defp get_doc_url(token, doc_id) do
    url = "#{@google_drive_api}/#{doc_id}?fields=webViewLink"
    headers = [{"Authorization", "Bearer #{token}"}]

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: %{"webViewLink" => link}}} ->
        {:ok, link}

      _ ->
        {:ok, "https://docs.google.com/document/d/#{doc_id}"}
    end
  end
end
