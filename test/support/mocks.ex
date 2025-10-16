defmodule WeaviateEx.Test.Mocks do
  @moduledoc """
  Mock definitions using Mox for testing.

  Note: Mock definitions are in test_helper.exs to avoid redefinition warnings.
  This module only contains helper functions for working with mocks.
  """

  @doc "Setup test client with mocked protocol"
  def setup_test_client(_context) do
    client = %WeaviateEx.Client{
      config: %WeaviateEx.Client.Config{
        base_url: "http://localhost:8080",
        grpc_host: "localhost",
        grpc_port: 50051,
        api_key: nil
      },
      protocol_impl: WeaviateEx.Protocol.Mock
    }

    {:ok, client: client}
  end

  @doc "Expect successful HTTP response"
  def expect_http_success(mock, method, path, response_body) do
    Mox.expect(mock, :request, fn _client, ^method, ^path, _body, _opts ->
      {:ok, response_body}
    end)
  end

  @doc "Expect HTTP error"
  def expect_http_error(mock, method, path, error_type) do
    Mox.expect(mock, :request, fn _client, ^method, ^path, _body, _opts ->
      {:error, %WeaviateEx.Error{type: error_type, message: "Test error"}}
    end)
  end
end
