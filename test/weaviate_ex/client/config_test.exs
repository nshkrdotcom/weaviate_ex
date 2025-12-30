defmodule WeaviateEx.Client.ConfigTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Client.Config

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
      assert config.grpc_host == "my-cluster.weaviate.network"
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
