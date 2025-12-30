# Prompt - Fluent with_tenant API

## Objective

Implement a fluent `with_tenant` API that returns a tenant-scoped collection reference, matching Python's pattern for cleaner multi-tenant operations.

## Priority

P1 - High (Developer experience)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/08-multi-tenancy.md`
- `README.md` (multi-tenancy section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/tenant_client.ex` - Existing tenant client (if exists)
- `lib/weaviate_ex/api/tenants.ex` - Tenant API
- `lib/weaviate_ex/collection.ex` - Collection struct
- `lib/weaviate_ex/objects.ex` - Object operations
- `lib/weaviate_ex/query.ex` - Query operations
- `lib/weaviate_ex/batch.ex` - Batch operations
- `test/weaviate_ex/api/tenants_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/collection.py` - with_tenant method
- `../weaviate-python-client/weaviate/collections/tenants.py` - Tenant operations

## Context

### Current State
- Tenant operations require passing tenant as parameter to each method
- No scoped collection reference
- Verbose and error-prone for multi-tenant workflows

### Python Pattern
```python
# Get tenant-scoped collection
tenant_collection = collection.with_tenant("tenant_A")

# All operations automatically scoped to tenant
tenant_collection.data.insert({"name": "test"})
tenant_collection.query.bm25("query")
tenant_collection.batch.dynamic()
```

### Gap
Elixir requires explicit tenant parameter on every operation:
```elixir
Objects.create(client, "Collection", object, tenant: "tenant_A")
Query.bm25(query, client, tenant: "tenant_A")
Batch.create_objects(client, objects, tenant: "tenant_A")
```

## Implementation Instructions (TDD Required)

### Step 1: Create TenantCollection Struct

Create `lib/weaviate_ex/tenant_collection.ex`:

```elixir
defmodule WeaviateEx.TenantCollection do
  @moduledoc """
  A tenant-scoped collection reference.
  All operations are automatically scoped to the specified tenant.
  """

  @enforce_keys [:client, :collection, :tenant]
  defstruct [:client, :collection, :tenant]

  @type t :: %__MODULE__{
    client: WeaviateEx.Client.t(),
    collection: String.t(),
    tenant: String.t()
  }

  @doc """
  Creates a tenant-scoped collection reference.
  """
  @spec new(WeaviateEx.Client.t(), String.t(), String.t()) :: t()
  def new(client, collection, tenant) do
    %__MODULE__{
      client: client,
      collection: collection,
      tenant: tenant
    }
  end
end
```

### Step 2: Add with_tenant to Collections

Update `lib/weaviate_ex/collections.ex`:

```elixir
defmodule WeaviateEx.Collections do
  alias WeaviateEx.TenantCollection

  @doc """
  Returns a tenant-scoped collection reference.

  ## Examples

      tenant_col = Collections.with_tenant(client, "Articles", "tenant_A")

      # All operations now scoped to tenant_A
      TenantCollection.insert(tenant_col, %{title: "Test"})
      TenantCollection.query(tenant_col) |> Query.bm25("search")
  """
  @spec with_tenant(Client.t(), String.t(), String.t()) :: TenantCollection.t()
  def with_tenant(client, collection, tenant) do
    TenantCollection.new(client, collection, tenant)
  end
end
```

### Step 3: Add Data Operations to TenantCollection

Add data operations to `lib/weaviate_ex/tenant_collection.ex`:

```elixir
defmodule WeaviateEx.TenantCollection do
  alias WeaviateEx.{Objects, Query, Batch}

  # Data Operations

  @doc """
  Inserts an object into the tenant's collection.
  """
  @spec insert(t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def insert(%__MODULE__{} = tc, object, opts \\ []) do
    Objects.create(tc.client, tc.collection, object, Keyword.put(opts, :tenant, tc.tenant))
  end

  @doc """
  Inserts multiple objects into the tenant's collection.
  """
  @spec insert_many(t(), [map()], keyword()) :: {:ok, map()} | {:error, term()}
  def insert_many(%__MODULE__{} = tc, objects, opts \\ []) do
    Batch.create_objects(tc.client, tc.collection, objects, Keyword.put(opts, :tenant, tc.tenant))
  end

  @doc """
  Gets an object by UUID from the tenant's collection.
  """
  @spec get(t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(%__MODULE__{} = tc, uuid, opts \\ []) do
    Objects.get(tc.client, tc.collection, uuid, Keyword.put(opts, :tenant, tc.tenant))
  end

  @doc """
  Updates an object in the tenant's collection.
  """
  @spec update(t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update(%__MODULE__{} = tc, uuid, properties, opts \\ []) do
    Objects.update(tc.client, tc.collection, uuid, properties, Keyword.put(opts, :tenant, tc.tenant))
  end

  @doc """
  Deletes an object from the tenant's collection.
  """
  @spec delete(t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete(%__MODULE__{} = tc, uuid, opts \\ []) do
    Objects.delete(tc.client, tc.collection, uuid, Keyword.put(opts, :tenant, tc.tenant))
  end

  # Query Operations

  @doc """
  Creates a query builder for the tenant's collection.
  """
  @spec query(t()) :: Query.t()
  def query(%__MODULE__{} = tc) do
    Query.get(tc.collection)
    |> Query.with_tenant(tc.tenant)
  end

  # Batch Operations

  @doc """
  Creates a batch context for the tenant's collection.
  """
  @spec batch(t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def batch(%__MODULE__{} = tc, opts \\ []) do
    Batch.start(tc.client, tc.collection, Keyword.put(opts, :tenant, tc.tenant))
  end
end
```

### Step 4: Add with_tenant to Query

Update `lib/weaviate_ex/query.ex`:

```elixir
@doc """
Scopes the query to a specific tenant.
"""
@spec with_tenant(t(), String.t()) :: t()
def with_tenant(query, tenant) do
  %{query | tenant: tenant}
end
```

### Step 5: Execute Query with Tenant

Update query execution to include tenant:

```elixir
def execute(%{tenant: tenant} = query, client, opts) when not is_nil(tenant) do
  opts = Keyword.put(opts, :tenant, tenant)
  do_execute(query, client, opts)
end
```

### Step 6: Add Convenience Method to Client

Optionally, add to `lib/weaviate_ex/client.ex`:

```elixir
@doc """
Returns a tenant-scoped collection reference.
"""
@spec collection(t(), String.t(), String.t()) :: TenantCollection.t()
def collection(client, collection_name, tenant) do
  TenantCollection.new(client, collection_name, tenant)
end
```

## Tests to Write

### TenantCollection Tests (`test/weaviate_ex/tenant_collection_test.exs`)

```elixir
describe "new/3" do
  test "creates tenant-scoped collection reference"
  test "stores client, collection, and tenant"
end

describe "insert/3" do
  test "passes tenant to Objects.create"
  test "merges with other options"
end

describe "insert_many/3" do
  test "passes tenant to Batch.create_objects"
end

describe "get/3" do
  test "passes tenant to Objects.get"
end

describe "update/4" do
  test "passes tenant to Objects.update"
end

describe "delete/3" do
  test "passes tenant to Objects.delete"
end

describe "query/1" do
  test "returns query builder with tenant set"
end

describe "batch/2" do
  test "starts batch with tenant scope"
end
```

### Integration Tests

```elixir
@tag :integration
describe "fluent tenant API" do
  setup do
    # Create multi-tenant collection
    # Create tenants
  end

  test "complete workflow with with_tenant" do
    tenant_col = Collections.with_tenant(client, "Articles", "tenant_A")

    # Insert
    {:ok, obj} = TenantCollection.insert(tenant_col, %{title: "Test"})

    # Query
    {:ok, results} = tenant_col
    |> TenantCollection.query()
    |> Query.bm25("Test")
    |> Query.execute(client)

    # Get
    {:ok, fetched} = TenantCollection.get(tenant_col, obj["id"])

    # Delete
    :ok = TenantCollection.delete(tenant_col, obj["id"])
  end

  test "batch operations with tenant scope"
end
```

## Docs Updates

### README.md

Update multi-tenancy section:

```markdown
### Multi-Tenancy

#### Fluent with_tenant API

Get a tenant-scoped collection for cleaner multi-tenant code:

\`\`\`elixir
# Get tenant-scoped collection
tenant_col = WeaviateEx.Collections.with_tenant(client, "Articles", "tenant_A")

# All operations automatically scoped to tenant_A
{:ok, _} = WeaviateEx.TenantCollection.insert(tenant_col, %{
  title: "My Article",
  content: "Article content"
})

# Query within tenant
{:ok, results} = tenant_col
|> WeaviateEx.TenantCollection.query()
|> WeaviateEx.Query.bm25("search term")
|> WeaviateEx.Query.execute(client)

# Batch insert within tenant
{:ok, _} = WeaviateEx.TenantCollection.insert_many(tenant_col, [
  %{title: "Article 1"},
  %{title: "Article 2"}
])
\`\`\`

#### Traditional API (still supported)

\`\`\`elixir
# Pass tenant as option to each operation
{:ok, _} = WeaviateEx.Objects.create(client, "Articles", object, tenant: "tenant_A")
\`\`\`
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- `WeaviateEx.TenantCollection` for fluent tenant-scoped operations
- `Collections.with_tenant/3` returns tenant-scoped collection reference
- `TenantCollection.insert/3`, `insert_many/3`, `get/3`, `update/4`, `delete/3`
- `TenantCollection.query/1` returns tenant-scoped query builder
- `TenantCollection.batch/2` starts tenant-scoped batch context
- `Query.with_tenant/2` for explicit tenant scoping
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New TenantCollection tests pass
- [ ] Integration tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `TenantCollection` struct implemented
2. `Collections.with_tenant/3` returns scoped reference
3. Data operations (insert, get, update, delete) work on TenantCollection
4. Query builder includes tenant automatically
5. Batch operations respect tenant scope
6. Integration test demonstrates full workflow
7. All quality gates pass
