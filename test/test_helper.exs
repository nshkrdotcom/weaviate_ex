# Start ExUnit with async test support
ExUnit.start()

# Note: Support files are automatically compiled via elixirc_paths in mix.exs
# No need to require them here as it causes module redefinition warnings

# Configure Mox
Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)

# Always define the mock for HTTP client (needed for unit tests even when running with --include integration)
Mox.defmock(WeaviateEx.HTTPClient.Mock, for: WeaviateEx.HTTPClient)

# Set global mode for async tests
Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)

# Default to mock mode for unit tests
Application.put_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Mock)

# Disable strict health checks during tests
Application.put_env(:weaviate_ex, :strict, false)

# Exclude integration tests by default
ExUnit.configure(exclude: [:integration, :property, :performance])

defmodule WeaviateEx.TestHelpers do
  @moduledoc """
  Shared test helpers and utilities.
  """

  import Mox

  @doc """
  Checks if we should run tests against a live Weaviate instance.

  Set WEAVIATE_INTEGRATION=true to enable integration tests.
  """
  def integration_mode? do
    System.get_env("WEAVIATE_INTEGRATION") == "true"
  end

  @doc """
  Sets up the appropriate HTTP client based on test mode.

  - In mock mode: Uses WeaviateEx.HTTPClient.Mock
  - In integration mode: Uses WeaviateEx.HTTPClient.Finch (real HTTP)
  """
  def setup_http_client(_context) do
    if integration_mode?() do
      Application.put_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Finch)
      :ok
    else
      Application.put_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Mock)
      :ok
    end
  end

  @doc """
  Expects an HTTP request and returns a mocked response.

  ## Examples

      expect_http_request(:get, "/v1/meta", fn ->
        %{status: 200, body: ~s({"version": "1.28.1"}), headers: []}
      end)
  """
  def expect_http_request(method, path_matcher, response_fn) do
    expect(WeaviateEx.HTTPClient.Mock, :request, fn ^method, url, _headers, _body, _opts ->
      if url =~ path_matcher do
        {:ok, response_fn.()}
      else
        {:error, :not_found}
      end
    end)
  end

  @doc """
  Expects an HTTP request with specific body and returns a mocked response.
  """
  def expect_http_request_with_body(method, path_matcher, body_matcher, response_fn) do
    expect(WeaviateEx.HTTPClient.Mock, :request, fn ^method, url, _headers, body, _opts ->
      if url =~ path_matcher and (body_matcher == :any or body =~ body_matcher) do
        {:ok, response_fn.()}
      else
        {:error, :unexpected_request}
      end
    end)
  end

  @doc """
  Creates a mock HTTP error response.
  """
  def mock_error_response(status, error_message) do
    %{
      status: status,
      body: Jason.encode!(%{"error" => [%{"message" => error_message}]}),
      headers: [{"content-type", "application/json"}]
    }
  end

  @doc """
  Creates a mock success response.
  """
  def mock_success_response(data, status \\ 200) do
    %{
      status: status,
      body: Jason.encode!(data),
      headers: [{"content-type", "application/json"}]
    }
  end
end
