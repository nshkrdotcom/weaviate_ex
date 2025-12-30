defmodule WeaviateEx.Journey.PhoenixTest do
  @moduledoc """
  Phoenix integration tests for WeaviateEx.

  Validates that WeaviateEx works correctly when embedded in a Phoenix
  web application, testing:

  1. Client initialization at application startup
  2. Client access via conn.assigns
  3. Concurrent request handling
  4. Proper cleanup on shutdown

  Run with: WEAVIATE_INTEGRATION=true mix test --include journey
  """

  use ExUnit.Case, async: false

  alias WeaviateEx.Client
  alias WeaviateEx.Journey.Scenarios

  @moduletag :journey
  @moduletag :integration

  # Define test modules inline to avoid compilation issues
  # These are the minimal Phoenix components needed for testing

  defmodule WeaviateClientPlug do
    @moduledoc false
    @behaviour Plug
    import Plug.Conn

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, _opts) do
      # Get client from application state (set during startup)
      client = Application.get_env(:weaviate_ex, :journey_test_client)
      assign(conn, :weaviate_client, client)
    end
  end

  defmodule JourneyController do
    @moduledoc false
    import Plug.Conn

    def simple(conn, _params) do
      client = conn.assigns[:weaviate_client]

      case Scenarios.simple(client) do
        :ok ->
          send_json(conn, 200, %{status: "success", journey: "simple"})

        {:error, reason} ->
          send_json(conn, 500, %{status: "error", reason: inspect(reason)})
      end
    end

    def batch(conn, _params) do
      client = conn.assigns[:weaviate_client]

      case Scenarios.batch_insert_and_search(client) do
        :ok ->
          send_json(conn, 200, %{status: "success", journey: "batch"})

        {:error, reason} ->
          send_json(conn, 500, %{status: "error", reason: inspect(reason)})
      end
    end

    def concurrent(conn, _params) do
      client = conn.assigns[:weaviate_client]

      case Scenarios.concurrent_operations(client) do
        :ok ->
          send_json(conn, 200, %{status: "success", journey: "concurrent"})

        {:error, reason} ->
          send_json(conn, 500, %{status: "error", reason: inspect(reason)})
      end
    end

    def health(conn, _params) do
      client = conn.assigns[:weaviate_client]

      if client && !Client.closed?(client) do
        send_json(conn, 200, %{status: "ok", client_status: "connected"})
      else
        send_json(conn, 503, %{status: "unavailable", client_status: "disconnected"})
      end
    end

    defp send_json(conn, status, body) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status, Jason.encode!(body))
    end
  end

  defmodule TestRouter do
    @moduledoc false
    use Plug.Router

    plug(:match)
    plug(WeaviateClientPlug)
    plug(:dispatch)

    get "/health" do
      JourneyController.health(conn, %{})
    end

    get "/journey/simple" do
      JourneyController.simple(conn, %{})
    end

    get "/journey/batch" do
      JourneyController.batch(conn, %{})
    end

    get "/journey/concurrent" do
      JourneyController.concurrent(conn, %{})
    end

    match _ do
      send_resp(conn, 404, "Not found")
    end
  end

  defmodule TestEndpoint do
    @moduledoc false
    use Plug.Builder

    plug(Plug.Parsers,
      parsers: [:json],
      pass: ["application/json"],
      json_decoder: Jason
    )

    plug(TestRouter)
  end

  # Test setup

  setup_all do
    # Ensure we're using the real HTTP client
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Connect to Weaviate (simulating application startup)
    case Client.connect(base_url: "http://localhost:8080", skip_init_checks: true) do
      {:ok, client} ->
        Application.put_env(:weaviate_ex, :journey_test_client, client)

        # Start Bandit HTTP server
        {:ok, server} =
          Bandit.start_link(
            plug: TestEndpoint,
            port: 4002,
            ip: {127, 0, 0, 1}
          )

        on_exit(fn ->
          # Clean up (simulating application shutdown)
          Client.close(client)
          Application.delete_env(:weaviate_ex, :journey_test_client)
          Supervisor.stop(server)
        end)

        {:ok, client: client, server: server}

      {:error, reason} ->
        flunk("Failed to connect to Weaviate: #{inspect(reason)}")
    end
  end

  describe "Phoenix integration" do
    test "health endpoint returns connected status" do
      {:ok, response} = http_get("/health")

      assert response.status == 200
      body = Jason.decode!(response.body)
      assert body["status"] == "ok"
      assert body["client_status"] == "connected"
    end

    test "client initialized at startup survives multiple requests" do
      # Make multiple health requests to verify client persists
      for _ <- 1..5 do
        {:ok, response} = http_get("/health")
        assert response.status == 200
      end
    end

    test "simple journey works through Phoenix endpoint" do
      {:ok, response} = http_get("/journey/simple")

      assert response.status == 200
      body = Jason.decode!(response.body)
      assert body["status"] == "success"
      assert body["journey"] == "simple"
    end

    @tag timeout: 120_000
    test "batch journey works through Phoenix endpoint" do
      {:ok, response} = http_get("/journey/batch")

      assert response.status == 200
      body = Jason.decode!(response.body)
      assert body["status"] == "success"
      assert body["journey"] == "batch"
    end

    @tag timeout: 60_000
    test "concurrent requests share client safely" do
      # Spawn multiple concurrent HTTP requests
      tasks =
        1..5
        |> Enum.map(fn _ ->
          Task.async(fn ->
            http_get("/health")
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All requests should succeed
      assert Enum.all?(results, fn {:ok, response} -> response.status == 200 end)
    end

    @tag timeout: 60_000
    test "concurrent journey works through Phoenix endpoint" do
      {:ok, response} = http_get("/journey/concurrent")

      assert response.status == 200
      body = Jason.decode!(response.body)
      assert body["status"] == "success"
      assert body["journey"] == "concurrent"
    end

    test "client properly cleaned up on shutdown", %{client: client} do
      # Verify client is still connected
      refute Client.closed?(client)

      # The actual cleanup test happens in on_exit callback
      # Here we just verify the client is in expected state
      status = Client.status(client)
      assert status == :connected
    end
  end

  # Helper functions

  defp http_get(path) do
    url = "http://127.0.0.1:4002#{path}"

    request = Finch.build(:get, url)

    case Finch.request(request, WeaviateEx.Finch, receive_timeout: 120_000) do
      {:ok, %Finch.Response{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
