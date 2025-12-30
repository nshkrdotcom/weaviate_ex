defmodule WeaviateEx.Journey.ScenariosTest do
  @moduledoc """
  Tests for WeaviateEx.Journey.Scenarios module.

  These tests validate that the journey scenarios work correctly when
  executed against a live Weaviate instance.

  Run with: WEAVIATE_INTEGRATION=true mix test --include journey
  """

  use ExUnit.Case, async: false

  alias WeaviateEx.Client
  alias WeaviateEx.Journey.Scenarios

  @moduletag :journey
  @moduletag :integration

  setup_all do
    # Ensure we're using the real HTTP client
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Connect to Weaviate
    case Client.connect(base_url: "http://localhost:8080", skip_init_checks: true) do
      {:ok, client} ->
        on_exit(fn ->
          Client.close(client)
        end)

        {:ok, client: client}

      {:error, reason} ->
        flunk("Failed to connect to Weaviate: #{inspect(reason)}")
    end
  end

  describe "simple/1" do
    test "creates collection, inserts objects, queries, and cleans up", %{client: client} do
      result = Scenarios.simple(client)
      assert result == :ok
    end

    test "handles multiple sequential runs", %{client: client} do
      # Run the scenario multiple times to ensure cleanup is working
      assert Scenarios.simple(client) == :ok
      assert Scenarios.simple(client) == :ok
      assert Scenarios.simple(client) == :ok
    end
  end

  describe "batch_insert_and_search/1" do
    @tag timeout: 120_000
    test "batch inserts 1000 objects and performs vector search", %{client: client} do
      result = Scenarios.batch_insert_and_search(client)
      assert result == :ok
    end
  end

  describe "concurrent_operations/1" do
    @tag timeout: 60_000
    test "handles 10 concurrent operations without errors", %{client: client} do
      result = Scenarios.concurrent_operations(client)
      assert result == :ok
    end

    test "multiple concurrent runs work correctly", %{client: client} do
      # Run concurrent operations twice to ensure state isolation
      assert Scenarios.concurrent_operations(client) == :ok
      assert Scenarios.concurrent_operations(client) == :ok
    end
  end

  describe "error handling" do
    test "simple/1 returns error tuple on failure" do
      # Create a client with wrong URL to simulate failure
      {:ok, bad_client} =
        Client.new(base_url: "http://localhost:9999", skip_init_checks: true)

      result = Scenarios.simple(bad_client)
      assert match?({:error, _}, result)
    end
  end
end
