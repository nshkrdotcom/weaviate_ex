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
  alias WeaviateEx.Embedded

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

  ## Embedded Weaviate

  @doc """
  Starts an embedded Weaviate instance using the official binary.

  This function delegates to `WeaviateEx.Embedded.start/1` and returns an
  opaque handle that should be passed to `stop_embedded/1` when you're done.

  ## Examples

      {:ok, emb} = WeaviateEx.start_embedded(version: "1.30.5", port: 8090)
      WeaviateEx.health_check()
      :ok = WeaviateEx.stop_embedded(emb)
  """
  @spec start_embedded([Embedded.option()]) :: {:ok, Embedded.Instance.t()} | {:error, term()}
  def start_embedded(opts \\ []), do: Embedded.start(opts)

  @doc """
  Stops an embedded Weaviate instance started with `start_embedded/1`.
  """
  @spec stop_embedded(Embedded.Instance.t()) :: :ok
  def stop_embedded(instance), do: Embedded.stop(instance)

  ## HTTP Client

  @doc false
  @spec request(atom(), String.t(), map() | nil, Keyword.t()) :: api_response()
  def request(method, path, body \\ nil, opts \\ []) do
    # Create a client using the configured protocol implementation
    {:ok, client} =
      WeaviateEx.Client.new(
        base_url: base_url(),
        api_key: api_key()
      )

    # Delegate to the client
    WeaviateEx.Client.request(client, method, path, body, opts)
  end
end
