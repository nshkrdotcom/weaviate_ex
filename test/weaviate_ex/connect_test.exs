defmodule WeaviateEx.ConnectTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Connect

  describe "to_weaviate_cloud/1" do
    test "builds Weaviate Cloud config with cluster URL" do
      config = Connect.to_weaviate_cloud(cluster_url: "my-cluster.weaviate.network")

      assert config.base_url == "https://my-cluster.weaviate.network"
      assert config.grpc_host == "grpc-my-cluster.weaviate.network"
      assert config.grpc_port == 443
    end

    test "accepts API key" do
      config =
        Connect.to_weaviate_cloud(
          cluster_url: "my-cluster.weaviate.network",
          api_key: "my-api-key"
        )

      assert config.api_key == "my-api-key"
    end

    test "normalizes URL with https prefix" do
      config = Connect.to_weaviate_cloud(cluster_url: "https://my-cluster.weaviate.network")

      assert config.base_url == "https://my-cluster.weaviate.network"
    end

    test "accepts additional headers" do
      config =
        Connect.to_weaviate_cloud(
          cluster_url: "my-cluster.weaviate.network",
          headers: [{"X-Custom", "value"}]
        )

      assert config.headers == [{"X-Custom", "value"}]
    end
  end

  describe "to_local/1" do
    test "builds local config with defaults" do
      config = Connect.to_local()

      assert config.base_url == "http://localhost:8080"
      assert config.grpc_host == "localhost"
      assert config.grpc_port == 50_051
    end

    test "accepts custom host and port" do
      config = Connect.to_local(host: "192.168.1.100", port: 9080)

      assert config.base_url == "http://192.168.1.100:9080"
    end

    test "accepts custom grpc port" do
      config = Connect.to_local(grpc_port: 50_052)

      assert config.grpc_port == 50_052
    end

    test "accepts API key" do
      config = Connect.to_local(api_key: "local-api-key")

      assert config.api_key == "local-api-key"
    end
  end

  describe "to_custom/1" do
    test "builds custom config" do
      config =
        Connect.to_custom(
          http_host: "custom.host.com",
          http_port: 8080,
          http_secure: true
        )

      assert config.base_url == "https://custom.host.com:8080"
    end

    test "uses http for insecure connection" do
      config =
        Connect.to_custom(
          http_host: "custom.host.com",
          http_port: 8080,
          http_secure: false
        )

      assert config.base_url == "http://custom.host.com:8080"
    end

    test "accepts grpc configuration" do
      config =
        Connect.to_custom(
          http_host: "custom.host.com",
          http_port: 8080,
          grpc_host: "grpc.custom.host.com",
          grpc_port: 50_051,
          grpc_secure: true
        )

      assert config.grpc_host == "grpc.custom.host.com"
      assert config.grpc_port == 50_051
      assert config.grpc_secure == true
    end
  end

  describe "to_embedded/1" do
    test "builds embedded config" do
      config = Connect.to_embedded()

      assert config.base_url == "http://127.0.0.1:8079"
      assert config.embedded == true
    end

    test "accepts custom port" do
      config = Connect.to_embedded(port: 8090)

      assert config.base_url == "http://127.0.0.1:8090"
    end

    test "accepts version" do
      config = Connect.to_embedded(version: "1.30.5")

      assert config.version == "1.30.5"
    end
  end
end
