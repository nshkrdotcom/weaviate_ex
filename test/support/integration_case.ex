defmodule WeaviateEx.IntegrationCase do
  @moduledoc """
  Shared test case module for integration tests.

  Provides common setup, helper functions, and cleanup utilities for tests
  that run against a live Weaviate instance.

  ## Usage

      defmodule MyIntegrationTest do
        use WeaviateEx.IntegrationCase

        test "something" do
          {name, _} = create_test_collection("MyTest", properties: [...])
          # test code
        end
      end

  ## Features

  - Automatic protocol configuration for HTTP client
  - Unique collection name generation
  - Collection creation with automatic cleanup registration
  - Wait-for-ready functionality for Weaviate startup
  - `with_collection/2` helper for scoped collection usage

  ## Configuration

  The module automatically configures:
  - `async: false` - Integration tests should not run concurrently
  - `@moduletag :integration` - Tags all tests for selective execution
  - Protocol implementation set to `WeaviateEx.Protocol.HTTP.Client`
  - Base URL set to `http://localhost:8080`
  """

  use ExUnit.CaseTemplate

  alias WeaviateEx.Collections

  @default_url "http://localhost:8080"
  @default_port 8080
  @default_timeout 30_000
  @poll_interval 500

  using do
    quote do
      use ExUnit.Case, async: false

      @moduletag :integration

      import WeaviateEx.IntegrationCase

      setup_all do
        WeaviateEx.IntegrationCase.setup_integration_env()
        :ok
      end

      setup do
        # Initialize the process dictionary for tracking collections
        WeaviateEx.IntegrationCase.init_collection_tracking()

        on_exit(fn ->
          WeaviateEx.IntegrationCase.cleanup_collections()
        end)

        :ok
      end
    end
  end

  @doc """
  Sets up the integration environment with HTTP client and URL configuration.

  Called automatically in `setup_all` when using this module.
  """
  @spec setup_integration_env(keyword()) :: :ok
  def setup_integration_env(opts \\ []) do
    url = Keyword.get(opts, :url, @default_url)
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, url)
    :ok
  end

  @doc """
  Initializes the process dictionary for tracking created collections.

  Called automatically in `setup` when using this module.
  """
  @spec init_collection_tracking() :: :ok
  def init_collection_tracking do
    Process.put(:integration_test_collections, [])
    :ok
  end

  @doc """
  Generates a unique collection name with the given prefix.

  Uses a combination of timestamp and random bytes to ensure uniqueness.

  ## Examples

      iex> unique_collection_name("Article")
      "Article_1703847123456_a1b2c3d4"

      iex> unique_collection_name()
      "Test_1703847123456_e5f6g7h8"
  """
  @spec unique_collection_name(String.t()) :: String.t()
  def unique_collection_name(prefix \\ "Test") do
    timestamp = System.system_time(:millisecond)
    random_suffix = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "#{prefix}_#{timestamp}_#{random_suffix}"
  end

  @doc """
  Creates a test collection and registers it for cleanup.

  Returns `{collection_name, result}` where result is the collection data
  returned by Weaviate on success.

  ## Options

  - `:properties` - List of property definitions (default: single text property)
  - `:vectorizer` - Vectorizer to use (default: "none")
  - `:description` - Collection description
  - Any other options supported by `WeaviateEx.Collections.create/3`

  ## Examples

      # Create a simple collection
      {name, _} = create_test_collection("MyTest")

      # Create with custom properties
      {name, _} = create_test_collection("Article", properties: [
        %{name: "title", dataType: ["text"]},
        %{name: "content", dataType: ["text"]}
      ])

      # Create with specific vectorizer
      {name, _} = create_test_collection("VectorTest", vectorizer: "text2vec-openai")
  """
  @spec create_test_collection(String.t(), keyword()) ::
          {String.t(), {:ok, map()} | {:error, term()}}
  def create_test_collection(prefix, opts \\ []) do
    name = unique_collection_name(prefix)

    properties =
      Keyword.get(opts, :properties, [
        %{name: "testField", dataType: ["text"]}
      ])

    vectorizer = Keyword.get(opts, :vectorizer, "none")
    description = Keyword.get(opts, :description, "Integration test collection")

    config =
      opts
      |> Keyword.drop([:properties, :vectorizer, :description])
      |> Keyword.merge(
        properties: properties,
        vectorizer: vectorizer,
        description: description
      )
      |> Enum.into(%{})

    result = Collections.create(name, config)

    # Register for cleanup on success
    case result do
      {:ok, _} ->
        register_collection(name)

      {:error, _} ->
        :ok
    end

    {name, result}
  end

  @doc """
  Registers a collection name for cleanup at the end of the test.

  Useful when you create a collection manually but still want automatic cleanup.

  ## Examples

      # Manually create and register
      {:ok, _} = Collections.create("MyCollection", %{...})
      register_collection("MyCollection")
  """
  @spec register_collection(String.t()) :: :ok
  def register_collection(name) do
    collections = Process.get(:integration_test_collections, [])
    Process.put(:integration_test_collections, [name | collections])
    :ok
  end

  @doc """
  Cleans up all registered collections.

  Called automatically in `on_exit` callback when using this module.
  Can also be called manually if needed.

  Returns a list of `{name, result}` tuples for each cleanup attempt.
  """
  @spec cleanup_collections() :: [{String.t(), {:ok, term()} | {:error, term()}}]
  def cleanup_collections do
    collections = Process.get(:integration_test_collections, [])

    results =
      Enum.map(collections, fn name ->
        result = Collections.delete(name)
        {name, result}
      end)

    Process.put(:integration_test_collections, [])
    results
  end

  @doc """
  Waits for Weaviate to be ready and accepting connections.

  Polls the readiness endpoint until it returns success or timeout is reached.

  ## Options

  - `:port` - Port to check (default: 8080)
  - `:timeout` - Maximum time to wait in milliseconds (default: 30_000)
  - `:host` - Host to check (default: "localhost")

  ## Examples

      # Wait with defaults
      :ok = wait_for_ready()

      # Wait with custom timeout
      :ok = wait_for_ready(timeout: 60_000)

      # Wait for custom port
      :ok = wait_for_ready(port: 8081)
  """
  @spec wait_for_ready(keyword()) :: :ok | {:error, :timeout}
  def wait_for_ready(opts \\ []) do
    port = Keyword.get(opts, :port, @default_port)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    host = Keyword.get(opts, :host, "localhost")

    # Configure the URL for this check
    url = "http://#{host}:#{port}"
    setup_integration_env(url: url)

    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_ready(deadline)
  end

  defp do_wait_for_ready(deadline) do
    case WeaviateEx.ready?() do
      {:ok, true} ->
        :ok

      _ ->
        now = System.monotonic_time(:millisecond)

        if now >= deadline do
          {:error, :timeout}
        else
          Process.sleep(@poll_interval)
          do_wait_for_ready(deadline)
        end
    end
  end

  @doc """
  Creates a collection, runs a function, and ensures cleanup.

  Useful for tests that need a collection for a specific scope.

  ## Options

  Same as `create_test_collection/2`.

  ## Examples

      with_collection([prefix: "Article", properties: [...]], fn name ->
        # Use the collection
        {:ok, _} = WeaviateEx.Objects.create(name, %{properties: %{...}})
        # Collection is automatically cleaned up after this block
      end)

      # With options map
      with_collection(%{prefix: "Test", vectorizer: "none"}, fn name ->
        # test code
      end)
  """
  @spec with_collection(keyword() | map(), (String.t() -> term())) :: term()
  def with_collection(opts, fun) when is_list(opts) do
    prefix = Keyword.get(opts, :prefix, "Test")
    collection_opts = Keyword.delete(opts, :prefix)

    {name, result} = create_test_collection(prefix, collection_opts)

    case result do
      {:ok, _} ->
        try do
          fun.(name)
        after
          Collections.delete(name)
          # Remove from tracking since we already cleaned up
          remove_from_tracking(name)
        end

      {:error, error} ->
        {:error, {:collection_creation_failed, error}}
    end
  end

  def with_collection(opts, fun) when is_map(opts) do
    with_collection(Map.to_list(opts), fun)
  end

  defp remove_from_tracking(name) do
    collections = Process.get(:integration_test_collections, [])
    Process.put(:integration_test_collections, List.delete(collections, name))
    :ok
  end

  @doc """
  Creates multiple test collections and registers them all for cleanup.

  ## Examples

      names = create_test_collections(["Users", "Posts", "Comments"])
      # Returns ["Users_123_abc", "Posts_123_def", "Comments_123_ghi"]
  """
  @spec create_test_collections([String.t()], keyword()) :: [String.t()]
  def create_test_collections(prefixes, opts \\ []) do
    Enum.map(prefixes, fn prefix ->
      {name, _} = create_test_collection(prefix, opts)
      name
    end)
  end

  @doc """
  Gets the list of currently registered collections for cleanup.

  Useful for debugging or advanced test scenarios.
  """
  @spec registered_collections() :: [String.t()]
  def registered_collections do
    Process.get(:integration_test_collections, [])
  end

  @doc """
  Asserts that Weaviate is ready before running tests.

  Raises if Weaviate is not ready within the timeout period.

  ## Examples

      # In setup_all
      setup_all do
        assert_weaviate_ready!(timeout: 60_000)
        :ok
      end
  """
  @spec assert_weaviate_ready!(keyword()) :: :ok
  def assert_weaviate_ready!(opts \\ []) do
    case wait_for_ready(opts) do
      :ok ->
        :ok

      {:error, :timeout} ->
        timeout = Keyword.get(opts, :timeout, @default_timeout)
        port = Keyword.get(opts, :port, @default_port)

        raise """
        Weaviate is not ready after #{timeout}ms.

        Make sure Weaviate is running on port #{port}.

        To start Weaviate with Docker:
            docker run -d -p #{port}:8080 semitechnologies/weaviate:latest

        To skip integration tests:
            mix test --exclude integration
        """
    end
  end
end
