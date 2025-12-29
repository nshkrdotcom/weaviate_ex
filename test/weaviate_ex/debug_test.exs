defmodule WeaviateEx.DebugTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Client
  alias WeaviateEx.Debug

  # Mock protocol implementation for testing
  defmodule MockProtocol do
    def request(_client, method, path, body, _opts) do
      case Process.get(:mock_responses) do
        [response | rest] ->
          Process.put(:mock_responses, rest)

          Process.put(:recorded_requests, [
            {method, path, body} | Process.get(:recorded_requests, [])
          ])

          response

        [] ->
          {:error, :no_response}
      end
    end
  end

  defp mock_client(responses) do
    Process.put(:mock_responses, responses)
    Process.put(:recorded_requests, [])

    %Client{
      config: %WeaviateEx.Client.Config{
        base_url: "http://localhost:8080",
        api_key: nil,
        grpc_host: "localhost",
        grpc_port: 50_051,
        grpc_max_message_size: 104_857_600
      },
      grpc_channel: nil,
      protocol_impl: MockProtocol
    }
  end

  defp get_requests do
    Enum.reverse(Process.get(:recorded_requests, []))
  end

  describe "get_object_rest/4" do
    test "retrieves object via REST API" do
      response = %{
        "id" => "test-uuid-123",
        "class" => "Article",
        "properties" => %{"title" => "Test Article"},
        "vector" => [0.1, 0.2, 0.3]
      }

      client = mock_client([{:ok, response}])

      {:ok, object} = Debug.get_object_rest(client, "Article", "test-uuid-123")

      assert object["id"] == "test-uuid-123"
      assert object["properties"]["title"] == "Test Article"

      [{:get, path, _}] = get_requests()
      assert path =~ "/v1/objects/Article/test-uuid-123"
    end

    test "retrieves object with tenant option" do
      response = %{
        "id" => "test-uuid-123",
        "class" => "Article",
        "properties" => %{"title" => "Test Article"}
      }

      client = mock_client([{:ok, response}])

      {:ok, _object} =
        Debug.get_object_rest(client, "Article", "test-uuid-123", tenant: "tenant-a")

      [{:get, path, _}] = get_requests()
      assert path =~ "tenant=tenant-a"
    end

    test "retrieves object with include option" do
      response = %{
        "id" => "test-uuid-123",
        "class" => "Article",
        "properties" => %{"title" => "Test Article"},
        "vector" => [0.1, 0.2, 0.3]
      }

      client = mock_client([{:ok, response}])

      {:ok, _object} =
        Debug.get_object_rest(client, "Article", "test-uuid-123", include: ["vector"])

      [{:get, path, _}] = get_requests()
      assert path =~ "include="
    end

    test "returns error for non-existent object" do
      error = %WeaviateEx.Error{type: :not_found, message: "Object not found"}
      client = mock_client([{:error, error}])

      {:error, err} = Debug.get_object_rest(client, "Article", "nonexistent")

      assert err.type == :not_found
    end
  end

  describe "get_object_grpc/4" do
    test "returns error when no gRPC channel" do
      client = mock_client([])

      {:error, error} = Debug.get_object_grpc(client, "Article", "test-uuid-123")

      assert error.type == :connection_error
      assert error.message =~ "gRPC"
    end
  end

  describe "compare_protocols/4" do
    test "compares REST and gRPC results when gRPC unavailable" do
      rest_response = %{
        "id" => "test-uuid-123",
        "class" => "Article",
        "properties" => %{"title" => "Test Article"},
        "vector" => [0.1, 0.2, 0.3]
      }

      client = mock_client([{:ok, rest_response}])

      # When gRPC is not available, it should return error or partial comparison
      result = Debug.compare_protocols(client, "Article", "test-uuid-123")

      case result do
        {:ok, comparison} ->
          assert Map.has_key?(comparison, :rest_object)
          assert comparison.rest_object != nil

        {:error, _} ->
          # Expected when gRPC is not available
          assert true
      end
    end
  end

  describe "connection_info/1" do
    test "returns connection information" do
      client = mock_client([])

      {:ok, info} = Debug.connection_info(client)

      assert info.base_url == "http://localhost:8080"
      assert info.grpc_host == "localhost"
      assert info.grpc_port == 50_051
      assert info.grpc_connected == false
    end

    test "includes TLS status" do
      client = mock_client([])

      {:ok, info} = Debug.connection_info(client)

      assert Map.has_key?(info, :tls_enabled)
      assert info.tls_enabled == false
    end
  end
end
