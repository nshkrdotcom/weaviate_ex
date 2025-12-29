<p align="center">
  <img src="assets/weaviate_ex.svg" alt="WeaviateEx Logo" width="200" height="200">
</p>

# WeaviateEx

[![Elixir](https://img.shields.io/badge/elixir-1.18-purple.svg)](https://elixir-lang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/weaviate_ex.svg)](https://hex.pm/packages/weaviate_ex)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/weaviate_ex)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-881%20passing-brightgreen.svg)](https://github.com/nshkrdotcom/weaviate_ex)

A modern, idiomatic Elixir client for [Weaviate](https://weaviate.io) vector database (v1.28+) with **full Python client feature parity**.

## Features

### Core Capabilities
- **Complete API Coverage** - Collections, objects, batch operations, queries, aggregations, cross-references, tenants
- **RBAC & User Management** - Full role-based access control, user lifecycle management, OIDC groups
- **Hybrid Protocol Architecture** - gRPC for high-performance data operations, HTTP for schema management
- **Type-Safe** - Protocol-based architecture with comprehensive typespecs
- **Test-First Design** - 1000+ tests with Mox-based mocking for fast, isolated testing
- **Production-Ready** - gRPC persistent channels, Finch HTTP pooling, proper error handling, health checks
- **Easy Setup** - First-class Mix tasks for managing local Weaviate stacks

### Generative AI (RAG) - 20+ Providers
- **OpenAI** (GPT-4, GPT-3.5, O1/O3 reasoning models)
- **Anthropic** (Claude 3.5 Sonnet, Claude 3 Opus/Haiku)
- **Cohere**, **Google Vertex/Gemini**, **AWS Bedrock/SageMaker**
- **Mistral**, **Ollama**, **XAI (Grok)**, **ContextualAI**
- **NEW in v0.3**: NVIDIA NIM, Databricks, FriendliAI
- Typed provider configurations with full parameter support
- Multimodal generation with image support

### Vector Search
- **Semantic Search** - near_text, near_vector, near_object
- **Hybrid Search** - Combined keyword + vector with configurable alpha
- **BM25 Keyword Search** - Full-text search with AND/OR operators
- **Multi-Vector Support** - ColBERT-style embeddings with Muvera encoding
- **Named Vectors** - Multiple vectors per object with targeting strategies

### Advanced Features
- **Cross-References** - Full CRUD for object relationships
- **Multi-Tenancy** - HOT, COLD, FROZEN, OFFLOADED states
- **Batch Operations** - Error tracking, retry logic, rate limit handling
- **Embedded Mode** - Run Weaviate without Docker
- **15+ Vectorizers** - OpenAI, Cohere, VoyageAI, Jina, and more

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Embedded Mode](#embedded-mode)
  - [Health Checks](#health-checks)
  - [Collections (Schema Management)](#collections-schema-management)
  - [Data Operations (CRUD)](#data-operations-crud)
  - [Objects API](#objects-api)
  - [Batch Operations](#batch-operations)
  - [Queries & Vector Search](#queries--vector-search)
  - [Aggregations](#aggregations)
  - [Advanced Filtering](#advanced-filtering)
  - [Vector Configuration](#vector-configuration)
  - [Backup & Restore](#backup--restore)
  - [Multi-Tenancy](#multi-tenancy)
  - [RBAC (Role-Based Access Control)](#rbac-role-based-access-control)
  - [User Management](#user-management)
  - [Group Management](#group-management)
- [Examples](#examples)
- [Testing](#testing)
- [Mix Tasks](#mix-tasks)
- [Docker Management](#docker-management)
- [Authentication](#authentication)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

### 1. Start Weaviate locally

> 🧰 **Prerequisite**: Docker Desktop (macOS/Windows) or Docker Engine (Linux)

We ship the full set of Docker Compose profiles from the Python client under `ci/weaviate/`. Use our Mix tasks to bring everything up:

```bash
# Boot every profile (single node, modules, RBAC, async, cluster, proxy, etc.)
mix weaviate.start --version latest

# Inspect running services and exposed ports
mix weaviate.status
```

The first run downloads several images (contextionary, proxy, multiple Weaviate variants) and waits for every `/v1/.well-known/ready` endpoint to return `200`. Expect it to take a couple of minutes on a fresh machine.

When you're done:

```bash
mix weaviate.stop --version latest
```

Need only the async “journey tests” stack? Pass `--profile async` to `mix weaviate.start`. The tasks accept any Docker image tag, so swap `latest` for an explicit `1.30.5` (or export `WEAVIATE_VERSION` to suppress Docker’s warning banners).

> Prefer the classic single-node setup? `./install.sh` still exists and brings up the minimal compose file, but the Mix tasks give you the full parity matrix the Python client uses for integration testing.

### 2. Add to Your Project

Add `weaviate_ex` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:weaviate_ex, "~> 0.5.0"}
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
  Version: 1.34.0-rc.0

```

You can also run `mix weaviate.status` to see every profile that’s currently online and the ports they expose.

If configuration is missing, you'll get helpful error messages:

```
╔══════════════════════════════════════════════════════════════════════╗
║                  WeaviateEx Configuration Error                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  Missing required configuration: WEAVIATE_URL                        ║
║                                                                      ║
║  Please set the Weaviate URL using one of these methods:             ║
║  1. Environment variable: export WEAVIATE_URL=http://localhost:8080  ║
║  2. Application configuration (config/config.exs)                    ║
║  3. Runtime configuration (config/runtime.exs)                       ║
╚══════════════════════════════════════════════════════════════════════╝
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

### gRPC Configuration

WeaviateEx v0.4.0+ uses a hybrid protocol architecture: gRPC for data operations (queries, batch, aggregations) and HTTP for schema management. gRPC provides significantly better performance for high-throughput operations.

```elixir
# config/config.exs
config :weaviate_ex,
  url: "http://localhost:8080",       # HTTP endpoint for schema operations
  grpc_host: "localhost",             # gRPC host (default: derived from url)
  grpc_port: 50051,                   # gRPC port (default: 50051)
  grpc_max_message_size: 104_857_600, # Max message size in bytes (default: 100MB)
  api_key: nil                        # Used for both HTTP and gRPC auth
```

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `grpc_host` | No | Derived from `url` | gRPC endpoint hostname |
| `grpc_port` | No | `50051` | gRPC port |
| `grpc_max_message_size` | No | `104857600` | Maximum gRPC message size (100MB) |

The gRPC connection is automatically established when you create a client:

```elixir
# Connect with gRPC (automatic)
{:ok, client} = WeaviateEx.Client.connect(
  url: "http://localhost:8080",
  grpc_port: 50051
)

# Client now has both HTTP and gRPC channels
client.grpc_channel  # => gRPC channel for data operations
client.config        # => Configuration for HTTP operations
```

### Proxy Configuration (v0.5.0+)

WeaviateEx supports HTTP, HTTPS, and gRPC proxy configuration:

```elixir
alias WeaviateEx.Config.Proxy

# Read from environment variables (HTTP_PROXY, HTTPS_PROXY, GRPC_PROXY)
proxy = Proxy.from_env()

# Or configure explicitly
proxy = Proxy.new(
  http: "http://proxy.example.com:8080",
  https: "https://proxy.example.com:8443",
  grpc: "http://grpc-proxy.example.com:8080"
)

# Check if proxy is configured
Proxy.configured?(proxy)  # => true

# Get Finch HTTP client options
Proxy.to_finch_opts(proxy)  # => [proxy: {:https, "proxy.example.com", 8443, []}]

# Get gRPC channel options
Proxy.to_grpc_opts(proxy)   # => [http_proxy: "http://grpc-proxy.example.com:8080"]
```

Environment variables are read case-insensitively (uppercase takes precedence):
- `HTTP_PROXY` / `http_proxy` - HTTP proxy URL
- `HTTPS_PROXY` / `https_proxy` - HTTPS proxy URL
- `GRPC_PROXY` / `grpc_proxy` - gRPC proxy URL

### Runtime Configuration (Recommended for Production)

```elixir
# config/runtime.exs
config :weaviate_ex,
  url: System.fetch_env!("WEAVIATE_URL"),
  api_key: System.get_env("WEAVIATE_API_KEY")
```

## Usage

### Embedded Mode

Need an ephemeral instance without Docker? WeaviateEx can download and manage the official embedded binary:

```elixir
# Downloads (once) into ~/.cache/weaviate-embedded and starts the process
{:ok, embedded} =
  WeaviateEx.start_embedded(
    version: "1.34.0",
    port: 8099,
    grpc_port: 50155,
    persistence_data_path: Path.expand("tmp/weaviate-data"),
    environment_variables: %{"DISABLE_TELEMETRY" => "true"}
  )

# Talk to it just like any other instance
System.put_env("WEAVIATE_URL", "http://localhost:8099")
{:ok, meta} = WeaviateEx.health_check()

# Always stop the handle when finished
:ok = WeaviateEx.stop_embedded(embedded)
```

Passing `version: "latest"` fetches the most recent GitHub release. Binaries are cached, so subsequent calls reuse the download. You can override `binary_path`/`persistence_data_path` to control where the executable and data live.

### Health Checks

Check if Weaviate is accessible and get version information:

```elixir
# Get metadata (version, modules)
{:ok, meta} = WeaviateEx.health_check()
# => %{"version" => "1.34.0-rc.0", "modules" => %{}}

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

# Semantic direction with Move (v0.5.0+)
query = Query.get("Article")
  |> Query.near_text("technology",
       move_to: [concepts: ["artificial intelligence", "machine learning"], force: 0.8],
       move_away: [concepts: ["politics", "sports"], force: 0.5]
     )
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

### Inverted Index Configuration (v0.5.0+)

Configure BM25 and stopwords for full-text search:

```elixir
alias WeaviateEx.API.InvertedIndexConfig

# Configure BM25 algorithm parameters
bm25_config = InvertedIndexConfig.bm25(b: 0.75, k1: 1.2)

# Configure stopwords with English preset and customizations
stopwords = InvertedIndexConfig.stopwords(
  preset: :en,
  additions: ["foo", "bar"],
  removals: ["the"]
)

# Build complete inverted index configuration
config = InvertedIndexConfig.build(
  bm25: [b: 0.8, k1: 1.5],
  stopwords: [preset: :en],
  index_timestamps: true,
  index_property_length: true,
  index_null_state: false,
  cleanup_interval_seconds: 60
)

# Validate configuration
{:ok, validated} = InvertedIndexConfig.validate(config)

# Merge configurations
merged = InvertedIndexConfig.merge(base_config, override_config)
```

### Backup & Restore

Complete backup and restore operations with multiple storage backends:

```elixir
alias WeaviateEx.Backup.{Config, Location}

# Create a backup to filesystem
{:ok, status} = WeaviateEx.create_backup(client, "daily-backup", :filesystem)

# Create backup to S3 with specific collections and wait for completion
{:ok, status} = WeaviateEx.create_backup(client, "daily-backup", :s3,
  include_collections: ["Article", "Author"],
  wait_for_completion: true,
  config: Config.create(compression: :best_compression)
)

# Check backup status
{:ok, status} = WeaviateEx.get_backup_status(client, "daily-backup", :filesystem)
IO.puts("Status: #{status.status}")  # :started, :transferring, :success, etc.

# List all backups
{:ok, backups} = WeaviateEx.list_backups(client, :filesystem)

# Restore a backup
{:ok, status} = WeaviateEx.restore_backup(client, "daily-backup", :filesystem,
  wait_for_completion: true
)

# Restore specific collections only
{:ok, status} = WeaviateEx.restore_backup(client, "daily-backup", :s3,
  include_collections: ["Article"]
)

# Cancel an in-progress backup
:ok = WeaviateEx.cancel_backup(client, "daily-backup", :filesystem)
```

#### Storage Backends

| Backend | Description | Configuration |
|---------|-------------|---------------|
| `:filesystem` | Local filesystem | `BACKUP_FILESYSTEM_PATH` on server |
| `:s3` | Amazon S3 / S3-compatible | Bucket, region, credentials |
| `:gcs` | Google Cloud Storage | Bucket, project ID, credentials |
| `:azure` | Azure Blob Storage | Container, connection string |

#### Compression Options (v0.5.0+)

```elixir
alias WeaviateEx.Backup.{Config, Compression}

# GZIP compression (default)
Config.create(compression: :default)          # Balanced GZIP
Config.create(compression: :best_speed)       # Fast GZIP
Config.create(compression: :best_compression) # Max GZIP

# ZSTD compression (faster, better ratios)
Config.create(compression: :zstd_default)          # Balanced ZSTD
Config.create(compression: :zstd_best_speed)       # Fast ZSTD
Config.create(compression: :zstd_best_compression) # Max ZSTD

# No compression
Config.create(compression: :no_compression)

# Check compression type
Compression.gzip?(:default)  # => true
Compression.zstd?(:zstd_default)  # => true
```

#### Location Configuration (Advanced)

```elixir
alias WeaviateEx.Backup.Location

# Create location configs for cloud backends
s3_loc = Location.s3("my-bucket", "/backups",
  endpoint: "s3.us-west-2.amazonaws.com",
  region: "us-west-2",
  access_key_id: "...",
  secret_access_key: "..."
)

gcs_loc = Location.gcs("my-bucket", "/backups",
  project_id: "my-project",
  credentials: %{...}
)

azure_loc = Location.azure("my-container", "/backups",
  connection_string: "..."
)
```

### Collection Aliases (v0.5.0+)

Aliases allow zero-downtime collection updates by providing alternative names:

```elixir
alias WeaviateEx.API.Aliases

# Create an alias (requires Weaviate v1.32.0+)
{:ok, _} = Aliases.create(client, "articles", "Article_v1")

# List all aliases
{:ok, aliases} = Aliases.list(client)
# => [%Alias{alias: "articles", collection: "Article_v1"}]

# Update alias to point to new collection (blue-green deployment)
{:ok, _} = Aliases.update(client, "articles", "Article_v2")

# Get alias details
{:ok, alias_info} = Aliases.get(client, "articles")
# => %Alias{alias: "articles", collection: "Article_v2"}

# Check if alias exists
{:ok, true} = Aliases.exists?(client, "articles")

# Delete alias (underlying collection remains)
{:ok, true} = Aliases.delete(client, "articles")
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

### RBAC (Role-Based Access Control)

WeaviateEx provides full RBAC support for managing roles, permissions, users, and groups.

#### Creating Roles with Permissions

```elixir
alias WeaviateEx.API.RBAC
alias WeaviateEx.RBAC.Permissions

# Define permissions using the builder API
permissions = [
  Permissions.collections("Article", [:read, :create]),
  Permissions.data("Article", [:read, :create, :update]),
  Permissions.tenants("Article", [:read])
]

# Create a role
{:ok, role} = RBAC.create_role(client, "article-editor", permissions)

# List all roles
{:ok, roles} = RBAC.list_roles(client)

# Check if role has specific permissions
{:ok, true} = RBAC.has_permissions?(client, "article-editor",
  [Permissions.data("Article", :read)]
)

# Add more permissions to a role
:ok = RBAC.add_permissions(client, "article-editor",
  [Permissions.nodes(:verbose)]
)

# Delete a role
:ok = RBAC.delete_role(client, "article-editor")
```

#### Permission Types

| Type | Actions | Description |
|------|---------|-------------|
| collections | create, read, update, delete, manage | Collection schema operations |
| data | create, read, update, delete, manage | Object CRUD operations |
| tenants | create, read, update, delete | Multi-tenancy management |
| roles | create, read, update, delete | Role management |
| users | create, read, update, delete, assign_and_revoke | User management |
| groups | read, assign_and_revoke | OIDC group management |
| cluster | read | Cluster information |
| nodes | read (minimal/verbose) | Node information |
| backups | manage | Backup operations |
| replicate | create, read, update, delete | Replication management |
| alias | create, read, update, delete | Collection aliases |

### User Management

```elixir
alias WeaviateEx.API.Users

# Create a new DB user (returns API key)
{:ok, user} = Users.create(client, "john.doe")
IO.puts("API Key: #{user.api_key}")

# Get user info
{:ok, user} = Users.get(client, "john.doe")

# Get current authenticated user
{:ok, me} = Users.get_my_user(client)

# Assign roles to user
:ok = Users.assign_roles(client, "john.doe", ["article-editor", "viewer"])

# Revoke roles from user
:ok = Users.revoke_roles(client, "john.doe", ["viewer"])

# Get user's assigned roles
{:ok, roles} = Users.get_assigned_roles(client, "john.doe")

# Rotate API key
{:ok, new_key} = Users.rotate_key(client, "john.doe")

# Deactivate/activate user
:ok = Users.deactivate(client, "john.doe")
:ok = Users.activate(client, "john.doe")

# Delete user
:ok = Users.delete(client, "john.doe")
```

### Group Management

OIDC group management for role assignments:

```elixir
alias WeaviateEx.API.Groups

# List known OIDC groups
{:ok, groups} = Groups.list_known(client)

# Assign roles to a group
:ok = Groups.assign_roles(client, "engineering", ["developer", "viewer"])

# Get roles assigned to a group
{:ok, roles} = Groups.get_assigned_roles(client, "engineering")

# Revoke roles from a group
:ok = Groups.revoke_roles(client, "engineering", ["admin"])
```

## Examples

WeaviateEx includes **8 runnable examples** that demonstrate all major features:

| Example | Description | What You'll Learn |
|---------|-------------|-------------------|
| `01_collections.exs` | Collection management | Create, list, get, add properties, delete collections |
| `02_data.exs` | CRUD operations | Insert, get, patch, check existence, delete objects |
| `03_filter.exs` | Advanced filtering | Equality, comparison, pattern matching, geo, array filters |
| `04_aggregate.exs` | Aggregations | Count, statistics, top occurrences, group by |
| `05_vector_config.exs` | Vector configuration | HNSW, PQ compression, flat index, distance metrics |
| `06_tenants.exs` | Multi-tenancy | Create tenants, activate/deactivate, list, delete |
| `07_batch.exs` | Batch API | Bulk create/delete with summaries, query remaining data |
| `08_query.exs` | Query builder | BM25 search, filters, near-vector similarity |

### Prerequisites

Follow these steps once before running any example:

1. **Start the local stack** (full profile with all compose files):

   ```bash
   # from the project root
   mix weaviate.start --version latest
   # or use the helper script
   ./scripts/weaviate-stack.sh start --version latest
   ```

   To shut everything down afterwards use `mix weaviate.stop --version latest` (or `./scripts/weaviate-stack.sh stop`).

2. **Confirm the services are healthy** (optional but recommended):

   ```bash
   mix weaviate.status
   ```

3. **Point the client at the running cluster** (avoids repeated configuration warnings):

   ```bash
   export WEAVIATE_URL=http://localhost:8080
   # set WEAVIATE_API_KEY=... as well if your instance requires auth
   ```

### Running Examples

All examples are self-contained and include clean visual output:

```bash
# With WEAVIATE_URL exported

# Run any example
mix run examples/01_collections.exs
mix run examples/02_data.exs
mix run examples/03_filter.exs
# ... etc

# Or run all examples
for example in examples/*.exs; do
  echo "Running $example..."
  mix run "$example"
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
- ✅ Uses Mox to mock HTTP/Protocol and gRPC responses
- ✅ No Weaviate instance required
- ✅ Fast execution (~0.2 seconds)
- ✅ 1575 unit tests
- ✅ Perfect for TDD and CI/CD

**Integration Mode** - Real Weaviate testing:
- ✅ Tests against live Weaviate instance
- ✅ Validates actual API behavior
- ✅ Requires Weaviate running locally
- ✅ Run with `--include integration` flag
- ✅ 53 integration tests

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
- ✅ **Batch Operations**: 35+ tests - Bulk create, delete, error tracking, retry logic
- ✅ **Query System**: 60+ tests - GraphQL, near_text, hybrid, BM25, move, rerank, groupBy
- ✅ **Aggregations**: 15+ tests - Count, statistics, group by
- ✅ **Tenants**: 20+ tests - Multi-tenancy with freeze/offload states
- ✅ **References**: 10+ tests - Cross-reference CRUD, multi-target references
- ✅ **Generative AI**: 62 tests - All providers, typed configs, result parsing
- ✅ **Vector Config**: 15+ tests - HNSW, PQ, flat index, multi-vector
- ✅ **Multi-Vector**: 10+ tests - ColBERT, Muvera encoding, Jina vectorizers
- ✅ **gRPC Services**: 50+ tests - Channel management, search, batch, aggregate, tenants, health
- ✅ **gRPC Error Handling**: 30+ tests - Status code mapping, retryable errors

**Total: 1575 tests passing**

## Mix Tasks

Our developer tooling mirrors the Python client’s workflows by shelling out to the Compose scripts in `ci/weaviate/`:

```bash
# Start every profile with a specific Weaviate tag (default: latest)
mix weaviate.start --version 1.34.0

# Only bring up the async/journey-test stack
mix weaviate.start --profile async --version latest

# Stop containers (match the version you started with)
mix weaviate.stop --version latest

# Tear everything down and wipe named volumes
mix weaviate.stop --version latest --remove-volumes

# See container status for each compose file and exposed ports
mix weaviate.status

# Tail the last 100 lines from a specific compose file
mix weaviate.logs --file docker-compose-backup.yml --tail 100

# Follow logs for the async profile
mix weaviate.logs --file docker-compose-async.yml --follow
```

> ℹ️ The log and status tasks execute `docker compose -f ci/weaviate/<file> …`. If you don’t want to pass `--version` every time, export `WEAVIATE_VERSION=<tag>` in your shell to avoid Docker warnings about missing variables.

### Helper script

Prefer a single entry point? Use the convenience wrapper in `scripts/`:

```bash
# Show help
./scripts/weaviate-stack.sh help

# Run the full start → status → logs → stop cycle
./scripts/weaviate-stack.sh cycle

# Start only the async profile with a specific tag
./scripts/weaviate-stack.sh start --profile async --version 1.34.0
```

The script simply forwards to the Mix tasks under the hood, adding a friendly help menu and defaults (`--version latest`, logs from `docker-compose.yml`, tail 20 lines).

## Docker Management

### Using the bundled scripts

All Compose profiles live under `ci/weaviate/` (ported straight from the Python client). The shell helpers there mirror our Mix tasks:

```bash
# Start every profile (single node, modules, RBAC, cluster, async, proxy…)
./ci/weaviate/start_weaviate.sh latest

# Async-only sandbox for journey tests
./ci/weaviate/start_weaviate_jt.sh latest

# Stop whatever is running
./ci/weaviate/stop_weaviate.sh latest
```

Edit `ci/weaviate/compose.sh` if you add/remove compose files so the scripts (and Mix tasks) continue to iterate over the correct set.

### Direct Docker Compose commands

You can operate on any profile manually by passing `-f ci/weaviate/<file>`:

```bash
# Spawn just the baseline stack
docker compose -f ci/weaviate/docker-compose.yml up -d

# Inspect the cluster nodes
docker compose -f ci/weaviate/docker-compose-cluster.yml ps

# Tail logs for the RBAC profile
docker compose -f ci/weaviate/docker-compose-rbac.yml logs -f

# Remove everything (data included)
docker compose -f ci/weaviate/docker-compose.yml down -v
```

### Troubleshooting tips

```bash
# Confirm Docker is running
docker info

# See which services are up for a given profile
docker compose -f ci/weaviate/docker-compose-backup.yml ps -a

# Check the ready endpoint of the primary instance
curl http://localhost:8080/v1/.well-known/ready

# Query metadata
curl http://localhost:8080/v1/meta
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
- **Examples** - 8 runnable examples in the GitHub repository (see [Examples](#examples) section)

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
├── ci/
│   └── weaviate/                   # Docker assets mirrored from Python client
│       ├── compose.sh
│       ├── start_weaviate.sh
│       ├── docker-compose.yml
│       └── docker-compose-*.yml
├── priv/
│   └── protos/v1/                  # Weaviate gRPC proto definitions
│       ├── weaviate.proto
│       ├── batch.proto
│       ├── search_get.proto
│       └── ...
├── lib/
│   ├── weaviate_ex.ex              # Top-level API
│   ├── weaviate_ex/
│   │   ├── embedded.ex             # Embedded binary lifecycle manager
│   │   ├── dev_support/            # Internal tooling (compose helper)
│   │   ├── application.ex          # OTP application
│   │   ├── client.ex               # Client struct & config
│   │   ├── config.ex               # Configuration management
│   │   ├── error.ex                # Error types (HTTP + gRPC)
│   │   ├── filter.ex               # Filter DSL
│   │   ├── api/                    # API modules
│   │   │   ├── collections.ex
│   │   │   ├── data.ex
│   │   │   ├── aggregate.ex
│   │   │   ├── tenants.ex
│   │   │   └── vector_config.ex
│   │   ├── grpc/                   # gRPC infrastructure
│   │   │   ├── channel.ex          # Channel management
│   │   │   ├── services/           # gRPC service clients
│   │   │   │   ├── search.ex
│   │   │   │   ├── batch.ex
│   │   │   │   ├── aggregate.ex
│   │   │   │   ├── tenants.ex
│   │   │   │   └── health.ex
│   │   │   └── generated/v1/       # Proto-generated modules
│   │   └── ...
│   └── mix/
│       └── tasks/
│           ├── weaviate.start.ex
│           ├── weaviate.stop.ex
│           ├── weaviate.status.ex
│           └── weaviate.logs.ex
├── test/                           # Test suite
├── examples/                       # Runnable examples (in source repo)
├── install.sh                      # Legacy single-profile bootstrap
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
- Uses [grpc-elixir](https://github.com/elixir-grpc/grpc) for high-performance gRPC operations
- Uses [Finch](https://github.com/sneako/finch) for HTTP/2 connection pooling (schema operations)
- Powered by Elixir and the BEAM VM

---

**Questions or Issues?** Open an issue on [GitHub](https://github.com/yourusername/weaviate_ex/issues)
