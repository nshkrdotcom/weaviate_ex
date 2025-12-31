# Getting Started with WeaviateEx

This guide will help you get started with WeaviateEx, the Elixir client for Weaviate vector database.

## Prerequisites

- Elixir 1.18+
- Docker (for running Weaviate locally)

## Installation

Add WeaviateEx to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:weaviate_ex, "~> 0.7.4"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Starting Weaviate Locally

WeaviateEx includes Mix tasks for managing a local Weaviate instance:

```bash
# Start Weaviate containers
mix weaviate.start

# Check status and health
mix weaviate.status

# Stop containers when done
mix weaviate.stop
```

For development, you can also start Weaviate directly with Docker:

```bash
docker run -d \
  -p 8080:8080 \
  -p 50051:50051 \
  -e AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=true \
  -e DEFAULT_VECTORIZER_MODULE=none \
  cr.weaviate.io/semitechnologies/weaviate:1.28.14
```

## Configuration

### Environment Variables

The simplest way to configure WeaviateEx is through environment variables:

```bash
export WEAVIATE_URL=http://localhost:8080
export WEAVIATE_API_KEY=your-api-key  # Optional, for authenticated instances
```

### Application Configuration

You can also configure WeaviateEx in your `config/config.exs`:

```elixir
config :weaviate_ex,
  url: "http://localhost:8080",
  api_key: nil  # Optional, for authenticated instances
```

### Runtime Configuration

For runtime configuration, WeaviateEx checks configuration sources in this order:
1. Environment variables (`WEAVIATE_URL`, `WEAVIATE_API_KEY`)
2. Application configuration
3. Defaults (`http://localhost:8080`)

## Connecting to Weaviate

### Local Instance

If you have Weaviate running locally (e.g., via Docker), WeaviateEx will connect automatically using the configured URL:

```elixir
# Check if Weaviate is ready
{:ok, true} = WeaviateEx.ready?()

# Get instance metadata
{:ok, meta} = WeaviateEx.health_check()
IO.inspect(meta["version"])
```

### Embedded Mode

WeaviateEx supports running an embedded Weaviate instance, similar to the Python client:

```elixir
# Start an embedded instance
{:ok, instance} = WeaviateEx.start_embedded(
  version: "1.30.5",
  port: 8090
)

# Use Weaviate normally
{:ok, true} = WeaviateEx.ready?()

# Stop when done
:ok = WeaviateEx.stop_embedded(instance)
```

See the [Embedded Mode Guide](embedded_mode.md) for more details.

### Weaviate Cloud

To connect to Weaviate Cloud Services (WCS):

```elixir
config :weaviate_ex,
  url: "https://your-instance.weaviate.network",
  api_key: "your-wcs-api-key"
```

You can also configure auth per client, including OIDC:

```elixir
alias WeaviateEx.Auth

# API key
{:ok, client} =
  WeaviateEx.Client.connect(
    base_url: "https://your-instance.weaviate.network",
    auth: Auth.api_key("your-wcs-api-key")
  )

# OIDC client credentials (auto-refresh)
auth = Auth.client_credentials("client-id", "client-secret", scopes: ["openid", "profile"])

{:ok, client} =
  WeaviateEx.Client.connect(
    base_url: "https://your-instance.weaviate.network",
    auth: auth
  )
```

### With AI Provider API Keys

When using vectorizers or generative modules, you need to provide API keys for the AI providers. Use the `WeaviateEx.Integrations` module:

```elixir
# Create integration headers
headers = WeaviateEx.Integrations.openai(api_key: "sk-...")

# Or combine multiple providers
headers = WeaviateEx.Integrations.merge([
  WeaviateEx.Integrations.openai(api_key: "sk-..."),
  WeaviateEx.Integrations.cohere(api_key: "cohere-key")
])

# Use with a custom client
{:ok, client} = WeaviateEx.Client.new(
  base_url: "http://localhost:8080",
  headers: headers
)
```

### Skip Init Checks (Optional)

If you want to skip the meta/version/gRPC checks during connect:

```elixir
{:ok, client} =
  WeaviateEx.Client.connect(
    base_url: "http://localhost:8080",
    skip_init_checks: true
  )
```

## Quick Start Example

Here's a complete example that creates a collection, adds objects, and performs a search:

```elixir
# 1. Verify connection
{:ok, true} = WeaviateEx.ready?()

# 2. Create a collection
{:ok, _collection} = WeaviateEx.Collections.create("Article", %{
  description: "A collection for articles",
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]},
    %{name: "category", dataType: ["text"]}
  ],
  vectorizer: "none"  # We'll provide vectors manually
})

# 3. Insert an object with a vector
{:ok, object} = WeaviateEx.Objects.create("Article", %{
  properties: %{
    title: "Introduction to Elixir",
    content: "Elixir is a dynamic, functional language...",
    category: "Programming"
  },
  vector: [0.1, 0.2, 0.3, 0.4, 0.5]  # Example vector
})

IO.puts("Created object with ID: #{object["id"]}")

# 4. Query objects
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title", "content", "category"])
  |> WeaviateEx.Query.limit(10)

{:ok, results} = WeaviateEx.Query.execute(query)

Enum.each(results, fn article ->
  IO.puts("- #{article["title"]}")
end)

# 5. Vector similarity search
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_vector([0.1, 0.2, 0.3, 0.4, 0.5], certainty: 0.7)
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.additional(["certainty", "distance"])
  |> WeaviateEx.Query.limit(5)

{:ok, similar} = WeaviateEx.Query.execute(query)

# 6. Clean up
{:ok, _} = WeaviateEx.Collections.delete("Article")
```

## Health Checks

WeaviateEx provides several health check functions:

```elixir
# Get instance metadata (version, modules, etc.)
{:ok, meta} = WeaviateEx.health_check()

# Check if instance is ready to serve requests
{:ok, true} = WeaviateEx.ready?()

# Check if instance is alive (liveness probe)
{:ok, true} = WeaviateEx.alive?()
```

## Error Handling

WeaviateEx returns errors as `{:error, %WeaviateEx.Error{}}` tuples:

```elixir
case WeaviateEx.Collections.get("NonExistent") do
  {:ok, collection} ->
    IO.inspect(collection)

  {:error, %WeaviateEx.Error{type: :not_found, message: msg}} ->
    IO.puts("Collection not found: #{msg}")

  {:error, %WeaviateEx.Error{type: :connection_error}} ->
    IO.puts("Could not connect to Weaviate")

  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

## Testing

WeaviateEx supports two testing modes:

### Unit Tests (Mocked)

Run fast, isolated tests without a Weaviate instance:

```bash
mix test
```

These tests use Mox to mock HTTP and gRPC responses.

### Integration Tests (Live Weaviate)

Run tests against a real Weaviate instance:

```bash
# Easiest: Automatic Weaviate management
mix weaviate.test

# Or manual management
mix weaviate.start
mix test --include integration
mix weaviate.stop
```

### Writing Integration Tests

Use the `WeaviateEx.IntegrationCase` module for consistent test setup:

```elixir
defmodule MyApp.MyIntegrationTest do
  use WeaviateEx.IntegrationCase

  test "creates and queries data" do
    # Create a unique test collection (auto-cleaned up)
    {name, {:ok, _}} = create_test_collection("MyTest", properties: [
      %{name: "title", dataType: ["text"]}
    ])

    # Test your code
    {:ok, _} = WeaviateEx.Objects.create(name, %{
      properties: %{title: "Test"}
    })

    # Collection is automatically deleted after test
  end
end
```

## Next Steps

- [Collections Guide](collections.md) - Learn how to create and configure collections
- [CRUD Operations Guide](crud_operations.md) - Insert, update, and delete objects
- [Queries Guide](queries.md) - Search with BM25, vector search, and hybrid queries
- [Generative Search Guide](generative_search.md) - RAG with AI providers
- [Multi-tenancy Guide](multi_tenancy.md) - Tenant management

## Module Reference

| Module | Description |
|--------|-------------|
| `WeaviateEx` | Main entry point, health checks, configuration |
| `WeaviateEx.Collections` | Collection schema management |
| `WeaviateEx.Objects` | Object CRUD operations |
| `WeaviateEx.Batch` | Batch operations for bulk imports |
| `WeaviateEx.Query` | GraphQL query builder |
| `WeaviateEx.Client` | Low-level HTTP client |
| `WeaviateEx.Embedded` | Embedded Weaviate instance management |
| `WeaviateEx.Integrations` | AI provider API key headers |
| `WeaviateEx.API.Tenants` | Multi-tenancy operations |
| `WeaviateEx.API.Generative` | Generative search (RAG) |
| `WeaviateEx.API.References` | Cross-reference operations |
