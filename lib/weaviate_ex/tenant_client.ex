defmodule WeaviateEx.TenantClient do
  @moduledoc """
  Fluent API for tenant-scoped operations.

  Provides a Python-like `with_tenant` experience for multi-tenant collections,
  enabling clean and readable tenant-scoped data operations.

  ## Usage

      # Create a tenant-scoped client
      tenant_client = client
        |> WeaviateEx.TenantClient.with_tenant("tenant_A")
        |> WeaviateEx.TenantClient.collection("Articles")

      # Perform operations scoped to the tenant
      {:ok, object} = TenantClient.insert(tenant_client, %{title: "Hello World"})
      {:ok, objects} = TenantClient.query(tenant_client, limit: 10)

  ## Pipelining

  The module supports a fluent pipeline style:

      client
      |> TenantClient.with_tenant("customer_123")
      |> TenantClient.collection("Documents")
      |> TenantClient.insert(%{content: "Document content"})

  ## All Operations

  All standard data operations are available:
  - `insert/3` - Insert a single object
  - `query/2` - List/query objects
  - `get/2` - Get a single object by ID
  - `update/3` - Update an object
  - `delete/2` - Delete an object
  - `batch_insert/3` - Batch insert multiple objects
  - `near_vector/3` - Vector similarity search
  - `near_text/3` - Text-based search
  - `hybrid/3` - Hybrid search
  - `bm25/3` - Keyword search
  """

  alias WeaviateEx.API.Batch
  alias WeaviateEx.API.Data
  alias WeaviateEx.Client

  @type t :: %__MODULE__{
          client: Client.t(),
          tenant: String.t(),
          collection: String.t() | nil
        }

  defstruct [:client, :tenant, :collection]

  @doc """
  Creates a tenant-scoped client wrapper.

  ## Examples

      tenant_client = TenantClient.with_tenant(client, "tenant_A")
  """
  @spec with_tenant(Client.t(), String.t()) :: t()
  def with_tenant(client, tenant) when is_binary(tenant) do
    %__MODULE__{client: client, tenant: tenant}
  end

  @doc """
  Sets the collection for subsequent operations.

  ## Examples

      tenant_client = tenant_client
        |> TenantClient.collection("Articles")
  """
  @spec collection(t(), String.t()) :: t()
  def collection(%__MODULE__{} = tc, coll) when is_binary(coll) do
    %{tc | collection: coll}
  end

  @doc """
  Inserts an object within the tenant scope.

  The tenant is automatically added to the object.

  ## Examples

      {:ok, result} = TenantClient.insert(tenant_client, %{title: "Hello World"})
  """
  @spec insert(t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def insert(%__MODULE__{} = tc, object, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.insert(tc.client, tc.collection, object, opts)
  end

  @doc """
  Gets an object by ID within the tenant scope.

  ## Examples

      {:ok, object} = TenantClient.get(tenant_client, "uuid-123")
  """
  @spec get(t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(%__MODULE__{} = tc, id, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.get_by_id(tc.client, tc.collection, id, opts)
  end

  @doc """
  Updates an object within the tenant scope.

  ## Examples

      {:ok, result} = TenantClient.update(tenant_client, "uuid-123", %{title: "Updated"})
  """
  @spec update(t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update(%__MODULE__{} = tc, id, updates, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.update(tc.client, tc.collection, id, updates, opts)
  end

  @doc """
  Replaces an object within the tenant scope.

  ## Examples

      {:ok, result} = TenantClient.replace(tenant_client, "uuid-123", %{title: "Replaced"})
  """
  @spec replace(t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def replace(%__MODULE__{} = tc, id, object, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    # Use update with full replacement
    Data.update(tc.client, tc.collection, id, object, opts)
  end

  @doc """
  Deletes an object within the tenant scope.

  ## Examples

      :ok = TenantClient.delete(tenant_client, "uuid-123")
  """
  @spec delete(t(), String.t(), keyword()) :: :ok | {:ok, map()} | {:error, term()}
  def delete(%__MODULE__{} = tc, id, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.delete_by_id(tc.client, tc.collection, id, opts)
  end

  @doc """
  Queries/lists objects within the tenant scope using GraphQL Get query.

  ## Options

  - `:limit` - Maximum number of results (default: 25)
  - `:fields` - Fields to return

  ## Examples

      {:ok, objects} = TenantClient.query(tenant_client, limit: 10)
  """
  @spec query(t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def query(%__MODULE__{} = tc, opts \\ []) do
    ensure_collection!(tc)

    query =
      WeaviateEx.Query.get(tc.collection)
      |> WeaviateEx.Query.tenant(tc.tenant)
      |> maybe_add_query_limit(opts)
      |> maybe_add_query_fields(opts)

    WeaviateEx.Query.execute(query, tc.client)
  end

  @doc """
  Performs vector similarity search within the tenant scope.

  ## Examples

      {:ok, results} = TenantClient.near_vector(tenant_client, [0.1, 0.2, ...], limit: 5)
  """
  @spec near_vector(t(), list(float()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def near_vector(%__MODULE__{} = tc, vector, opts \\ []) when is_list(vector) do
    ensure_collection!(tc)

    query =
      WeaviateEx.Query.get(tc.collection)
      |> WeaviateEx.Query.near_vector(vector, opts)
      |> WeaviateEx.Query.tenant(tc.tenant)
      |> maybe_add_query_limit(opts)
      |> maybe_add_query_fields(opts)

    WeaviateEx.Query.execute(query, tc.client)
  end

  @doc """
  Performs text-based vector search within the tenant scope.

  ## Examples

      {:ok, results} = TenantClient.near_text(tenant_client, "machine learning", limit: 5)
  """
  @spec near_text(t(), String.t() | list(String.t()), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def near_text(%__MODULE__{} = tc, concepts, opts \\ []) do
    ensure_collection!(tc)

    query =
      WeaviateEx.Query.get(tc.collection)
      |> WeaviateEx.Query.near_text(concepts, opts)
      |> WeaviateEx.Query.tenant(tc.tenant)
      |> maybe_add_query_limit(opts)
      |> maybe_add_query_fields(opts)

    WeaviateEx.Query.execute(query, tc.client)
  end

  @doc """
  Performs hybrid search within the tenant scope.

  Combines vector similarity and keyword (BM25) search.

  ## Options

  - `:alpha` - Weight between vector (1.0) and keyword (0.0) search (default: 0.5)
  - `:properties` - Properties to search for BM25

  ## Examples

      {:ok, results} = TenantClient.hybrid(tenant_client, "machine learning",
        alpha: 0.7,
        limit: 10
      )
  """
  @spec hybrid(t(), String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def hybrid(%__MODULE__{} = tc, query_text, opts \\ []) do
    ensure_collection!(tc)

    query =
      WeaviateEx.Query.get(tc.collection)
      |> WeaviateEx.Query.hybrid(query_text, opts)
      |> WeaviateEx.Query.tenant(tc.tenant)
      |> maybe_add_query_limit(opts)
      |> maybe_add_query_fields(opts)

    WeaviateEx.Query.execute(query, tc.client)
  end

  @doc """
  Performs BM25 keyword search within the tenant scope.

  ## Options

  - `:properties` - Properties to search in (optional)

  ## Examples

      {:ok, results} = TenantClient.bm25(tenant_client, "machine learning",
        properties: ["title", "content"],
        limit: 10
      )
  """
  @spec bm25(t(), String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def bm25(%__MODULE__{} = tc, query_text, opts \\ []) do
    ensure_collection!(tc)

    query =
      WeaviateEx.Query.get(tc.collection)
      |> WeaviateEx.Query.bm25(query_text, opts)
      |> WeaviateEx.Query.tenant(tc.tenant)
      |> maybe_add_query_limit(opts)
      |> maybe_add_query_fields(opts)

    WeaviateEx.Query.execute(query, tc.client)
  end

  @doc """
  Batch inserts objects within the tenant scope.

  All objects will have the tenant added automatically.

  ## Examples

      objects = [%{properties: %{title: "Doc 1"}}, %{properties: %{title: "Doc 2"}}]
      {:ok, results} = TenantClient.batch_insert(tenant_client, objects)
  """
  @spec batch_insert(t(), list(map()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def batch_insert(%__MODULE__{} = tc, objects, opts \\ []) when is_list(objects) do
    ensure_collection!(tc)

    objects_with_tenant =
      Enum.map(objects, fn obj ->
        obj
        |> Map.put(:tenant, tc.tenant)
        |> Map.put(:class, tc.collection)
      end)

    opts = Keyword.put(opts, :tenant, tc.tenant)
    Batch.create_objects(tc.client, objects_with_tenant, opts)
  end

  @doc """
  Returns the tenant name.

  ## Examples

      "tenant_A" = TenantClient.tenant_name(tenant_client)
  """
  @spec tenant_name(t()) :: String.t()
  def tenant_name(%__MODULE__{tenant: tenant}), do: tenant

  @doc """
  Returns the collection name.

  ## Examples

      "Articles" = TenantClient.collection_name(tenant_client)
  """
  @spec collection_name(t()) :: String.t() | nil
  def collection_name(%__MODULE__{collection: coll}), do: coll

  @doc """
  Returns the underlying client.

  ## Examples

      client = TenantClient.client(tenant_client)
  """
  @spec client(t()) :: Client.t()
  def client(%__MODULE__{client: c}), do: c

  # Private helper functions

  defp ensure_collection!(%__MODULE__{collection: nil}) do
    raise ArgumentError, "Collection must be set. Use TenantClient.collection/2 first."
  end

  defp ensure_collection!(%__MODULE__{}), do: :ok

  defp maybe_add_query_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> WeaviateEx.Query.limit(query, limit)
    end
  end

  defp maybe_add_query_fields(query, opts) do
    case Keyword.get(opts, :fields) do
      nil -> query
      fields -> WeaviateEx.Query.fields(query, fields)
    end
  end
end
