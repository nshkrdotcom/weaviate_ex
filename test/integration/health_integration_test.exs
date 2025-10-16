defmodule WeaviateEx.Integration.HealthTest do
  use ExUnit.Case, async: false
  alias WeaviateEx

  @moduletag :integration

  setup_all do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")
    :ok
  end

  describe "WeaviateEx.health_check/0 (live)" do
    test "connects to real Weaviate and returns metadata" do
      assert {:ok, meta} = WeaviateEx.health_check()
      assert is_map(meta)
      assert is_binary(meta["version"])
      assert is_binary(meta["hostname"])
      assert is_map(meta["modules"])
    end
  end

  describe "WeaviateEx.ready?/0 (live)" do
    test "checks if Weaviate is ready" do
      assert {:ok, true} = WeaviateEx.ready?()
    end
  end

  describe "WeaviateEx.alive?/0 (live)" do
    test "checks if Weaviate is alive" do
      assert {:ok, true} = WeaviateEx.alive?()
    end
  end
end
