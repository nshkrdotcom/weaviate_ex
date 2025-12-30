# WeaviateEx Gap Implementation Prompt

**Date:** 2025-12-29
**Version Target:** 0.8.0
**Goal:** Fill all gaps identified in the gap analysis to achieve 100% Python client feature parity

---

## Executive Summary

This document provides detailed instructions for implementing all identified gaps in WeaviateEx to achieve full feature parity with the Python Weaviate client v4.x. Implementation should follow TDD methodology, updating all documentation, and ensuring zero warnings/errors/dialyzer/credo issues.

---

## Required Reading

### Gap Analysis Documents (Must Read First)
1. `docs/20251229/gap-analysis/00-executive-summary.md` - Overall assessment and priorities
2. `docs/20251229/gap-analysis/01-collections-schema-api.md` - Collections/schema gaps
3. `docs/20251229/gap-analysis/02-query-search-api.md` - Query/search gaps
4. `docs/20251229/gap-analysis/03-batch-operations.md` - Batch operation gaps
5. `docs/20251229/gap-analysis/04-auth-connection.md` - Auth/connection gaps
6. `docs/20251229/gap-analysis/05-rbac-users-groups.md` - RBAC gaps (**most critical**)
7. `docs/20251229/gap-analysis/06-backup-cluster.md` - Complete (100% parity)
8. `docs/20251229/gap-analysis/07-vectorizers-generative.md` - Vectorizer/generative gaps

### Source Files to Study

#### Collections/Schema (01)
- Python: `weaviate-python-client/weaviate/classes/config.py` - Configure classes
- Python: `weaviate-python-client/weaviate/collections/collections.py` - Collection operations
- Python: `weaviate-python-client/weaviate/collections/tenants.py` - Tenant operations
- Elixir: `lib/weaviate_ex/api/collections.ex` - Collections API
- Elixir: `lib/weaviate_ex/api/tenants.ex` - Tenants API
- Elixir: `lib/weaviate_ex/schema/multi_tenancy_config.ex` - Multi-tenancy config

#### Query/Search (02)
- Python: `weaviate-python-client/weaviate/collections/queries/` - All query executors
- Python: `weaviate-python-client/weaviate/classes/query.py` - Query types
- Elixir: `lib/weaviate_ex/query.ex` - Query builder
- Elixir: `lib/weaviate_ex/query/near_vector.ex` - Near vector search
- Elixir: `lib/weaviate_ex/api/aggregate.ex` - Aggregations

#### Batch Operations (03)
- Python: `weaviate-python-client/weaviate/collections/batch/base.py` - Core batch
- Python: `weaviate-python-client/weaviate/collections/batch/batch_wrapper.py` - Batch wrapper
- Elixir: `lib/weaviate_ex/api/batch.ex` - Batch API
- Elixir: `lib/weaviate_ex/batch/stream.ex` - Batch streaming
- Elixir: `lib/weaviate_ex/batch/dynamic.ex` - Dynamic batching

#### Auth/Connection (04)
- Python: `weaviate-python-client/weaviate/connect/authentication.py` - OIDC flows
- Python: `weaviate-python-client/weaviate/connect/v4.py` - Connection management
- Elixir: `lib/weaviate_ex/auth/token_manager.ex` - Token management
- Elixir: `lib/weaviate_ex/auth/oidc.ex` - OIDC support
- Elixir: `lib/weaviate_ex/client.ex` - Client connection

#### RBAC (05) - Critical
- Python: `weaviate-python-client/weaviate/rbac/` - All RBAC modules
- Python: `weaviate-python-client/weaviate/users/` - User management
- Python: `weaviate-python-client/weaviate/groups/` - Group management
- Elixir: `lib/weaviate_ex/api/rbac.ex` - RBAC API
- Elixir: `lib/weaviate_ex/api/users.ex` - Users API
- Elixir: `lib/weaviate_ex/api/groups.ex` - Groups API

#### Vectorizers/Generative (07)
- Python: `weaviate-python-client/weaviate/classes/generate.py` - Generative configs
- Elixir: `lib/weaviate_ex/api/vector_config.ex` - Vector configuration
- Elixir: `lib/weaviate_ex/generative/config.ex` - Generative AI config

---

## Implementation Tasks by Priority

### P0 - Critical (Must Implement)

#### 1. Batch: Wait for Vector Indexing
**Location:** `lib/weaviate_ex/api/batch.ex`, `lib/weaviate_ex/batch/vector_indexing.ex` (new)

**Python Reference:**
```python
def wait_for_vector_indexing(
    self, shards: Optional[List[Shard]] = None, how_many_failures: int = 5
) -> None:
    """Wait for all vectors of batch imported objects to be indexed."""
    while not self.__is_ready(how_many_failures, shards):
        time.sleep(0.25)
```

**Implementation:**
```elixir
# lib/weaviate_ex/batch/vector_indexing.ex
defmodule WeaviateEx.Batch.VectorIndexing do
  @moduledoc "Wait for vector indexing completion."

  @type shard :: %{collection: String.t(), tenant: String.t() | nil}

  @spec wait_for_indexing(Client.t(), [shard()], keyword()) :: :ok | {:error, term()}
  def wait_for_indexing(client, shards, opts \\ [])

  @spec shard_ready?(Client.t(), shard()) :: boolean()
  def shard_ready?(client, shard)

  @spec get_shard_status(Client.t(), shard()) :: {:ok, map()} | {:error, term()}
  def get_shard_status(client, shard)
end

# lib/weaviate_ex/api/batch.ex - add function
@spec wait_for_vector_indexing(Client.t(), [shard()], keyword()) :: :ok | {:error, term()}
def wait_for_vector_indexing(client, shards \\ [], opts \\ []) do
  max_failures = Keyword.get(opts, :how_many_failures, 5)
  poll_interval = Keyword.get(opts, :poll_interval, 250)
  timeout = Keyword.get(opts, :timeout, 60_000)
  VectorIndexing.wait_for_indexing(client, shards,
    max_failures: max_failures,
    poll_interval: poll_interval,
    timeout: timeout
  )
end
```

**Tests to Add:**
- `test/weaviate_ex/batch/vector_indexing_test.exs`

---

#### 2. Batch: Object Caching for Stream Recovery
**Location:** `lib/weaviate_ex/batch/stream.ex`

**Python Reference:**
```python
with self.__objs_cache_lock:
    self.__objs_cache[uuid] = batch_object
```

**Implementation:**
```elixir
# Update lib/weaviate_ex/batch/stream.ex
defmodule WeaviateEx.Batch.Stream do
  # Add to struct:
  defstruct [
    # ... existing fields ...
    :objects_cache,      # NEW: %{uuid => object} for recovery
    :references_cache,   # NEW: %{uuid => reference} for recovery
    :cache_lock          # NEW: Agent or mutex for thread-safe cache
  ]

  def new(client, collection, opts \\ []) do
    %__MODULE__{
      # ... existing ...
      objects_cache: %{},
      references_cache: %{}
    }
  end

  # Add caching before send
  defp cache_objects(stream, objects) do
    cached = Enum.reduce(objects, stream.objects_cache, fn obj, acc ->
      Map.put(acc, obj.uuid, obj)
    end)
    %{stream | objects_cache: cached}
  end

  # Clear cache on success
  defp clear_cache(stream, uuids) do
    new_cache = Map.drop(stream.objects_cache, uuids)
    %{stream | objects_cache: new_cache}
  end

  # On reconnect, requeue cached objects
  defp requeue_cached_objects(stream) do
    cached_objects = Map.values(stream.objects_cache)
    %{stream | buffer: cached_objects ++ stream.buffer, objects_cache: %{}}
  end
end
```

---

#### 3. Collections: Auto-Tenant Configuration
**Location:** `lib/weaviate_ex/schema/multi_tenancy_config.ex`

**Python Reference:**
```python
Configure.multi_tenancy(
    enabled=True,
    auto_tenant_creation=True,
    auto_tenant_activation=True
)
```

**Implementation:**
```elixir
# lib/weaviate_ex/schema/multi_tenancy_config.ex
defmodule WeaviateEx.Schema.MultiTenancyConfig do
  @moduledoc "Multi-tenancy configuration with auto-tenant options."

  defstruct enabled: false,
            auto_tenant_creation: false,
            auto_tenant_activation: false

  @type t :: %__MODULE__{
    enabled: boolean(),
    auto_tenant_creation: boolean(),
    auto_tenant_activation: boolean()
  }

  @spec fully_automatic() :: t()
  def fully_automatic do
    %__MODULE__{
      enabled: true,
      auto_tenant_creation: true,
      auto_tenant_activation: true
    }
  end

  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    %{
      "enabled" => config.enabled,
      "autoTenantCreation" => config.auto_tenant_creation,
      "autoTenantActivation" => config.auto_tenant_activation
    }
  end
end
```

---

#### 4. RBAC: get_user_assignments with Type Information
**Location:** `lib/weaviate_ex/api/rbac.ex`, `lib/weaviate_ex/rbac/user_assignment.ex` (new)

**Python Reference:**
```python
# Returns List[UserAssignment] with user_id and user_type
assignments = client.roles.get_user_assignments("editor")
for assignment in assignments:
    print(f"User: {assignment.user_id}, Type: {assignment.user_type}")
```

**Implementation:**
```elixir
# lib/weaviate_ex/rbac/user_assignment.ex
defmodule WeaviateEx.RBAC.UserAssignment do
  @moduledoc "User assignment with type information."

  @type user_type :: :db_user | :db_env_user | :oidc

  defstruct [:user_id, :user_type]

  @type t :: %__MODULE__{
    user_id: String.t(),
    user_type: user_type()
  }

  @spec from_api(map()) :: t()
  def from_api(%{"userId" => id, "userType" => type}) do
    %__MODULE__{
      user_id: id,
      user_type: parse_user_type(type)
    }
  end

  defp parse_user_type("db_user"), do: :db_user
  defp parse_user_type("db_env_user"), do: :db_env_user
  defp parse_user_type("oidc"), do: :oidc
end

# lib/weaviate_ex/api/rbac.ex - add function
@spec get_user_assignments(Client.t(), String.t(), keyword()) ::
      {:ok, [UserAssignment.t()]} | {:error, Error.t()}
def get_user_assignments(client, role_name, opts \\ []) do
  path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}/user-assignments"
  case Client.request(client, :get, path, nil, opts) do
    {:ok, response} ->
      assignments = Enum.map(response, &UserAssignment.from_api/1)
      {:ok, assignments}
    {:error, _} = error -> error
  end
end
```

---

#### 5. RBAC: get_group_assignments with Type Information
**Location:** `lib/weaviate_ex/api/rbac.ex`, `lib/weaviate_ex/rbac/group_assignment.ex` (new)

**Implementation:**
```elixir
# lib/weaviate_ex/rbac/group_assignment.ex
defmodule WeaviateEx.RBAC.GroupAssignment do
  @moduledoc "Group assignment with type information."

  @type group_type :: :oidc

  defstruct [:group_id, :group_type]

  @type t :: %__MODULE__{
    group_id: String.t(),
    group_type: group_type()
  }

  @spec from_api(map()) :: t()
  def from_api(%{"groupId" => id, "groupType" => type}) do
    %__MODULE__{
      group_id: id,
      group_type: parse_group_type(type)
    }
  end

  defp parse_group_type("oidc"), do: :oidc
end

# lib/weaviate_ex/api/rbac.ex - add function
@spec get_group_assignments(Client.t(), String.t(), keyword()) ::
      {:ok, [GroupAssignment.t()]} | {:error, Error.t()}
def get_group_assignments(client, role_name, opts \\ []) do
  path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}/group-assignments"
  case Client.request(client, :get, path, nil, opts) do
    {:ok, response} ->
      assignments = Enum.map(response, &GroupAssignment.from_api/1)
      {:ok, assignments}
    {:error, _} = error -> error
  end
end
```

---

### P1 - High Priority

#### 6. Collections: Reconfigure Module
**Location:** `lib/weaviate_ex/reconfigure.ex` (new)

**Implementation:**
```elixir
# lib/weaviate_ex/reconfigure.ex
defmodule WeaviateEx.Reconfigure do
  @moduledoc """
  Type-safe configuration update builders for collections.

  ## Example

      updates = Reconfigure.inverted_index(bm25: [b: 0.8])
      |> Reconfigure.replication(factor: 5)

      Collections.update(client, "Article", updates)
  """

  @spec inverted_index(keyword()) :: map()
  def inverted_index(opts \\ [])

  @spec replication(keyword()) :: map()
  def replication(opts \\ [])

  @spec vector_index_hnsw(keyword()) :: map()
  def vector_index_hnsw(opts \\ [])

  @spec named_vectors_update(String.t(), keyword()) :: map()
  def named_vectors_update(name, opts \\ [])
end
```

---

#### 7. Query: Multi-Vector Query Patterns
**Location:** `lib/weaviate_ex/query/near_vector.ex`

**Python Reference:**
```python
# List of vectors query
collection.query.near_vector(
    near_vector=NearVector.list_of_vectors(vec1, vec2, vec3)
)

# Per-target different vectors
collection.query.near_vector(
    near_vector={
        "title_vector": [0.1, 0.2, ...],
        "content_vector": [0.3, 0.4, ...]
    }
)
```

**Implementation:**
```elixir
# lib/weaviate_ex/query/near_vector.ex - add functions
defmodule WeaviateEx.Query.NearVector do
  # Add list_of_vectors support
  @spec list_of_vectors([list(float())]) :: %{vectors: [list(float())]}
  def list_of_vectors(vectors) when is_list(vectors) do
    %{vectors: vectors}
  end

  # Add per-target vectors support
  @spec per_target(map()) :: %{targets: map()}
  def per_target(vector_map) when is_map(vector_map) do
    %{targets: vector_map}
  end
end
```

---

#### 8. RBAC: include_permissions Parameter
**Location:** `lib/weaviate_ex/api/users/db.ex`, `lib/weaviate_ex/api/groups.ex`

**Implementation:**
```elixir
# Update get_roles functions to support include_permissions
@spec get_roles(Client.t(), String.t(), keyword()) ::
      {:ok, map()} | {:error, Error.t()}
def get_roles(client, user_id, opts \\ []) do
  include_permissions = Keyword.get(opts, :include_permissions, false)
  path = "/v1/authz/users/#{URI.encode_www_form(user_id)}/roles"
  query = if include_permissions, do: "?include_permissions=true", else: ""

  case Client.request(client, :get, path <> query, nil, opts) do
    {:ok, response} ->
      if include_permissions do
        roles = Enum.into(response, %{}, fn {name, data} ->
          {name, Role.from_api(data)}
        end)
        {:ok, roles}
      else
        {:ok, Map.keys(response)}
      end
    {:error, _} = error -> error
  end
end
```

---

#### 9. Auth: Integrated OIDC Discovery
**Location:** `lib/weaviate_ex/client.ex`, `lib/weaviate_ex/auth/oidc.ex`

**Implementation:**
```elixir
# lib/weaviate_ex/client.ex - update connect/1
def connect(opts \\ []) do
  # ... existing code ...

  # Auto-discover OIDC if auth requires it
  auth = Keyword.get(opts, :auth)

  client = if requires_oidc_discovery?(auth) do
    with {:ok, oidc_config} <- discover_oidc_from_server(base_url),
         {:ok, token_manager} <- start_token_manager(oidc_config, auth) do
      %{client | token_manager: token_manager}
    else
      {:error, reason} ->
        Logger.warning("OIDC discovery failed: #{inspect(reason)}")
        client
    end
  else
    client
  end

  {:ok, client}
end

defp requires_oidc_discovery?(%{type: :oidc_client_credentials}), do: true
defp requires_oidc_discovery?(%{type: :oidc_password}), do: true
defp requires_oidc_discovery?(_), do: false

defp discover_oidc_from_server(base_url) do
  path = "/.well-known/openid-configuration"
  # Fetch OIDC config from Weaviate
end
```

---

#### 10. Tenants: Convenience Methods
**Location:** `lib/weaviate_ex/api/tenants.ex`

**Implementation:**
```elixir
# lib/weaviate_ex/api/tenants.ex - add functions

@spec activate(Client.t(), String.t(), String.t() | [String.t()], keyword()) ::
      :ok | {:error, Error.t()}
def activate(client, collection, tenant_or_tenants, opts \\ []) do
  tenants = List.wrap(tenant_or_tenants)
  updates = Enum.map(tenants, &%Tenant{name: &1, activity_status: :hot})
  update(client, collection, updates, opts)
end

@spec deactivate(Client.t(), String.t(), String.t() | [String.t()], keyword()) ::
      :ok | {:error, Error.t()}
def deactivate(client, collection, tenant_or_tenants, opts \\ []) do
  tenants = List.wrap(tenant_or_tenants)
  updates = Enum.map(tenants, &%Tenant{name: &1, activity_status: :cold})
  update(client, collection, updates, opts)
end

@spec offload(Client.t(), String.t(), String.t() | [String.t()], keyword()) ::
      :ok | {:error, Error.t()}
def offload(client, collection, tenant_or_tenants, opts \\ []) do
  tenants = List.wrap(tenant_or_tenants)
  updates = Enum.map(tenants, &%Tenant{name: &1, activity_status: :offloaded})
  update(client, collection, updates, opts)
end

@spec exists?(Client.t(), String.t(), String.t(), keyword()) ::
      {:ok, boolean()} | {:error, Error.t()}
def exists?(client, collection, tenant_name, opts \\ []) do
  case get_by_name(client, collection, tenant_name, opts) do
    {:ok, _tenant} -> {:ok, true}
    {:error, %{type: :not_found}} -> {:ok, false}
    {:error, _} = error -> error
  end
end

@spec get_by_name(Client.t(), String.t(), String.t(), keyword()) ::
      {:ok, Tenant.t()} | {:error, Error.t()}
def get_by_name(client, collection, tenant_name, opts \\ []) do
  # GET /v1/schema/{collection}/tenants/{tenant_name}
  path = "/v1/schema/#{collection}/tenants/#{URI.encode_www_form(tenant_name)}"
  case Client.request(client, :get, path, nil, opts) do
    {:ok, data} -> {:ok, Tenant.from_map(data)}
    {:error, _} = error -> error
  end
end
```

---

#### 11. Aggregation: near_image Support
**Location:** `lib/weaviate_ex/api/aggregate.ex`

**Implementation:**
```elixir
# lib/weaviate_ex/api/aggregate.ex - add function

@spec with_near_image(Client.t(), String.t(), String.t() | binary(), keyword()) ::
      {:ok, map()} | {:error, Error.t()}
def with_near_image(client, collection, image_data, opts \\ []) do
  # Build nearImage aggregate query
  certainty = Keyword.get(opts, :certainty)
  distance = Keyword.get(opts, :distance)
  target_vectors = Keyword.get(opts, :target_vectors)

  near_image = %{
    "image" => image_data
  }
  |> maybe_add(:certainty, certainty)
  |> maybe_add(:distance, distance)
  |> maybe_add(:targetVectors, target_vectors)

  do_aggregate(client, collection, near_image: near_image, opts: opts)
end
```

---

### P2 - Medium Priority

#### 12. Batch: Vectorizer Batching Detection
**Location:** `lib/weaviate_ex/batch/vectorizer_detection.ex` (new)

**Implementation:**
```elixir
defmodule WeaviateEx.Batch.VectorizerDetection do
  @moduledoc "Detect vectorizer-based batching and adjust step sizes."

  @vectorizer_batching_step_size 48  # Cohere max batch size is 96

  @spec detect_vectorizer_batching(Client.t(), String.t()) ::
        {:ok, boolean()} | {:error, term()}
  def detect_vectorizer_batching(client, collection) do
    case Collections.get(client, collection) do
      {:ok, schema} ->
        vectorizer = get_in(schema, ["vectorizer"])
        {:ok, requires_batching?(vectorizer)}
      error -> error
    end
  end

  defp requires_batching?("text2vec-cohere"), do: true
  defp requires_batching?("text2vec-openai"), do: true
  defp requires_batching?("text2vec-" <> _), do: true
  defp requires_batching?(_), do: false
end
```

---

#### 13. Users.DB: Deactivate with revoke_key Option
**Location:** `lib/weaviate_ex/api/users/db.ex`

**Implementation:**
```elixir
# Update deactivate function
@spec deactivate(Client.t(), String.t(), keyword()) :: :ok | {:error, Error.t()}
def deactivate(client, user_id, opts \\ []) do
  revoke_key = Keyword.get(opts, :revoke_key, false)
  path = "/v1/users/db/#{URI.encode_www_form(user_id)}/deactivate"
  body = if revoke_key, do: %{"revokeKey" => true}, else: nil

  case Client.request(client, :put, path, body, opts) do
    {:ok, _} -> :ok
    {:error, _} = error -> error
  end
end
```

---

#### 14. Nodes Permissions: Collection Filter
**Location:** `lib/weaviate_ex/rbac/permissions.ex`

**Implementation:**
```elixir
# Update nodes function to support collection
@spec nodes(:verbose | :minimal, keyword()) :: map()
def nodes(verbosity, opts \\ []) do
  collection = Keyword.get(opts, :collection)

  base = %{
    "action" => if(verbosity == :verbose, do: "read_nodes", else: "read_nodes_minimal"),
    "nodes" => %{"verbosity" => to_string(verbosity)}
  }

  if collection do
    put_in(base, ["nodes", "collection"], collection)
  else
    base
  end
end
```

---

#### 15. Multi-Vector Index: Muvera Encoding
**Location:** `lib/weaviate_ex/api/multi_vector.ex`

**Implementation:**
```elixir
# lib/weaviate_ex/api/multi_vector.ex - add encoding support
defmodule WeaviateEx.API.MultiVector.Encoding do
  @moduledoc "Multi-vector encoding configurations."

  defstruct [:type, :ksim, :dprojections, :repetitions]

  @type t :: %__MODULE__{
    type: :muvera | :none,
    ksim: non_neg_integer() | nil,
    dprojections: non_neg_integer() | nil,
    repetitions: non_neg_integer() | nil
  }

  @spec muvera(keyword()) :: t()
  def muvera(opts \\ []) do
    %__MODULE__{
      type: :muvera,
      ksim: Keyword.get(opts, :ksim, 10),
      dprojections: Keyword.get(opts, :dprojections, 256),
      repetitions: Keyword.get(opts, :repetitions, 4)
    }
  end

  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{type: :muvera} = config) do
    %{
      "type" => "muvera",
      "ksim" => config.ksim,
      "dProjections" => config.dprojections,
      "repetitions" => config.repetitions
    }
  end
end
```

---

#### 16. Tenant Activity Statuses
**Location:** `lib/weaviate_ex/types/tenant.ex`

**Implementation:**
```elixir
# Add missing statuses
@type activity_status ::
  :active | :inactive | :hot | :cold |
  :frozen | :offloaded | :offloading | :onloading

defp parse_status("OFFLOADED"), do: :offloaded
defp parse_status("OFFLOADING"), do: :offloading
defp parse_status("ONLOADING"), do: :onloading
```

---

#### 17. Auth: trust_env Option
**Location:** `lib/weaviate_ex/config/proxy.ex`, `lib/weaviate_ex/client/config.ex`

**Implementation:**
```elixir
# lib/weaviate_ex/client/config.ex
defstruct [
  # ... existing fields ...
  :trust_env  # NEW: whether to read proxy from env vars (default: true)
]

# lib/weaviate_ex/config/proxy.ex
def from_env(trust_env \\ true) do
  if trust_env do
    %__MODULE__{
      http: get_env_case_insensitive("HTTP_PROXY"),
      https: get_env_case_insensitive("HTTPS_PROXY"),
      grpc: get_env_case_insensitive("GRPC_PROXY")
    }
  else
    %__MODULE__{}
  end
end
```

---

### P3 - Low Priority

#### 18. Object TTL Configuration
**Location:** `lib/weaviate_ex/config/object_ttl.ex`

#### 19. Generative Provider Runtime Config
**Location:** `lib/weaviate_ex/query/generate.ex`

#### 20. Prompt Debug Mode
**Location:** `lib/weaviate_ex/generative/parameters.ex`

---

## TDD Implementation Process

For each feature:

### 1. Write Tests First
```elixir
# test/weaviate_ex/<module>_test.exs
defmodule WeaviateEx.<Module>Test do
  use WeaviateEx.TestCase, async: true

  describe "<function_name>/N" do
    test "returns expected result for valid input" do
      # Setup mocks
      expect(WeaviateEx.MockHTTP, :request, fn _, _, _, _, _ ->
        {:ok, %{"data" => "expected"}}
      end)

      # Call function
      result = Module.function(args)

      # Assert
      assert {:ok, data} = result
      assert data.field == "expected"
    end

    test "returns error for invalid input" do
      # ...
    end
  end
end
```

### 2. Implement the Feature
- Follow the implementation specs above
- Add proper @doc and @spec annotations
- Handle all error cases

### 3. Run Tests
```bash
mix test test/weaviate_ex/<module>_test.exs
```

### 4. Run Full Suite
```bash
mix test
mix dialyzer
mix credo --strict
```

---

## Documentation Updates

### README.md Updates

Add sections for new features:

```markdown
### Wait for Vector Indexing

After batch operations, wait for vectors to be indexed:

\```elixir
# Wait for all shards
:ok = WeaviateEx.Batch.wait_for_vector_indexing(client)

# Wait for specific shards with timeout
:ok = WeaviateEx.Batch.wait_for_vector_indexing(client,
  [%{collection: "Article", tenant: nil}],
  timeout: 120_000,
  poll_interval: 500
)
\```

### RBAC User/Group Assignments

Get detailed assignment information:

\```elixir
# Get users with their types
{:ok, assignments} = WeaviateEx.RBAC.get_user_assignments(client, "editor")
for a <- assignments do
  IO.puts("#{a.user_id} (#{a.user_type})")
end

# Get groups with their types
{:ok, groups} = WeaviateEx.RBAC.get_group_assignments(client, "viewer")
\```

### Tenant Convenience Methods

\```elixir
# Activate/deactivate/offload tenants
:ok = WeaviateEx.Tenants.activate(client, "Article", "tenant-1")
:ok = WeaviateEx.Tenants.deactivate(client, "Article", ["t1", "t2"])
:ok = WeaviateEx.Tenants.offload(client, "Article", "cold-tenant")

# Check if tenant exists
{:ok, true} = WeaviateEx.Tenants.exists?(client, "Article", "tenant-1")

# Get tenant by name
{:ok, tenant} = WeaviateEx.Tenants.get_by_name(client, "Article", "tenant-1")
\```
```

### Guide Updates

Update these guides:
- `guides/collections.md` - Add auto-tenant configuration
- `guides/multi_tenancy.md` - Add convenience methods
- `guides/batch_operations.md` - Add wait_for_vector_indexing
- `guides/rbac.md` - Add assignment methods

---

## CHANGELOG Entry

Update `CHANGELOG.md` with version 0.8.0:

```markdown
## [0.8.0] - 2025-12-30

### Added

#### Batch Operations
- **Wait for Vector Indexing** (`WeaviateEx.Batch.VectorIndexing`):
  - `wait_for_indexing/3` - Wait for all vectors to be indexed after batch operations
  - `shard_ready?/2` - Check if a specific shard is ready
  - `get_shard_status/2` - Get detailed shard indexing status
  - Options: `:timeout`, `:poll_interval`, `:how_many_failures`

- **Object Caching for Stream Recovery** (`WeaviateEx.Batch.Stream`):
  - Automatic caching of in-flight objects for stream recovery
  - On reconnection, cached objects are automatically requeued
  - `objects_cache` and `references_cache` fields added to stream struct

#### Multi-Tenancy
- **Auto-Tenant Configuration** (`WeaviateEx.Schema.MultiTenancyConfig`):
  - `auto_tenant_creation` - Automatically create tenants on first insert
  - `auto_tenant_activation` - Automatically activate tenants when accessed
  - `fully_automatic/0` - Convenience constructor for both options

- **Tenant Convenience Methods** (`WeaviateEx.API.Tenants`):
  - `activate/4` - Set tenant(s) to HOT status
  - `deactivate/4` - Set tenant(s) to COLD status
  - `offload/4` - Set tenant(s) to OFFLOADED status
  - `exists?/4` - Check if tenant exists
  - `get_by_name/4` - Get specific tenant by name

- **Additional Tenant Statuses**:
  - `:offloaded`, `:offloading`, `:onloading` activity statuses

#### RBAC Enhancements
- **User Assignments with Type** (`WeaviateEx.API.RBAC`):
  - `get_user_assignments/3` - Get users assigned to role with type info
  - `UserAssignment` struct with `user_id` and `user_type` fields
  - Supports `:db_user`, `:db_env_user`, `:oidc` user types

- **Group Assignments with Type** (`WeaviateEx.API.RBAC`):
  - `get_group_assignments/3` - Get groups assigned to role with type info
  - `GroupAssignment` struct with `group_id` and `group_type` fields

- **Include Permissions Parameter**:
  - `Users.DB.get_roles/3` now supports `:include_permissions` option
  - `Users.OIDC.get_roles/3` now supports `:include_permissions` option
  - `Groups.get_assigned_roles/3` now supports `:include_permissions` option

- **Deactivate with Key Revocation**:
  - `Users.DB.deactivate/3` now supports `:revoke_key` option

- **Nodes Permission Collection Filter**:
  - `Permissions.nodes/2` now supports `:collection` option for verbose mode

#### Collections/Schema
- **Reconfigure Module** (`WeaviateEx.Reconfigure`):
  - `inverted_index/1` - Build inverted index update config
  - `replication/1` - Build replication update config
  - `vector_index_hnsw/1` - Build HNSW index update config
  - `named_vectors_update/2` - Build named vector update config

#### Query Enhancements
- **Multi-Vector Queries** (`WeaviateEx.Query.NearVector`):
  - `list_of_vectors/1` - Query with multiple vectors over single space
  - `per_target/1` - Query with different vectors per target

#### Aggregation
- **Near Image Aggregation** (`WeaviateEx.API.Aggregate`):
  - `with_near_image/4` - Aggregate with near_image similarity constraint

#### Authentication
- **Integrated OIDC Discovery**:
  - `Client.connect/1` automatically discovers OIDC config for client credentials flows
  - No manual OIDC setup required for standard deployments

- **Trust Environment Option**:
  - `:trust_env` option for controlling proxy environment variable reading

#### Vectorizers
- **Multi-Vector Encoding** (`WeaviateEx.API.MultiVector.Encoding`):
  - `muvera/1` - Configure Muvera encoding for ColBERT-style multi-vectors
  - Options: `:ksim`, `:dprojections`, `:repetitions`

### Stats
- XXXX tests passing (XXX new tests added)
- Full Python client feature parity achieved (100%)
- Zero warnings, errors, dialyzer issues, or credo violations
```

---

## Verification Checklist

Before marking complete, verify:

- [ ] All P0 tasks implemented
- [ ] All P1 tasks implemented
- [ ] Tests written for each new feature
- [ ] All tests pass: `mix test`
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] Dialyzer passes: `mix dialyzer`
- [ ] Credo passes: `mix credo --strict`
- [ ] README.md updated with new features
- [ ] All guides updated
- [ ] CHANGELOG.md entry added
- [ ] Version bumped in mix.exs to 0.8.0
- [ ] Examples updated if needed

---

## Files to Create

```
lib/weaviate_ex/batch/vector_indexing.ex          # NEW
lib/weaviate_ex/rbac/user_assignment.ex           # NEW
lib/weaviate_ex/rbac/group_assignment.ex          # NEW
lib/weaviate_ex/reconfigure.ex                    # NEW
lib/weaviate_ex/batch/vectorizer_detection.ex     # NEW
lib/weaviate_ex/api/multi_vector/encoding.ex      # NEW
test/weaviate_ex/batch/vector_indexing_test.exs   # NEW
test/weaviate_ex/rbac/user_assignment_test.exs    # NEW
test/weaviate_ex/rbac/group_assignment_test.exs   # NEW
test/weaviate_ex/reconfigure_test.exs             # NEW
test/weaviate_ex/api/tenants_convenience_test.exs # NEW
```

## Files to Modify

```
lib/weaviate_ex/api/batch.ex                      # Add wait_for_vector_indexing
lib/weaviate_ex/batch/stream.ex                   # Add object caching
lib/weaviate_ex/schema/multi_tenancy_config.ex    # Add auto_tenant fields
lib/weaviate_ex/api/rbac.ex                       # Add assignment functions
lib/weaviate_ex/api/tenants.ex                    # Add convenience methods
lib/weaviate_ex/api/users/db.ex                   # Add include_permissions, revoke_key
lib/weaviate_ex/api/groups.ex                     # Add include_permissions
lib/weaviate_ex/query/near_vector.ex              # Add multi-vector support
lib/weaviate_ex/api/aggregate.ex                  # Add with_near_image
lib/weaviate_ex/rbac/permissions.ex               # Add collection to nodes
lib/weaviate_ex/types/tenant.ex                   # Add statuses
lib/weaviate_ex/config/proxy.ex                   # Add trust_env
lib/weaviate_ex/client.ex                         # Add OIDC auto-discovery
lib/weaviate_ex/api/multi_vector.ex               # Add encoding
README.md                                          # Update features
CHANGELOG.md                                       # Add 0.8.0 entry
guides/collections.md                              # Update
guides/multi_tenancy.md                            # Update
guides/batch_operations.md                         # Create or update
guides/rbac.md                                     # Update
mix.exs                                            # Version bump
```

---

*This implementation prompt was generated from the gap analysis conducted on 2025-12-29.*
