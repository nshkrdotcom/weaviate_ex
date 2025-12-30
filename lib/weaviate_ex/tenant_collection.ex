defmodule WeaviateEx.TenantCollection do
  @moduledoc """
  A tenant-scoped collection reference for fluent multi-tenant operations.

  This module provides a Python-like `with_tenant` experience, allowing you
  to get a tenant-scoped collection reference where all operations are
  automatically scoped to the specified tenant.

  ## Usage

      # Get tenant-scoped collection
      tenant_col = WeaviateEx.Collections.with_tenant(client, "Articles", "tenant_A")

      # All operations automatically scoped to tenant_A
      {:ok, obj} = WeaviateEx.TenantCollection.insert(tenant_col, %{title: "Hello"})
      {:ok, results} = tenant_col
        |> WeaviateEx.TenantCollection.query()
        |> WeaviateEx.Query.bm25("search term")
        |> WeaviateEx.Query.execute(client)

  ## Alternative API

  You can also use the existing `TenantClient` module which provides a
  similar fluent API but with a different method chaining style:

      tenant_client = client
        |> WeaviateEx.TenantClient.with_tenant("tenant_A")
        |> WeaviateEx.TenantClient.collection("Articles")

  ## Comparison with Python Client

  Python:
      tenant_col = collection.with_tenant("tenant_A")
      tenant_col.data.insert({"name": "test"})
      tenant_col.query.bm25("query")

  Elixir:
      tenant_col = Collections.with_tenant(client, "Articles", "tenant_A")
      TenantCollection.insert(tenant_col, %{name: "test"})
      tenant_col |> TenantCollection.query() |> Query.bm25("query")
  """

  alias WeaviateEx.API.Batch, as: BatchAPI
  alias WeaviateEx.API.Data
  alias WeaviateEx.Batch
  alias WeaviateEx.Client
  alias WeaviateEx.Query

  @enforce_keys [:client, :collection, :tenant]
  defstruct [:client, :collection, :tenant]

  @type t :: %__MODULE__{
          client: Client.t(),
          collection: String.t(),
          tenant: String.t()
        }

  @doc """
  Creates a new tenant-scoped collection reference.

  ## Parameters

    - `client` - WeaviateEx.Client instance
    - `collection` - Collection name
    - `tenant` - Tenant name

  ## Examples

      tenant_col = TenantCollection.new(client, "Articles", "tenant_A")
  """
  @spec new(Client.t(), String.t(), String.t()) :: t()
  def new(%Client{} = client, collection, tenant)
      when is_binary(collection) and is_binary(tenant) do
    %__MODULE__{
      client: client,
      collection: collection,
      tenant: tenant
    }
  end

  # ===========================================================================
  # Data Operations
  # ===========================================================================

  @doc """
  Inserts an object into the tenant's collection.

  ## Parameters

    - `tc` - TenantCollection reference
    - `object` - Object properties to insert
    - `opts` - Additional options

  ## Options

    - `:uuid` - Custom UUID for the object
    - `:vector` - Custom vector for the object
    - `:consistency_level` - Consistency level for the operation

  ## Examples

      {:ok, result} = TenantCollection.insert(tenant_col, %{
        title: "My Article",
        content: "Article content"
      })

      # With custom UUID
      {:ok, result} = TenantCollection.insert(tenant_col, %{title: "Test"},
        uuid: "550e8400-e29b-41d4-a716-446655440000"
      )
  """
  @spec insert(t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def insert(%__MODULE__{} = tc, object, opts \\ []) do
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.insert(tc.client, tc.collection, object, opts)
  end

  @doc """
  Inserts multiple objects into the tenant's collection.

  Uses batch operations for efficient bulk inserts.

  ## Parameters

    - `tc` - TenantCollection reference
    - `objects` - List of object property maps
    - `opts` - Additional options

  ## Options

    - `:consistency_level` - Consistency level for the operation
    - `:return_summary` - If true, returns a summary with success/failure counts

  ## Examples

      {:ok, result} = TenantCollection.insert_many(tenant_col, [
        %{title: "Article 1"},
        %{title: "Article 2"},
        %{title: "Article 3"}
      ])

      # Get summary
      {:ok, summary} = TenantCollection.insert_many(tenant_col, objects,
        return_summary: true
      )
  """
  @spec insert_many(t(), [map()], keyword()) :: {:ok, term()} | {:error, term()}
  def insert_many(%__MODULE__{} = tc, objects, opts \\ []) when is_list(objects) do
    formatted_objects =
      Enum.map(objects, fn obj ->
        base = %{
          "class" => tc.collection,
          "properties" => normalize_properties(obj),
          "tenant" => tc.tenant
        }

        base
        |> maybe_put("id", get_object_field(obj, [:uuid, :id, "uuid", "id"]))
        |> maybe_put("vector", get_object_field(obj, [:vector, "vector"]))
      end)

    summary? = Keyword.get(opts, :return_summary, false)
    request_opts = Keyword.drop(opts, [:return_summary])

    case BatchAPI.create_objects(
           tc.client,
           formatted_objects,
           Keyword.put(request_opts, :summary, summary?)
         ) do
      {:ok, %BatchAPI.Result{} = result} -> {:ok, result}
      other -> other
    end
  end

  @doc """
  Gets an object by UUID from the tenant's collection.

  ## Parameters

    - `tc` - TenantCollection reference
    - `uuid` - Object UUID
    - `opts` - Additional options

  ## Options

    - `:include` - Additional fields to include (e.g., "vector", "classification")
    - `:consistency_level` - Consistency level for the operation

  ## Examples

      {:ok, object} = TenantCollection.get(tenant_col, "550e8400-e29b-41d4-a716-446655440000")

      # Include vector
      {:ok, object} = TenantCollection.get(tenant_col, uuid, include: "vector")
  """
  @spec get(t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(%__MODULE__{} = tc, uuid, opts \\ []) do
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.get_by_id(tc.client, tc.collection, uuid, opts)
  end

  @doc """
  Updates an object in the tenant's collection (full replacement).

  This performs a PUT request which replaces the entire object.

  ## Parameters

    - `tc` - TenantCollection reference
    - `uuid` - Object UUID
    - `properties` - New object properties
    - `opts` - Additional options

  ## Options

    - `:consistency_level` - Consistency level for the operation
    - `:keep_vector` - If true, keeps the existing vector

  ## Examples

      {:ok, updated} = TenantCollection.update(tenant_col, uuid, %{
        title: "Updated Title",
        content: "Updated Content"
      })
  """
  @spec update(t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update(%__MODULE__{} = tc, uuid, properties, opts \\ []) do
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.update(tc.client, tc.collection, uuid, properties, opts)
  end

  @doc """
  Replaces an object in the tenant's collection (alias for update).

  ## Examples

      {:ok, replaced} = TenantCollection.replace(tenant_col, uuid, %{
        title: "Replaced Title"
      })
  """
  @spec replace(t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def replace(%__MODULE__{} = tc, uuid, properties, opts \\ []) do
    update(tc, uuid, properties, opts)
  end

  @doc """
  Deletes an object from the tenant's collection.

  ## Parameters

    - `tc` - TenantCollection reference
    - `uuid` - Object UUID
    - `opts` - Additional options

  ## Examples

      :ok = TenantCollection.delete(tenant_col, "550e8400-e29b-41d4-a716-446655440000")
  """
  @spec delete(t(), String.t(), keyword()) :: :ok | {:ok, map()} | {:error, term()}
  def delete(%__MODULE__{} = tc, uuid, opts \\ []) do
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.delete_by_id(tc.client, tc.collection, uuid, opts)
  end

  @doc """
  Checks if an object exists in the tenant's collection.

  ## Parameters

    - `tc` - TenantCollection reference
    - `uuid` - Object UUID
    - `opts` - Additional options

  ## Examples

      {:ok, true} = TenantCollection.exists?(tenant_col, uuid)
      {:ok, false} = TenantCollection.exists?(tenant_col, "non-existent-uuid")
  """
  @spec exists?(t(), String.t(), keyword()) :: {:ok, boolean()} | {:error, term()}
  def exists?(%__MODULE__{} = tc, uuid, opts \\ []) do
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.exists?(tc.client, tc.collection, uuid, opts)
  end

  # ===========================================================================
  # Query Operations
  # ===========================================================================

  @doc """
  Creates a query builder for the tenant's collection.

  The returned query is automatically scoped to the tenant. Chain additional
  query methods and execute with `Query.execute/2`.

  ## Examples

      # Simple query
      {:ok, results} = tenant_col
        |> TenantCollection.query()
        |> Query.limit(10)
        |> Query.execute(tenant_col.client)

      # BM25 search
      {:ok, results} = tenant_col
        |> TenantCollection.query()
        |> Query.bm25("search term")
        |> Query.fields(["title", "content"])
        |> Query.execute(tenant_col.client)

      # Vector search
      {:ok, results} = tenant_col
        |> TenantCollection.query()
        |> Query.near_text("machine learning", certainty: 0.7)
        |> Query.limit(5)
        |> Query.execute(tenant_col.client)

      # Hybrid search
      {:ok, results} = tenant_col
        |> TenantCollection.query()
        |> Query.hybrid("AI research", alpha: 0.7)
        |> Query.execute(tenant_col.client)
  """
  @spec query(t()) :: Query.t()
  def query(%__MODULE__{} = tc) do
    Query.get(tc.collection)
    |> Query.tenant(tc.tenant)
  end

  # ===========================================================================
  # Batch Operations
  # ===========================================================================

  @doc """
  Creates a batch context for the tenant's collection.

  Returns a batch context that can be used with `Batch.add_object/4` and
  related functions. All objects added will be scoped to the tenant.

  ## Options

    - `:mode` - Batch mode: `:fixed` (default), `:dynamic`, or `:rate_limited`
    - `:batch_size` - Objects per batch (default: 100)
    - Other options passed to `Batch.with_batch/3`

  ## Examples

      # Context manager style
      {:ok, results} = TenantCollection.with_batch(tenant_col, [batch_size: 100], fn batch ->
        batch
        |> Batch.add_object(tenant_col.collection, %{title: "Article 1"}, tenant: tenant_col.tenant)
        |> Batch.add_object(tenant_col.collection, %{title: "Article 2"}, tenant: tenant_col.tenant)
      end)

  See `batch_insert/3` for a simpler bulk insert API.
  """
  @spec with_batch(t(), keyword(), (Batch.batch_context() -> Batch.batch_context())) ::
          {:ok, term()} | {:error, term()}
  def with_batch(%__MODULE__{} = tc, opts, fun) when is_function(fun, 1) do
    Batch.with_batch(tc.client, opts, fun)
  end

  @doc """
  Starts a background batch processor for the tenant's collection.

  Returns a batch processor that runs asynchronously. Use `Batch.Background`
  functions to add objects and stop the processor.

  ## Options

    - `:batch_size` - Objects per batch (default: 100)
    - `:concurrent_requests` - Max concurrent requests (default: 2)
    - `:flush_interval` - Auto-flush interval in ms (default: 1000)

  ## Examples

      {:ok, batcher} = TenantCollection.batch(tenant_col, batch_size: 100)

      for article <- articles do
        :ok = Batch.Background.add_object(batcher, %{
          class: tenant_col.collection,
          properties: article,
          tenant: tenant_col.tenant
        })
      end

      results = Batch.Background.stop(batcher, flush: true)
  """
  @spec batch(t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def batch(%__MODULE__{} = tc, opts \\ []) do
    opts =
      opts
      |> Keyword.put(:tenant, tc.tenant)
      |> Keyword.put(:client, tc.client)
      |> Keyword.put(:collection, tc.collection)

    Batch.background(tc.client, tc.collection, opts)
  end

  # ===========================================================================
  # Accessor Functions
  # ===========================================================================

  @doc """
  Returns the tenant name.

  ## Examples

      "tenant_A" = TenantCollection.tenant_name(tenant_col)
  """
  @spec tenant_name(t()) :: String.t()
  def tenant_name(%__MODULE__{tenant: tenant}), do: tenant

  @doc """
  Returns the collection name.

  ## Examples

      "Articles" = TenantCollection.collection_name(tenant_col)
  """
  @spec collection_name(t()) :: String.t()
  def collection_name(%__MODULE__{collection: collection}), do: collection

  @doc """
  Returns the underlying client.

  ## Examples

      client = TenantCollection.client(tenant_col)
  """
  @spec client(t()) :: Client.t()
  def client(%__MODULE__{client: client}), do: client

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  defp normalize_properties(%{properties: props}), do: props
  defp normalize_properties(%{"properties" => props}), do: props
  defp normalize_properties(props) when is_map(props), do: props

  defp get_object_field(obj, keys) do
    Enum.find_value(keys, fn key -> Map.get(obj, key) end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
