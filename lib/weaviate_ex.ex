defmodule WeaviateEx do
  @moduledoc """
  A modern Elixir client for Weaviate vector database.

  WeaviateEx provides a clean, idiomatic Elixir interface to interact with Weaviate,
  including support for:

  - Collections management (create, read, update, delete)
  - Object operations (CRUD with vectors)
  - Batch operations for efficient bulk imports
  - GraphQL queries for complex searches
  - Vector similarity search
  - Health checks and monitoring

  ## Configuration

  Configure WeaviateEx in your `config/config.exs`:

      config :weaviate_ex,
        url: "http://localhost:8080",
        api_key: nil  # Optional, for authenticated instances

  Or use environment variables:

      export WEAVIATE_URL=http://localhost:8080
      export WEAVIATE_API_KEY=your-api-key  # Optional

  ## Examples

      # Health check
      {:ok, meta} = WeaviateEx.health_check()

      # Create a collection
      {:ok, collection} = WeaviateEx.Collections.create("Article", %{
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]}
        ]
      })

      # Insert an object
      {:ok, object} = WeaviateEx.Objects.create("Article", %{
        properties: %{
          title: "Hello Weaviate",
          content: "This is a test article"
        }
      })

      # Query objects
      {:ok, results} = WeaviateEx.Objects.list("Article", limit: 10)
  """

  require Logger

  @type api_response :: {:ok, map() | list()} | {:error, term()}
  @type uuid :: String.t()

  ## Configuration

  @doc """
  Returns the configured Weaviate base URL.
  """
  @spec base_url() :: String.t()
  def base_url do
    System.get_env("WEAVIATE_URL") ||
      Application.get_env(:weaviate_ex, :url) ||
      "http://localhost:8080"
  end

  @doc """
  Returns the API key for authentication, if configured.
  """
  @spec api_key() :: String.t() | nil
  def api_key do
    System.get_env("WEAVIATE_API_KEY") ||
      Application.get_env(:weaviate_ex, :api_key)
  end

  ## Health & Meta API

  @doc """
  Performs a health check against the Weaviate instance.

  Returns metadata about the Weaviate instance including version,
  modules, and configuration.

  ## Examples

      iex> WeaviateEx.health_check()
      {:ok, %{"version" => "1.28.1", "modules" => %{}}}
  """
  @spec health_check() :: api_response()
  def health_check do
    request(:get, "/v1/meta", nil)
  end

  @doc """
  Checks if Weaviate is ready to serve requests.

  ## Examples

      iex> WeaviateEx.ready?()
      {:ok, true}
  """
  @spec ready?() :: {:ok, boolean()} | {:error, term()}
  def ready? do
    case request(:get, "/v1/.well-known/ready", nil) do
      {:ok, _} -> {:ok, true}
      error -> error
    end
  end

  @doc """
  Checks if Weaviate is alive (liveness probe).

  ## Examples

      iex> WeaviateEx.alive?()
      {:ok, true}
  """
  @spec alive?() :: {:ok, boolean()} | {:error, term()}
  def alive? do
    case request(:get, "/v1/.well-known/live", nil) do
      {:ok, _} -> {:ok, true}
      error -> error
    end
  end

  ## HTTP Client

  @doc false
  @spec request(atom(), String.t(), map() | nil, Keyword.t()) :: api_response()
  def request(method, path, body \\ nil, opts \\ []) do
    url = build_url(path)
    headers = build_headers()
    encoded_body = if body, do: Jason.encode!(body), else: nil

    request =
      method
      |> Finch.build(url, headers, encoded_body)

    case Finch.request(request, WeaviateEx.Finch, opts) do
      {:ok, %Finch.Response{status: status, body: response_body}}
      when status in 200..299 ->
        parse_response(response_body)

      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:error, %{status: status, body: parse_error_response(response_body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_url(path) do
    base = base_url() |> String.trim_trailing("/")
    path = if String.starts_with?(path, "/"), do: path, else: "/#{path}"
    base <> path
  end

  defp build_headers do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    case api_key() do
      nil -> headers
      key -> [{"Authorization", "Bearer #{key}"} | headers]
    end
  end

  defp parse_response(""), do: {:ok, %{}}

  defp parse_response(body) do
    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, body}
    end
  end

  defp parse_error_response(body) do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> body
    end
  end
end
