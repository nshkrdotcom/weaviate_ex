defmodule WeaviateEx.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client operations.

  This allows us to mock HTTP calls in tests while using real HTTP
  in production. The implementation can be swapped via configuration.
  """

  @type method :: :get | :post | :put | :patch | :delete | :head
  @type url :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t() | nil
  @type opts :: Keyword.t()

  @type response ::
          {:ok, %{status: integer(), body: String.t(), headers: headers()}} | {:error, term()}

  @doc """
  Performs an HTTP request.

  ## Parameters

  - `method` - HTTP method (:get, :post, etc.)
  - `url` - Full URL to request
  - `headers` - List of header tuples
  - `body` - Request body (nil for GET/HEAD)
  - `opts` - Additional options

  ## Returns

  - `{:ok, %{status: integer(), body: String.t(), headers: list()}}` on success
  - `{:error, reason}` on failure
  """
  @callback request(method(), url(), headers(), body(), opts()) :: response()

  @doc """
  Returns the configured HTTP client implementation.

  Defaults to production client, but can be overridden in test config.
  """
  def client do
    Application.get_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Finch)
  end

  @doc """
  Delegates to the configured HTTP client implementation.
  """
  defdelegate request(method, url, headers, body \\ nil, opts \\ []),
    to: __MODULE__,
    as: :do_request

  def do_request(method, url, headers, body, opts) do
    client().request(method, url, headers, body, opts)
  end
end
