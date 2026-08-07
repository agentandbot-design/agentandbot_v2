defmodule AgentbotCore.Modules.LLM.Summary do
  @moduledoc """
  Event summarization — agent-hızı MCP event'lerini insan-hızı özetlere dönüştürür.

  Phase 0/1: Pattern-based (LLM yok). EventTaxonomy kullanarak Türkçe etiket üretir.
  Phase 4'te LLM Bridge (Ollama/OpenAI) entegre edilecek — bu modül behavior olarak tasarlandı.
  """

  alias AgentbotCore.Modules.Protocol.EventTaxonomy

  @type summary :: %{
          text: String.t(),
          event_type: String.t(),
          room_id: String.t(),
          severity: :info | :warning | :error,
          timestamp: integer()
        }

  @doc """
  Bir event'i insan-okunabilir summary'ye dönüştürür.

  ## Parametreler
    - event: PubSub event adı (atom veya string)
    - payload: Event verisi (map)

  ## Döndürür
    - summary map veya {:error, reason}
  """
  @spec summarize(atom() | String.t(), map()) :: summary()
  def summarize(event, payload) when is_map(payload) do
    event_str = to_string(event)
    event_type = classify_event(event_str, payload)
    label = EventTaxonomy.label(event_type)
    severity = determine_severity(event_type)
    text = build_summary_text(label, event_str, payload)

    %{
      text: text,
      event_type: event_type,
      room_id: extract_room_id(payload),
      severity: severity,
      timestamp: System.system_time(:millisecond)
    }
  end

  @doc "Payload listesini tek bir summary'ye gruplar (batch processing için)"
  @spec summarize_batch([{atom() | String.t(), map()}]) :: summary()
  def summarize_batch(events) when is_list(events) do
    case events do
      [] ->
        %{
          text: "Boş batch",
          event_type: "empty",
          room_id: "unknown",
          severity: :info,
          timestamp: System.system_time(:millisecond)
        }

      [{event, payload} | _rest] ->
        # İlk event'i baz al, batch boyutunu ekle
        base = summarize(event, payload)

        if length(events) > 1 do
          %{base | text: "#{base.text} (+#{length(events) - 1} olay daha)"}
        else
          base
        end
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp classify_event(event_str, payload) do
    # EventTaxonomy string key'ler bekler — atom key'leri dönüştür
    normalized_payload = normalize_keys(payload)

    cond do
      Map.has_key?(normalized_payload, "method") ->
        EventTaxonomy.classify(normalized_payload)

      event_str == "new_message" ->
        "content_delivered"

      event_str in ["agent_joined", "agent_left"] ->
        event_str

      true ->
        EventTaxonomy.classify(normalized_payload)
    end
  end

  defp normalize_keys(payload) when is_map(payload) do
    Map.new(payload, fn
      {k, v} when is_atom(k) -> {to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp determine_severity(event_type) do
    cond do
      event_type in ["task_failed", "tool_call_failed"] -> :error
      event_type in ["task_cancelled", "tool_call_cancelled"] -> :warning
      true -> :info
    end
  end

  defp build_summary_text(label, _event_str, payload) do
    sender = get_sender(payload)
    room_name = Map.get(payload, :room_name) || Map.get(payload, "room_name")

    parts = [
      format_sender(sender),
      label,
      format_room(room_name)
    ]

    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
  end

  defp format_sender(nil), do: nil
  defp format_sender(name), do: "[#{name}]"

  defp format_room(nil), do: nil
  defp format_room(name), do: "(#{name})"

  defp get_sender(payload) do
    Map.get(payload, :sender_name) ||
      Map.get(payload, "sender_name") ||
      Map.get(payload, :agent_name) ||
      Map.get(payload, "agent_name")
  end

  defp extract_room_id(payload) do
    room_id = Map.get(payload, :room_id) || Map.get(payload, "room_id") || "unknown"
    to_string(room_id)
  end
end
