# Multi-Tenancy Deep Gap Analysis

**Date:** 2025-12-29
**Scope:** Multi-tenancy support comparison between Python client and Elixir port
**Analyst:** Multi-Agent Gap Analysis
**Reference:** `weaviate-python-client` (canonical)
**Port:** `weaviate_ex` (Elixir implementation)

---

## Executive Summary

The Elixir port has made significant progress in multi-tenancy support, implementing core CRUD operations and a dedicated `TenantClient` module. However, there remain notable gaps in type specialization, validation enforcement, and API parity with the Python client's rich tenant management capabilities.

### Key Findings

| Area | Python Client | Elixir Port | Gap Severity |
|------|--------------|-------------|--------------|
| Tenant CRUD Operations | Full (create, get, get_by_name, get_by_names, remove, update, exists) | Partial (list, get, create, update, delete, exists?) | Medium |
| Tenant States | 8 states with deprecation handling | 6 states, status mapping present | Low |
| Tenant-Scoped Operations | `.with_tenant()` fluent API | `TenantClient` module | Low |
| Bulk Tenant Operations | 100-item batch updates, parallel async | `batch_update` with 100-item batching | Low |
| Tenant Existence Checks | `HEAD`-based efficient check | `GET`-based fallback | Low |
| Tenant Search by Names | `get_by_names()` with gRPC | Missing | Medium |
| TenantClient Context | Returns full scoped Collection | Separate wrapper struct | Medium |
| Type Specialization | TenantCreate, TenantUpdate, TenantOutput types | Single Tenant struct | Medium |
| Status Validation | Enforced on create/update | Not enforced | Medium |
| Deprecation Warnings | HOT/COLD/FROZEN warnings | None | Low |

### Overall Assessment

**Maturity Level:** 80% feature parity

The Elixir implementation provides a solid foundation for multi-tenant operations. The `TenantClient` module addresses the primary UX gap of tenant-scoped operations. The main remaining gaps are specialized tenant types for different operations and stricter validation of activity status transitions.

---

## 1. Tenant CRUD Operations

### 1.1 Create Tenants

#### Python Client

```python
# In weaviate/collections/tenants/executor.py
class _TenantsExecutor:
    def create(
        self,
        tenants: Union[TenantCreateInputType, Sequence[TenantCreateInputType]],
    ) -> executor.Result[None]:
        """Create the specified tenants for this collection."""
        if self._validate_arguments:
            _validate_input([
                _ValidateArgument(
                    expected=[str, Tenant, TenantCreate, Sequence[Union[str, Tenant, TenantCreate]]],
                    name="tenants",
                    value=tenants,
                )
            ])
        path = "/schema/" + self._name + "/tenants"
        return executor.execute(
            response_callback=resp,
            method=self._connection.post,
            path=path,
            weaviate_object=self.__map_create_tenants(tenants),
            ...
        )

    def __map_create_tenant(self, tenant: TenantCreateInputType) -> TenantCreate:
        if isinstance(tenant, str):
            return TenantCreate(name=tenant)
        if isinstance(tenant, Tenant):
            # CRITICAL: Validates status for creation
            if tenant.activity_status not in [
                TenantActivityStatus.ACTIVE,
                TenantActivityStatus.INACTIVE,
            ]:
                raise WeaviateInvalidInputError(
                    f"Tenant activity status must be either 'ACTIVE' or 'INACTIVE'. "
                    f"Other statuses are read-only and cannot be set."
                )
            activity_status = TenantCreateActivityStatus(tenant.activity_status)
            return TenantCreate(name=tenant.name, activity_status=activity_status)
        return tenant
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 47-94, 201-214)

**Key Features:**
- Accepts string, `Tenant`, or `TenantCreate` objects
- Validates that only ACTIVE/INACTIVE can be set on creation
- Uses specialized `TenantCreate` type with restricted status options

#### Elixir Port

```elixir
# In lib/weaviate_ex/api/tenants.ex
@spec create(Client.t(), collection_name(), tenant_names(), opts()) ::
        {:ok, [map()]} | {:error, Error.t()}
def create(client, collection_name, tenant_names, opts \\ [])

def create(client, collection_name, tenant_name, opts) when is_binary(tenant_name) do
  create(client, collection_name, [tenant_name], opts)
end

def create(client, collection_name, tenant_names, opts) when is_list(tenant_names) do
  activity_status = Keyword.get(opts, :activity_status, :hot) |> activity_to_string()

  tenants =
    Enum.map(tenant_names, fn name ->
      %{"name" => name, "activityStatus" => activity_status}
    end)

  Client.request(client, :post, "/v1/schema/#{collection_name}/tenants", tenants, [])
end
```

**File:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/tenants.ex` (lines 150-179)

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| String tenant name | Yes | Yes | None |
| Tenant object | `Tenant`/`TenantCreate` | Name string only | **Medium** |
| Status validation | ACTIVE/INACTIVE only | Any status accepted | **Medium** |
| Default status | ACTIVE | :hot (deprecated) | **Low** |

**Critical Gap:** Elixir accepts any activity status on create, while Python restricts to ACTIVE/INACTIVE. Creating a tenant with OFFLOADED or transitional states should fail with validation error.

---

### 1.2 Get/List Tenants

#### Python Client

```python
# Multiple get methods with different capabilities
def get(self) -> executor.Result[Dict[str, TenantOutputType]]:
    """Return all tenants - uses gRPC when available."""
    return executor.execute(
        response_callback=resp,
        method=(
            self.__get_with_grpc
            if self._connection._weaviate_version.supports_tenants_get_grpc
            else self.__get_with_rest
        ),
    )

def get_by_names(
    self, tenants: Sequence[TenantInputType]
) -> executor.Result[Dict[str, TenantOutputType]]:
    """Return named tenants - gRPC only, requires v1.25.0+."""
    self._connection._weaviate_version.check_is_at_least_1_25_0("The 'get_by_names' method")
    return self.__get_with_grpc(tenants=tenants)

def get_by_name(self, tenant: TenantInputType) -> executor.Result[Optional[TenantOutputType]]:
    """Return a specific tenant with RBAC handling for v1.28.0+."""
    self._connection._weaviate_version.check_is_at_least_1_25_0("The 'get_by_name' method")
    tenant_name = tenant.name if isinstance(tenant, Tenant) else tenant

    if self._connection._weaviate_version.is_lower_than(1, 28, 0):
        # For versions without RBAC, use gRPC
        return self.__get_with_grpc(tenants=[tenant_name])

    # For v1.28.0+, use REST API due to RBAC filtering in gRPC
    return executor.execute(
        response_callback=resp_rest,
        method=self._connection.get,
        path=f"/schema/{self._name}/tenants/{tenant_name}",
        ...
    )
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 263-365)

#### Elixir Port

```elixir
# In lib/weaviate_ex/api/tenants.ex
@spec list(Client.t(), collection_name()) :: {:ok, [map()]} | {:error, Error.t()}
def list(client, collection_name) do
  if grpc_available?(client) do
    list_grpc(client, collection_name)
  else
    list_http(client, collection_name)
  end
end

@spec get(Client.t(), collection_name(), tenant_name()) ::
        {:ok, map()} | {:error, Error.t()}
def get(client, collection_name, tenant_name) do
  if grpc_available?(client) do
    get_grpc(client, collection_name, tenant_name)
  else
    get_http(client, collection_name, tenant_name)
  end
end

# Also in lib/weaviate_ex/grpc/services/tenants.ex
@spec get(GRPC.Channel.t(), String.t(), String.t() | [String.t()], tenant_opts()) ::
      {:ok, struct()} | {:error, Error.t()}
def get(channel, collection, tenant_names, opts \\ []) do
  names = if is_binary(tenant_names), do: [tenant_names], else: tenant_names
  tenant_names_msg = %Weaviate.V1.TenantNames{values: names}
  request = %TenantsGetRequest{
    collection: collection,
    params: {:names, tenant_names_msg}
  }
  execute_tenants_get(channel, request, opts)
end
```

**Files:**
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/tenants.ex` (lines 28-78)
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/grpc/services/tenants.ex` (lines 47-69)

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| `get()` (all tenants) | Dict return | List return | **Low** (API difference) |
| `get_by_name()`  | Optional return + RBAC handling | `get/3` basic | **Medium** |
| `get_by_names()` | Batch retrieval via gRPC | gRPC supports it at service level | **Low** |
| Version checking | `check_is_at_least_1_25_0` | None | **Low** |
| RBAC-aware switch | v1.28+ uses REST | Not implemented | **Medium** |

**API Difference:** Python returns `Dict[str, TenantOutputType]` (keyed by name), Elixir returns `[map()]` (list). This affects lookup ergonomics.

---

### 1.3 Update Tenants

#### Python Client

```python
def update(
    self,
    tenants: Union[TenantUpdateInputType, Sequence[TenantUpdateInputType]],
) -> executor.Result[None]:
    """Update the specified tenants."""
    if self._validate_arguments:
        _validate_input(
            _ValidateArgument(
                expected=[Tenant, TenantUpdate, Sequence[Union[Tenant, TenantUpdate]]],
                name="tenants",
                value=tenants,
            )
        )
    return self.__update(tenants=tenants)

def __map_update_tenant(self, tenant: TenantUpdateInputType) -> TenantUpdate:
    if isinstance(tenant, Tenant):
        # CRITICAL: Validates status for updates
        if tenant.activity_status not in [
            TenantActivityStatus.ACTIVE,
            TenantActivityStatus.INACTIVE,
            TenantActivityStatus.OFFLOADED,
        ]:
            raise WeaviateInvalidInputError(
                f"Tenant activity status must be one of 'ACTIVE', 'INACTIVE' or 'OFFLOADED'. "
                f"Other statuses are read-only and cannot be set."
            )
        activity_status = TenantUpdateActivityStatus(tenant.activity_status)
        return TenantUpdate(name=tenant.name, activity_status=activity_status)
    return tenant
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 403-432, 216-228)

#### Elixir Port

```elixir
@spec update(Client.t(), collection_name(), tenant_names(), opts()) ::
        {:ok, [map()]} | {:error, Error.t()}
def update(client, collection_name, tenant_name, opts) when is_binary(tenant_name) do
  update(client, collection_name, [tenant_name], opts)
end

def update(client, collection_name, tenant_names, opts) when is_list(tenant_names) do
  activity_status = Keyword.get(opts, :activity_status, :hot) |> activity_to_string()

  tenants =
    Enum.map(tenant_names, fn name ->
      %{"name" => name, "activityStatus" => activity_status}
    end)

  Client.request(client, :put, "/v1/schema/#{collection_name}/tenants", tenants, [])
end
```

**File:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/tenants.ex` (lines 182-209)

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Status validation | ACTIVE/INACTIVE/OFFLOADED only | Any status | **Medium** |
| Tenant object input | `Tenant`/`TenantUpdate` | Name string only | **Medium** |
| Transitional states blocked | Yes (OFFLOADING, ONLOADING) | No | **Medium** |

---

### 1.4 Delete Tenants

#### Python Client

```python
def remove(
    self,
    tenants: Union[TenantInputType, Sequence[TenantInputType]],
) -> executor.Result[None]:
    """Remove the specified tenants from this collection."""
    if self._validate_arguments:
        _validate_input([
            _ValidateArgument(
                expected=[str, Tenant, Sequence[Union[str, Tenant]]],
                name="tenants",
                value=tenants,
            )
        ])

    tenant_names: List[str] = []
    if isinstance(tenants, str) or isinstance(tenants, Tenant):
        tenant_names = [tenants.name if isinstance(tenants, Tenant) else tenants]
    else:
        for tenant in tenants:
            tenant_names.append(tenant.name if isinstance(tenant, Tenant) else tenant)

    return executor.execute(
        method=self._connection.delete,
        path=path,
        weaviate_object=tenant_names,
        ...
    )
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 96-149)

#### Elixir Port

```elixir
@spec delete(Client.t(), collection_name(), tenant_names()) ::
        {:ok, map()} | {:error, Error.t()}
def delete(client, collection_name, tenant_name) when is_binary(tenant_name) do
  delete(client, collection_name, [tenant_name])
end

def delete(client, collection_name, tenant_names) when is_list(tenant_names) do
  Client.request(client, :delete, "/v1/schema/#{collection_name}/tenants", tenant_names, [])
end
```

**File:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/tenants.ex` (lines 211-231)

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Method name | `remove()` | `delete()` | **None** (semantic equivalent) |
| Tenant object input | Accepts `Tenant` objects | String only | **Low** |
| Bulk delete | Yes | Yes | None |

---

## 2. Tenant States (HOT, COLD, FROZEN, ACTIVE, INACTIVE)

### Python Client

```python
# In weaviate/collections/classes/tenants.py
class TenantActivityStatus(str, Enum):
    """Full status enum for reading tenant state."""
    ACTIVE = "ACTIVE"        # Tenant is fully active
    INACTIVE = "INACTIVE"    # Files stored locally, not loaded
    OFFLOADED = "OFFLOADED"  # Files stored on cloud
    OFFLOADING = "OFFLOADING"  # Transitioning to offloaded
    ONLOADING = "ONLOADING"    # Transitioning to active
    # Deprecated aliases
    HOT = "HOT"
    COLD = "COLD"
    FROZEN = "FROZEN"

class TenantCreateActivityStatus(str, Enum):
    """Limited status options for tenant creation."""
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    HOT = "HOT"    # Deprecated
    COLD = "COLD"  # Deprecated

class TenantUpdateActivityStatus(str, Enum):
    """Status options for tenant updates."""
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    OFFLOADED = "OFFLOADED"
    HOT = "HOT"    # Deprecated
    COLD = "COLD"  # Deprecated
    FROZEN = "FROZEN"  # Deprecated

# Deprecation warning handling in Tenant model
def model_post_init(self, __context: Any) -> None:
    self._model_post_init(user_input=True)

def _model_post_init(self, user_input: bool) -> None:
    if self.activityStatusInternal == TenantActivityStatus.HOT:
        if user_input:
            _Warnings.deprecated_tenant_type("HOT", "ACTIVE")
        self.activityStatusInternal = TenantActivityStatus.ACTIVE
    elif self.activityStatusInternal == TenantUpdateActivityStatus.COLD:
        if user_input:
            _Warnings.deprecated_tenant_type("COLD", "INACTIVE")
        self.activityStatusInternal = TenantActivityStatus.INACTIVE
    elif self.activityStatusInternal == TenantUpdateActivityStatus.FROZEN:
        if user_input:
            _Warnings.deprecated_tenant_type("FROZEN", "OFFLOADED")
        self.activityStatusInternal = TenantActivityStatus.OFFLOADED
```

**File:** `weaviate-python-client/weaviate/collections/classes/tenants.py` (lines 28-139)

### Elixir Port

```elixir
# In lib/weaviate_ex/types/tenant.ex
@type activity_status :: :active | :inactive | :hot | :cold | :frozen | :offloaded

@valid_statuses ~w(active inactive hot cold frozen offloaded)a

@spec validate_status!(atom()) :: :ok | no_return()
def validate_status!(status) when status in @valid_statuses, do: :ok

def validate_status!(status) do
  raise ArgumentError,
        "Invalid activity_status: #{inspect(status)}. Must be one of #{inspect(@valid_statuses)}"
end

# Status string to atom mapping
@status_string_map %{
  "ACTIVE" => :active,
  "INACTIVE" => :inactive,
  "HOT" => :hot,
  "COLD" => :cold,
  "WARM" => :hot,
  "FROZEN" => :frozen,
  "OFFLOADED" => :offloaded,
  "FREEZING" => :frozen,
  "UNFREEZING" => :hot,
  "OFFLOADING" => :offloaded,
  "ONLOADING" => :hot
}

# In lib/weaviate_ex/api/tenants.ex
defp activity_to_string(:active), do: "ACTIVE"
defp activity_to_string(:inactive), do: "INACTIVE"
defp activity_to_string(:hot), do: "HOT"
defp activity_to_string(:cold), do: "COLD"
defp activity_to_string(:frozen), do: "FROZEN"
defp activity_to_string(:offloaded), do: "OFFLOADED"
defp activity_to_string(status) when is_binary(status), do: String.upcase(status)
```

**Files:**
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/types/tenant.ex` (lines 31-214)
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/tenants.ex` (lines 457-463)

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| ACTIVE/INACTIVE | Yes | Yes (`:active`/`:inactive`) | None |
| HOT/COLD/FROZEN (deprecated) | Yes with warnings | Yes, no warnings | **Low** |
| OFFLOADED | Yes | Yes (`:offloaded`) | None |
| OFFLOADING/ONLOADING | Yes (read-only) | Mapped in parse | None |
| Separate enums per operation | Yes (3 types) | Single type | **Medium** |
| Deprecation warnings | Yes | Not implemented | **Low** |
| Automatic migration | HOT->ACTIVE etc | Mapped in parse | Partial |

**Note:** The Elixir `Tenant` struct in `types/tenant.ex` provides good status handling, but the API module uses deprecated names (`:hot`, `:cold`) as defaults. The `activate()` function sets `:hot` instead of `:active`.

---

## 3. Tenant-Scoped Operations

### Python Client - `.with_tenant()` Fluent API

```python
# In weaviate/collections/collection/sync.py
class Collection(Generic[Properties, References], _CollectionBase[ConnectionSync]):
    def __init__(
        self,
        connection: ConnectionSync,
        name: str,
        validate_arguments: bool,
        consistency_level: Optional[ConsistencyLevel] = None,
        tenant: Optional[str] = None,  # Tenant stored at collection level
        ...
    ) -> None:
        # All operations automatically scoped to tenant
        self.data: _DataCollection[Properties] = _DataCollection[Properties](
            connection, name, consistency_level, tenant, validate_arguments
        )
        self.query: _QueryCollection = _QueryCollection(
            connection=connection, name=name, tenant=tenant, ...
        )
        self.aggregate = _AggregateCollection(
            connection=connection, name=name, tenant=tenant, ...
        )
        self.tenants: _Tenants = _Tenants(connection=connection, name=name, ...)

    def with_tenant(self, tenant: Union[str, Tenant]) -> "Collection[Properties, References]":
        """Return a collection object specific to a single tenant.

        This method does not send a request to Weaviate.
        """
        return Collection(
            connection=self._connection,
            name=self.name,
            validate_arguments=self._validate_arguments,
            consistency_level=self.consistency_level,
            tenant=tenant.name if isinstance(tenant, Tenant) else tenant,
            properties=self.__properties,
            references=self.__references,
        )
```

**Usage:**

```python
# Create tenants
collection.tenants.create([Tenant(name="tenant1"), Tenant(name="tenant2")])

# Get tenant-scoped collection - ALL operations now scoped
tenant1 = collection.with_tenant("tenant1")

# Data operations
tenant1.data.insert(properties={"name": "some name"})
tenant1.data.delete_by_id(uuid)

# Query operations
tenant1.query.fetch_objects()  # Only returns tenant1's objects
tenant1.query.bm25(query="search term")

# Aggregate operations
tenant1.aggregate.over_all(total_count=True)
```

**File:** `weaviate-python-client/weaviate/collections/collection/sync.py` (lines 37-177)

### Elixir Port - `TenantClient` Module

```elixir
# In lib/weaviate_ex/tenant_client.ex
defmodule WeaviateEx.TenantClient do
  @moduledoc """
  Fluent API for tenant-scoped operations.
  """

  @type t :: %__MODULE__{
          client: Client.t(),
          tenant: String.t(),
          collection: String.t() | nil
        }

  defstruct [:client, :tenant, :collection]

  @spec with_tenant(Client.t(), String.t()) :: t()
  def with_tenant(client, tenant) when is_binary(tenant) do
    %__MODULE__{client: client, tenant: tenant}
  end

  @spec collection(t(), String.t()) :: t()
  def collection(%__MODULE__{} = tc, coll) when is_binary(coll) do
    %{tc | collection: coll}
  end

  # Data operations - automatically add tenant
  @spec insert(t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def insert(%__MODULE__{} = tc, object, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.insert(tc.client, tc.collection, object, opts)
  end

  @spec get(t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(%__MODULE__{} = tc, id, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.get_by_id(tc.client, tc.collection, id, opts)
  end

  @spec update(t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update(%__MODULE__{} = tc, id, updates, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.update(tc.client, tc.collection, id, updates, opts)
  end

  @spec delete(t(), String.t(), keyword()) :: :ok | {:ok, map()} | {:error, term()}
  def delete(%__MODULE__{} = tc, id, opts \\ []) do
    ensure_collection!(tc)
    opts = Keyword.put(opts, :tenant, tc.tenant)
    Data.delete_by_id(tc.client, tc.collection, id, opts)
  end

  # Query operations - automatically add tenant
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

  # Search operations
  @spec near_vector(t(), list(float()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def near_vector(%__MODULE__{} = tc, vector, opts \\ []) when is_list(vector) do
    ensure_collection!(tc)
    query =
      WeaviateEx.Query.get(tc.collection)
      |> WeaviateEx.Query.near_vector(vector, opts)
      |> WeaviateEx.Query.tenant(tc.tenant)
      |> maybe_add_query_limit(opts)
    WeaviateEx.Query.execute(query, tc.client)
  end

  @spec hybrid(t(), String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def hybrid(%__MODULE__{} = tc, query_text, opts \\ []) do
    ensure_collection!(tc)
    query =
      WeaviateEx.Query.get(tc.collection)
      |> WeaviateEx.Query.hybrid(query_text, opts)
      |> WeaviateEx.Query.tenant(tc.tenant)
    WeaviateEx.Query.execute(query, tc.client)
  end

  @spec bm25(t(), String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def bm25(%__MODULE__{} = tc, query_text, opts \\ []) do
    ensure_collection!(tc)
    query =
      WeaviateEx.Query.get(tc.collection)
      |> WeaviateEx.Query.bm25(query_text, opts)
      |> WeaviateEx.Query.tenant(tc.tenant)
    WeaviateEx.Query.execute(query, tc.client)
  end

  # Batch operations
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

  # Accessor functions
  @spec tenant_name(t()) :: String.t()
  def tenant_name(%__MODULE__{tenant: tenant}), do: tenant

  @spec collection_name(t()) :: String.t() | nil
  def collection_name(%__MODULE__{collection: coll}), do: coll

  @spec client(t()) :: Client.t()
  def client(%__MODULE__{client: c}), do: c
end
```

**Usage:**

```elixir
# Create tenant-scoped client
tenant_client = client
  |> WeaviateEx.TenantClient.with_tenant("tenant_A")
  |> WeaviateEx.TenantClient.collection("Articles")

# Perform operations scoped to the tenant
{:ok, object} = TenantClient.insert(tenant_client, %{title: "Hello World"})
{:ok, objects} = TenantClient.query(tenant_client, limit: 10)
{:ok, results} = TenantClient.hybrid(tenant_client, "machine learning", alpha: 0.7)
{:ok, results} = TenantClient.batch_insert(tenant_client, objects)
```

**File:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/tenant_client.ex` (lines 1-356)

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Fluent tenant scoping | `.with_tenant()` | `TenantClient.with_tenant/2` | None |
| Returns Collection | Full Collection object | Separate struct | **Medium** |
| CRUD operations | All via scoped collection | `insert`, `get`, `update`, `delete` | None |
| Query operations | All query types | `query`, `near_vector`, `near_text`, `hybrid`, `bm25` | None |
| Batch operations | Batch namespace | `batch_insert` | Partial |
| Aggregate operations | Scoped aggregates | Missing | **Medium** |
| Generate operations | RAG capabilities | Missing | **Medium** |
| Config operations | Collection config | Missing | **Low** |
| Backup operations | Collection backup | Missing | **Low** |
| Iterator support | Scoped iterator | Missing | **Medium** |

**Significant Progress:** The `TenantClient` module provides a solid foundation for tenant-scoped operations, covering the most common use cases (CRUD, searches, batch insert). The main gaps are aggregate operations and the fact it returns a custom struct rather than a fully-featured collection wrapper.

---

## 4. Bulk Tenant Operations

### Python Client

```python
# Batch size constant
UPDATE_TENANT_BATCH_SIZE = 100

def __map_update_tenants(
    self, tenants: Union[TenantUpdateInputType, Sequence[TenantUpdateInputType]]
) -> List[List[dict]]:
    """Split tenants into batches of 100 for update operations."""
    if isinstance(tenants, Tenant) or isinstance(tenants, TenantUpdate):
        return [[self.__map_update_tenant(tenants).model_dump()]]
    else:
        batches = ceil(len(tenants) / UPDATE_TENANT_BATCH_SIZE)
        return [
            [
                self.__map_update_tenant(tenants[i + b * UPDATE_TENANT_BATCH_SIZE]).model_dump()
                for i in range(min(
                    len(tenants) - b * UPDATE_TENANT_BATCH_SIZE,
                    UPDATE_TENANT_BATCH_SIZE,
                ))
            ]
            for b in range(batches)
        ]

def __update(self, tenants: ...) -> executor.Result[None]:
    """Execute batched update with parallel requests for async."""
    path = "/schema/" + self._name + "/tenants"
    if isinstance(self._connection, ConnectionAsync):
        async def _execute() -> None:
            # Async: parallel execution of batches
            await asyncio.gather(*[
                executor.aresult(self._connection.put(
                    path=path,
                    weaviate_object=mapped_tenants,
                    ...
                ))
                for mapped_tenants in self.__map_update_tenants(tenants)
            ])
        return _execute()
    # Sync: sequential batches
    for mapped_tenants in self.__map_update_tenants(tenants):
        self._connection.put(path=path, weaviate_object=mapped_tenants, ...)
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 29, 243-261, 367-402)

**Integration test for 1001 tenants:**

```python
def test_tenants_create_and_update_1001_tenants(collection_factory):
    tenants = [TenantCreate(name=f"tenant{i}") for i in range(1001)]
    collection.tenants.create(tenants)

    # Update all 1001 tenants - automatically batched into 11 requests
    tenants = [
        Tenant(name=f"tenant{i}", activity_status=TenantActivityStatus.INACTIVE)
        for i in range(1001)
    ]
    collection.tenants.update(tenants)
```

**File:** `weaviate-python-client/integration/test_tenants.py` (lines 461-483)

### Elixir Port

```elixir
# In lib/weaviate_ex/api/tenants.ex
@batch_size 100

@doc """
Updates tenants in batches of #{@batch_size} (matching Python client behavior).
"""
@spec batch_update(Client.t(), collection_name(), [map()]) ::
        {:ok, [map()]} | {:error, Error.t()}
def batch_update(client, collection_name, tenants) when is_list(tenants) do
  tenants
  |> Enum.chunk_every(@batch_size)
  |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
    case update_batch(client, collection_name, batch) do
      {:ok, results} -> {:cont, {:ok, acc ++ results}}
      {:error, _} = error -> {:halt, error}
    end
  end)
end

defp update_batch(client, collection_name, batch) do
  tenants =
    Enum.map(batch, fn
      %{name: name, activity_status: status} ->
        %{"name" => name, "activityStatus" => activity_to_string(status)}
      %{"name" => name, "activity_status" => status} ->
        %{"name" => name, "activityStatus" => activity_to_string(status)}
      %{"name" => name, "activityStatus" => status} ->
        %{"name" => name, "activityStatus" => status}
      %{name: name} ->
        %{"name" => name, "activityStatus" => "HOT"}
    end)

  Client.request(client, :put, "/v1/schema/#{collection_name}/tenants", tenants, [])
end

@spec batch_size() :: pos_integer()
def batch_size, do: @batch_size
```

**File:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/tenants.ex` (lines 25-26, 395-453)

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Batch size | 100 | 100 | None |
| Batch creation | Single request | Single request | None |
| Batch update | Auto-batching | `batch_update/3` | Partial |
| Async parallel | Yes | No (sequential) | **Low** |
| Regular `update/4` batching | Implicit | Not batched | **Low** |
| Expose batch_size | Not exposed | `batch_size/0` | None |

**Note:** Elixir has implemented `batch_update/3` which handles batching, but the regular `update/4` function does not batch. Python automatically batches all update calls.

---

## 5. Tenant Existence Checks

### Python Client

```python
def exists(self, tenant: TenantInputType) -> executor.Result[bool]:
    """Check if a tenant exists - requires v1.25.0+."""
    self._connection._weaviate_version.check_is_at_least_1_25_0("The 'exists' method")
    if self._validate_arguments:
        _validate_input(
            _ValidateArgument(
                expected=[str, Tenant],
                name="tenant",
                value=tenant,
            )
        )

    def resp(res: Response) -> bool:
        return res.status_code == 200

    tenant_name = tenant.name if isinstance(tenant, Tenant) else tenant
    path = "/schema/" + self._name + "/tenants/" + tenant_name
    return executor.execute(
        response_callback=resp,
        method=self._connection.head,  # Uses HEAD request
        path=path,
        error_msg=f"Could not check if tenant exists for {self._name}",
        status_codes=_ExpectedStatusCodes(
            ok_in=[200, 404], error=f"Check if tenant exists for {self._name}"
        ),
    )
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 434-472)

### Elixir Port

```elixir
@doc """
Check if tenant exists.

## Examples

    {:ok, true} = Tenants.exists?(client, "Article", "TenantA")
    {:ok, false} = Tenants.exists?(client, "Article", "NonExistent")
"""
@spec exists?(Client.t(), collection_name(), tenant_name()) :: {:ok, boolean()}
def exists?(client, collection_name, tenant_name) do
  case get(client, collection_name, tenant_name) do
    {:ok, _} -> {:ok, true}
    {:error, %Error{type: :not_found}} -> {:ok, false}
    {:error, _} -> {:ok, false}
  end
end
```

**File:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/tenants.ex` (lines 233-252)

Also in gRPC service:

```elixir
# In lib/weaviate_ex/grpc/services/tenants.ex
@spec exists?(GRPC.Channel.t(), String.t(), String.t(), tenant_opts()) ::
        {:ok, boolean()} | {:error, Error.t()}
def exists?(channel, collection, tenant_name, opts \\ []) do
  case get(channel, collection, tenant_name, opts) do
    {:ok, reply} ->
      exists = Enum.any?(reply.tenants, fn t -> t.name == tenant_name end)
      {:ok, exists}
    {:error, %Error{type: :not_found}} ->
      {:ok, false}
    {:error, error} ->
      {:error, error}
  end
end
```

**File:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/grpc/services/tenants.ex` (lines 77-92)

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Implementation | HEAD request | GET-based fallback | **Low** |
| Efficiency | Minimal response | Full tenant data | **Low** |
| Version check | v1.25.0+ required | None | **Low** |
| Error handling | 200/404 expected | Error type matching | None |

---

## 6. Tenant Search by Name Patterns

### Python Client

```python
def get_by_names(
    self, tenants: Sequence[TenantInputType]
) -> executor.Result[Dict[str, TenantOutputType]]:
    """Return named tenants currently associated with this collection.

    If the tenant does not exist, it will not be included in the response.
    If no names are provided, all tenants will be returned.
    The collection must have been created with multi-tenancy enabled.

    Args:
        tenants: Sequence of tenant names or wvc.tenants.Tenant objects.

    Raises:
        weaviate.exceptions.WeaviateConnectionError: If the network connection fails.
        weaviate.exceptions.UnexpectedStatusCodeError: If Weaviate reports non-OK status.
    """
    self._connection._weaviate_version.check_is_at_least_1_25_0("The 'get_by_names' method")
    if self._validate_arguments:
        _validate_input(
            _ValidateArgument(
                expected=[Sequence[Union[str, Tenant]]],
                name="names",
                value=tenants,
            )
        )
    return self.__get_with_grpc(tenants=tenants)
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 285-310)

**Usage in tests:**

```python
def test_tenants(collection_factory: CollectionFactory) -> None:
    collection.tenants.create([Tenant(name="tenant1"), Tenant(name="tenant2")])

    if collection._connection._weaviate_version.supports_tenants_get_grpc:
        tenants = collection.tenants.get_by_names(tenants=["tenant2"])
        assert len(tenants) == 1
        assert isinstance(tenants["tenant2"], Tenant)
```

**File:** `weaviate-python-client/integration/test_tenants.py` (lines 147-155)

### Elixir Port

The Elixir port has gRPC-level support for getting by names, but no high-level API function:

```elixir
# In lib/weaviate_ex/grpc/services/tenants.ex - Low-level gRPC support exists
def get(channel, collection, tenant_names, opts \\ []) do
  names = if is_binary(tenant_names), do: [tenant_names], else: tenant_names
  tenant_names_msg = %Weaviate.V1.TenantNames{values: names}
  request = %TenantsGetRequest{
    collection: collection,
    params: {:names, tenant_names_msg}
  }
  execute_tenants_get(channel, request, opts)
end
```

**Gap Analysis:**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| `get_by_names()` API | Yes | Missing (gRPC exists) | **Medium** |
| Pattern matching | Via gRPC | gRPC supports | Partial |
| Version checking | v1.25.0+ | None | **Low** |

**Recommendation:** Add `get_by_names/3` to `WeaviateEx.API.Tenants`:

```elixir
@spec get_by_names(Client.t(), collection_name(), [tenant_name()]) ::
        {:ok, [map()]} | {:error, Error.t()}
def get_by_names(client, collection_name, tenant_names) when is_list(tenant_names) do
  if grpc_available?(client) do
    get_by_names_grpc(client, collection_name, tenant_names)
  else
    # Fallback: filter from full list
    case list(client, collection_name) do
      {:ok, tenants} ->
        filtered = Enum.filter(tenants, &(&1["name"] in tenant_names))
        {:ok, filtered}
      error ->
        error
    end
  end
end
```

---

## 7. TenantClient/Tenant Context Handling

### Comparison Summary

| Aspect | Python | Elixir |
|--------|--------|--------|
| Pattern | Returns full `Collection` with tenant set | Returns `TenantClient` struct |
| Operation namespaces | `.data`, `.query`, `.aggregate`, `.generate` | Direct methods |
| Type preservation | Generic `Collection[Properties, References]` | No type params |
| Chaining | `collection.with_tenant("t").with_consistency_level(...)` | Must recreate struct |
| Tenant accessor | `collection.tenant` property | `TenantClient.tenant_name/1` |

### Python Client - Full Collection Return

```python
def with_tenant(self, tenant: Union[str, Tenant]) -> "Collection[Properties, References]":
    """Return a collection object specific to a single tenant."""
    return Collection(
        connection=self._connection,
        name=self.name,
        validate_arguments=self._validate_arguments,
        consistency_level=self.consistency_level,
        tenant=tenant.name if isinstance(tenant, Tenant) else tenant,
        properties=self.__properties,  # Type info preserved
        references=self.__references,
    )
```

The Python approach means:
- Full access to all Collection namespaces (`.data`, `.query`, `.aggregate`, `.generate`, `.batch`, `.config`, `.backup`)
- Type safety preserved via generics
- Can chain with `.with_consistency_level()`
- Uniform API whether tenant-scoped or not

### Elixir Port - Separate Wrapper

```elixir
def with_tenant(client, tenant) when is_binary(tenant) do
  %__MODULE__{client: client, tenant: tenant}
end

def collection(%__MODULE__{} = tc, coll) when is_binary(coll) do
  %{tc | collection: coll}
end
```

The Elixir approach means:
- Explicit tenant scoping via dedicated module
- Pipeline-friendly for Elixir idioms
- Missing some operations (aggregate, generate, config, backup, iterator)
- Different API surface from regular operations

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Full collection API | Yes | Subset | **Medium** |
| Aggregate support | Yes | Missing | **Medium** |
| Generate (RAG) | Yes | Missing | **Low** |
| Config operations | Yes | Missing | **Low** |
| Backup operations | Yes | Missing | **Low** |
| Iterator support | Yes | Missing | **Medium** |
| Type preservation | Yes (generics) | No | N/A (language diff) |
| Consistency level | Chainable | Not supported | **Low** |

---

## Summary Table

| Category | Feature | Python | Elixir | Priority |
|----------|---------|--------|--------|----------|
| **CRUD** | create with validation | Yes | No | Medium |
| **CRUD** | get_by_names | Yes | Missing | Medium |
| **CRUD** | get_by_name with RBAC | Yes | Partial | Medium |
| **CRUD** | delete/remove | Yes | Yes | None |
| **CRUD** | update with validation | Yes | No | Medium |
| **CRUD** | exists (HEAD) | Yes | GET-based | Low |
| **States** | ACTIVE/INACTIVE | Yes | Yes | None |
| **States** | OFFLOADED | Yes | Yes | None |
| **States** | Transitional (read-only) | Yes | Mapped | None |
| **States** | Deprecation warnings | Yes | No | Low |
| **States** | Separate enums | 3 types | 1 type | Medium |
| **Scoping** | TenantClient | .with_tenant() | TenantClient | Low |
| **Scoping** | Full operations | All namespaces | Subset | Medium |
| **Scoping** | Aggregate support | Yes | Missing | Medium |
| **Scoping** | Iterator support | Yes | Missing | Medium |
| **Bulk** | Batch update (100) | Auto | batch_update/3 | Low |
| **Bulk** | Async parallel | Yes | No | Low |
| **Search** | get_by_names | Yes | gRPC only | Medium |
| **Config** | auto_tenant_creation | Yes | Present | None |
| **Config** | auto_tenant_activation | Yes | Present | None |

---

## Recommendations

### High Priority

1. **Add status validation on create/update**
   - Create: Only allow `:active`/`:inactive`
   - Update: Only allow `:active`/`:inactive`/`:offloaded`
   - Block transitional states (`:offloading`, `:onloading`)

2. **Add `get_by_names/3` to API.Tenants**
   - Expose the gRPC-level functionality at API level
   - Add HTTP fallback via list filtering

3. **Extend TenantClient with aggregate support**
   - Add `aggregate/2` function
   - Add `aggregate_count/1` convenience function

### Medium Priority

4. **Update default status to `:active` instead of `:hot`**
   - Align with Python's non-deprecated defaults
   - Keep `:hot`/`:cold`/`:frozen` as aliases

5. **Add Tenant struct acceptance to CRUD operations**
   - Allow `%Tenant{}` input in addition to strings
   - Extract name automatically

6. **Add RBAC-aware `get_by_name/3`**
   - Use REST for v1.28.0+ instead of gRPC
   - Add version detection

### Low Priority

7. **Implement HEAD-based `exists?/3`**
   - More efficient than full GET
   - Requires HTTP client HEAD support

8. **Add deprecation logging for old status names**
   - Warn when `:hot`, `:cold`, `:frozen` used
   - Suggest `:active`, `:inactive`, `:offloaded`

9. **Add iterator support to TenantClient**
   - Stream-based object iteration within tenant scope

---

## File References

### Python Client Files
- `weaviate-python-client/weaviate/collections/classes/tenants.py` - Tenant types and enums
- `weaviate-python-client/weaviate/collections/tenants/executor.py` - Core executor with all operations
- `weaviate-python-client/weaviate/collections/tenants/sync.py` - Sync wrapper
- `weaviate-python-client/weaviate/collections/tenants/async_.py` - Async wrapper
- `weaviate-python-client/weaviate/collections/tenants/types.py` - Type aliases
- `weaviate-python-client/weaviate/collections/grpc/tenants.py` - gRPC operations
- `weaviate-python-client/weaviate/collections/collection/sync.py` - Collection.with_tenant()
- `weaviate-python-client/weaviate/collections/collection/async_.py` - Async with_tenant()
- `weaviate-python-client/integration/test_tenants.py` - Integration tests

### Elixir Port Files
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/tenants.ex` - Main tenant API
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/types/tenant.ex` - Tenant struct
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/tenant_client.ex` - TenantClient module
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/grpc/services/tenants.ex` - gRPC service
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/schema/multi_tenancy_config.ex` - MT config

---

## Conclusion

The Elixir port has made substantial progress in multi-tenancy support, achieving approximately **80% feature parity** with the Python client. The introduction of the `TenantClient` module addresses the key UX concern of tenant-scoped operations, providing a fluent API for common use cases.

**Key Achievements:**
- Full CRUD operations for tenants
- gRPC and HTTP support with automatic fallback
- TenantClient for scoped operations
- Batch update support with 100-item chunking
- All activity states supported

**Primary Gaps:**
- Status validation not enforced on create/update
- `get_by_names/3` not exposed at API level
- TenantClient missing aggregate and iterator operations
- Uses deprecated status names as defaults

The most impactful improvements would be adding status validation (preventing invalid state transitions) and exposing `get_by_names/3` for efficient bulk tenant lookup.
