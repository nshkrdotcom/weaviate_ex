# Multi-Tenancy Deep Gap Analysis

**Date:** 2025-12-29
**Scope:** Multi-tenancy support comparison between Python client and Elixir port
**Reference:** `weaviate-python-client` (canonical)
**Port:** `weaviate_ex` (Elixir implementation)

---

## Executive Summary

The Elixir port provides **substantial multi-tenancy functionality** through both HTTP and gRPC interfaces. The core CRUD operations (create, list, get, update, delete) are well-implemented with comprehensive activity status support. However, there are significant gaps in the type system, validation, and developer experience features compared to the Python client's rich object model.

### Key Findings

| Area | Python Client | Elixir Port | Gap Severity |
|------|--------------|-------------|--------------|
| Basic CRUD | Full | Full | None |
| Activity Status States | 8 states + transitions | All mapped | Low |
| Type-safe Tenant Classes | 4 specialized types | Map-based | Medium |
| Collection `.with_tenant()` | Fluent API | Manual tenant param | High |
| Auto-tenant Creation | Supported | Configuration only | Medium |
| Auto-tenant Activation | Supported | Missing | Medium |
| Batch Tenant Updates | 100-item batching | No batching | Medium |
| Status Migration Helpers | activate/deactivate/offload | activate/deactivate/freeze/offload | None |
| Deprecation Warnings | HOT/COLD/FROZEN warnings | None | Low |
| gRPC Tenant Get | Full with version checks | Basic implementation | Low |

### Overall Assessment

**Maturity Level:** 75% feature parity

The Elixir implementation covers all essential multi-tenancy operations but lacks the type safety, fluent collection API, and advanced configuration options that make the Python client ergonomic for large-scale multi-tenant deployments.

---

## Detailed Feature Comparison

### 1. Tenant Data Types and Classes

#### Python Client

The Python client provides a rich hierarchy of tenant-related types in `weaviate/collections/classes/tenants.py`:

```python
# Base tenant class with Pydantic model
class Tenant(BaseModel):
    """Tenant class used to describe a tenant in Weaviate."""
    name: str
    activityStatusInternal: TenantActivityStatus = Field(
        default=TenantActivityStatus.ACTIVE,
        alias="activity_status",
    )
    activityStatus: _TenantActivistatusServerValues = Field(...)

    @property
    def activity_status(self) -> TenantActivityStatus:
        """Getter for the activity status of the tenant."""
        return self.activityStatusInternal

# Specialized types for different operations
class TenantCreate(BaseModel):
    """Tenant class for creation - limited status options."""
    activityStatusInternal: TenantCreateActivityStatus  # Only ACTIVE/INACTIVE

class TenantUpdate(BaseModel):
    """Tenant class for updates - includes OFFLOADED."""
    activityStatusInternal: TenantUpdateActivityStatus  # ACTIVE/INACTIVE/OFFLOADED

class TenantOutput(Tenant):
    """Output wrapper with different post_init behavior."""
```

**Activity Status Enums:**

```python
class TenantActivityStatus(str, Enum):
    """Full status enum for reading tenant state."""
    ACTIVE = "ACTIVE"      # Tenant is fully active
    INACTIVE = "INACTIVE"  # Files stored locally, not loaded
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
```

**File:** `weaviate-python-client/weaviate/collections/classes/tenants.py`

#### Elixir Port

The Elixir port uses simple atoms and maps:

```elixir
# In lib/weaviate_ex/api/tenants.ex
@type activity_status :: :hot | :cold | :frozen

# Activity status handling
defp activity_to_string(:hot), do: "HOT"
defp activity_to_string(:cold), do: "COLD"
defp activity_to_string(:frozen), do: "FROZEN"
defp activity_to_string(:offloaded), do: "OFFLOADED"
defp activity_to_string(status) when is_binary(status), do: String.upcase(status)

# Tenants returned as maps
%{
  "name" => tenant.name,
  "activityStatus" => status_to_string(status)
}
```

**File:** `lib/weaviate_ex/api/tenants.ex`

#### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Pydantic/typed structs | Yes | No | **HIGH** |
| Separate Create/Update types | Yes | No | **MEDIUM** |
| Status validation on create | Yes (ACTIVE/INACTIVE only) | No | **MEDIUM** |
| Status validation on update | Yes (excludes OFFLOADING/ONLOADING) | No | **MEDIUM** |
| Deprecation warnings | Yes (HOT->ACTIVE, etc.) | No | **LOW** |
| TenantOutput wrapper | Yes | No | **LOW** |

**Recommendation:** Create `WeaviateEx.Tenant` struct with typespec enforcement:

```elixir
defmodule WeaviateEx.Tenant do
  @type activity_status :: :active | :inactive | :offloaded | :offloading | :onloading
  @type create_status :: :active | :inactive
  @type update_status :: :active | :inactive | :offloaded

  defstruct [:name, activity_status: :active]

  @spec new(String.t(), keyword()) :: t()
  @spec for_create(String.t(), create_status()) :: t()
  @spec for_update(String.t(), update_status()) :: t()
end
```

---

### 2. Tenant CRUD Operations

#### Python Client - Executor Pattern

The Python client uses a generic executor pattern in `weaviate/collections/tenants/executor.py`:

```python
class _TenantsExecutor(Generic[ConnectionType]):
    def __init__(self, connection: ConnectionType, name: str, validate_arguments: bool = True):
        self._connection = connection
        self._name = name
        self._grpc = _TenantsGRPC(weaviate_version=connection._weaviate_version, name=name)
        self._validate_arguments = validate_arguments

    def create(self, tenants: Union[TenantCreateInputType, Sequence[TenantCreateInputType]]) -> executor.Result[None]:
        """Create the specified tenants for this collection."""
        if self._validate_arguments:
            _validate_input([_ValidateArgument(
                expected=[str, Tenant, TenantCreate, Sequence[Union[str, Tenant, TenantCreate]]],
                name="tenants", value=tenants
            )])
        path = "/schema/" + self._name + "/tenants"
        return executor.execute(
            response_callback=resp,
            method=self._connection.post,
            path=path,
            weaviate_object=self.__map_create_tenants(tenants),
            ...
        )

    def get(self) -> executor.Result[Dict[str, TenantOutputType]]:
        """Return all tenants - uses gRPC when available."""
        return executor.execute(
            response_callback=resp,
            method=(self.__get_with_grpc if self._connection._weaviate_version.supports_tenants_get_grpc
                    else self.__get_with_rest),
        )

    def get_by_names(self, tenants: Sequence[TenantInputType]) -> executor.Result[Dict[str, TenantOutputType]]:
        """Return named tenants - gRPC only, requires v1.25.0+."""
        self._connection._weaviate_version.check_is_at_least_1_25_0("The 'get_by_names' method")
        return self.__get_with_grpc(tenants=tenants)

    def get_by_name(self, tenant: TenantInputType) -> executor.Result[Optional[TenantOutputType]]:
        """Return a specific tenant with RBAC handling for v1.28.0+."""
        self._connection._weaviate_version.check_is_at_least_1_25_0("The 'get_by_name' method")
        if self._connection._weaviate_version.is_lower_than(1, 28, 0):
            # Use gRPC for versions without RBAC
            return self.__get_with_grpc(tenants=[tenant_name])
        # Use REST for v1.28.0+ due to RBAC filtering
        return executor.execute(
            method=self._connection.get,
            path=f"/schema/{self._name}/tenants/{tenant_name}",
            ...
        )

    def exists(self, tenant: TenantInputType) -> executor.Result[bool]:
        """Check if a tenant exists - requires v1.25.0+."""
        self._connection._weaviate_version.check_is_at_least_1_25_0("The 'exists' method")
        return executor.execute(
            method=self._connection.head,
            path=f"/schema/{self._name}/tenants/{tenant_name}",
            ...
        )
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py`

#### Elixir Port

```elixir
# In lib/weaviate_ex/api/tenants.ex
defmodule WeaviateEx.API.Tenants do
  @spec list(Client.t(), collection_name()) :: {:ok, [map()]} | {:error, Error.t()}
  def list(client, collection_name) do
    if grpc_available?(client) do
      list_grpc(client, collection_name)
    else
      list_http(client, collection_name)
    end
  end

  @spec get(Client.t(), collection_name(), tenant_name()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, collection_name, tenant_name) do
    if grpc_available?(client) do
      get_grpc(client, collection_name, tenant_name)
    else
      get_http(client, collection_name, tenant_name)
    end
  end

  @spec create(Client.t(), collection_name(), tenant_names(), opts()) :: {:ok, [map()]} | {:error, Error.t()}
  def create(client, collection_name, tenant_names, opts \\ [])

  def create(client, collection_name, tenant_name, opts) when is_binary(tenant_name) do
    create(client, collection_name, [tenant_name], opts)
  end

  def create(client, collection_name, tenant_names, opts) when is_list(tenant_names) do
    activity_status = Keyword.get(opts, :activity_status, :hot) |> activity_to_string()
    tenants = Enum.map(tenant_names, fn name ->
      %{"name" => name, "activityStatus" => activity_status}
    end)
    Client.request(client, :post, "/v1/schema/#{collection_name}/tenants", tenants, [])
  end

  @spec exists?(Client.t(), collection_name(), tenant_name()) :: {:ok, boolean()}
  def exists?(client, collection_name, tenant_name) do
    case get(client, collection_name, tenant_name) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{type: :not_found}} -> {:ok, false}
      {:error, _} -> {:ok, false}
    end
  end
end
```

**File:** `lib/weaviate_ex/api/tenants.ex`

#### Gap Analysis

| Operation | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| `create()` | Full validation | Basic | **MEDIUM** |
| `remove()` / `delete()` | Both names | `delete()` only | None |
| `get()` (all) | gRPC/REST fallback | gRPC/REST fallback | None |
| `get_by_names()` | Version-checked | Missing | **MEDIUM** |
| `get_by_name()` | RBAC-aware v1.28+ | Basic get | **MEDIUM** |
| `exists()` | HEAD request | GET-based | **LOW** |
| `update()` | Batched (100 items) | Single request | **MEDIUM** |
| Input validation | Comprehensive | None | **MEDIUM** |

---

### 3. Tenant Activity Status Migration

#### Python Client

```python
# In executor.py - convenience methods for status changes
def activate(self, tenant: Union[TenantInputType, Sequence[TenantInputType]]) -> executor.Result[None]:
    """Activate the specified tenants (set to ACTIVE status)."""
    self.__update_tenant_activity_status(
        tenant=tenant,
        activity_status=TenantUpdateActivityStatus.ACTIVE,
    )

def deactivate(self, tenant: Union[TenantInputType, Sequence[TenantInputType]]) -> executor.Result[None]:
    """Deactivate the specified tenants (set to INACTIVE status)."""
    self.__update_tenant_activity_status(
        tenant=tenant,
        activity_status=TenantUpdateActivityStatus.INACTIVE,
    )

def offload(self, tenant: Union[TenantInputType, Sequence[TenantInputType]]) -> executor.Result[None]:
    """Offload the specified tenants (set to OFFLOADED status)."""
    self.__update_tenant_activity_status(
        tenant=tenant,
        activity_status=TenantUpdateActivityStatus.OFFLOADED,
    )

def __update_tenant_activity_status(
    self,
    tenant: Union[TenantInputType, Sequence[TenantInputType]],
    activity_status: TenantUpdateActivityStatus,
) -> executor.Result[None]:
    if self._validate_arguments:
        _validate_input([...])
    if isinstance(tenant, str) or isinstance(tenant, Tenant):
        tenants = [TenantUpdate(name=..., activity_status=activity_status)]
    else:
        tenants = [TenantUpdate(name=t.name if isinstance(t, Tenant) else t,
                                activity_status=activity_status) for t in tenant]
    return self.__update(tenants=tenants)
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 508-569)

#### Elixir Port

```elixir
# In lib/weaviate_ex/api/tenants.ex
@spec activate(Client.t(), collection_name(), tenant_names()) :: {:ok, [map()]} | {:error, Error.t()}
def activate(client, collection_name, tenant_names) do
  update(client, collection_name, tenant_names, activity_status: :hot)
end

@spec deactivate(Client.t(), collection_name(), tenant_names()) :: {:ok, [map()]} | {:error, Error.t()}
def deactivate(client, collection_name, tenant_names) do
  update(client, collection_name, tenant_names, activity_status: :cold)
end

@spec freeze(Client.t(), collection_name(), tenant_names()) :: {:ok, [map()]} | {:error, Error.t()}
def freeze(client, collection_name, tenant_names) do
  update(client, collection_name, tenant_names, activity_status: :frozen)
end

@spec offload(Client.t(), collection_name(), tenant_names()) :: {:ok, [map()]} | {:error, Error.t()}
def offload(client, collection_name, tenant_names) do
  update(client, collection_name, tenant_names, activity_status: :offloaded)
end
```

**File:** `lib/weaviate_ex/api/tenants.ex` (lines 250-325)

#### Gap Analysis

| Helper | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `activate()` | ACTIVE | :hot | **Name mismatch** (uses deprecated) |
| `deactivate()` | INACTIVE | :cold | **Name mismatch** (uses deprecated) |
| `offload()` | OFFLOADED | :offloaded | Aligned |
| `freeze()` | N/A | :frozen | **Elixir extra** (deprecated) |

**Issue:** The Elixir implementation uses deprecated status names (`:hot`, `:cold`, `:frozen`) while Python uses the new names (`ACTIVE`, `INACTIVE`, `OFFLOADED`). This could cause confusion.

**Recommendation:** Update Elixir to use `:active`, `:inactive`, `:offloaded` with deprecation warnings for old names.

---

### 4. Collection-Level Tenant Scoping

#### Python Client - Fluent `.with_tenant()` API

The Python client provides a fluent API for tenant-scoped operations:

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
        super().__init__(connection, name, validate_arguments, consistency_level, tenant)

        # All operations automatically tenant-scoped
        self.data: _DataCollection[Properties] = _DataCollection[Properties](
            connection, name, consistency_level, tenant, validate_arguments
        )
        self.query: _QueryCollection[Properties, References] = _QueryCollection[...](
            connection=connection, name=name, tenant=tenant, ...
        )
        self.tenants: _Tenants = _Tenants(connection=connection, name=name, ...)

    def with_tenant(self, tenant: Union[str, Tenant]) -> "Collection[Properties, References]":
        """Return a collection object specific to a single tenant.

        This method does not send a request to Weaviate. It only returns a new
        collection object that is specific to the tenant you specify.
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

# Get tenant-scoped collection
tenant1 = collection.with_tenant("tenant1")

# All operations now tenant-scoped
tenant1.data.insert(properties={"name": "some name"})
tenant1.query.fetch_objects()  # Only returns tenant1's objects
tenant1.data.delete_by_id(uuid)
```

**File:** `weaviate-python-client/weaviate/collections/collection/sync.py` (lines 158-177)

#### Elixir Port - Manual Tenant Parameter

The Elixir port requires passing `tenant:` option to each operation:

```elixir
# Tenant management is separate from operations
{:ok, _} = Tenants.create(client, "Article", ["tenant1", "tenant2"])

# Each operation needs explicit tenant parameter
{:ok, _} = WeaviateEx.Objects.create(
  %{class: "Article", properties: %{name: "some name"}},
  tenant: "tenant1"
)

# Query with tenant
query = WeaviateEx.Query.new("Article")
        |> WeaviateEx.Query.with_tenant("tenant1")
        |> WeaviateEx.Query.with_limit(10)
{:ok, results} = WeaviateEx.Query.execute(query, client)

# Batch with tenant
{:ok, _} = WeaviateEx.Batch.create_objects([
  %{class: "Article", tenant: "tenant1", properties: %{name: "obj1"}},
  %{class: "Article", tenant: "tenant1", properties: %{name: "obj2"}}
])
```

**Files:**
- `lib/weaviate_ex/query.ex` (line 568: `with_tenant/2`)
- `lib/weaviate_ex/objects.ex` (tenant option)
- `lib/weaviate_ex/batch.ex` (tenant in object)

#### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Fluent `.with_tenant()` | Returns scoped collection | Query builder only | **HIGH** |
| Collection-level tenant | Stored in collection | Per-operation | **HIGH** |
| Automatic scoping | All operations | Manual per call | **HIGH** |
| Type-safe tenant | `Tenant` object accepted | String only | **MEDIUM** |

**Recommendation:** Create a tenant-scoped client wrapper:

```elixir
defmodule WeaviateEx.TenantClient do
  defstruct [:client, :collection, :tenant]

  def new(client, collection, tenant) do
    %__MODULE__{client: client, collection: collection, tenant: tenant}
  end

  def insert(tc, properties, opts \\ []) do
    WeaviateEx.Objects.create(
      %{class: tc.collection, properties: properties},
      Keyword.merge(opts, tenant: tc.tenant, client: tc.client)
    )
  end

  def query(tc) do
    WeaviateEx.Query.new(tc.collection)
    |> WeaviateEx.Query.with_tenant(tc.tenant)
  end
end
```

---

### 5. Multi-Tenancy Configuration

#### Python Client

```python
# In weaviate/collections/classes/config.py
class _MultiTenancyConfigCreate(_ConfigCreateModel):
    enabled: bool = Field(default=False)
    autoTenantCreation: Optional[bool] = None
    autoTenantActivation: Optional[bool] = None

class _MultiTenancyConfigUpdate(_ConfigUpdateModel):
    autoTenantCreation: Optional[bool] = None
    autoTenantActivation: Optional[bool] = None

class _MultiTenancyConfig(_ConfigBase):
    enabled: bool
    auto_tenant_creation: bool
    auto_tenant_activation: bool

# Configure factory
class Configure:
    @staticmethod
    def multi_tenancy(
        enabled: bool = True,
        auto_tenant_creation: Optional[bool] = None,
        auto_tenant_activation: Optional[bool] = None,
    ) -> _MultiTenancyConfigCreate:
        """Create multi-tenancy configuration.

        Args:
            enabled: Enable multi-tenancy for this collection.
            auto_tenant_creation: Automatically create nonexistent tenants during object creation.
            auto_tenant_activation: Automatically turn tenants HOT when accessed.
        """
        return _MultiTenancyConfigCreate(
            enabled=enabled,
            autoTenantCreation=auto_tenant_creation,
            autoTenantActivation=auto_tenant_activation,
        )

# Reconfigure factory for updates
class Reconfigure:
    @staticmethod
    def multi_tenancy(
        auto_tenant_creation: Optional[bool] = None,
        auto_tenant_activation: Optional[bool] = None,
    ) -> _MultiTenancyConfigUpdate:
        """Update multi-tenancy configuration.

        Note: `enabled` cannot be changed after collection creation.
        """
        return _MultiTenancyConfigUpdate(
            autoTenantCreation=auto_tenant_creation,
            autoTenantActivation=auto_tenant_activation,
        )
```

**File:** `weaviate-python-client/weaviate/collections/classes/config.py` (lines 333-342, 2392-2405, 2679-2692)

#### Elixir Port

```elixir
# In lib/weaviate_ex/api/vector_config.ex
@doc "Add multi-tenancy configuration"
def with_multi_tenancy(config, opts \\ []) do
  mt_config = %{
    "enabled" => Keyword.get(opts, :enabled, false)
  }
  Map.put(config, "multiTenancyConfig", mt_config)
end
```

**File:** `lib/weaviate_ex/api/vector_config.ex` (lines 652-659)

#### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| `enabled` | Yes | Yes | None |
| `auto_tenant_creation` | Yes | Missing | **MEDIUM** |
| `auto_tenant_activation` | Yes | Missing | **MEDIUM** |
| Update config | Via Reconfigure | Not implemented | **MEDIUM** |
| Config read | Via `config.get()` | Missing parsing | **LOW** |

**Recommendation:** Extend `with_multi_tenancy/2`:

```elixir
def with_multi_tenancy(config, opts \\ []) do
  mt_config = %{
    "enabled" => Keyword.get(opts, :enabled, false)
  }
  |> maybe_put("autoTenantCreation", Keyword.get(opts, :auto_tenant_creation))
  |> maybe_put("autoTenantActivation", Keyword.get(opts, :auto_tenant_activation))

  Map.put(config, "multiTenancyConfig", mt_config)
end
```

---

### 6. Batch Tenant Update Operations

#### Python Client

The Python client implements batched tenant updates for large-scale operations:

```python
# In executor.py
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

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 243-261, 367-402)

**Integration test showing 1001 tenant batch:**

```python
def test_tenants_create_and_update_1001_tenants(collection_factory):
    collection = collection_factory(
        vectorizer_config=Configure.Vectorizer.none(),
        multi_tenancy_config=Configure.multi_tenancy(),
    )
    tenants = [TenantCreate(name=f"tenant{i}") for i in range(1001)]
    collection.tenants.create(tenants)

    # Update all 1001 tenants - automatically batched
    tenants = [Tenant(name=f"tenant{i}", activity_status=TenantActivityStatus.INACTIVE)
               for i in range(1001)]
    collection.tenants.update(tenants)
```

**File:** `weaviate-python-client/integration/test_tenants.py` (lines 461-483)

#### Elixir Port

```elixir
# In lib/weaviate_ex/api/tenants.ex
def update(client, collection_name, tenant_names, opts) when is_list(tenant_names) do
  activity_status = Keyword.get(opts, :activity_status, :hot) |> activity_to_string()
  tenants = Enum.map(tenant_names, fn name ->
    %{"name" => name, "activityStatus" => activity_status}
  end)
  # Single request with all tenants - no batching
  Client.request(client, :put, "/v1/schema/#{collection_name}/tenants", tenants, [])
end
```

**File:** `lib/weaviate_ex/api/tenants.ex` (lines 197-206)

#### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Batch size limit | 100 per request | None | **MEDIUM** |
| Parallel async batches | Yes | Not applicable | N/A |
| Sequential sync batches | Yes | No | **MEDIUM** |
| Large-scale updates | Tested with 1001 | Unknown | **MEDIUM** |

**Recommendation:** Add batching support:

```elixir
@batch_size 100

def update(client, collection_name, tenant_names, opts) when is_list(tenant_names) do
  activity_status = Keyword.get(opts, :activity_status, :hot) |> activity_to_string()

  tenant_names
  |> Enum.chunk_every(@batch_size)
  |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
    tenants = Enum.map(batch, &%{"name" => &1, "activityStatus" => activity_status})
    case Client.request(client, :put, "/v1/schema/#{collection_name}/tenants", tenants, []) do
      {:ok, result} -> {:cont, {:ok, acc ++ result}}
      {:error, _} = error -> {:halt, error}
    end
  end)
end
```

---

### 7. gRPC Tenant Operations

#### Python Client

```python
# In weaviate/collections/grpc/tenants.py
class _TenantsGRPC(_BaseGRPC):
    def __init__(self, weaviate_version: _ServerVersion, name: str):
        super().__init__(weaviate_version, None, False)
        self._name: str = name

    def get(self, names: Optional[Sequence[str]]) -> tenants_pb2.TenantsGetRequest:
        return tenants_pb2.TenantsGetRequest(
            collection=self._name,
            names=tenants_pb2.TenantNames(values=names) if names is not None else None,
        )

    def map_activity_status(self, status: tenants_pb2.TenantActivityStatus) -> TenantActivityStatus:
        """Map protobuf status to client enum with deprecated aliases."""
        if status == tenants_pb2.TENANT_ACTIVITY_STATUS_COLD or \
           status == tenants_pb2.TENANT_ACTIVITY_STATUS_INACTIVE:
            return TenantActivityStatus.INACTIVE
        if status == tenants_pb2.TENANT_ACTIVITY_STATUS_HOT or \
           status == tenants_pb2.TENANT_ACTIVITY_STATUS_ACTIVE:
            return TenantActivityStatus.ACTIVE
        if status == tenants_pb2.TENANT_ACTIVITY_STATUS_FROZEN or \
           status == tenants_pb2.TENANT_ACTIVITY_STATUS_OFFLOADED:
            return TenantActivityStatus.OFFLOADED
        if status == tenants_pb2.TENANT_ACTIVITY_STATUS_FREEZING or \
           status == tenants_pb2.TENANT_ACTIVITY_STATUS_OFFLOADING:
            return TenantActivityStatus.OFFLOADING
        if status == tenants_pb2.TENANT_ACTIVITY_STATUS_UNFREEZING or \
           status == tenants_pb2.TENANT_ACTIVITY_STATUS_ONLOADING:
            return TenantActivityStatus.ONLOADING
        raise ValueError(f"Unknown TenantActivityStatus: {status}")
```

**File:** `weaviate-python-client/weaviate/collections/grpc/tenants.py`

#### Elixir Port

```elixir
# In lib/weaviate_ex/grpc/services/tenants.ex
defmodule WeaviateEx.GRPC.Services.Tenants do
  alias Weaviate.V1.TenantsGetRequest
  alias Weaviate.V1.Weaviate.Stub, as: WeaviateStub

  @spec list(GRPC.Channel.t(), String.t(), tenant_opts()) :: {:ok, struct()} | {:error, Error.t()}
  def list(channel, collection, opts \\ []) do
    request = %TenantsGetRequest{collection: collection}
    execute_tenants_get(channel, request, opts)
  end

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

  @spec parse_status(atom() | integer()) :: atom()
  def parse_status(:TENANT_ACTIVITY_STATUS_HOT), do: :hot
  def parse_status(:TENANT_ACTIVITY_STATUS_COLD), do: :cold
  def parse_status(:TENANT_ACTIVITY_STATUS_WARM), do: :warm
  def parse_status(:TENANT_ACTIVITY_STATUS_FROZEN), do: :frozen
  def parse_status(:TENANT_ACTIVITY_STATUS_UNFREEZING), do: :unfreezing
  def parse_status(:TENANT_ACTIVITY_STATUS_FREEZING), do: :freezing
  def parse_status(:TENANT_ACTIVITY_STATUS_OFFLOADED), do: :offloaded
  def parse_status(:TENANT_ACTIVITY_STATUS_OFFLOADING), do: :offloading
  def parse_status(:TENANT_ACTIVITY_STATUS_ONLOADING), do: :onloading
  def parse_status(_), do: :unknown
end
```

**File:** `lib/weaviate_ex/grpc/services/tenants.ex`

#### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| gRPC list | Yes | Yes | None |
| gRPC get by names | Yes | Yes | None |
| Status mapping | Combined deprecated | Separate atoms | **LOW** |
| Version checking | `supports_tenants_get_grpc` | None | **LOW** |
| ACTIVE/INACTIVE mapping | Yes | Missing (ACTIVE -> :hot) | **LOW** |

---

### 8. Input Validation

#### Python Client

The Python client has comprehensive input validation:

```python
# In executor.py
def create(self, tenants: ...):
    if self._validate_arguments:
        _validate_input([
            _ValidateArgument(
                expected=[str, Tenant, TenantCreate, Sequence[Union[str, Tenant, TenantCreate]]],
                name="tenants",
                value=tenants,
            )
        ])

def __map_create_tenant(self, tenant: TenantCreateInputType) -> TenantCreate:
    if isinstance(tenant, str):
        return TenantCreate(name=tenant)
    if isinstance(tenant, Tenant):
        if tenant.activity_status not in [TenantActivityStatus.ACTIVE, TenantActivityStatus.INACTIVE]:
            raise WeaviateInvalidInputError(
                f"Tenant activity status must be either 'ACTIVE' or 'INACTIVE'. "
                f"Other statuses are read-only and cannot be set. "
                f"Tenant: {tenant.name} had status: {tenant.activity_status}"
            )
        activity_status = TenantCreateActivityStatus(tenant.activity_status)
        return TenantCreate(name=tenant.name, activity_status=activity_status)
    return tenant

def __map_update_tenant(self, tenant: TenantUpdateInputType) -> TenantUpdate:
    if isinstance(tenant, Tenant):
        if tenant.activity_status not in [
            TenantActivityStatus.ACTIVE,
            TenantActivityStatus.INACTIVE,
            TenantActivityStatus.OFFLOADED,
        ]:
            raise WeaviateInvalidInputError(
                f"Tenant activity status must be one of 'ACTIVE', 'INACTIVE' or 'OFFLOADED'. "
                f"Other statuses are read-only and cannot be set. "
                f"Tenant: {tenant.name} had status: {tenant.activity_status}"
            )
```

**File:** `weaviate-python-client/weaviate/collections/tenants/executor.py` (lines 201-228)

#### Elixir Port

No input validation beyond basic type guards:

```elixir
def create(client, collection_name, tenant_name, opts) when is_binary(tenant_name) do
  create(client, collection_name, [tenant_name], opts)
end

def create(client, collection_name, tenant_names, opts) when is_list(tenant_names) do
  # No validation of status - any atom accepted
  activity_status = Keyword.get(opts, :activity_status, :hot) |> activity_to_string()
  ...
end
```

#### Gap Analysis

| Validation | Python | Elixir | Gap |
|------------|--------|--------|-----|
| Type validation | Comprehensive | Basic guards | **MEDIUM** |
| Create status restriction | ACTIVE/INACTIVE only | Any status | **MEDIUM** |
| Update status restriction | No OFFLOADING/ONLOADING | Any status | **MEDIUM** |
| Error messages | Descriptive | Server-side only | **LOW** |

---

## Summary Table

| Category | Feature | Python | Elixir | Priority |
|----------|---------|--------|--------|----------|
| **Types** | Tenant struct | Pydantic | Map | Medium |
| **Types** | TenantCreate/Update types | Yes | No | Medium |
| **Types** | Activity status enums | 3 enums | Atoms | Low |
| **CRUD** | create() | Full | Basic | Low |
| **CRUD** | get_by_names() | Yes | Missing | Medium |
| **CRUD** | get_by_name() with RBAC | Yes | No | Medium |
| **CRUD** | exists() via HEAD | Yes | GET-based | Low |
| **Status** | activate/deactivate/offload | Yes | Yes | None |
| **Status** | Deprecation warnings | Yes | No | Low |
| **Status** | New naming (ACTIVE/INACTIVE) | Yes | Uses deprecated | Medium |
| **Config** | auto_tenant_creation | Yes | Missing | Medium |
| **Config** | auto_tenant_activation | Yes | Missing | Medium |
| **Scoping** | with_tenant() fluent | Collection-level | Query only | **High** |
| **Batch** | 100-item batching | Yes | No | Medium |
| **Batch** | Async parallel updates | Yes | N/A | N/A |
| **Validation** | Status restrictions | Yes | No | Medium |
| **gRPC** | Version checking | Yes | No | Low |

---

## Recommendations

### High Priority

1. **Implement TenantClient wrapper** for fluent tenant-scoped operations:
   ```elixir
   collection.with_tenant("tenant1") |> insert(properties)
   ```

2. **Add tenant-scoped collection module** that encapsulates tenant context for all operations.

### Medium Priority

3. **Create Tenant struct** with proper typespecs:
   ```elixir
   defmodule WeaviateEx.Tenant do
     @type t :: %__MODULE__{name: String.t(), activity_status: activity_status()}
   end
   ```

4. **Add `get_by_names/3`** function for batch tenant retrieval.

5. **Implement batched updates** (100 items per request) for large-scale tenant management.

6. **Add `auto_tenant_creation` and `auto_tenant_activation`** to multi-tenancy config.

7. **Update status naming** to use `:active`/`:inactive`/`:offloaded` with deprecation for `:hot`/`:cold`/`:frozen`.

8. **Add input validation** for activity status restrictions:
   - Create: only `:active`/`:inactive`
   - Update: only `:active`/`:inactive`/`:offloaded`

### Low Priority

9. **Add deprecation warnings** when using legacy status names.

10. **Implement HEAD-based `exists?/3`** for efficiency.

11. **Add gRPC version checking** for feature availability.

---

## File References

### Python Client Files
- `weaviate-python-client/weaviate/collections/classes/tenants.py` - Tenant classes and enums
- `weaviate-python-client/weaviate/collections/tenants/executor.py` - Core tenant operations
- `weaviate-python-client/weaviate/collections/tenants/sync.py` - Sync wrapper
- `weaviate-python-client/weaviate/collections/tenants/async_.py` - Async wrapper
- `weaviate-python-client/weaviate/collections/grpc/tenants.py` - gRPC tenant operations
- `weaviate-python-client/weaviate/collections/collection/sync.py` - with_tenant() method
- `weaviate-python-client/weaviate/collections/classes/config.py` - Multi-tenancy config
- `weaviate-python-client/integration/test_tenants.py` - Integration tests

### Elixir Port Files
- `lib/weaviate_ex/api/tenants.ex` - Main tenant API module
- `lib/weaviate_ex/grpc/services/tenants.ex` - gRPC tenant service
- `lib/weaviate_ex/api/vector_config.ex` - Multi-tenancy config builder
- `lib/weaviate_ex/collections.ex` - Collection management (add/remove tenants)
- `lib/weaviate_ex/query.ex` - Query with_tenant support
- `lib/weaviate_ex/batch.ex` - Batch operations with tenant
- `lib/weaviate_ex/grpc/generated/v1/tenants.pb.ex` - Generated protobuf
- `priv/protos/v1/tenants.proto` - Proto definitions
- `test/weaviate_ex/api/tenants_test.exs` - Unit tests
- `test/weaviate_ex/grpc/services/tenants_test.exs` - gRPC tests
- `examples/06_tenants.exs` - Usage example

---

## Conclusion

The Elixir port provides solid multi-tenancy functionality for basic use cases. The core CRUD operations work well, and gRPC support for tenant listing is implemented. However, the lack of a fluent tenant-scoped collection API and the absence of advanced configuration options (auto-tenant creation/activation) represent significant gaps for large-scale multi-tenant applications.

The highest-impact improvement would be implementing a `TenantClient` or tenant-scoped collection wrapper that mirrors Python's `.with_tenant()` pattern, eliminating the need to pass tenant parameters to every operation.
