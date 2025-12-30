defmodule WeaviateEx.Journey.PlugTest do
  @moduledoc """
  Plug integration tests for WeaviateEx.

  Tests WeaviateEx integration with Plug without the full Phoenix overhead.
  Uses Plug.Test for in-process testing, which is faster and more isolated.

  Run with: WEAVIATE_INTEGRATION=true mix test --include journey
  """

  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias WeaviateEx.Client
  alias WeaviateEx.Journey.Scenarios

  @moduletag :journey
  @moduletag :integration

  # Define test Plug router

  defmodule TestPlug do
    @moduledoc false
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    get "/health" do
      client = Application.get_env(:weaviate_ex, :journey_test_client)

      if client && !Client.closed?(client) do
        send_resp(conn, 200, Jason.encode!(%{status: "ok"}))
      else
        send_resp(conn, 503, Jason.encode!(%{status: "unavailable"}))
      end
    end

    get "/journey/:name" do
      client = Application.get_env(:weaviate_ex, :journey_test_client)

      result =
        case name do
          "simple" -> Scenarios.simple(client)
          "batch" -> Scenarios.batch_insert_and_search(client)
          "concurrent" -> Scenarios.concurrent_operations(client)
          _ -> {:error, :unknown_journey}
        end

      case result do
        :ok ->
          send_resp(conn, 200, Jason.encode!(%{status: "success", journey: name}))

        {:error, reason} ->
          send_resp(conn, 500, Jason.encode!(%{status: "error", reason: inspect(reason)}))
      end
    end

    match _ do
      send_resp(conn, 404, "Not found")
    end
  end

  # Test setup

  setup_all do
    # Ensure we're using the real HTTP client
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Connect to Weaviate
    case Client.connect(base_url: "http://localhost:8080", skip_init_checks: true) do
      {:ok, client} ->
        Application.put_env(:weaviate_ex, :journey_test_client, client)

        on_exit(fn ->
          Client.close(client)
          Application.delete_env(:weaviate_ex, :journey_test_client)
        end)

        {:ok, client: client}

      {:error, reason} ->
        flunk("Failed to connect to Weaviate: #{inspect(reason)}")
    end
  end

  describe "Plug integration" do
    test "client accessible via Application env" do
      client = Application.get_env(:weaviate_ex, :journey_test_client)
      refute is_nil(client)
      refute Client.closed?(client)
    end

    test "health check works through Plug router" do
      conn = conn(:get, "/health")
      conn = TestPlug.call(conn, TestPlug.init([]))

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "ok"
    end

    test "simple journey works through Plug router" do
      conn = conn(:get, "/journey/simple")
      conn = TestPlug.call(conn, TestPlug.init([]))

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "success"
      assert body["journey"] == "simple"
    end

    @tag timeout: 120_000
    test "batch journey works through Plug router" do
      conn = conn(:get, "/journey/batch")
      conn = TestPlug.call(conn, TestPlug.init([]))

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "success"
      assert body["journey"] == "batch"
    end

    @tag timeout: 60_000
    test "concurrent journey works through Plug router" do
      conn = conn(:get, "/journey/concurrent")
      conn = TestPlug.call(conn, TestPlug.init([]))

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "success"
      assert body["journey"] == "concurrent"
    end

    test "unknown journey returns error" do
      conn = conn(:get, "/journey/unknown")
      conn = TestPlug.call(conn, TestPlug.init([]))

      assert conn.status == 500
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "error"
    end

    test "404 for non-existent routes" do
      conn = conn(:get, "/nonexistent")
      conn = TestPlug.call(conn, TestPlug.init([]))

      assert conn.status == 404
    end
  end

  describe "Client lifecycle in Plug context" do
    test "client survives multiple requests" do
      # Simulate multiple sequential requests
      for _ <- 1..5 do
        conn = conn(:get, "/health")
        conn = TestPlug.call(conn, TestPlug.init([]))
        assert conn.status == 200
      end
    end

    test "concurrent Plug requests share client safely" do
      tasks =
        1..10
        |> Enum.map(fn _ ->
          Task.async(fn ->
            conn = conn(:get, "/health")
            conn = TestPlug.call(conn, TestPlug.init([]))
            conn.status
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All requests should succeed
      assert Enum.all?(results, fn status -> status == 200 end)
    end

    test "client state is consistent across requests", %{client: client} do
      # Verify initial state
      initial_status = Client.status(client)
      assert initial_status == :connected

      # Make some requests
      for _ <- 1..3 do
        conn = conn(:get, "/journey/simple")
        conn = TestPlug.call(conn, TestPlug.init([]))
        assert conn.status == 200
      end

      # Verify client is still in expected state
      final_status = Client.status(client)
      assert final_status == :connected
    end
  end

  describe "Plug.Test helpers" do
    test "conn assigns work correctly" do
      # Create a custom plug that uses assigns
      defmodule AssignsPlug do
        @moduledoc false
        import Plug.Conn

        def init(opts), do: opts

        def call(conn, _opts) do
          client = Application.get_env(:weaviate_ex, :journey_test_client)
          conn = assign(conn, :weaviate_client, client)

          if conn.assigns[:weaviate_client] do
            send_resp(conn, 200, "Client assigned")
          else
            send_resp(conn, 500, "No client")
          end
        end
      end

      conn = conn(:get, "/test")
      conn = AssignsPlug.call(conn, AssignsPlug.init([]))

      assert conn.status == 200
      assert conn.resp_body == "Client assigned"
      refute is_nil(conn.assigns[:weaviate_client])
    end
  end
end
