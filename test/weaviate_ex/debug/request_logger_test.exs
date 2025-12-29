defmodule WeaviateEx.Debug.RequestLoggerTest do
  use ExUnit.Case, async: false

  alias WeaviateEx.Debug.RequestLogger

  # Helper to safely stop a GenServer
  defp safe_stop(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.stop(pid)
    else
      :ok
    end
  catch
    :exit, _ -> :ok
  end

  defp safe_stop(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> :ok
      pid -> safe_stop(pid)
    end
  end

  describe "start_link/1" do
    test "starts the logger GenServer" do
      {:ok, pid} = RequestLogger.start_link(name: :test_logger_1)
      assert Process.alive?(pid)
      safe_stop(pid)
    end

    test "starts with custom name" do
      {:ok, pid} = RequestLogger.start_link(name: :custom_logger)
      assert Process.whereis(:custom_logger) == pid
      safe_stop(pid)
    end

    test "starts with max_logs option" do
      {:ok, pid} = RequestLogger.start_link(name: :test_logger_2, max_logs: 100)
      assert Process.alive?(pid)
      safe_stop(pid)
    end
  end

  describe "enable/1 and disable/1" do
    setup do
      {:ok, pid} = RequestLogger.start_link(name: :enable_test_logger)
      on_exit(fn -> safe_stop(pid) end)
      %{logger: :enable_test_logger, pid: pid}
    end

    test "enables logging", %{logger: logger} do
      assert :ok == RequestLogger.enable(logger)
      assert RequestLogger.enabled?(logger) == true
    end

    test "disables logging", %{logger: logger} do
      RequestLogger.enable(logger)
      assert :ok == RequestLogger.disable(logger)
      assert RequestLogger.enabled?(logger) == false
    end

    test "starts disabled by default", %{logger: logger} do
      assert RequestLogger.enabled?(logger) == false
    end
  end

  describe "log_request/2" do
    setup do
      {:ok, pid} = RequestLogger.start_link(name: :log_test_logger)
      RequestLogger.enable(:log_test_logger)
      on_exit(fn -> safe_stop(pid) end)
      %{logger: :log_test_logger, pid: pid}
    end

    test "logs HTTP request", %{logger: logger} do
      entry = %{
        protocol: :http,
        method: :get,
        path: "/v1/objects",
        request_body: nil,
        response_status: 200,
        response_body: %{"objects" => []},
        duration_ms: 50
      }

      :ok = RequestLogger.log_request(logger, entry)

      logs = RequestLogger.get_logs(logger)
      assert length(logs) == 1

      [log] = logs
      assert log.protocol == :http
      assert log.method == :get
      assert log.path == "/v1/objects"
      assert log.response_status == 200
      assert log.duration_ms == 50
      assert %DateTime{} = log.timestamp
    end

    test "logs gRPC request", %{logger: logger} do
      entry = %{
        protocol: :grpc,
        method: "Search",
        path: "weaviate.v1.Weaviate/Search",
        request_body: %{collection: "Article"},
        response_status: :ok,
        response_body: %{results: []},
        duration_ms: 25
      }

      :ok = RequestLogger.log_request(logger, entry)

      logs = RequestLogger.get_logs(logger)
      assert length(logs) == 1

      [log] = logs
      assert log.protocol == :grpc
      assert log.method == "Search"
    end

    test "does not log when disabled", %{logger: logger} do
      RequestLogger.disable(logger)

      entry = %{
        protocol: :http,
        method: :get,
        path: "/v1/objects",
        response_status: 200,
        duration_ms: 50
      }

      :ok = RequestLogger.log_request(logger, entry)

      logs = RequestLogger.get_logs(logger)
      assert logs == []
    end
  end

  describe "get_logs/1" do
    setup do
      {:ok, pid} = RequestLogger.start_link(name: :get_logs_test_logger)
      RequestLogger.enable(:get_logs_test_logger)
      on_exit(fn -> safe_stop(pid) end)
      %{logger: :get_logs_test_logger, pid: pid}
    end

    test "returns all logs", %{logger: logger} do
      Enum.each(1..3, fn i ->
        RequestLogger.log_request(logger, %{
          protocol: :http,
          method: :get,
          path: "/v1/objects/#{i}",
          response_status: 200,
          duration_ms: 10 * i
        })
      end)

      logs = RequestLogger.get_logs(logger)
      assert length(logs) == 3
    end

    test "returns logs with limit option", %{logger: logger} do
      Enum.each(1..5, fn i ->
        RequestLogger.log_request(logger, %{
          protocol: :http,
          method: :get,
          path: "/v1/objects/#{i}",
          response_status: 200,
          duration_ms: 10
        })
      end)

      logs = RequestLogger.get_logs(logger, limit: 2)
      assert length(logs) == 2
    end

    test "returns logs with protocol filter", %{logger: logger} do
      RequestLogger.log_request(logger, %{
        protocol: :http,
        method: :get,
        path: "/v1/objects",
        response_status: 200,
        duration_ms: 10
      })

      RequestLogger.log_request(logger, %{
        protocol: :grpc,
        method: "Search",
        path: "weaviate/Search",
        response_status: :ok,
        duration_ms: 10
      })

      http_logs = RequestLogger.get_logs(logger, protocol: :http)
      grpc_logs = RequestLogger.get_logs(logger, protocol: :grpc)

      assert length(http_logs) == 1
      assert length(grpc_logs) == 1
      assert hd(http_logs).protocol == :http
      assert hd(grpc_logs).protocol == :grpc
    end

    test "returns empty list when no logs", %{logger: logger} do
      RequestLogger.clear_logs(logger)
      logs = RequestLogger.get_logs(logger)
      assert logs == []
    end
  end

  describe "clear_logs/1" do
    setup do
      {:ok, pid} = RequestLogger.start_link(name: :clear_test_logger)
      RequestLogger.enable(:clear_test_logger)
      on_exit(fn -> safe_stop(pid) end)
      %{logger: :clear_test_logger, pid: pid}
    end

    test "clears all logs", %{logger: logger} do
      Enum.each(1..3, fn i ->
        RequestLogger.log_request(logger, %{
          protocol: :http,
          method: :get,
          path: "/v1/objects/#{i}",
          response_status: 200,
          duration_ms: 10
        })
      end)

      assert length(RequestLogger.get_logs(logger)) == 3

      :ok = RequestLogger.clear_logs(logger)

      assert RequestLogger.get_logs(logger) == []
    end
  end

  describe "export_logs/3" do
    setup do
      {:ok, pid} = RequestLogger.start_link(name: :export_test_logger)
      RequestLogger.enable(:export_test_logger)
      on_exit(fn -> safe_stop(pid) end)
      %{logger: :export_test_logger, pid: pid}
    end

    test "exports logs to JSON file", %{logger: logger} do
      RequestLogger.log_request(logger, %{
        protocol: :http,
        method: :get,
        path: "/v1/objects",
        response_status: 200,
        duration_ms: 50
      })

      path = Path.join(System.tmp_dir!(), "test_logs_#{:rand.uniform(10000)}.json")

      try do
        :ok = RequestLogger.export_logs(logger, path, :json)
        assert File.exists?(path)

        content = File.read!(path)
        {:ok, decoded} = Jason.decode(content)
        assert is_list(decoded)
        assert length(decoded) == 1
      after
        File.rm(path)
      end
    end

    test "exports logs to text file", %{logger: logger} do
      RequestLogger.log_request(logger, %{
        protocol: :http,
        method: :get,
        path: "/v1/objects",
        response_status: 200,
        duration_ms: 50
      })

      path = Path.join(System.tmp_dir!(), "test_logs_#{:rand.uniform(10000)}.txt")

      try do
        :ok = RequestLogger.export_logs(logger, path, :text)
        assert File.exists?(path)

        content = File.read!(path)
        assert content =~ "GET"
        assert content =~ "/v1/objects"
        assert content =~ "200"
      after
        File.rm(path)
      end
    end

    test "returns error for invalid format", %{logger: logger} do
      path = Path.join(System.tmp_dir!(), "test_logs.xyz")

      {:error, reason} = RequestLogger.export_logs(logger, path, :invalid)
      assert reason =~ "Unsupported format"
    end
  end

  describe "max_logs behavior" do
    test "respects max_logs limit" do
      {:ok, pid} = RequestLogger.start_link(name: :max_logs_test_logger, max_logs: 3)
      RequestLogger.enable(:max_logs_test_logger)

      try do
        Enum.each(1..5, fn i ->
          RequestLogger.log_request(:max_logs_test_logger, %{
            protocol: :http,
            method: :get,
            path: "/v1/objects/#{i}",
            response_status: 200,
            duration_ms: 10
          })
        end)

        logs = RequestLogger.get_logs(:max_logs_test_logger)
        assert length(logs) == 3

        # Should keep most recent logs (paths /3, /4, /5)
        paths = Enum.map(logs, & &1.path)
        refute "/v1/objects/1" in paths
        refute "/v1/objects/2" in paths
      after
        safe_stop(pid)
      end
    end
  end
end
