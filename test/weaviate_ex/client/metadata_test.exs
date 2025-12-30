defmodule WeaviateEx.Client.MetadataTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Client

  test "grpc_metadata includes additional headers by default" do
    {:ok, client} =
      Client.new(
        base_url: "http://localhost:8080",
        api_key: "test-key",
        additional_headers: %{"X-OpenAI-Api-Key" => "sk-test"}
      )

    metadata = Client.grpc_metadata(client)

    assert metadata["authorization"] == "Bearer test-key"
    assert metadata["x-openai-api-key"] == "sk-test"
  end
end
