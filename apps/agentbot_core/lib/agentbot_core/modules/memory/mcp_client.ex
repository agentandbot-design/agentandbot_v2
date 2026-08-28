defmodule AgentbotCore.Modules.Memory.MCPClient do
  @moduledoc """
  MCP (Model Context Protocol) client for external memory services.
  Supports Streamable HTTP transport with SSE response parsing.
  """

  require Logger

  @type tool_call :: %{
          name: String.t(),
          arguments: map()
        }

  @type tool_result :: %{
          content: [map()],
          is_error: boolean()
        }

  @doc """
  Initialize MCP connection with server.
  """
  @spec initialize(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def initialize(url, api_key) do
    payload = %{
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: %{
        protocolVersion: "2024-11-05",
        capabilities: %{},
        clientInfo: %{
          name: "agentandbot",
          version: "0.1.0"
        }
      }
    }

    case make_request(url, api_key, payload) do
      {:ok, %{"result" => result}} -> {:ok, result}
      {:error, _} = err -> err
    end
  end

  @doc """
  List available tools from MCP server.
  """
  @spec list_tools(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def list_tools(url, api_key) do
    payload = %{
      jsonrpc: "2.0",
      id: 2,
      method: "tools/list",
      params: %{}
    }

    case make_request(url, api_key, payload) do
      {:ok, %{"result" => %{"tools" => tools}}} -> {:ok, tools}
      {:error, _} = err -> err
    end
  end

  @doc """
  Call a tool on the MCP server.
  """
  @spec call_tool(String.t(), String.t(), String.t(), map()) :: {:ok, tool_result()} | {:error, term()}
  def call_tool(url, api_key, tool_name, arguments) do
    payload = %{
      jsonrpc: "2.0",
      id: System.unique_integer([:positive]),
      method: "tools/call",
      params: %{
        name: tool_name,
        arguments: arguments
      }
    }

    case make_request(url, api_key, payload) do
      {:ok, %{"result" => result}} -> {:ok, result}
      {:error, _} = err -> err
    end
  end

  # Private helpers

  defp make_request(url, api_key, payload) do
    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json, text/event-stream"},
      {"authorization", "Bearer #{api_key}"}
    ]

    body = Jason.encode!(payload)

    case Req.post(url, headers: headers, body: body, receive_timeout: 30_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        parse_sse_response(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("MCP request failed: #{status} - #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("MCP request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_sse_response(body) when is_binary(body) do
    # SSE format: "event: message\ndata: {...}\n\n"
    body
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data: "))
    |> Enum.map(&String.trim_leading(&1, "data: "))
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&Jason.decode!/1)
    |> case do
      [result | _] -> {:ok, result}
      [] -> {:error, :no_sse_data}
    end
  rescue
    e in Jason.DecodeError ->
      Logger.error("Failed to parse SSE JSON: #{inspect(e)}")
      {:error, {:parse_error, e}}
  end

  defp parse_sse_response(%{} = json) do
    {:ok, json}
  end
end
