# Prompt - Auto-Tenant Creation/Activation

## Objective

Implement automatic tenant creation and activation features to simplify multi-tenant workflows.

## Priority

P2 - Medium (Multi-tenant setup convenience)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/08-multi-tenancy.md`
- `README.md` (multi-tenancy section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/api/tenants.ex` - Tenant operations
- `lib/weaviate_ex/config/auto_tenant.ex` - Auto-tenant config (if exists)
- `lib/weaviate_ex/tenant_client.ex` - Tenant client
- `lib/weaviate_ex/collections.ex` - Collection creation
- `test/weaviate_ex/api/tenants_test.exs`
- `test/weaviate_ex/config/auto_tenant_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/classes/config.py` - AutoTenantConfig
- `../weaviate-python-client/weaviate/collections/tenants.py` - Tenant operations

## Context

### Current State
- Tenants must be explicitly created before use
- No auto-creation on first operation
- Tenant activation is manual

### Gap
Python supports auto-tenant features:
```python
# Auto-create tenants on first operation
client.collections.create(
    name="Articles",
    multi_tenancy_config=MultiTenancyConfig(
        enabled=True,
        auto_tenant_creation=True,
        auto_tenant_activation=True
    )
)

# Tenant auto-created and activated on first insert
tenant_col = collection.with_tenant("new_tenant")
tenant_col.data.insert({"title": "test"})  # Tenant auto-created
```

### Auto-Tenant Behavior
- `auto_tenant_creation`: Create tenant if it doesn't exist on first operation
- `auto_tenant_activation`: Activate tenant (set to HOT) on first operation

## Implementation Instructions (TDD Required)

### Step 1: Create/Update AutoTenant Config

Create/update `lib/weaviate_ex/config/auto_tenant.ex`:

```elixir
defmodule WeaviateEx.Config.AutoTenant do
  @moduledoc """
  Configuration for automatic tenant management.
  """

  @type t :: %__MODULE__{
    auto_creation: boolean(),
    auto_activation: boolean()
  }

  defstruct auto_creation: false, auto_activation: false

  @doc """
  Creates auto-tenant configuration.

  ## Examples

      # Enable both auto-creation and auto-activation
      AutoTenant.new(auto_creation: true, auto_activation: true)

      # Only auto-creation
      AutoTenant.new(auto_creation: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      auto_creation: Keyword.get(opts, :auto_creation, false),
      auto_activation: Keyword.get(opts, :auto_activation, false)
    }
  end

  @doc """
  Converts to Weaviate API format.
  """
  @spec to_api_format(t()) :: map()
  def to_api_format(%__MODULE__{} = config) do
    %{
      "autoTenantCreation" => config.auto_creation,
      "autoTenantActivation" => config.auto_activation
    }
  end

  @doc """
  Parses from Weaviate API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(%{"autoTenantCreation" => creation, "autoTenantActivation" => activation}) do
    %__MODULE__{auto_creation: creation, auto_activation: activation}
  end

  def from_api_response(_), do: %__MODULE__{}
end
```

### Step 2: Update Multi-Tenancy Config

Update `lib/weaviate_ex/config/multi_tenancy.ex` (or create if needed):

```elixir
defmodule WeaviateEx.Config.MultiTenancy do
  @moduledoc """
  Multi-tenancy configuration for collections.
  """

  alias WeaviateEx.Config.AutoTenant

  @type t :: %__MODULE__{
    enabled: boolean(),
    auto_tenant: AutoTenant.t()
  }

  defstruct enabled: false, auto_tenant: %AutoTenant{}

  @doc """
  Creates multi-tenancy configuration.

  ## Examples

      # Basic multi-tenancy
      MultiTenancy.new(enabled: true)

      # With auto-tenant features
      MultiTenancy.new(
        enabled: true,
        auto_creation: true,
        auto_activation: true
      )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, false),
      auto_tenant: AutoTenant.new(
        auto_creation: Keyword.get(opts, :auto_creation, false),
        auto_activation: Keyword.get(opts, :auto_activation, false)
      )
    }
  end

  @spec to_api_format(t()) :: map()
  def to_api_format(%__MODULE__{enabled: enabled, auto_tenant: auto}) do
    Map.merge(
      %{"enabled" => enabled},
      AutoTenant.to_api_format(auto)
    )
  end
end
```

### Step 3: Update Collection Creation

Update `lib/weaviate_ex/collections.ex`:

```elixir
defmodule WeaviateEx.Collections do
  alias WeaviateEx.Config.MultiTenancy

  @doc """
  Creates a collection with multi-tenancy support.

  ## Examples

      # Basic multi-tenant collection
      Collections.create(client, "Articles",
        multi_tenancy: MultiTenancy.new(enabled: true)
      )

      # With auto-tenant features
      Collections.create(client, "Articles",
        multi_tenancy: MultiTenancy.new(
          enabled: true,
          auto_creation: true,
          auto_activation: true
        )
      )
  """
  def create(client, name, opts \\ []) do
    params = build_create_params(name, opts)
    # ... create collection
  end

  defp build_create_params(name, opts) do
    base = %{"class" => name}

    base
    |> maybe_add_multi_tenancy(opts[:multi_tenancy])
    # ... other options
  end

  defp maybe_add_multi_tenancy(params, nil), do: params
  defp maybe_add_multi_tenancy(params, %MultiTenancy{} = mt) do
    Map.put(params, "multiTenancyConfig", MultiTenancy.to_api_format(mt))
  end
end
```

### Step 4: Add Batch Tenant Update

Update `lib/weaviate_ex/api/tenants.ex`:

```elixir
defmodule WeaviateEx.API.Tenants do
  @doc """
  Updates multiple tenants' status in a single batch.

  Batches updates into groups of 100 (Weaviate limit).

  ## Examples

      # Activate multiple tenants
      Tenants.update_many(client, "Articles", [
        %{name: "tenant1", status: :hot},
        %{name: "tenant2", status: :hot}
      ])

      # Deactivate tenants
      Tenants.update_many(client, "Articles", [
        %{name: "tenant1", status: :cold}
      ])
  """
  @spec update_many(Client.t(), String.t(), [map()], keyword()) ::
    :ok | {:error, term()}
  def update_many(client, collection, updates, opts \\ []) do
    batch_size = opts[:batch_size] || 100

    updates
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce_while(:ok, fn batch, :ok ->
      case do_batch_update(client, collection, batch) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp do_batch_update(client, collection, updates) do
    body = Enum.map(updates, fn update ->
      %{
        "name" => update.name,
        "activityStatus" => status_to_string(update.status)
      }
    end)

    case HTTP.Client.put(client, "/v1/schema/#{collection}/tenants", body) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{body: body}} -> {:error, body}
      {:error, _} = error -> error
    end
  end

  defp status_to_string(:hot), do: "HOT"
  defp status_to_string(:cold), do: "COLD"
  defp status_to_string(:frozen), do: "FROZEN"
  defp status_to_string(:offloaded), do: "OFFLOADED"
end
```

### Step 5: Add Convenience Method

Add to `lib/weaviate_ex/api/tenants.ex`:

```elixir
@doc """
Ensures a tenant exists and is active (HOT).

Creates the tenant if it doesn't exist (when auto-creation is not enabled).
Activates the tenant if it's not HOT.

## Examples

      Tenants.ensure_active(client, "Articles", "tenant1")
"""
@spec ensure_active(Client.t(), String.t(), String.t()) :: :ok | {:error, term()}
def ensure_active(client, collection, tenant_name) do
  case get(client, collection, tenant_name) do
    {:ok, %{activity_status: :hot}} ->
      :ok

    {:ok, %{activity_status: _other}} ->
      update(client, collection, tenant_name, %{status: :hot})

    {:error, :not_found} ->
      with {:ok, _} <- create(client, collection, %{name: tenant_name, status: :hot}) do
        :ok
      end

    {:error, _} = error ->
      error
  end
end
```

## Tests to Write

### AutoTenant Tests (`test/weaviate_ex/config/auto_tenant_test.exs`)

```elixir
describe "new/1" do
  test "creates config with defaults (both false)"
  test "enables auto_creation"
  test "enables auto_activation"
  test "enables both"
end

describe "to_api_format/1" do
  test "converts to Weaviate format"
end

describe "from_api_response/1" do
  test "parses Weaviate response"
  test "handles missing fields"
end
```

### MultiTenancy Tests (`test/weaviate_ex/config/multi_tenancy_test.exs`)

```elixir
describe "new/1" do
  test "creates basic multi-tenancy config"
  test "includes auto-tenant settings"
end
```

### Tenant Batch Update Tests (`test/weaviate_ex/api/tenants_test.exs`)

```elixir
describe "update_many/4" do
  test "updates multiple tenants"
  test "batches updates in groups of 100"
  test "handles partial failures"
end

describe "ensure_active/3" do
  test "returns ok for already active tenant"
  test "activates inactive tenant"
  test "creates and activates missing tenant"
end
```

### Integration Tests

```elixir
@tag :integration
describe "auto-tenant features" do
  test "collection with auto_creation allows operation on new tenant" do
    # Create collection with auto_creation: true
    # Insert to non-existent tenant
    # Verify tenant was created
  end

  test "collection with auto_activation activates cold tenant" do
    # Create collection with auto_activation: true
    # Create cold tenant
    # Insert to cold tenant
    # Verify tenant is now hot
  end
end

describe "batch tenant updates" do
  test "updates 200 tenants in 2 batches"
end
```

## Docs Updates

### README.md

Update multi-tenancy section:

```markdown
### Auto-Tenant Features

Simplify multi-tenant workflows with automatic tenant management:

\`\`\`elixir
alias WeaviateEx.{Collections, Config.MultiTenancy}

# Create collection with auto-tenant features
{:ok, _} = Collections.create(client, "Articles",
  multi_tenancy: MultiTenancy.new(
    enabled: true,
    auto_creation: true,    # Create tenant on first operation
    auto_activation: true   # Activate tenant on first operation
  )
)

# Operations on new tenant automatically create and activate it
tenant_col = Collections.with_tenant(client, "Articles", "new_tenant")
{:ok, _} = TenantCollection.insert(tenant_col, %{title: "Test"})
# Tenant "new_tenant" was auto-created and activated
\`\`\`

### Batch Tenant Updates

Update multiple tenants efficiently:

\`\`\`elixir
# Activate all tenants
{:ok, tenants} = WeaviateEx.API.Tenants.list(client, "Articles")
updates = Enum.map(tenants, &%{name: &1.name, status: :hot})
:ok = WeaviateEx.API.Tenants.update_many(client, "Articles", updates)

# Ensure a tenant is active (creates if missing)
:ok = WeaviateEx.API.Tenants.ensure_active(client, "Articles", "tenant1")
\`\`\`
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- `WeaviateEx.Config.AutoTenant` for automatic tenant management
- `MultiTenancy.new/1` supports `auto_creation` and `auto_activation` options
- `Tenants.update_many/4` for batch tenant status updates
- `Tenants.ensure_active/3` convenience method for tenant activation
- Auto-tenant configuration in collection creation

### Changed
- Tenant batch updates respect Weaviate's 100-item batch limit
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New auto-tenant tests pass
- [ ] Integration tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `AutoTenant` config struct implemented
2. `MultiTenancy.new/1` accepts auto_creation/auto_activation
3. Collection creation includes auto-tenant config
4. `Tenants.update_many/4` batches updates correctly
5. `Tenants.ensure_active/3` creates/activates as needed
6. Integration tests verify auto-creation/activation behavior
7. All quality gates pass
