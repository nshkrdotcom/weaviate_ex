<p align="center">
  <img src="assets/weaviate_ex.svg" alt="WeaviateEx Logo" width="200" height="200">
</p>

# WeaviateEx

[![Elixir](https://img.shields.io/badge/elixir-1.18-purple.svg)](https://elixir-lang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/weaviate_ex.svg)](https://hex.pm/packages/weaviate_ex)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/weaviate_ex)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A modern, idiomatic Elixir client for [Weaviate](https://weaviate.io) vector database (v1.28+).

## Features

- **Complete API Coverage** - Collections, objects, batch operations, queries, aggregations, tenants
- **Type-Safe** - Protocol-based architecture with comprehensive specs
- **Test-First Design** - 158+ tests with Mox-based mocking for fast, isolated testing
- **Developer-Friendly** - Intuitive API with helpful error messages
- **Production-Ready** - Connection pooling with Finch, proper error handling, health checks
- **Easy Setup** - Automated Docker installation with `install.sh`
- **Rich Examples** - 6 runnable examples covering all major features

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Health Checks](#health-checks)
  - [Collections (Schema Management)](#collections-schema-management)
  - [Data Operations (CRUD)](#data-operations-crud)
  - [Objects API](#objects-api)
  - [Batch Operations](#batch-operations)
  - [Queries & Vector Search](#queries--vector-search)
  - [Aggregations](#aggregations)
  - [Advanced Filtering](#advanced-filtering)
  - [Vector Configuration](#vector-configuration)
  - [Multi-Tenancy](#multi-tenancy)
- [Examples](#examples)
- [Testing](#testing)
- [Mix Tasks](#mix-tasks)
- [Docker Management](#docker-management)
- [Authentication](#authentication)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

### 1. Install Weaviate

Run the installation script to set up Weaviate with Docker:

```bash
./install.sh
```

This automated script will:
- ✅ Check and install Docker (if needed on Ubuntu/Debian)
- ✅ Create a `.env` file with default configuration
- ✅ Pull the Weaviate Docker image (v1.28.1)
- ✅ Start Weaviate with health checks
- ✅ Verify the connection is working
- ✅ Display helpful commands for managing Weaviate

**Manual Installation** (if `install.sh` doesn't work):

```bash
# 1. Ensure Docker is installed
docker --version

# 2. Start Weaviate using Docker Compose
docker compose up -d

# 3. Wait for health check (30-60 seconds)
docker compose ps

# 4. Verify connection
curl http://localhost:8080/v1/meta
```

For detailed installation instructions, see [INSTALL.md](INSTALL.md).

### 2. Add to Your Project

Add `weaviate_ex` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:weaviate_ex, "~> 0.1.1"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

### 3. Configure

The library automatically reads from environment variables (loaded from `.env`):

```bash
# .env file (created by install.sh)
WEAVIATE_URL=http://localhost:8080
WEAVIATE_API_KEY=  # Optional, for authenticated instances
```

Or configure in your Elixir config files:

```elixir
# config/config.exs
config :weaviate_ex,
  url: "http://localhost:8080",
  api_key: nil,    # Optional
  strict: true     # Default: true - fails fast if Weaviate is unreachable
```

**Strict Mode**: By default, WeaviateEx validates connectivity on startup. If Weaviate is unreachable, your application won't start. Set `strict: false` to allow startup anyway (useful for development when Weaviate might not always be running).

### 4. Verify Connection

The library automatically performs a health check on startup:

```
[WeaviateEx] Successfully connected to Weaviate
  URL: http://localhost:8080
  Version: 1.28.1
```

If configuration is missing, you'll get helpful error messages:

```
╔════════════════════════════════════════════════════════════════╗
║                  WeaviateEx Configuration Error                 ║
╠════════════════════════════════════════════════════════════════╣
║  Missing required configuration: WEAVIATE_URL                    ║
║                                                                  ║
║  Please set the Weaviate URL using one of these methods:        ║
║  1. Environment variable: export WEAVIATE_URL=http://localhost:8080
║  2. Application configuration (config/config.exs)                ║
║  3. Runtime configuration (config/runtime.exs)                   ║
╚════════════════════════════════════════════════════════════════╝
```

### 5. Shape a Tenant-Aware Collection and Load Data

```elixir
alias WeaviateEx.{Collections, Objects, Batch}

# Define the collection and toggle multi-tenancy when ready
{:ok, _collection} =
  Collections.create("Article", %{
    description: "Articles by tenant",
    properties: [
      %{name: "title", dataType: ["text"]},
      %{name: "content", dataType: ["text"]}
    ]
  })

{:ok, %{"enabled" => true}} = Collections.set_multi_tenancy("Article", true)
{:ok, true} = Collections.exists?("Article")

# Create & read tenant-scoped objects with _additional metadata
{:ok, created} =
  Objects.create("Article", %{properties: %{title: "Tenant scoped", content: "Hello!"}},
    tenant: "tenant-a"
  )

{:ok, fetched} =
  Objects.get("Article", created["id"],
    tenant: "tenant-a",
    include: ["_additional", "vector"]
  )

# Batch ingest with a summary that separates successes from errors
objects =
  Enum.map(1..3, fn idx ->
    %{class: "Article", properties: %{title: "Story #{idx}"}, tenant: "tenant-a"}
  end)

{:ok, summary} = Batch.create_objects(objects, return_summary: true, tenant: "tenant-a")
summary.statistics
#=> %{processed: 3, successful: 3, failed: 0}
```

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions covering:
- Docker installation on various platforms
- Manual Weaviate setup
- Configuration options
- Troubleshooting

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WEAVIATE_URL` | Yes | - | Full URL to Weaviate (e.g., `http://localhost:8080`) |
| `WEAVIATE_API_KEY` | No | - | API key for authentication (for cloud/production) |

### Application Configuration

```elixir
# config/config.exs
config :weaviate_ex,
  url: System.get_env("WEAVIATE_URL", "http://localhost:8080"),
  api_key: System.get_env("WEAVIATE_API_KEY"),
  strict: true,      # Fail on startup if unreachable
  timeout: 30_000    # Request timeout in milliseconds
```

### Runtime Configuration (Recommended for Production)

```elixir
# config/runtime.exs
config :weaviate_ex,
  url: System.fetch_env!("WEAVIATE_URL"),
  api_key: System.get_env("WEAVIATE_API_KEY")
```

## Usage

### Health Checks

Check if Weaviate is accessible and get version information:

```elixir
# Get metadata (version, modules)
{:ok, meta} = WeaviateEx.health_check()
# => %{"version" => "1.28.1", "modules" => %{}}

# Check readiness (can handle requests)
{:ok, true} = WeaviateEx.ready?()

# Check liveness (service is up)
{:ok, true} = WeaviateEx.alive?()
```

### Collections (Schema Management)

Collections define the structure of your data:

```elixir
# Create a collection with properties
{:ok, collection} = WeaviateEx.Collections.create("Article", %{
  description: "News articles",
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]},
    %{name: "publishedAt", dataType: ["date"]},
    %{name: "views", dataType: ["int"]}
  ],
  vectorizer: "none"  # Use "text2vec-openai" for auto-vectorization
})

# List all collections
{:ok, schema} = WeaviateEx.Collections.list()

# Get a specific collection
{:ok, collection} = WeaviateEx.Collections.get("Article")

# Add a property to existing collection
{:ok, property} = WeaviateEx.Collections.add_property("Article", %{
  name: "author",
  dataType: ["text"]
})

# Check if collection exists
{:ok, true} = WeaviateEx.Collections.exists?("Article")

# Delete a collection
{:ok, _} = WeaviateEx.Collections.delete("Article")
```

### Data Operations (CRUD)

Simple CRUD operations with automatic UUID generation:

```elixir
alias WeaviateEx.API.Data

# Create (insert) a new object
data = %{
  properties: %{
    "title" => "Hello Weaviate",
    "content" => "This is a test article",
    "views" => 0
  },
  vector: [0.1, 0.2, 0.3, 0.4, 0.5]  # Optional if using auto-vectorization
}

{:ok, object} = Data.insert(client, "Article", data)
uuid = object["id"]

# Read - get object by ID
{:ok, retrieved} = Data.get_by_id(client, "Article", uuid)

# Update - partial update (PATCH)
{:ok, updated} = Data.patch(client, "Article", uuid, %{
  properties: %{"views" => 42},
  vector: [0.1, 0.2, 0.3, 0.4, 0.5]
})

# Check if object exists
{:ok, true} = Data.exists?(client, "Article", uuid)

# Delete
{:ok, _} = Data.delete_by_id(client, "Article", uuid)
```

### Objects API

Full CRUD operations with explicit UUID control:

```elixir
# Create with custom UUID
{:ok, object} = WeaviateEx.Objects.create("Article", %{
  id: "custom-uuid-here",  # Optional
  properties: %{
    title: "Hello Weaviate",
    content: "This is a test article",
    publishedAt: "2025-01-15T10:00:00Z"
  },
  vector: [0.1, 0.2, 0.3]  # Optional
})

# Get an object with additional fields
{:ok, object} = WeaviateEx.Objects.get("Article", uuid,
  include: "vector,classification"
)

# List objects with pagination
{:ok, result} = WeaviateEx.Objects.list("Article",
  limit: 10,
  offset: 0,
  include: "vector"
)

# Update (full replacement)
{:ok, updated} = WeaviateEx.Objects.update("Article", uuid, %{
  properties: %{
    title: "Updated Title",
    content: "Updated content"
  }
})

# Patch (partial update)
{:ok, patched} = WeaviateEx.Objects.patch("Article", uuid, %{
  properties: %{title: "New Title"}
})

# Delete
{:ok, _} = WeaviateEx.Objects.delete("Article", uuid)

# Check existence
{:ok, true} = WeaviateEx.Objects.exists?("Article", uuid)
```

### Batch Operations

Efficient bulk operations for importing large datasets:

```elixir
# Batch create multiple objects
objects = [
  %{class: "Article", properties: %{title: "Article 1", content: "Content 1"}},
  %{class: "Article", properties: %{title: "Article 2", content: "Content 2"}},
  %{class: "Article", properties: %{title: "Article 3", content: "Content 3"}}
]

{:ok, summary} = WeaviateEx.Batch.create_objects(objects, return_summary: true)

# Check rolled-up stats and per-object errors
summary.statistics
#=> %{processed: 3, successful: 3, failed: 0}

Enum.each(summary.errors, fn error ->
  Logger.warn("[Batch error] #{error.id} => #{Enum.join(error.messages, "; ")}")
end)

# Batch delete with criteria (WHERE filter)
{:ok, result} = WeaviateEx.Batch.delete_objects(%{
  class: "Article",
  where: %{
    path: ["status"],
    operator: "Equal",
    valueText: "draft"
  }
})
```

### Queries & Vector Search

Powerful query capabilities with semantic search:

```elixir
alias WeaviateEx.Query

# Simple query with field selection
query = Query.get("Article")
  |> Query.fields(["title", "content", "publishedAt"])
  |> Query.limit(10)

{:ok, results} = Query.execute(query)

# Semantic search with near_text (requires vectorizer)
query = Query.get("Article")
  |> Query.near_text("artificial intelligence", certainty: 0.7)
  |> Query.fields(["title", "content"])
  |> Query.additional(["certainty", "distance"])
  |> Query.limit(5)

{:ok, results} = Query.execute(query)

# Vector search with custom vectors
query = Query.get("Article")
  |> Query.near_vector([0.1, 0.2, 0.3], certainty: 0.8)
  |> Query.fields(["title"])

{:ok, results} = Query.execute(query)

# Hybrid search (combines keyword + vector)
query = Query.get("Article")
  |> Query.hybrid("machine learning", alpha: 0.5)  # alpha: 0=keyword, 1=vector
  |> Query.fields(["title", "content"])

{:ok, results} = Query.execute(query)

# BM25 keyword search
query = Query.get("Article")
  |> Query.bm25("elixir programming")
  |> Query.fields(["title", "content"])

{:ok, results} = Query.execute(query)

# Queries with filters (WHERE clause)
query = Query.get("Article")
  |> Query.where(%{
    path: ["publishedAt"],
    operator: "GreaterThan",
    valueDate: "2025-01-01T00:00:00Z"
  })
  |> Query.fields(["title", "publishedAt"])
  |> Query.sort([%{path: ["publishedAt"], order: "desc"}])

{:ok, results} = Query.execute(query)
```

### Aggregations

Statistical analysis over your data:

```elixir
alias WeaviateEx.API.Aggregate

# Count all objects
{:ok, result} = Aggregate.over_all(client, "Product", metrics: [:count])

# Numeric aggregations (mean, sum, min, max)
{:ok, stats} = Aggregate.over_all(client, "Product",
  properties: [{:price, [:mean, :sum, :maximum, :minimum, :count]}]
)

# Top occurrences for text fields
{:ok, categories} = Aggregate.over_all(client, "Product",
  properties: [{:category, [:topOccurrences], limit: 10}]
)

# Group by with aggregations
{:ok, grouped} = Aggregate.group_by(client, "Product", "category",
  metrics: [:count],
  properties: [{:price, [:mean, :maximum, :minimum]}]
)
```

### Advanced Filtering

Build complex filters with a type-safe DSL:

```elixir
alias WeaviateEx.Filter

# Simple equality
filter = Filter.equal("status", "published")

# Numeric comparisons
filter = Filter.greater_than("views", 100)
filter = Filter.less_than_equal("price", 50.0)

# Text pattern matching
filter = Filter.like("title", "*AI*")

# Array operations
filter = Filter.contains_any("tags", ["elixir", "phoenix"])
filter = Filter.contains_all("tags", ["elixir", "tutorial"])

# Geospatial queries
filter = Filter.within_geo_range("location", {40.7128, -74.0060}, 5000.0)

# Date comparisons
filter = Filter.greater_than("publishedAt", "2025-01-01T00:00:00Z")

# Null checks
filter = Filter.is_null("deletedAt")

# Combine filters with AND
combined = Filter.all_of([
  Filter.equal("status", "published"),
  Filter.greater_than("views", 100),
  Filter.like("title", "*Elixir*")
])

# Combine filters with OR
or_filter = Filter.any_of([
  Filter.equal("category", "technology"),
  Filter.equal("category", "science")
])

# Negate filters
not_filter = Filter.none_of([
  Filter.equal("status", "draft")
])

# Use in queries
query = Query.get("Article")
  |> Query.where(Filter.to_graphql(combined))
  |> Query.fields(["title", "views"])
```

### Vector Configuration

Configure vectorizers and index types:

```elixir
alias WeaviateEx.API.VectorConfig

# Custom vectors with HNSW index
config = VectorConfig.new("AIArticle")
  |> VectorConfig.with_vectorizer(:none)  # Bring your own vectors
  |> VectorConfig.with_hnsw_index(
    distance: :cosine,
    ef: 100,
    max_connections: 64
  )
  |> VectorConfig.with_properties([
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "content", "dataType" => ["text"]}
  ])

{:ok, _} = Collections.create(client, config)

# HNSW with Product Quantization (compression)
config = VectorConfig.new("CompressedData")
  |> VectorConfig.with_vectorizer(:none)
  |> VectorConfig.with_hnsw_index(distance: :dot)
  |> VectorConfig.with_product_quantization(
    enabled: true,
    segments: 96,
    centroids: 256
  )

# Flat index for exact search (no approximation)
config = VectorConfig.new("ExactSearch")
  |> VectorConfig.with_vectorizer(:none)
  |> VectorConfig.with_flat_index(distance: :dot)
```

### Multi-Tenancy

Isolate data per tenant with automatic partitioning:

```elixir
alias WeaviateEx.API.{VectorConfig, Tenants}

# Create multi-tenant collection
config = VectorConfig.new("TenantArticle")
  |> VectorConfig.with_multi_tenancy(enabled: true)
  |> VectorConfig.with_properties([
    %{"name" => "title", "dataType" => ["text"]}
  ])

Collections.create(client, config)

# Create tenants
{:ok, created} = Tenants.create(client, "TenantArticle",
  ["CompanyA", "CompanyB", "CompanyC"]
)

# List all tenants
{:ok, tenants} = Tenants.list(client, "TenantArticle")

# Get specific tenant
{:ok, tenant} = Tenants.get(client, "TenantArticle", "CompanyA")

# Check existence
{:ok, true} = Tenants.exists?(client, "TenantArticle", "CompanyA")

# Deactivate tenant (set to COLD storage)
{:ok, _} = Tenants.deactivate(client, "TenantArticle", "CompanyB")

# List only active tenants
{:ok, active} = Tenants.list_active(client, "TenantArticle")

# Activate tenant (set to HOT)
{:ok, _} = Tenants.activate(client, "TenantArticle", "CompanyB")

# Count tenants
{:ok, count} = Tenants.count(client, "TenantArticle")

# Delete tenant
{:ok, _} = Tenants.delete(client, "TenantArticle", "CompanyC")

# Use tenant in queries (specify tenant parameter)
{:ok, objects} = Data.insert(client, "TenantArticle", data, tenant: "CompanyA")
```

## Examples

WeaviateEx includes **6 runnable examples** that demonstrate all major features:

| Example | Description | What You'll Learn |
|---------|-------------|-------------------|
| `01_collections.exs` | Collection management | Create, list, get, add properties, delete collections |
| `02_data.exs` | CRUD operations | Insert, get, patch, check existence, delete objects |
| `03_filter.exs` | Advanced filtering | Equality, comparison, pattern matching, geo, array filters |
| `04_aggregate.exs` | Aggregations | Count, statistics, top occurrences, group by |
| `05_vector_config.exs` | Vector configuration | HNSW, PQ compression, flat index, distance metrics |
| `06_tenants.exs` | Multi-tenancy | Create tenants, activate/deactivate, list, delete |

### Running Examples

All examples are self-contained and include clean visual output:

```bash
# Make sure Weaviate is running
mix weaviate.start

# Run any example
elixir examples/01_collections.exs
elixir examples/02_data.exs
elixir examples/03_filter.exs
# ... etc

# Or run all examples
for example in examples/*.exs; do
  echo "Running $example..."
  elixir "$example"
done
```

Each example:
- ✅ Checks Weaviate connectivity before running
- ✅ Shows the code being executed
- ✅ Displays formatted results
- ✅ Cleans up after itself (deletes test data)
- ✅ Provides clear success/error messages

## Testing

WeaviateEx has **comprehensive test coverage** with two testing modes:

### Test Modes

**Mock Mode (Default)** - Fast, isolated unit tests:
- ✅ Uses Mox to mock HTTP/Protocol responses
- ✅ No Weaviate instance required
- ✅ Fast execution (~0.1 seconds)
- ✅ 158+ unit tests
- ✅ Perfect for TDD and CI/CD

**Integration Mode** - Real Weaviate testing:
- ✅ Tests against live Weaviate instance
- ✅ Validates actual API behavior
- ✅ Requires Weaviate running locally
- ✅ Run with `--include integration` flag
- ✅ 50+ integration tests

### Running Tests

```bash
# Run all unit tests with mocks (default - no Weaviate needed)
mix test

# Run integration tests (requires live Weaviate)
mix weaviate.start  # Start Weaviate first
mix test --include integration

# Or use environment variable
WEAVIATE_INTEGRATION=true mix test

# Run specific test file
mix test test/weaviate_ex/api/collections_test.exs

# Run specific test by line number
mix test test/weaviate_ex/objects_test.exs:95

# Run with coverage report
mix test --cover

# Run only integration tests
mix test --only integration
```

### Test Structure

```
test/
├── test_helper.exs           # Test setup, Mox configuration
├── support/
│   └── fixtures.ex           # Test fixtures and helpers
├── weaviate_ex_test.exs      # Top-level API tests
├── weaviate_ex/
│   ├── api/                  # API module tests (mocked)
│   │   ├── collections_test.exs
│   │   ├── data_test.exs
│   │   ├── aggregate_test.exs
│   │   ├── tenants_test.exs
│   │   └── ...
│   ├── filter_test.exs       # Filter system tests
│   ├── objects_test.exs      # Objects API tests
│   ├── batch_test.exs        # Batch operations tests
│   └── query_test.exs        # Query builder tests
└── integration/              # Integration tests (live Weaviate)
    ├── collections_integration_test.exs
    ├── objects_integration_test.exs
    ├── batch_integration_test.exs
    ├── query_integration_test.exs
    └── health_integration_test.exs
```

### Test Coverage

Current test coverage by module:

- ✅ **Collections API**: 17 tests - Create, list, get, exists, delete, add property
- ✅ **Filter System**: 26 tests - All operators, combinators, GraphQL conversion
- ✅ **Data Operations**: 17 tests - Insert, get, patch, exists, delete with vectors
- ✅ **Objects API**: 15+ tests - Full CRUD with pagination
- ✅ **Batch Operations**: 10+ tests - Bulk create, delete with criteria
- ✅ **Query System**: 20+ tests - GraphQL queries, near_text, hybrid, BM25
- ✅ **Aggregations**: 15+ tests - Count, statistics, group by
- ✅ **Tenants**: 12+ tests - Multi-tenancy operations
- ✅ **Vector Config**: 10+ tests - HNSW, PQ, flat index
- 🎯 **Total: 158+ tests passing**

## Mix Tasks

Convenient Mix tasks for managing your local Weaviate instance:

```bash
# Start Weaviate (uses docker compose)
mix weaviate.start

# Stop Weaviate
mix weaviate.stop

# Stop and remove all data (WARNING: deletes everything)
mix weaviate.stop --remove-volumes

# Check status
mix weaviate.status

# View logs
mix weaviate.logs

# Follow logs in real-time
mix weaviate.logs --follow

# View last 50 lines
mix weaviate.logs --tail 50
```

These tasks are wrappers around Docker Compose for convenience.

## Docker Management

### Using Docker Compose Directly

```bash
# Start Weaviate in detached mode
docker compose up -d

# Stop Weaviate
docker compose down

# Stop and remove all data
docker compose down -v

# View logs
docker compose logs -f weaviate

# Check status
docker compose ps

# Restart Weaviate
docker compose restart

# Pull latest image
docker compose pull
```

### Docker Compose Configuration

The included `docker-compose.yml` configures:

- **Image**: Weaviate v1.28.1
- **Ports**:
  - `8080:8080` - HTTP REST API
  - `40051:50051` - gRPC API
- **Environment**:
  - Anonymous access enabled (for local development)
  - No default vectorizer (bring your own vectors)
  - Persistence enabled
- **Volumes**: `weaviate_data` for persistent storage
- **Health checks**: Automatic health monitoring

### Troubleshooting Docker

```bash
# Check if Docker is running
docker info

# View detailed container status
docker compose ps -a

# Check container logs for errors
docker compose logs weaviate --tail 100

# Restart with fresh data (WARNING: deletes all data)
docker compose down -v && docker compose up -d

# Test connectivity
curl http://localhost:8080/v1/meta

# Check health endpoint
curl http://localhost:8080/v1/.well-known/ready
```

## Authentication

For **production or cloud Weaviate instances** with authentication:

### Environment Variables (Recommended)

```bash
# Add to .env file (NOT committed to git)
WEAVIATE_URL=https://your-cluster.weaviate.network
WEAVIATE_API_KEY=your-secret-api-key-here

# Or add to ~/.bash_secrets (sourced by ~/.bashrc)
export WEAVIATE_URL=https://your-cluster.weaviate.network
export WEAVIATE_API_KEY=your-secret-api-key-here
```

### Runtime Configuration (Production)

```elixir
# config/runtime.exs
config :weaviate_ex,
  url: System.fetch_env!("WEAVIATE_URL"),
  api_key: System.fetch_env!("WEAVIATE_API_KEY"),
  strict: true  # Fail fast if unreachable
```

### Development Configuration

```elixir
# config/dev.exs (NEVER commit production keys!)
config :weaviate_ex,
  url: "http://localhost:8080",
  api_key: nil  # No auth for local development
```

**Security Best Practices:**
- ✅ Never commit API keys to version control
- ✅ Use environment variables for production
- ✅ Add `.env` to `.gitignore` (already done)
- ✅ Use `System.fetch_env!/1` to fail fast on missing keys
- ✅ Store production secrets in secure vaults (e.g., AWS Secrets Manager)
- ✅ Use different keys for dev/staging/production

## Documentation

- **[INSTALL.md](INSTALL.md)** - Detailed installation guide for all platforms
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes
- **[API Documentation](https://hexdocs.pm/weaviate_ex)** - Full API reference on HexDocs
- **[Weaviate Docs](https://docs.weaviate.io)** - Official Weaviate documentation
- **Examples** - 6 runnable examples in the GitHub repository (see [Examples](#examples) section)

### Building Documentation Locally

```bash
# Generate docs
mix docs

# Open in browser (macOS)
open doc/index.html

# Open in browser (Linux)
xdg-open doc/index.html
```

## Development

```bash
# Clone the repository
git clone https://github.com/yourusername/weaviate_ex.git
cd weaviate_ex

# Install dependencies
mix deps.get

# Compile
mix compile

# Run unit tests (mocked - fast)
mix test

# Run integration tests (requires live Weaviate)
mix weaviate.start
mix test --include integration

# Generate documentation
mix docs

# Run code analysis
mix credo

# Run type checking (if dialyzer is set up)
mix dialyzer

# Format code
mix format
```

### Project Structure

```
weaviate_ex/
├── lib/
│   ├── weaviate_ex.ex              # Top-level API
│   ├── weaviate_ex/
│   │   ├── application.ex          # OTP application
│   │   ├── client.ex               # Client struct & config
│   │   ├── config.ex               # Configuration management
│   │   ├── error.ex                # Error types
│   │   ├── filter.ex               # Filter DSL
│   │   ├── api/                    # API modules
│   │   │   ├── collections.ex
│   │   │   ├── data.ex
│   │   │   ├── aggregate.ex
│   │   │   ├── tenants.ex
│   │   │   └── vector_config.ex
│   │   ├── protocol/               # Protocol-based HTTP client
│   │   │   └── http/
│   │   │       └── client.ex
│   │   └── ...
│   └── mix/
│       └── tasks/                  # Mix tasks
│           ├── weaviate.start.ex
│           ├── weaviate.stop.ex
│           ├── weaviate.status.ex
│           └── weaviate.logs.ex
├── test/                           # Test suite
├── examples/                       # Runnable examples (in source repo)
├── docker-compose.yml              # Weaviate Docker setup
├── install.sh                      # Automated installation
└── mix.exs                         # Project configuration
```

## Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Write tests**: All new features should include tests
4. **Run tests**: `mix test` (should pass)
5. **Run Credo**: `mix credo` (should pass)
6. **Commit changes**: `git commit -m 'Add amazing feature'`
7. **Push to branch**: `git push origin feature/amazing-feature`
8. **Open a Pull Request**

### Development Guidelines

- Write tests first (TDD approach)
- Maintain test coverage above 90%
- Follow Elixir style guide
- Add typespecs for public functions
- Update documentation for API changes
- Add examples for new features

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built for [Weaviate](https://weaviate.io) vector database
- Inspired by official Python and TypeScript clients
- Uses [Finch](https://github.com/sneako/finch) for HTTP/2 connection pooling
- Powered by Elixir and the BEAM VM

---

**Questions or Issues?** Open an issue on [GitHub](https://github.com/yourusername/weaviate_ex/issues)
