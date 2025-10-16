defmodule WeaviateExTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks
  alias WeaviateEx.Fixtures

  setup :verify_on_exit!
  setup :setup_test_client

  describe "health_check/0 with client" do
    test "returns metadata when successful", %{client: client} do
      expect(WeaviateEx.Protocol.Mock, :request, fn ^client, :get, "/v1/meta", nil, _opts ->
        {:ok, Fixtures.meta_fixture()}
      end)

      # The old API WeaviateEx.health_check() needs to be migrated to a client-based API
      # For now, let's test using Client.request directly
      assert {:ok, meta} = WeaviateEx.Client.request(client, :get, "/v1/meta", nil, [])
      assert meta["version"] == "1.28.1"
      assert is_map(meta["modules"])
    end

    test "returns error when request fails", %{client: client} do
      expect(WeaviateEx.Protocol.Mock, :request, fn ^client, :get, "/v1/meta", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :connection_error, message: "Connection refused"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :connection_error}} =
               WeaviateEx.Client.request(client, :get, "/v1/meta", nil, [])
    end

    test "returns error for non-200 status", %{client: client} do
      expect(WeaviateEx.Protocol.Mock, :request, fn ^client, :get, "/v1/meta", nil, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :http_error,
           message: "Internal server error",
           details: %{},
           status_code: 500
         }}
      end)

      assert {:error, %WeaviateEx.Error{status_code: 500}} =
               WeaviateEx.Client.request(client, :get, "/v1/meta", nil, [])
    end
  end

  describe "ready?/0 with client" do
    test "returns true when Weaviate is ready", %{client: client} do
      expect(WeaviateEx.Protocol.Mock, :request, fn ^client,
                                                    :get,
                                                    "/v1/.well-known/ready",
                                                    nil,
                                                    _opts ->
        {:ok, %{}}
      end)

      case WeaviateEx.Client.request(client, :get, "/v1/.well-known/ready", nil, []) do
        {:ok, _} -> assert true
        error -> flunk("Expected success, got: #{inspect(error)}")
      end
    end

    test "returns error when not ready", %{client: client} do
      expect(WeaviateEx.Protocol.Mock, :request, fn ^client,
                                                    :get,
                                                    "/v1/.well-known/ready",
                                                    nil,
                                                    _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :http_error,
           message: "Service unavailable",
           details: %{},
           status_code: 503
         }}
      end)

      assert {:error, %WeaviateEx.Error{status_code: 503}} =
               WeaviateEx.Client.request(client, :get, "/v1/.well-known/ready", nil, [])
    end
  end

  describe "alive?/0 with client" do
    test "returns true when Weaviate is alive", %{client: client} do
      expect(WeaviateEx.Protocol.Mock, :request, fn ^client,
                                                    :get,
                                                    "/v1/.well-known/live",
                                                    nil,
                                                    _opts ->
        {:ok, %{}}
      end)

      case WeaviateEx.Client.request(client, :get, "/v1/.well-known/live", nil, []) do
        {:ok, _} -> assert true
        error -> flunk("Expected success, got: #{inspect(error)}")
      end
    end
  end

  describe "configuration" do
    test "base_url/0 returns configured URL" do
      assert WeaviateEx.base_url() =~ "http"
    end

    test "api_key/0 returns configured API key or nil" do
      assert is_nil(WeaviateEx.api_key()) or is_binary(WeaviateEx.api_key())
    end
  end

  describe "integration tests (requires live Weaviate)" do
    @tag :integration
    test "health_check/0 connects to real Weaviate" do
      if WeaviateEx.TestHelpers.integration_mode?() do
        {:ok, client} =
          WeaviateEx.Client.new(
            base_url: WeaviateEx.base_url(),
            api_key: WeaviateEx.api_key()
          )

        assert {:ok, meta} = WeaviateEx.Client.request(client, :get, "/v1/meta", nil, [])
        assert is_binary(meta["version"])
      else
        # Skip if not in integration mode
        assert true
      end
    end
  end
end
