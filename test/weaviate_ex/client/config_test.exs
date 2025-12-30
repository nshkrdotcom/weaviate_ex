defmodule WeaviateEx.Client.ConfigTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Client.Config
  alias WeaviateEx.Config.Connection

  describe "new/1" do
    test "creates config with default values" do
      config = Config.new()
      assert config.base_url == "http://localhost:8080"
      assert config.grpc_host == "localhost"
      assert config.grpc_port == 50_051
      assert config.api_key == nil
      assert config.additional_headers == %{}
    end

    test "accepts base_url option" do
      config = Config.new(base_url: "http://weaviate:8080")
      assert config.base_url == "http://weaviate:8080"
    end

    test "derives grpc_host from base_url" do
      config = Config.new(base_url: "https://my-cluster.weaviate.network")
      assert config.grpc_host == "my-cluster.grpc.weaviate.network"
      assert config.grpc_port == 443
    end

    test "allows explicit grpc_host override" do
      config =
        Config.new(
          base_url: "https://my-cluster.weaviate.network",
          grpc_host: "grpc-my-cluster.weaviate.network"
        )

      assert config.grpc_host == "grpc-my-cluster.weaviate.network"
    end

    test "accepts connection config struct" do
      connection = Connection.new(pool_size: 25)
      config = Config.new(connection: connection)

      assert config.connection == connection
    end

    test "accepts connection config keyword list" do
      config = Config.new(connection: [pool_size: 12, max_connections: 60])

      assert %WeaviateEx.Config.Connection{} = config.connection
      assert config.connection.pool_size == 12
      assert config.connection.max_connections == 60
    end

    test "accepts proxy config keyword list" do
      config = Config.new(proxy: [http: "http://proxy.example.com:8080"])

      assert %WeaviateEx.Config.Proxy{} = config.proxy
      assert config.proxy.http == "http://proxy.example.com:8080"
    end

    test "defaults to the shared Finch instance" do
      config = Config.new()

      assert config.finch_name == WeaviateEx.Finch
    end
  end

  describe "additional_headers" do
    test "accepts additional_headers in config" do
      config =
        Config.new(
          base_url: "http://localhost:8080",
          additional_headers: %{"X-OpenAI-Api-Key" => "sk-123"}
        )

      assert config.additional_headers == %{"X-OpenAI-Api-Key" => "sk-123"}
    end

    test "defaults to empty map when not provided" do
      config = Config.new(base_url: "http://localhost:8080")
      assert config.additional_headers == %{}
    end

    test "accepts multiple headers" do
      config =
        Config.new(
          base_url: "http://localhost:8080",
          additional_headers: %{
            "X-OpenAI-Api-Key" => "sk-123",
            "X-Cohere-Api-Key" => "cohere-456",
            "X-Custom-Header" => "custom-value"
          }
        )

      assert config.additional_headers["X-OpenAI-Api-Key"] == "sk-123"
      assert config.additional_headers["X-Cohere-Api-Key"] == "cohere-456"
      assert config.additional_headers["X-Custom-Header"] == "custom-value"
    end

    test "raises when header value is nil" do
      assert_raise ArgumentError, ~r/Header values cannot be nil/, fn ->
        Config.new(
          base_url: "http://localhost:8080",
          additional_headers: %{"X-Key" => nil}
        )
      end
    end

    test "raises when any header value in map is nil" do
      assert_raise ArgumentError, ~r/Header values cannot be nil.*X-Bad/, fn ->
        Config.new(
          base_url: "http://localhost:8080",
          additional_headers: %{
            "X-Good" => "value",
            "X-Bad" => nil
          }
        )
      end
    end
  end

  describe "use_tls?/1" do
    test "returns true for HTTPS base_url" do
      config = Config.new(base_url: "https://my-cluster.weaviate.network")
      assert Config.use_tls?(config) == true
    end

    test "returns true for port 443" do
      config =
        Config.new(
          base_url: "http://localhost",
          grpc_port: 443
        )

      assert Config.use_tls?(config) == true
    end

    test "returns false for HTTP base_url with non-443 port" do
      config = Config.new(base_url: "http://localhost:8080")
      assert Config.use_tls?(config) == false
    end
  end
end
