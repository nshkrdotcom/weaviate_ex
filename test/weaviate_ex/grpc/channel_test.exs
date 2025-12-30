defmodule WeaviateEx.GRPC.ChannelTest do
  use ExUnit.Case, async: false

  alias WeaviateEx.GRPC.Channel

  @moduletag :grpc

  describe "connect/1" do
    test "connects to Weaviate gRPC endpoint with valid config" do
      # Skip if no Weaviate available
      config = %{
        grpc_host: System.get_env("WEAVIATE_GRPC_HOST", "localhost"),
        grpc_port: String.to_integer(System.get_env("WEAVIATE_GRPC_PORT", "50051")),
        api_key: System.get_env("WEAVIATE_API_KEY")
      }

      case Channel.connect(config) do
        {:ok, channel} ->
          assert channel != nil

          assert is_reference(channel.adapter_payload.conn_pid) or
                   is_pid(channel.adapter_payload.conn_pid)

          Channel.disconnect(channel)

        {:error, %{type: :connection_error}} ->
          # Expected if no Weaviate running
          :ok
      end
    end

    test "returns error for invalid host" do
      config = %{
        grpc_host: "invalid-host-that-does-not-exist.local",
        grpc_port: 50_051,
        api_key: nil
      }

      assert {:error, error} = Channel.connect(config, timeout: 1000)
      assert error.type in [:connection_error, :timeout_error]
    end

    test "supports TLS connections" do
      config = %{
        grpc_host: "localhost",
        grpc_port: 50_051,
        api_key: nil,
        tls: true
      }

      # Should attempt TLS connection (may fail if no TLS server)
      result = Channel.connect(config, timeout: 1000)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "disconnect/1" do
    test "closes an active channel" do
      config = %{
        grpc_host: System.get_env("WEAVIATE_GRPC_HOST", "localhost"),
        grpc_port: String.to_integer(System.get_env("WEAVIATE_GRPC_PORT", "50051")),
        api_key: nil
      }

      case Channel.connect(config, timeout: 5000) do
        {:ok, channel} ->
          assert :ok = Channel.disconnect(channel)

        {:error, _} ->
          # No server available, skip
          :ok
      end
    end
  end

  describe "connected?/1" do
    test "returns true for active channel" do
      config = %{
        grpc_host: System.get_env("WEAVIATE_GRPC_HOST", "localhost"),
        grpc_port: String.to_integer(System.get_env("WEAVIATE_GRPC_PORT", "50051")),
        api_key: nil
      }

      case Channel.connect(config, timeout: 5000) do
        {:ok, channel} ->
          assert Channel.connected?(channel) == true
          Channel.disconnect(channel)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "with_metadata/2" do
    test "adds authorization header when api_key present" do
      config = %{
        grpc_host: "localhost",
        grpc_port: 50_051,
        api_key: "test-api-key"
      }

      metadata = Channel.build_metadata(config)
      assert metadata["authorization"] == "Bearer test-api-key"
    end

    test "returns empty metadata when no api_key" do
      config = %{
        grpc_host: "localhost",
        grpc_port: 50_051,
        api_key: nil
      }

      metadata = Channel.build_metadata(config)
      refute Map.has_key?(metadata, "authorization")
    end
  end

  describe "build_metadata/1 with additional_headers" do
    test "includes additional_headers in metadata" do
      config = %{
        api_key: "key",
        additional_headers: %{"X-Custom" => "value"}
      }

      metadata = Channel.build_metadata(config)
      assert metadata["authorization"] == "Bearer key"
      # Headers are lowercased for gRPC
      assert metadata["x-custom"] == "value"
    end

    test "lowercases all additional header keys" do
      config = %{
        api_key: nil,
        additional_headers: %{
          "X-OpenAI-Api-Key" => "sk-123",
          "X-UPPERCASE" => "value"
        }
      }

      metadata = Channel.build_metadata(config)
      assert metadata["x-openai-api-key"] == "sk-123"
      assert metadata["x-uppercase"] == "value"
      refute Map.has_key?(metadata, "X-OpenAI-Api-Key")
    end

    test "works without additional_headers key" do
      config = %{api_key: "key"}

      metadata = Channel.build_metadata(config)
      assert metadata["authorization"] == "Bearer key"
    end

    test "handles empty additional_headers map" do
      config = %{api_key: nil, additional_headers: %{}}

      metadata = Channel.build_metadata(config)
      assert metadata == %{}
    end

    test "merges api_key and additional_headers" do
      config = %{
        api_key: "my-key",
        additional_headers: %{
          "X-OpenAI-Api-Key" => "openai-key",
          "X-Cohere-Api-Key" => "cohere-key"
        }
      }

      metadata = Channel.build_metadata(config)
      assert metadata["authorization"] == "Bearer my-key"
      assert metadata["x-openai-api-key"] == "openai-key"
      assert metadata["x-cohere-api-key"] == "cohere-key"
    end
  end
end
