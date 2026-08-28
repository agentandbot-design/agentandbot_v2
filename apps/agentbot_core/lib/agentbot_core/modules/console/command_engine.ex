defmodule AgentbotCore.Modules.Console.CommandEngine do
  @moduledoc """
  Web terminal komut motoru — /api/exec ve /terminal sayfasının beyni.

  Komutlar düz metin girer, düz metin çıkar:
      "agents list"      → tablo
      "council ask ..."  → konsey (auth)
      "memory search ..."→ arama

  Aynı motor üç yüzeyde: web terminal (insan), /api/exec (agent),
  gelecekteki aab CLI. Parse sunucuda — client sadece transport.
  """

  alias AgentbotCore.Repo
  alias AgentbotCore.Modules.Chat.{Message, Room}
  alias AgentbotCore.Modules.Council.Council
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.Modules.Agents.AgentPresence
  alias AgentbotCore.Modules.Memory.FusionSearch

  @doc "Komut çalıştır → %{ok, output, ms}"
  @spec exec(String.t(), map()) :: %{ok: boolean(), output: String.t(), code: atom() | nil, ms: integer()}
  def exec(cmd, ctx \\ %{}) when is_binary(cmd) do
    t0 = System.monotonic_time(:millisecond)
    cmd = String.trim(cmd)

    result =
      case parse(cmd) do
        {"help", _} -> help_text(ctx)
        {"agents", rest} -> agents_cmd(rest)
        {"rooms", rest} -> rooms_cmd(rest)
        {"room", rest} -> room_cmd(rest, ctx)
        {"task", rest} -> task_cmd(rest, ctx)
        {"memory", rest} -> memory_cmd(rest, ctx)
        {"council", rest} -> council_cmd(rest, ctx)
        {"request", rest} -> request_cmd(rest, ctx)
        {"stats", _} -> stats_cmd()
        {"", _} -> %{ok: true, output: ""}
        {unknown, _} -> %{ok: false, code: :not_found, output: "Bilinmeyen komut: #{unknown} — help"}
      end

    ms = System.monotonic_time(:millisecond) - t0
    Map.put(result, :ms, ms)
  end

  # ── parse ──────────────────────────────────────────────
  defp parse(cmd) do
    case String.split(cmd, " ", parts: 2) do
      [head, rest] -> {head, String.trim(rest)}
      [head] -> {head, ""}
    end
  end

  # ── flag parser: --cap x --agents 3 kalan kelimeler ────
  defp flags(rest) do
    {flags, args} =
      String.split(rest)
      |> Enum.split_with(&String.starts_with?(&1, "--"))

    flag_map =
      flags
      |> Enum.chunk_every(2, 1, [nil])
      |> Enum.flat_map(fn
        ["--" <> k, v] when is_binary(v) and v != "" -> flag_val(k, v)
        ["--" <> k] -> [{k, "true"}]
        _ -> []
      end)
      |> Map.new()

    {flag_map, Enum.join(args, " ")}
  end

  defp flag_val(_k, "--" <> _), do: []
  defp flag_val(k, v), do: [{k, v}]

  defp to_map(m) when is_map(m), do: m
  defp to_map(other), do: %{"id" => other}

  # ── help ───────────────────────────────────────────────
  defp help_text(_ctx) do
    %{ok: true, output: """
    AgentAndBot Terminal — komutlar

    agents [online]              Kayıtlı/çevrimiçi agent'lar
    rooms                        Odalar
    room new <ad>                Yeni oda (auth)
    room say <id> <mesaj>        Odaya mesaj (auth)
    task list [--status open]    Task'lar
    task create <ad> --cap <c>   Task oluştur (auth)
    memory search <sorgu>        Kurumsal hafızada ara
    memory add <metin>           Hafızaya yaz (auth)
    council ask <soru> --agents N  Konsey (auth)
    request <ihtiyaç>            İnsan girişi — derdini yaz
    stats                        Sistem istatistikleri
    help                         Bu liste
    """}
  end

  # ── agents ─────────────────────────────────────────────
  defp agents_cmd(rest) do
    case rest do
      "online" ->
        case AgentPresence.list_online() do
          [] -> %{ok: true, output: "Çevrimiçi agent yok"}
          agents ->
            rows = Enum.map(agents, &"  #{String.pad_trailing(&1.agent_name || &1.agent_id, 22)} ● online")
            %{ok: true, output: "Çevrimiçi agent'lar:\n" <> Enum.join(rows, "\n")}
        end

      _ ->
        agents = Repo.all(AgentbotCore.Modules.Security.AgentCredential)
        rows =
          Enum.map(agents, fn a ->
            online = if AgentPresence.online?(a.agent_id), do: "● online", else: "○ offline"
            "  #{String.pad_trailing(a.agent_id, 22)} #{online}"
          end)

        %{ok: true, output: "Agent'lar (#{length(agents)}):\n" <> Enum.join(rows, "\n")}
    end
  end

  # ── rooms ──────────────────────────────────────────────
  defp rooms_cmd(_rest) do
    rooms = Repo.all(Room)
    rows = Enum.map(rooms, fn r -> "  ##{r.id}  #{r.name}" end)
    %{ok: true, output: "Odalar (#{length(rooms)}):\n" <> Enum.join(rows, "\n")}
  end

  defp room_cmd(rest, ctx) do
    case String.split(rest, " ", parts: 3) do
      ["new", name] ->
        if ctx[:agent_id] do
          {:ok, room} = Room.create(%{name: name})
          %{ok: true, output: "Oda oluşturuldu ##{room.id} #{room.name}"}
        else
          unauthorized("room new")
        end

      ["say", id, msg] ->
        if ctx[:agent_id] do
          case Repo.get(Room, id) do
            nil -> %{ok: false, code: :not_found, output: "Oda yok: #{id}"}
            room ->
              {:ok, _} = Message.create(%{
                room_id: room.id,
                sender_id: ctx[:agent_id],
                sender_name: ctx[:agent_name] || ctx[:agent_id],
                content: msg,
                message_type: "text"
              })
              %{ok: true, output: "→ ##{room.id} gönderildi"}
          end
        else
          unauthorized("room say")
        end

      _ ->
        %{ok: false, code: :usage, output: "Kullanım: room new <ad> | room say <id> <mesaj>"}
    end
  end

  # ── task ───────────────────────────────────────────────
  defp task_cmd(rest, ctx) do
    {fl, args} = flags(rest)

    case String.split(args, " ", parts: 2) do
      ["list"] ->
        tasks = Repo.all(Task) |> Enum.take(20)
        rows = Enum.map(tasks, fn t -> "  ##{t.id}  [#{t.status}]  #{t.title}" end)
        %{ok: true, output: "Task'lar (son #{length(tasks)}):\n" <> Enum.join(rows, "\n")}

      ["create", title] when title != "" ->
        if ctx[:agent_id] do
          case Task.create(%{title: title, capability: fl["cap"] || "general", created_by: ctx[:agent_id]}) do
            {:ok, task} ->
              assignee = if task.assigned_to, do: " → atandı: #{task.assigned_to}", else: ""
              %{ok: true, output: "Task ##{task.id} oluşturuldu#{assignee}"}
            {:error, reason} ->
              %{ok: false, code: :error, output: "Task hatası: #{inspect(reason)}"}
          end
        else
          unauthorized("task create")
        end

      _ ->
        %{ok: false, code: :usage, output: "Kullanım: task list | task create <başlık> --cap <capability>"}
    end
  end

  # ── memory ─────────────────────────────────────────────
  defp memory_cmd(rest, ctx) do
    case String.split(rest, " ", parts: 2) do
      ["search", query] when query != "" ->
        case FusionSearch.search(query, ctx[:user_id] || "terminal", limit: 5) do
          {:ok, results} ->
            lines =
              Enum.map(results, fn r ->
                "  [#{r.source}] #{String.slice(r.content || "", 0, 70)}"
              end)

            %{ok: true, output: "Bulunan (#{length(results)}):\n" <> Enum.join(lines, "\n")}
        end

      ["add", content] when content != "" ->
        if ctx[:agent_id] do
          chunk = %{"content" => content, "source" => "agent", "title" => "terminal", "project" => "console"}

          case AgentbotCore.Modules.Memory.MemLocalClient.ingest(chunk) do
            {:ok, data} ->
              id = get_in(to_map(data), ["id"]) || get_in(to_map(data), [:id]) || "?"
              %{ok: true, output: "Hafızaya yazıldı (##{id})"}
            {:error, e} ->
              %{ok: false, code: :error, output: "Yazma hatası: #{inspect(e)}"}
          end
        else
          unauthorized("memory add")
        end

      _ ->
        %{ok: false, code: :usage, output: "Kullanım: memory search <sorgu> | memory add <metin>"}
    end
  end

  # ── council ────────────────────────────────────────────
  defp council_cmd(rest, ctx) do
    {fl, args} = flags(rest)

    case String.split(args, " ", parts: 2) do
      ["ask", question] when question != "" ->
        if is_nil(ctx[:agent_id]) do
          unauthorized("council ask")
        else
          min = case Integer.parse(fl["agents"] || "2") do
            {n, _} -> n
            :error -> 2
          end

          case Council.create(%{question: question, min_responses: min}) do
            {:ok, council} ->
              %{ok: true, output: "Konsey ##{council.id} açıldı — #{min} agent'e soruldu.\nYanıtları izle: council show ##{council.id} (API: GET /api/council/#{council.id})"}
            {:error, e} ->
              %{ok: false, code: :error, output: "Konsey hatası: #{inspect(e)}"}
          end
        end

      ["show", id] ->
        case Repo.get(Council, id) do
          nil -> %{ok: false, code: :not_found, output: "Konsey yok: #{id}"}
          council -> %{ok: true, output: "Konsey ##{council.id}: #{council.question}\nDurum: #{council.status}"}
        end

      _ ->
        %{ok: false, code: :usage, output: "Kullanım: council ask <soru> --agents N | council show <id>"}
    end
  end

  # ── request (insan girişi) ─────────────────────────────
  defp request_cmd(rest, _ctx) do
    case rest do
      "" -> %{ok: false, code: :usage, output: "Kullanım: request <ihtiyacın>"}
      need ->
        %{ok: true, output: "İstek alındı: \"#{need}\"\n(Sistem capability tahmin edip uygun agent'a delege eder — POST /api/request)"}
    end
  end

  # ── stats ──────────────────────────────────────────────
  defp stats_cmd do
    counts = %{
      agents: Repo.aggregate(AgentbotCore.Modules.Security.AgentCredential, :count),
      rooms: Repo.aggregate(Room, :count),
      messages: Repo.aggregate(Message, :count),
      tasks: Repo.aggregate(Task, :count),
      online: AgentPresence.count_online()
    }

    %{ok: true, output: """
    AgentAndBot — canlı istatistikler
      agent'lar:     #{counts.agents}
      çevrimiçi:     #{counts.online}
      odalar:        #{counts.rooms}
      mesajlar:      #{counts.messages}
      task'lar:      #{counts.tasks}
    """}
  end

  defp unauthorized(cmd),
    do: %{ok: false, code: :unauthorized, output: "'#{cmd}' için yetki gerekli — token: terminal sayfasından veya aabt token <değer>"}
end
