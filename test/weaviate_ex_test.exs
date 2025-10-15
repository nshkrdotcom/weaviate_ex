defmodule WeaviateExTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.TestHelpers
  alias WeaviateEx.Fixtures

  setup :verify_on_exit!
  setup :setup_http_client

  describe "health_check/0" do
    test "returns metadata when successful" do
      expect_http_request(:get, "/v1/meta", fn ->
        mock_success_response(Fixtures.meta_fixture())
      end)

      assert {:ok, meta} = WeaviateEx.health_check()
      assert meta["version"] == "1.28.1"
      assert is_map(meta["modules"])
    end

    test "returns error when request fails" do
      expect(WeaviateEx.HTTPClient.Mock, :request, fn :get, _url, _headers, _body, _opts ->
        {:error, :econnrefused}
      end)

      assert {:error, :econnrefused} = WeaviateEx.health_check()
    end

    test "returns error for non-200 status" do
      expect_http_request(:get, "/v1/meta", fn ->
        mock_error_response(500, "Internal server error")
      end)

      assert {:error, %{status: 500}} = WeaviateEx.health_check()
    end
  end

  describe "ready?/0" do
    test "returns true when Weaviate is ready" do
      expect_http_request(:get, "/.well-known/ready", fn ->
        mock_success_response(%{})
      end)

      assert {:ok, true} = WeaviateEx.ready?()
    end

    test "returns error when not ready" do
      expect_http_request(:get, "/.well-known/ready", fn ->
        mock_error_response(503, "Service unavailable")
      end)

      assert {:error, %{status: 503}} = WeaviateEx.ready?()
    end
  end

  describe "alive?/0" do
    test "returns true when Weaviate is alive" do
      expect_http_request(:get, "/.well-known/live", fn ->
        mock_success_response(%{})
      end)

      assert {:ok, true} = WeaviateEx.alive?()
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
      if integration_mode?() do
        assert {:ok, meta} = WeaviateEx.health_check()
        assert is_binary(meta["version"])
      else
        # Skip if not in integration mode
        assert true
      end
    end
  end
end
