# WeaviateEx Architecture Design

> Clean, production-ready architecture for 100% feature parity with weaviate-python-client

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Directory Structure](#directory-structure)
3. [Module Organization](#module-organization)
4. [Protocol Layer](#protocol-layer)
5. [Client Architecture](#client-architecture)
6. [Configuration System](#configuration-system)
7. [Error Handling](#error-handling)
8. [Testing Strategy](#testing-strategy)

---

## Design Principles

### 1. Separation of Concerns
- **Protocol Layer**: HTTP/gRPC transport (Finch, Gun)
- **API Layer**: Domain-specific operations (Collections, Data, Query)
- **Client Layer**: Connection management and configuration
- **Type Layer**: Structs, schemas, validation

### 2. Composability
- Fluent query builders with pipe-friendly APIs
- Modular configuration builders
- Pluggable protocols and auth mechanisms

### 3. Performance
- Connection pooling (Finch for HTTP, Gun for gRPC)
- Batch operations with streaming
- Lazy evaluation where possible
- Protocol selection (prefer gRPC for bulk operations)

### 4. Reliability
- Comprehensive error handling
- Retry mechanisms with backoff
- Circuit breaker pattern
- Graceful degradation (gRPC → HTTP fallback)

### 5. Developer Experience
- Clear, documented APIs
- Helpful error messages
- Typespecs for everything
- Pattern matching for results

---

## Directory Structure

```
weaviate_ex/
├── lib/
│   ├── weaviate_ex.ex                      # Main entry point and client facade
│   │
│   ├── weaviate_ex/
│   │   ├── application.ex                  # OTP application supervisor
│   │   │
│   │   ├── client/                         # Client management
│   │   │   ├── client.ex                   # Client struct and lifecycle
│   │   │   ├── connection.ex               # Connection management
│   │   │   ├── config.ex                   # Client configuration
│   │   │   └── supervisor.ex               # Per-client supervision tree
│   │   │
│   │   ├── auth/                           # Authentication
│   │   │   ├── auth.ex                     # Auth behavior and facade
│   │   │   ├── api_key.ex                  # API key auth
│   │   │   ├── bearer.ex                   # Bearer token auth
│   │   │   ├── oauth2_client_credentials.ex
│   │   │   └── oauth2_password.ex
│   │   │
│   │   ├── protocol/                       # Protocol implementations
│   │   │   ├── protocol.ex                 # Protocol behavior
│   │   │   ├── http/
│   │   │   │   ├── client.ex               # HTTP client (Finch)
│   │   │   │   ├── request.ex              # HTTP request builder
│   │   │   │   └── response.ex             # HTTP response parser
│   │   │   └── grpc/
│   │   │       ├── client.ex               # gRPC client (Gun + protobuf)
│   │   │       ├── connection.ex           # gRPC connection pool
│   │   │       └── protocol/               # Generated protobuf files
│   │   │           ├── base.pb.ex
│   │   │           ├── batch.pb.ex
│   │   │           └── ...
│   │   │
│   │   ├── api/                            # API namespaces
│   │   │   ├── collections.ex              # Collection management
│   │   │   ├── data.ex                     # Object CRUD
│   │   │   ├── batch.ex                    # Batch operations
│   │   │   ├── query.ex                    # Query operations
│   │   │   ├── aggregate.ex                # Aggregation operations
│   │   │   ├── generate.ex                 # Generative search (RAG)
│   │   │   ├── backup.ex                   # Backup/restore
│   │   │   ├── cluster.ex                  # Cluster operations
│   │   │   ├── tenants.ex                  # Multi-tenancy
│   │   │   ├── users.ex                    # User management
│   │   │   ├── roles.ex                    # RBAC
│   │   │   ├── aliases.ex                  # Aliases
│   │   │   └── debug.ex                    # Debug/diagnostics
│   │   │
│   │   ├── collection/                     # Collection-scoped operations
│   │   │   ├── collection.ex               # Collection context struct
│   │   │   ├── data.ex                     # Collection.Data namespace
│   │   │   ├── query.ex                    # Collection.Query namespace
│   │   │   ├── batch.ex                    # Collection.Batch namespace
│   │   │   ├── aggregate.ex                # Collection.Aggregate namespace
│   │   │   ├── generate.ex                 # Collection.Generate namespace
│   │   │   ├── tenants.ex                  # Collection.Tenants namespace
│   │   │   ├── config.ex                   # Collection.Config namespace
│   │   │   └── backups.ex                  # Collection.Backups namespace
│   │   │
│   │   ├── query/                          # Query builders
│   │   │   ├── builder.ex                  # Main query builder
│   │   │   ├── near_text.ex                # Semantic text search
│   │   │   ├── near_vector.ex              # Vector similarity search
│   │   │   ├── near_object.ex              # Similar object search
│   │   │   ├── near_image.ex               # Image similarity search
│   │   │   ├── near_media.ex               # Media similarity search
│   │   │   ├── bm25.ex                     # BM25 keyword search
│   │   │   ├── hybrid.ex                   # Hybrid search
│   │   │   ├── fetch.ex                    # Fetch operations
│   │   │   ├── filter.ex                   # Filter builder
│   │   │   ├── sort.ex                     # Sort builder
│   │   │   ├── group_by.ex                 # GroupBy builder
│   │   │   ├── metadata.ex                 # Metadata/additional fields
│   │   │   └── graphql.ex                  # GraphQL code generation
│   │   │
│   │   ├── filter/                         # Filtering system
│   │   │   ├── filter.ex                   # Filter DSL
│   │   │   ├── operators.ex                # Filter operators
│   │   │   ├── property.ex                 # Property filters
│   │   │   ├── reference.ex                # Reference filters
│   │   │   ├── geo.ex                      # Geospatial filters
│   │   │   └── combinators.ex              # AND/OR/NOT
│   │   │
│   │   ├── batch/                          # Batch operations
│   │   │   ├── batch.ex                    # Batch coordinator
│   │   │   ├── dynamic.ex                  # Dynamic batching
│   │   │   ├── fixed.ex                    # Fixed-size batching
│   │   │   ├── rate_limiter.ex             # Rate limiting
│   │   │   └── result.ex                   # Batch result handling
│   │   │
│   │   ├── config/                         # Configuration builders
│   │   │   ├── configure.ex                # Create config builder
│   │   │   ├── reconfigure.ex              # Update config builder
│   │   │   ├── property.ex                 # Property config
│   │   │   ├── reference_property.ex       # Reference config
│   │   │   ├── vectorizer/                 # Vectorizer configs
│   │   │   │   ├── vectorizer.ex           # Base vectorizer
│   │   │   │   ├── text2vec/               # Text vectorizers
│   │   │   │   │   ├── openai.ex
│   │   │   │   │   ├── cohere.ex
│   │   │   │   │   ├── huggingface.ex
│   │   │   │   │   └── ... (25+ files)
│   │   │   │   ├── multi2vec/              # Multimodal vectorizers
│   │   │   │   │   ├── clip.ex
│   │   │   │   │   ├── bind.ex
│   │   │   │   │   └── ...
│   │   │   │   └── img2vec/                # Image vectorizers
│   │   │   │       └── neural.ex
│   │   │   ├── generative/                 # Generative configs
│   │   │   │   ├── generative.ex           # Base generative
│   │   │   │   ├── openai.ex
│   │   │   │   ├── anthropic.ex
│   │   │   │   ├── cohere.ex
│   │   │   │   └── ... (13+ files)
│   │   │   ├── vector_index/               # Vector index configs
│   │   │   │   ├── hnsw.ex
│   │   │   │   ├── flat.ex
│   │   │   │   ├── dynamic.ex
│   │   │   │   └── quantization/
│   │   │   │       ├── pq.ex               # Product quantization
│   │   │   │       ├── bq.ex               # Binary quantization
│   │   │   │       ├── sq.ex               # Scalar quantization
│   │   │   │       └── rq.ex               # Random quantization
│   │   │   ├── inverted_index.ex           # Inverted index config
│   │   │   ├── multi_tenancy.ex            # Multi-tenancy config
│   │   │   ├── replication.ex              # Replication config
│   │   │   └── sharding.ex                 # Sharding config
│   │   │
│   │   ├── types/                          # Data types and schemas
│   │   │   ├── data_type.ex                # Data type enum
│   │   │   ├── data_object.ex              # Data object struct
│   │   │   ├── reference.ex                # Reference struct
│   │   │   ├── geo_coordinate.ex           # GeoCoordinate
│   │   │   ├── phone_number.ex             # PhoneNumber
│   │   │   ├── uuid.ex                     # UUID helpers
│   │   │   ├── consistency_level.ex        # Consistency enum
│   │   │   ├── distance.ex                 # Distance metrics
│   │   │   ├── tokenization.ex             # Tokenization enum
│   │   │   ├── stopwords.ex                # Stopwords presets
│   │   │   └── tenant.ex                   # Tenant struct
│   │   │
│   │   ├── response/                       # Response models
│   │   │   ├── query_result.ex             # Query response
│   │   │   ├── aggregate_result.ex         # Aggregation response
│   │   │   ├── batch_result.ex             # Batch response
│   │   │   ├── generative_result.ex        # Generative response
│   │   │   ├── collection.ex               # Collection response
│   │   │   ├── object.ex                   # Object response
│   │   │   ├── tenant.ex                   # Tenant response
│   │   │   ├── backup.ex                   # Backup response
│   │   │   ├── cluster.ex                  # Cluster response
│   │   │   └── error.ex                    # Error response
│   │   │
│   │   ├── error/                          # Error types
│   │   │   ├── error.ex                    # Base error
│   │   │   ├── connection_error.ex
│   │   │   ├── authentication_error.ex
│   │   │   ├── validation_error.ex
│   │   │   ├── query_error.ex
│   │   │   ├── batch_error.ex
│   │   │   ├── timeout_error.ex
│   │   │   ├── unsupported_feature_error.ex
│   │   │   └── status_code_error.ex
│   │   │
│   │   ├── util/                           # Utilities
│   │   │   ├── retry.ex                    # Retry logic with backoff
│   │   │   ├── circuit_breaker.ex          # Circuit breaker
│   │   │   ├── validation.ex               # Validation helpers
│   │   │   ├── json.ex                     # JSON encoding/decoding
│   │   │   └── uuid.ex                     # UUID generation
│   │   │
│   │   └── telemetry.ex                    # Telemetry events
│   │
│   └── mix/tasks/                          # Mix tasks
│       ├── weaviate.start.ex
│       ├── weaviate.stop.ex
│       ├── weaviate.status.ex
│       └── weaviate.logs.ex
│
├── test/
│   ├── test_helper.exs                     # Test setup and Mox config
│   │
│   ├── support/                            # Test support files
│   │   ├── fixtures.ex                     # Test fixtures
│   │   ├── factory.ex                      # Data factory
│   │   ├── mocks.ex                        # Mock definitions
│   │   ├── assertions.ex                   # Custom assertions
│   │   └── bypass_helpers.ex               # Bypass helpers
│   │
│   ├── weaviate_ex/                        # Unit tests (with mocks)
│   │   ├── client/
│   │   │   ├── client_test.exs
│   │   │   ├── connection_test.exs
│   │   │   └── config_test.exs
│   │   ├── auth/
│   │   │   ├── api_key_test.exs
│   │   │   ├── bearer_test.exs
│   │   │   └── oauth2_test.exs
│   │   ├── protocol/
│   │   │   ├── http_test.exs
│   │   │   └── grpc_test.exs
│   │   ├── api/
│   │   │   ├── collections_test.exs
│   │   │   ├── data_test.exs
│   │   │   ├── batch_test.exs
│   │   │   ├── query_test.exs
│   │   │   ├── aggregate_test.exs
│   │   │   ├── generate_test.exs
│   │   │   ├── backup_test.exs
│   │   │   ├── cluster_test.exs
│   │   │   ├── tenants_test.exs
│   │   │   ├── users_test.exs
│   │   │   ├── roles_test.exs
│   │   │   └── aliases_test.exs
│   │   ├── query/
│   │   │   ├── builder_test.exs
│   │   │   ├── near_text_test.exs
│   │   │   ├── near_vector_test.exs
│   │   │   ├── filter_test.exs
│   │   │   └── ...
│   │   ├── filter/
│   │   │   ├── filter_test.exs
│   │   │   ├── operators_test.exs
│   │   │   └── combinators_test.exs
│   │   ├── batch/
│   │   │   ├── dynamic_test.exs
│   │   │   └── fixed_test.exs
│   │   ├── config/
│   │   │   ├── vectorizer_test.exs
│   │   │   ├── generative_test.exs
│   │   │   └── ...
│   │   └── types/
│   │       ├── data_object_test.exs
│   │       └── ...
│   │
│   ├── integration/                        # Integration tests (live)
│   │   ├── collections_integration_test.exs
│   │   ├── data_integration_test.exs
│   │   ├── batch_integration_test.exs
│   │   ├── query_integration_test.exs
│   │   ├── aggregate_integration_test.exs
│   │   ├── generate_integration_test.exs
│   │   ├── multi_tenancy_integration_test.exs
│   │   ├── backup_integration_test.exs
│   │   └── ...
│   │
│   └── property/                           # Property-based tests
│       ├── filter_property_test.exs
│       ├── batch_property_test.exs
│       └── ...
│
├── priv/                                   # Private resources
│   ├── proto/                              # Protobuf definitions
│   │   ├── base.proto
│   │   ├── batch.proto
│   │   └── ...
│   └── telemetry/
│       └── events.md                       # Telemetry event docs
│
├── config/
│   ├── config.exs                          # Shared config
│   ├── dev.exs                             # Dev config
│   ├── test.exs                            # Test config
│   └── runtime.exs                         # Runtime config
│
├── docs/                                   # Documentation
│   ├── guides/
│   │   ├── getting_started.md
│   │   ├── authentication.md
│   │   ├── queries.md
│   │   ├── filtering.md
│   │   ├── batch_operations.md
│   │   ├── multi_tenancy.md
│   │   ├── generative_search.md
│   │   └── performance_tuning.md
│   └── examples/
│       ├── basic_crud.exs
│       ├── semantic_search.exs
│       ├── rag_pipeline.exs
│       └── ...
│
├── .env.example                            # Example environment config
├── .formatter.exs                          # Code formatter config
├── .credo.exs                              # Credo config
├── .dialyzer_ignore.exs                    # Dialyzer ignores
├── docker-compose.yml                      # Docker setup
├── mix.exs                                 # Project definition
├── README.md                               # Main documentation
├── ARCHITECTURE.md                         # This file
├── FEATURE_PARITY_CHECKLIST.md            # Feature checklist
├── CHANGELOG.md                            # Version history
└── LICENSE                                 # MIT License
```

---

## Module Organization

### Core Client Module

```elixir
defmodule WeaviateEx do
  @moduledoc """
  Main entry point for the WeaviateEx client.

  ## Connection

      # Simple connection
      {:ok, client} = WeaviateEx.connect_to_local()

      # Weaviate Cloud Service
      {:ok, client} = WeaviateEx.connect_to_wcs(
        cluster_url: "https://my-cluster.weaviate.network",
        api_key: "my-api-key"
      )

      # Custom connection
      {:ok, client} = WeaviateEx.connect_to_custom(
        host: "localhost",
        http_port: 8080,
        grpc_port: 50051,
        secure: false,
        auth: WeaviateEx.Auth.api_key("my-key")
      )

  ## Client Lifecycle

      # Close connection
      :ok = WeaviateEx.close(client)

      # With block (auto-close)
      WeaviateEx.with_client(connection_opts, fn client ->
        # Use client
        WeaviateEx.Collections.list(client)
      end)
  """

  alias WeaviateEx.Client

  # Connection factory functions
  defdelegate connect_to_local(opts \\ []), to: Client
  defdelegate connect_to_wcs(opts), to: Client
  defdelegate connect_to_custom(opts), to: Client

  # Client lifecycle
  defdelegate close(client), to: Client
  defdelegate with_client(opts, fun), to: Client

  # Health checks
  defdelegate ready?(client), to: Client
  defdelegate alive?(client), to: Client
  defdelegate meta(client), to: Client

  # API namespaces
  defdelegate collections(client), to: WeaviateEx.API.Collections
  defdelegate batch(client), to: WeaviateEx.API.Batch
  defdelegate backup(client), to: WeaviateEx.API.Backup
  defdelegate cluster(client), to: WeaviateEx.API.Cluster
  defdelegate users(client), to: WeaviateEx.API.Users
  defdelegate roles(client), to: WeaviateEx.API.Roles
  defdelegate aliases(client), to: WeaviateEx.API.Aliases
end
```

### Client Structure

```elixir
defmodule WeaviateEx.Client do
  @moduledoc """
  Client context and connection management.
  """

  @type t :: %__MODULE__{
    config: WeaviateEx.Client.Config.t(),
    connection: WeaviateEx.Client.Connection.t(),
    auth: WeaviateEx.Auth.t() | nil,
    protocol: :http | :grpc | :auto,
    supervisor_pid: pid() | nil
  }

  defstruct [:config, :connection, :auth, :protocol, :supervisor_pid]

  @doc "Connect to Weaviate instance"
  @spec connect(keyword()) :: {:ok, t()} | {:error, term()}
  def connect(opts)

  @doc "Close client connection"
  @spec close(t()) :: :ok
  def close(client)

  @doc "Execute function with auto-closing client"
  @spec with_client(keyword(), (t() -> result)) :: result when result: var
  def with_client(opts, fun)
end
```

### Collection-Scoped Operations

```elixir
defmodule WeaviateEx.Collection do
  @moduledoc """
  Collection context for scoped operations.

  ## Usage

      client = WeaviateEx.connect_to_local!()
      collection = WeaviateEx.Collections.get(client, "Article")

      # Data operations
      {:ok, uuid} = WeaviateEx.Collection.Data.insert(collection, %{
        title: "Hello World",
        content: "..."
      })

      # Query operations
      {:ok, results} = WeaviateEx.Collection.Query.near_text(collection, "search term")

      # Batch operations
      {:ok, result} = WeaviateEx.Collection.Batch.insert_many(collection, objects)
  """

  @type t :: %__MODULE__{
    client: WeaviateEx.Client.t(),
    name: String.t(),
    config: map() | nil
  }

  defstruct [:client, :name, :config]

  # Sub-namespaces
  alias WeaviateEx.Collection.{Data, Query, Batch, Aggregate, Generate, Tenants, Config, Backups}
end
```

### Query Builder Pattern

```elixir
defmodule WeaviateEx.Query.Builder do
  @moduledoc """
  Fluent query builder with pipe-friendly API.

  ## Example

      alias WeaviateEx.Query
      alias WeaviateEx.Filter

      results =
        Query.new(collection)
        |> Query.near_text("machine learning")
        |> Query.where(
          Filter.by_property("category")
          |> Filter.equal("technology")
        )
        |> Query.limit(10)
        |> Query.with_additional([:id, :distance, :certainty])
        |> Query.execute()
  """

  @type t :: %__MODULE__{
    collection: WeaviateEx.Collection.t(),
    query_type: query_type(),
    parameters: map(),
    filters: WeaviateEx.Filter.t() | nil,
    fields: [String.t()],
    limit: integer() | nil,
    offset: integer() | nil,
    additional: [atom()],
    sort: [WeaviateEx.Query.Sort.t()],
    group_by: WeaviateEx.Query.GroupBy.t() | nil,
    consistency_level: atom() | nil,
    tenant: String.t() | nil
  }

  @type query_type ::
    :fetch_objects
    | :fetch_by_id
    | {:near_text, map()}
    | {:near_vector, map()}
    | {:near_object, map()}
    | {:near_image, map()}
    | {:near_media, map()}
    | {:bm25, map()}
    | {:hybrid, map()}

  defstruct [
    :collection,
    :query_type,
    :parameters,
    :filters,
    :fields,
    :limit,
    :offset,
    :additional,
    :sort,
    :group_by,
    :consistency_level,
    :tenant
  ]

  # Builder functions
  def new(collection)
  def near_text(query, concepts, opts \\ [])
  def near_vector(query, vector, opts \\ [])
  def where(query, filter)
  def limit(query, n)
  def with_additional(query, fields)
  def execute(query)
end
```

### Filter Builder DSL

```elixir
defmodule WeaviateEx.Filter do
  @moduledoc """
  Type-safe filter DSL for querying.

  ## Example

      import WeaviateEx.Filter

      filter =
        all_of([
          by_property("price") |> greater_than(100),
          by_property("category") |> equal("electronics"),
          any_of([
            by_property("brand") |> equal("Apple"),
            by_property("brand") |> equal("Samsung")
          ])
        ])
  """

  @type t :: %__MODULE__{
    operator: operator(),
    operands: [t()] | nil,
    path: [String.t()] | nil,
    value_type: value_type() | nil,
    value: term() | nil
  }

  @type operator ::
    :equal | :not_equal
    | :less_than | :less_or_equal
    | :greater_than | :greater_or_equal
    | :like
    | :within_geo_range
    | :contains_any | :contains_all | :contains_none
    | :is_none
    | :all_of | :any_of | :not

  @type value_type ::
    :text | :int | :number | :boolean | :date | :uuid | :geo | :phone

  # Constructors
  def by_property(path)
  def by_id(uuid)
  def by_ref(path)
  def by_ref_count(path)
  def by_creation_time()
  def by_update_time()

  # Operators
  def equal(filter, value)
  def not_equal(filter, value)
  def greater_than(filter, value)
  def less_than(filter, value)
  def like(filter, pattern)
  def within_geo_range(filter, coordinate, distance)
  def contains_any(filter, values)
  def is_none(filter)

  # Combinators
  def all_of(filters)
  def any_of(filters)
  def not_(filter)
end
```

### Configuration Builders

```elixir
defmodule WeaviateEx.Config.Configure do
  @moduledoc """
  Builder for collection configuration.

  ## Example

      alias WeaviateEx.Config.{Configure, Vectorizer, VectorIndex, InvertedIndex}

      config =
        Configure.collection("Article")
        |> Configure.description("News articles")
        |> Configure.vectorizer(
          Vectorizer.text2vec_openai(
            model: "text-embedding-ada-002"
          )
        )
        |> Configure.vector_index(
          VectorIndex.hnsw(
            distance_metric: :cosine,
            ef: 100,
            ef_construction: 128,
            max_connections: 64
          )
        )
        |> Configure.inverted_index(
          InvertedIndex.new(
            index_timestamps: true,
            index_null_state: true
          )
        )
        |> Configure.properties([
          Configure.property("title", :text)
          |> Configure.description("Article title")
          |> Configure.tokenization(:word),

          Configure.property("content", :text)
          |> Configure.skip_vectorization(false),

          Configure.property("publishedAt", :date)
          |> Configure.description("Publication date"),

          Configure.reference_property("author", "Author")
        ])
        |> Configure.multi_tenancy(enabled: true)
        |> Configure.replication(factor: 3)
  """

  def collection(name)
  def description(config, text)
  def vectorizer(config, vectorizer_config)
  def generative(config, generative_config)
  def vector_index(config, index_config)
  def inverted_index(config, index_config)
  def properties(config, props)
  def property(name, data_type)
  def reference_property(name, target_collection)
  def multi_tenancy(config, opts)
  def replication(config, opts)
  def sharding(config, opts)
end
```

---

## Protocol Layer

### Protocol Behavior

```elixir
defmodule WeaviateEx.Protocol do
  @moduledoc """
  Protocol behavior for HTTP and gRPC implementations.
  """

  @type client :: term()
  @type request :: map()
  @type response :: {:ok, map()} | {:error, term()}

  @callback request(client, method :: atom(), path :: String.t(), body :: map(), opts :: keyword()) :: response()
  @callback batch_request(client, operations :: [map()], opts :: keyword()) :: response()
  @callback stream_request(client, request, opts :: keyword()) :: Enumerable.t()
end
```

### HTTP Protocol

```elixir
defmodule WeaviateEx.Protocol.HTTP.Client do
  @moduledoc """
  HTTP protocol implementation using Finch.
  """

  @behaviour WeaviateEx.Protocol

  @impl true
  def request(client, method, path, body, opts) do
    # Build request
    # Add auth headers
    # Execute with Finch
    # Parse response
    # Handle errors
  end

  @impl true
  def batch_request(client, operations, opts) do
    # Batch HTTP request
  end

  @impl true
  def stream_request(client, request, opts) do
    # Streaming response handling
  end
end
```

### gRPC Protocol

```elixir
defmodule WeaviateEx.Protocol.GRPC.Client do
  @moduledoc """
  gRPC protocol implementation using Gun + protobuf.

  Provides high-performance access to Weaviate's gRPC API.
  """

  @behaviour WeaviateEx.Protocol

  @impl true
  def request(client, method, path, body, opts) do
    # Convert to protobuf message
    # Execute gRPC call
    # Parse protobuf response
    # Handle errors
  end

  @impl true
  def batch_request(client, operations, opts) do
    # High-performance gRPC batch
    # Streaming uploads
  end

  @impl true
  def stream_request(client, request, opts) do
    # gRPC streaming
  end
end
```

---

## Client Architecture

### Connection Management

```elixir
defmodule WeaviateEx.Client.Connection do
  @moduledoc """
  Connection pool and lifecycle management.
  """

  @type t :: %__MODULE__{
    http_pool: atom() | nil,
    grpc_conn: pid() | nil,
    base_url: String.t(),
    grpc_host: String.t() | nil,
    grpc_port: integer() | nil,
    secure: boolean()
  }

  defstruct [:http_pool, :grpc_conn, :base_url, :grpc_host, :grpc_port, :secure]

  @doc "Initialize connection pools"
  def init(config)

  @doc "Close all connections"
  def close(connection)

  @doc "Health check"
  def health_check(connection)
end
```

### Supervision Tree

```
WeaviateEx.Application
├── WeaviateEx.Finch (HTTP connection pool)
├── WeaviateEx.Client.Registry (client registry)
└── DynamicSupervisor (per-client supervisors)
    └── WeaviateEx.Client.Supervisor (per client)
        ├── WeaviateEx.Protocol.GRPC.Connection
        ├── WeaviateEx.Batch.Worker (if auto-batching)
        └── WeaviateEx.Util.CircuitBreaker
```

---

## Configuration System

### Configuration Layers

1. **Compile-time config** (`config/config.exs`)
2. **Runtime config** (`config/runtime.exs`)
3. **Environment variables** (`.env`)
4. **Per-client config** (connection options)

### Example Configuration

```elixir
# config/runtime.exs
import Config

config :weaviate_ex,
  # Default connection settings
  default_url: System.get_env("WEAVIATE_URL", "http://localhost:8080"),
  default_grpc_host: System.get_env("WEAVIATE_GRPC_HOST", "localhost"),
  default_grpc_port: String.to_integer(System.get_env("WEAVIATE_GRPC_PORT", "50051")),

  # Auth
  api_key: System.get_env("WEAVIATE_API_KEY"),

  # Protocol preferences
  prefer_grpc: true,
  grpc_fallback_to_http: true,

  # Connection pooling
  http_pool_size: 25,
  http_pool_count: 2,
  grpc_pool_size: 10,

  # Timeouts (milliseconds)
  connect_timeout: 5_000,
  request_timeout: 60_000,
  pool_timeout: 5_000,

  # Retry configuration
  max_retries: 3,
  retry_backoff_base: 100,
  retry_backoff_max: 10_000,

  # Circuit breaker
  circuit_breaker_threshold: 5,
  circuit_breaker_timeout: 60_000,

  # Batch defaults
  batch_size: 100,
  batch_dynamic: true,
  batch_rate_limit: 1000,

  # Telemetry
  telemetry_enabled: true,

  # Logging
  log_level: :info,
  log_requests: false,
  log_responses: false
```

---

## Error Handling

### Error Hierarchy

```elixir
defmodule WeaviateEx.Error do
  @moduledoc """
  Base error struct for all WeaviateEx errors.
  """

  @type t :: %__MODULE__{
    type: atom(),
    message: String.t(),
    details: map(),
    original: term() | nil
  }

  defstruct [:type, :message, :details, :original]

  @doc "Create error from status code"
  def from_status_code(code, body)

  @doc "Create error from exception"
  def from_exception(exception)
end

# Specific error types
defmodule WeaviateEx.ConnectionError, do: defexception [:message, :original]
defmodule WeaviateEx.AuthenticationError, do: defexception [:message, :details]
defmodule WeaviateEx.ValidationError, do: defexception [:message, :errors]
defmodule WeaviateEx.QueryError, do: defexception [:message, :query, :details]
defmodule WeaviateEx.BatchError, do: defexception [:message, :failures]
defmodule WeaviateEx.TimeoutError, do: defexception [:message, :timeout]
```

### Error Handling Pattern

```elixir
# All API functions return {:ok, result} | {:error, error}
case WeaviateEx.Collections.get(client, "Article") do
  {:ok, collection} ->
    # Success path

  {:error, %WeaviateEx.Error{type: :not_found}} ->
    # Handle not found

  {:error, %WeaviateEx.Error{type: :authentication_failed}} ->
    # Handle auth error

  {:error, error} ->
    # Generic error handling
end

# Bang versions raise exceptions
collection = WeaviateEx.Collections.get!(client, "Article")
```

---

## Testing Strategy

### Test Pyramid

```
              /\
             /  \  Integration Tests (Live Weaviate)
            /----\
           /      \  Property-Based Tests
          /--------\
         /          \  Unit Tests (Mocked)
        /____________\
```

### Mocking Strategy

```elixir
# test/test_helper.exs
Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)

# Configure test mode
Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)

# test/weaviate_ex/api/collections_test.exs
defmodule WeaviateEx.API.CollectionsTest do
  use ExUnit.Case, async: true
  import Mox

  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!

  describe "list/1" do
    test "returns list of collections" do
      # Setup mock expectation
      Mock
      |> expect(:request, fn _client, :get, "/v1/schema", _body, _opts ->
        {:ok, %{
          "classes" => [
            %{"class" => "Article"},
            %{"class" => "Author"}
          ]
        }}
      end)

      # Execute
      {:ok, collections} = WeaviateEx.Collections.list(client)

      # Assert
      assert length(collections) == 2
      assert "Article" in collections
    end

    test "handles error responses" do
      Mock
      |> expect(:request, fn _client, :get, "/v1/schema", _body, _opts ->
        {:error, %WeaviateEx.Error{type: :connection_error}}
      end)

      assert {:error, %WeaviateEx.Error{type: :connection_error}} =
        WeaviateEx.Collections.list(client)
    end
  end
end
```

### Test Organization

```elixir
# Unit tests: Fast, isolated, mocked dependencies
# Location: test/weaviate_ex/
# Run: mix test

# Integration tests: Real Weaviate instance required
# Location: test/integration/
# Run: mix test --include integration

# Property-based tests: Generate random test cases
# Location: test/property/
# Run: mix test --include property

# Performance tests: Benchmark operations
# Location: test/performance/
# Run: mix test --include performance
```

---

## Key Design Decisions

### 1. Collection-Scoped API
- Python: `client.collections.get("Article").data.insert(...)`
- Elixir: `WeaviateEx.Collection.Data.insert(collection, ...)`
- Rationale: More functional, explicit client passing

### 2. Builder Pattern
- Fluent, pipe-friendly query building
- Compile-time query validation where possible
- Type-safe filter DSL

### 3. Protocol Selection
- Auto-detect best protocol (prefer gRPC for batch)
- Graceful fallback (gRPC → HTTP)
- Per-operation protocol override

### 4. Error Handling
- `{:ok, result} | {:error, error}` pattern
- Bang versions for convenience (`get!`)
- Structured error types with context

### 5. Configuration
- Environment-based defaults
- Per-client overrides
- Sensible defaults for production

### 6. Testing
- Mox for protocol mocking
- Bypass for HTTP testing
- Separate integration test suite
- Property-based testing for complex logic

### 7. Performance
- Connection pooling (Finch, Gun)
- Lazy evaluation where possible
- Streaming for large results
- Protocol selection based on operation type

---

## Next Steps

1. **Implement Core Architecture** (this document)
2. **Test Infrastructure** (Mox setup, factories, fixtures)
3. **Stub All Modules** (compile but fail tests)
4. **Implement by Priority** (P0 → P1 → P2 → P3)
5. **Documentation** (Guides, examples, API docs)
6. **Performance Tuning** (Benchmarks, optimization)
7. **Release** (CI/CD, versioning, changelog)
