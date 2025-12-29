defmodule WeaviateEx.Debug.RequestLogger do
  @moduledoc """
  Request/response logging GenServer for debugging Weaviate operations.

  Provides centralized logging of HTTP and gRPC requests with timestamps,
  filtering, and export capabilities.

  ## Example

      # Start the logger
      {:ok, _pid} = RequestLogger.start_link(name: :my_logger, max_logs: 1000)

      # Enable logging
      RequestLogger.enable(:my_logger)

      # Perform operations...

      # Get recent logs
      logs = RequestLogger.get_logs(:my_logger, limit: 10)

      # Export to file
      RequestLogger.export_logs(:my_logger, "/tmp/debug.json", :json)
  """

  use GenServer

  @type protocol :: :http | :grpc

  @type log_entry :: %{
          timestamp: DateTime.t(),
          protocol: protocol(),
          method: atom() | String.t(),
          path: String.t(),
          request_body: term() | nil,
          response_status: pos_integer() | atom(),
          response_body: term() | nil,
          duration_ms: non_neg_integer()
        }

  @type state :: %{
          enabled: boolean(),
          logs: [log_entry()],
          max_logs: pos_integer()
        }

  @default_max_logs 10_000

  # Client API

  @doc """
  Start the RequestLogger GenServer.

  ## Options

    * `:name` - GenServer name (required for most operations)
    * `:max_logs` - Maximum number of logs to keep (default: 10000)

  ## Example

      {:ok, pid} = RequestLogger.start_link(name: :debug_logger, max_logs: 5000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    max_logs = Keyword.get(opts, :max_logs, @default_max_logs)

    init_state = %{
      enabled: false,
      logs: [],
      max_logs: max_logs
    }

    if name do
      GenServer.start_link(__MODULE__, init_state, name: name)
    else
      GenServer.start_link(__MODULE__, init_state)
    end
  end

  @doc """
  Enable request logging.

  ## Example

      RequestLogger.enable(:my_logger)
  """
  @spec enable(GenServer.server()) :: :ok
  def enable(server) do
    GenServer.call(server, :enable)
  end

  @doc """
  Disable request logging.

  ## Example

      RequestLogger.disable(:my_logger)
  """
  @spec disable(GenServer.server()) :: :ok
  def disable(server) do
    GenServer.call(server, :disable)
  end

  @doc """
  Check if logging is enabled.

  ## Example

      if RequestLogger.enabled?(:my_logger) do
        # logging is active
      end
  """
  @spec enabled?(GenServer.server()) :: boolean()
  def enabled?(server) do
    GenServer.call(server, :enabled?)
  end

  @doc """
  Log a request/response.

  The entry should contain:
    * `:protocol` - `:http` or `:grpc`
    * `:method` - HTTP method or gRPC procedure name
    * `:path` - Request path
    * `:request_body` - Request body (optional)
    * `:response_status` - HTTP status code or gRPC status
    * `:response_body` - Response body (optional)
    * `:duration_ms` - Request duration in milliseconds

  ## Example

      RequestLogger.log_request(:my_logger, %{
        protocol: :http,
        method: :get,
        path: "/v1/objects/Article/uuid",
        response_status: 200,
        duration_ms: 45
      })
  """
  @spec log_request(GenServer.server(), map()) :: :ok
  def log_request(server, entry) do
    GenServer.cast(server, {:log, entry})
  end

  @doc """
  Get logged requests.

  ## Options

    * `:limit` - Maximum number of logs to return
    * `:protocol` - Filter by protocol (`:http` or `:grpc`)
    * `:since` - Only return logs after this DateTime

  ## Example

      logs = RequestLogger.get_logs(:my_logger, limit: 10, protocol: :http)
  """
  @spec get_logs(GenServer.server(), keyword()) :: [log_entry()]
  def get_logs(server, opts \\ []) do
    GenServer.call(server, {:get_logs, opts})
  end

  @doc """
  Clear all logged requests.

  ## Example

      RequestLogger.clear_logs(:my_logger)
  """
  @spec clear_logs(GenServer.server()) :: :ok
  def clear_logs(server) do
    GenServer.call(server, :clear_logs)
  end

  @doc """
  Export logs to a file.

  ## Parameters

    * `server` - The logger GenServer
    * `path` - File path to write to
    * `format` - `:json` or `:text`

  ## Example

      RequestLogger.export_logs(:my_logger, "/tmp/logs.json", :json)
  """
  @spec export_logs(GenServer.server(), String.t(), :json | :text) :: :ok | {:error, String.t()}
  def export_logs(server, path, format) do
    GenServer.call(server, {:export_logs, path, format})
  end

  # Server Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:enable, _from, state) do
    {:reply, :ok, %{state | enabled: true}}
  end

  @impl true
  def handle_call(:disable, _from, state) do
    {:reply, :ok, %{state | enabled: false}}
  end

  @impl true
  def handle_call(:enabled?, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl true
  def handle_call({:get_logs, opts}, _from, state) do
    logs =
      state.logs
      |> filter_logs(opts)
      |> maybe_limit_logs(opts)

    {:reply, logs, state}
  end

  @impl true
  def handle_call(:clear_logs, _from, state) do
    {:reply, :ok, %{state | logs: []}}
  end

  @impl true
  def handle_call({:export_logs, path, format}, _from, state) do
    result = do_export_logs(state.logs, path, format)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:log, _entry}, %{enabled: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:log, entry}, state) do
    log_entry = build_log_entry(entry)

    new_logs =
      [log_entry | state.logs]
      |> Enum.take(state.max_logs)

    {:noreply, %{state | logs: new_logs}}
  end

  # Private functions

  defp build_log_entry(entry) do
    %{
      timestamp: DateTime.utc_now(),
      protocol: Map.get(entry, :protocol, :http),
      method: Map.get(entry, :method, :unknown),
      path: Map.get(entry, :path, ""),
      request_body: Map.get(entry, :request_body),
      response_status: Map.get(entry, :response_status),
      response_body: Map.get(entry, :response_body),
      duration_ms: Map.get(entry, :duration_ms, 0)
    }
  end

  defp filter_logs(logs, opts) do
    logs
    |> maybe_filter_protocol(Keyword.get(opts, :protocol))
    |> maybe_filter_since(Keyword.get(opts, :since))
  end

  defp maybe_filter_protocol(logs, nil), do: logs

  defp maybe_filter_protocol(logs, protocol) do
    Enum.filter(logs, &(&1.protocol == protocol))
  end

  defp maybe_filter_since(logs, nil), do: logs

  defp maybe_filter_since(logs, since) do
    Enum.filter(logs, fn log ->
      DateTime.compare(log.timestamp, since) in [:gt, :eq]
    end)
  end

  defp maybe_limit_logs(logs, opts) do
    case Keyword.get(opts, :limit) do
      nil -> logs
      limit -> Enum.take(logs, limit)
    end
  end

  defp do_export_logs(logs, path, :json) do
    json_logs =
      logs
      |> Enum.map(&serialize_log_for_json/1)

    case Jason.encode(json_logs, pretty: true) do
      {:ok, content} ->
        File.write(path, content)

      {:error, reason} ->
        {:error, "Failed to encode JSON: #{inspect(reason)}"}
    end
  end

  defp do_export_logs(logs, path, :text) do
    content = Enum.map_join(logs, "\n", &format_log_as_text/1)

    File.write(path, content)
  end

  defp do_export_logs(_logs, _path, format) do
    {:error, "Unsupported format: #{inspect(format)}"}
  end

  defp serialize_log_for_json(log) do
    %{
      timestamp: DateTime.to_iso8601(log.timestamp),
      protocol: to_string(log.protocol),
      method: format_method(log.method),
      path: log.path,
      response_status: status_to_string(log.response_status),
      duration_ms: log.duration_ms
    }
  end

  defp format_log_as_text(log) do
    timestamp = DateTime.to_iso8601(log.timestamp)
    method = format_method(log.method)
    status = status_to_string(log.response_status)

    "[#{timestamp}] #{String.upcase(to_string(log.protocol))} #{method} #{log.path} -> #{status} (#{log.duration_ms}ms)"
  end

  defp format_method(method) when is_atom(method), do: String.upcase(to_string(method))
  defp format_method(method) when is_binary(method), do: method
  defp format_method(method), do: inspect(method)

  defp status_to_string(status) when is_integer(status), do: to_string(status)
  defp status_to_string(status) when is_atom(status), do: to_string(status)
  defp status_to_string(status), do: inspect(status)
end
