# Multi-Tenancy Guide

This guide covers multi-tenancy in Weaviate using WeaviateEx. Multi-tenancy enables data isolation between different tenants (customers, organizations, etc.) within the same Weaviate instance.

## Overview

Multi-tenancy provides:
- **Data isolation** - Each tenant's data is completely separate
- **Cost efficiency** - Share infrastructure across tenants
- **Performance** - Query only your tenant's data
- **Activity management** - Hot, cold, frozen, and offloaded states

## Enabling Multi-Tenancy

Enable multi-tenancy when creating a collection:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "none",
  multiTenancyConfig: %{
    enabled: true,
    autoTenantCreation: false,    # Auto-create tenants on insert
    autoTenantActivation: true    # Auto-activate inactive tenants
  }
})
```

### Typed Config Helpers

```elixir
alias WeaviateEx.Config.AutoTenant
alias WeaviateEx.Schema.MultiTenancyConfig

{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "none",
  multi_tenancy_config: MultiTenancyConfig.new(
    enabled: true,
    auto_tenant_creation: true,
    auto_tenant_activation: true
  ),
  auto_tenant: AutoTenant.enable(auto_delete_timeout: 86_400)
})
```

### Enable on Existing Collection

```elixir
{:ok, _} = WeaviateEx.Collections.set_multi_tenancy("Document", true)
```

## Tenant Operations

Use `WeaviateEx.API.Tenants` for tenant management:

```elixir
alias WeaviateEx.API.Tenants

{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url())
```

### Create Tenants

Create one or more tenants:

```elixir
# Create a single tenant
{:ok, _} = Tenants.create(client, "Document", "tenant-a")

# Create multiple tenants
{:ok, _} = Tenants.create(client, "Document", ["tenant-b", "tenant-c", "tenant-d"])

# Create with specific activity status
{:ok, _} = Tenants.create(client, "Document", "tenant-cold", activity_status: :cold)
```

### List Tenants

```elixir
# List all tenants
{:ok, tenants} = Tenants.list(client, "Document")

Enum.each(tenants, fn tenant ->
  IO.puts("#{tenant["name"]}: #{tenant["activityStatus"]}")
end)

# List only active (HOT) tenants
{:ok, active} = Tenants.list_active(client, "Document")

# List only inactive (COLD/FROZEN) tenants
{:ok, inactive} = Tenants.list_inactive(client, "Document")

# Count tenants
{:ok, count} = Tenants.count(client, "Document")
IO.puts("Total tenants: #{count}")
```

### Get Tenant

```elixir
{:ok, tenant} = Tenants.get(client, "Document", "tenant-a")
IO.puts("Status: #{tenant["activityStatus"]}")
```

### Check Tenant Existence

```elixir
case Tenants.exists?(client, "Document", "tenant-a") do
  {:ok, true} -> IO.puts("Tenant exists")
  {:ok, false} -> IO.puts("Tenant does not exist")
end
```

### Delete Tenants

```elixir
# Delete a single tenant
{:ok, _} = Tenants.delete(client, "Document", "tenant-a")

# Delete multiple tenants
{:ok, _} = Tenants.delete(client, "Document", ["tenant-b", "tenant-c"])
```

## Tenant Activity Status

Tenants can be in different activity states:

| Status | Description | Data Access | Resource Usage |
|--------|-------------|-------------|----------------|
| `HOT` (Active) | Fully loaded, ready for queries | Yes | Full |
| `COLD` (Inactive) | Not loaded, but can be activated | No | Low |
| `FROZEN` | Persisted but not loaded | No | Minimal |
| `OFFLOADED` | Moved to cold storage | No | None |

### Activate Tenant

Make a tenant hot (active):

```elixir
{:ok, _} = Tenants.activate(client, "Document", "tenant-a")

# Or multiple tenants
{:ok, _} = Tenants.activate(client, "Document", ["tenant-a", "tenant-b"])
```

### Deactivate Tenant

Make a tenant cold (inactive):

```elixir
{:ok, _} = Tenants.deactivate(client, "Document", "tenant-a")
```

### Freeze Tenant

Freeze a tenant (more aggressive than cold):

```elixir
{:ok, _} = Tenants.freeze(client, "Document", "tenant-a")
```

### Offload Tenant

Move tenant to cold storage:

```elixir
{:ok, _} = Tenants.offload(client, "Document", "tenant-a")
```

### Update Status Manually

```elixir
{:ok, _} = Tenants.update(client, "Document", "tenant-a", activity_status: :cold)

# Multiple tenants
{:ok, _} = Tenants.update(client, "Document", ["tenant-a", "tenant-b"], activity_status: :hot)
```

## Tenant-Scoped Operations

All data operations must include a tenant when working with multi-tenant collections.

### Create Objects in Tenant

```elixir
{:ok, object} = WeaviateEx.Objects.create("Document", %{
  properties: %{
    title: "Tenant A Document",
    content: "This belongs to tenant A"
  }
}, tenant: "tenant-a")
```

### List Objects in Tenant

```elixir
{:ok, result} = WeaviateEx.Objects.list("Document", tenant: "tenant-a", limit: 10)

Enum.each(result["objects"], fn obj ->
  IO.puts("- #{obj["properties"]["title"]}")
end)
```

### Get Object in Tenant

```elixir
{:ok, object} = WeaviateEx.Objects.get("Document", uuid, tenant: "tenant-a")
```

### Update Object in Tenant

```elixir
{:ok, updated} = WeaviateEx.Objects.update("Document", uuid, %{
  properties: %{title: "Updated Title"}
}, tenant: "tenant-a")
```

### Delete Object in Tenant

```elixir
{:ok, _} = WeaviateEx.Objects.delete("Document", uuid, tenant: "tenant-a")
```

### Batch Operations with Tenant

```elixir
objects = [
  %{class: "Document", properties: %{title: "Doc 1"}, tenant: "tenant-a"},
  %{class: "Document", properties: %{title: "Doc 2"}, tenant: "tenant-a"}
]

{:ok, result} = WeaviateEx.Batch.create_objects(objects)
```

## Querying with Tenants

### Using Collections Module

```elixir
# Get shards for tenant
{:ok, shards} = WeaviateEx.Collections.get_shards("Document", tenant: "tenant-a")
```

### GraphQL Queries with Tenant

For GraphQL queries, set the tenant header:

```elixir
{:ok, client} = WeaviateEx.Client.new(
  base_url: WeaviateEx.base_url(),
  headers: [{"X-Weaviate-Tenant", "tenant-a"}]
)

query = """
{
  Get {
    Document(limit: 10) {
      title
      content
    }
  }
}
"""

{:ok, response} = WeaviateEx.Client.request(client, :post, "/v1/graphql", %{query: query})
```

## Auto Tenant Creation

When enabled, tenants are automatically created when inserting data:

```elixir
{:ok, _} = WeaviateEx.Collections.create("AutoTenantDoc", %{
  properties: [
    %{name: "data", dataType: ["text"]}
  ],
  multiTenancyConfig: %{
    enabled: true,
    autoTenantCreation: true  # Enable auto-creation
  }
})

# This will auto-create "new-tenant" if it doesn't exist
{:ok, _} = WeaviateEx.Objects.create("AutoTenantDoc", %{
  properties: %{data: "test"}
}, tenant: "new-tenant")
```

## Auto Tenant Activation

When enabled, cold tenants are automatically activated on access:

```elixir
{:ok, _} = WeaviateEx.Collections.create("AutoActivateDoc", %{
  properties: [
    %{name: "data", dataType: ["text"]}
  ],
  multiTenancyConfig: %{
    enabled: true,
    autoTenantActivation: true  # Auto-activate on access
  }
})
```

## Complete Example

Here's a complete multi-tenant application example:

```elixir
defmodule MultiTenantApp do
  alias WeaviateEx.API.Tenants

  @collection "CustomerData"

  def setup do
    # Create multi-tenant collection
    WeaviateEx.Collections.create(@collection, %{
      properties: [
        %{name: "name", dataType: ["text"]},
        %{name: "email", dataType: ["text"]},
        %{name: "data", dataType: ["text"]}
      ],
      vectorizer: "none",
      multiTenancyConfig: %{
        enabled: true,
        autoTenantCreation: false,
        autoTenantActivation: true
      }
    })
  end

  def create_tenant(client, tenant_name) do
    Tenants.create(client, @collection, tenant_name)
  end

  def add_customer(tenant_name, customer) do
    WeaviateEx.Objects.create(@collection, %{
      properties: customer
    }, tenant: tenant_name)
  end

  def list_customers(tenant_name, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    WeaviateEx.Objects.list(@collection, tenant: tenant_name, limit: limit)
  end

  def get_customer(tenant_name, customer_id) do
    WeaviateEx.Objects.get(@collection, customer_id, tenant: tenant_name)
  end

  def delete_customer(tenant_name, customer_id) do
    WeaviateEx.Objects.delete(@collection, customer_id, tenant: tenant_name)
  end

  def deactivate_tenant(client, tenant_name) do
    Tenants.deactivate(client, @collection, tenant_name)
  end

  def activate_tenant(client, tenant_name) do
    Tenants.activate(client, @collection, tenant_name)
  end

  def delete_tenant(client, tenant_name) do
    Tenants.delete(client, @collection, tenant_name)
  end

  def list_all_tenants(client) do
    Tenants.list(client, @collection)
  end

  def cleanup do
    WeaviateEx.Collections.delete(@collection)
  end
end

# Usage
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url())

# Setup
MultiTenantApp.setup()

# Create tenants for different customers
MultiTenantApp.create_tenant(client, "acme-corp")
MultiTenantApp.create_tenant(client, "globex-inc")

# Add data for each tenant
MultiTenantApp.add_customer("acme-corp", %{
  name: "John Doe",
  email: "john@acme.com",
  data: "VIP customer"
})

MultiTenantApp.add_customer("globex-inc", %{
  name: "Jane Smith",
  email: "jane@globex.com",
  data: "New customer"
})

# Query tenant-specific data
{:ok, acme_customers} = MultiTenantApp.list_customers("acme-corp")
{:ok, globex_customers} = MultiTenantApp.list_customers("globex-inc")

# Each tenant only sees their own data
IO.puts("ACME customers: #{length(acme_customers["objects"])}")
IO.puts("Globex customers: #{length(globex_customers["objects"])}")

# Deactivate unused tenant
MultiTenantApp.deactivate_tenant(client, "globex-inc")

# Later, reactivate when needed
MultiTenantApp.activate_tenant(client, "globex-inc")

# Clean up
MultiTenantApp.cleanup()
```

## Tenant Migration

To migrate data between tenants:

```elixir
defmodule TenantMigration do
  def migrate(from_tenant, to_tenant, collection) do
    # 1. List all objects from source tenant
    {:ok, result} = WeaviateEx.Objects.list(collection, tenant: from_tenant, limit: 1000)

    # 2. Create objects in target tenant
    for obj <- result["objects"] do
      WeaviateEx.Objects.create(collection, %{
        id: obj["id"],
        properties: obj["properties"],
        vector: obj["vector"]
      }, tenant: to_tenant)
    end

    {:ok, length(result["objects"])}
  end
end
```

## Best Practices

1. **Use meaningful tenant names** - e.g., customer IDs or organization slugs
2. **Monitor tenant activity** - Deactivate unused tenants to save resources
3. **Plan for tenant limits** - Consider sharding strategies for many tenants
4. **Handle tenant errors** - Accessing non-existent or inactive tenants fails
5. **Batch tenant operations** - Create/delete multiple tenants in one call

## Next Steps

- [Collections Guide](collections.md) - Configure multi-tenancy settings
- [CRUD Operations](crud_operations.md) - Tenant-scoped data operations
- [Queries Guide](queries.md) - Query within tenants
