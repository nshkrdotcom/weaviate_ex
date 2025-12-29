# WeaviateEx: Complete gRPC Cutover Prompt

**Date:** 2025-12-28
**Objective:** Replace HTTP/Finch with gRPC protocol. Remove all legacy HTTP code. Full TDD approach.

---

## Pre-Implementation Required Reading

### 1. Elixir Client Source (Current Implementation)

Read these files to understand what must be replaced:

```
# Core client and protocol layer (REPLACE)
lib/weaviate_ex/client.ex
lib/weaviate_ex/protocol.ex
lib/weaviate_ex/protocol/http/client.ex

# API modules that use HTTP (MODIFY to use gRPC)
lib/weaviate_ex/api/schema.ex
lib/weaviate_ex/api/objects.ex
lib/weaviate_ex/api/batch.ex
lib/weaviate_ex/api/query.ex
lib/weaviate_ex/api/graphql.ex
lib/weaviate_ex/api/meta.ex
lib/weaviate_ex/api/nodes.ex
lib/weaviate_ex/api/classification.ex
lib/weaviate_ex/api/backups.ex
lib/weaviate_ex/api/cluster.ex
lib/weaviate_ex/api/generative.ex
lib/weaviate_ex/api/vector_config.ex

# Batch system (MODIFY for gRPC streaming)
lib/weaviate_ex/batch/*.ex

# Connection and retry logic (REPLACE)
lib/weaviate_ex/connection.ex
lib/weaviate_ex/retry.ex

# Error handling (EXTEND for gRPC errors)
lib/weaviate_ex/error.ex

# Config (MODIFY - remove Finch, add gRPC config)
lib/weaviate_ex/config.ex
```

### 2. Python Client gRPC Reference (Implementation Guide)

Read these files to understand target gRPC implementation:

```
# Proto definitions (COPY/ADAPT)
weaviate-python-client/weaviate/proto/v1/v4216/v1/
├── weaviate_pb2.py
├── weaviate_pb2_grpc.py
├── batch_pb2.py
├── batch_delete_pb2.py
├── search_get_pb2.py
├── aggregate_pb2.py
├── tenants_pb2.py
├── properties_pb2.py
├── generative_pb2.py
├── health_weaviate_pb2.py
└── base_pb2.py

# gRPC connection management
weaviate-python-client/weaviate/connect/v4.py
weaviate-python-client/weaviate/connect/base.py

# gRPC retry logic
weaviate-python-client/weaviate/retry.py

# Batch streaming implementation
weaviate-python-client/weaviate/collections/batch/grpc_batch_objects.py
weaviate-python-client/weaviate/collections/batch/grpc_batch_delete.py
```

### 3. Gap Analysis Documentation

```
docs/20251228/weaviate-client-gap-analysis/
├── gap-analysis-summary.md      # Overall gaps and priorities
├── grpc-protocol.md             # gRPC-specific gaps (PRIMARY)
├── batch-operations.md          # Batch streaming requirements
├── query-api.md                 # Query gRPC methods
└── error-handling.md            # gRPC error mapping
```

### 4. Weaviate Official Proto Files

Fetch from Weaviate repository:
```
https://github.com/weaviate/weaviate/tree/main/grpc/proto
```

### 5. Elixir gRPC Libraries Documentation

```
# Primary dependencies to add
https://hexdocs.pm/grpc/readme.html
https://hexdocs.pm/protobuf/readme.html
https://github.com/elixir-grpc/grpc
```

---

## Context

### Current Architecture (HTTP/Finch - TO BE REMOVED)

```
WeaviateEx.Client
    └── WeaviateEx.Protocol (behaviour)
            └── WeaviateEx.Protocol.HTTP.Client (Finch-based)
                    └── Finch HTTP pool
```

- All API calls go through `Protocol.HTTP.Client.request/5`
- JSON serialization/deserialization
- Finch connection pooling
- Single timeout configuration

### Target Architecture (gRPC - TO BE IMPLEMENTED)

```
WeaviateEx.Client
    └── WeaviateEx.GRPC.Channel (persistent connection)
            ├── WeaviateEx.GRPC.Services.Weaviate (main service)
            ├── WeaviateEx.GRPC.Services.Batch (batch operations)
            ├── WeaviateEx.GRPC.Services.Search (queries)
            ├── WeaviateEx.GRPC.Services.Health (health checks)
            └── WeaviateEx.GRPC.Services.Aggregate (aggregations)
```

### Key Differences

| Aspect | HTTP (Current) | gRPC (Target) |
|--------|---------------|---------------|
| Serialization | JSON | Protobuf |
| Transport | HTTP/1.1 via Finch | HTTP/2 via grpc-elixir |
| Streaming | Not supported | Bidirectional |
| Connection | Per-request or pooled | Persistent channel |
| Batch | Multiple HTTP calls | Single streaming RPC |
| Types | Runtime maps | Compile-time structs |

---

## Implementation Instructions

### Phase 1: Setup and Proto Compilation

#### 1.1 Update mix.exs Dependencies

```elixir
# REMOVE
{:finch, "~> 0.18"},
{:jason, "~> 1.4"},  # Keep for config files only

# ADD
{:grpc, "~> 0.9"},
{:protobuf, "~> 0.13"},
{:gun, "~> 2.0"},  # HTTP/2 client for gRPC
```

#### 1.2 Create Proto Directory Structure

```
priv/protos/
├── v1/
│   ├── weaviate.proto
│   ├── batch.proto
│   ├── batch_delete.proto
│   ├── search_get.proto
│   ├── aggregate.proto
│   ├── tenants.proto
│   ├── properties.proto
│   ├── generative.proto
│   ├── base.proto
│   └── health.proto
```

#### 1.3 Add Proto Compilation to mix.exs

```elixir
defp aliases do
  [
    "compile.protos": ["cmd protoc --elixir_out=plugins=grpc:lib/weaviate_ex/grpc/generated priv/protos/v1/*.proto"]
  ]
end
```

#### 1.4 Generate Elixir Modules from Protos

Target output:
```
lib/weaviate_ex/grpc/generated/
├── weaviate.pb.ex
├── batch.pb.ex
├── search_get.pb.ex
├── aggregate.pb.ex
├── tenants.pb.ex
├── generative.pb.ex
├── health.pb.ex
└── base.pb.ex
```

### Phase 2: Core gRPC Infrastructure (TDD)

#### 2.1 Channel Management

Create `lib/weaviate_ex/grpc/channel.ex`:

```elixir
defmodule WeaviateEx.GRPC.Channel do
  @moduledoc """
  Manages persistent gRPC channel to Weaviate server.
  """

  use GenServer

  # Functions to implement:
  # - start_link/1 - Initialize channel with config
  # - get_channel/1 - Get active channel
  # - reconnect/1 - Handle reconnection
  # - health_check/1 - gRPC health check
  # - stop/1 - Clean shutdown
end
```

**Tests first** in `test/weaviate_ex/grpc/channel_test.exs`:
- `test "connects to Weaviate gRPC endpoint"`
- `test "reconnects on connection failure"`
- `test "health check returns SERVING status"`
- `test "handles connection timeout"`
- `test "supports TLS connections"`

#### 2.2 gRPC Error Mapping

Update `lib/weaviate_ex/error.ex`:

```elixir
# Add gRPC status code mapping
def from_grpc_status(status_code, message) do
  type = case status_code do
    :ok -> :ok
    :cancelled -> :cancelled
    :unknown -> :unknown_error
    :invalid_argument -> :bad_request
    :deadline_exceeded -> :timeout_error
    :not_found -> :not_found
    :already_exists -> :conflict
    :permission_denied -> :forbidden
    :resource_exhausted -> :rate_limited
    :failed_precondition -> :validation_error
    :aborted -> :aborted
    :out_of_range -> :bad_request
    :unimplemented -> :not_implemented
    :internal -> :server_error
    :unavailable -> :service_unavailable
    :data_loss -> :data_loss
    :unauthenticated -> :authentication_failed
  end

  %__MODULE__{type: type, message: message, details: %{grpc_status: status_code}}
end
```

**Tests first** in `test/weaviate_ex/error_test.exs`:
- `test "maps all gRPC status codes correctly"`
- `test "preserves original gRPC status in details"`

#### 2.3 gRPC Retry Logic

Update `lib/weaviate_ex/retry.ex`:

```elixir
# Add gRPC-specific retryable conditions
defp grpc_retryable?(status) do
  status in [:unavailable, :resource_exhausted, :aborted]
end
```

**Tests first**:
- `test "retries on UNAVAILABLE status"`
- `test "retries on RESOURCE_EXHAUSTED with backoff"`
- `test "does not retry on INVALID_ARGUMENT"`

### Phase 3: Service Implementations (TDD)

#### 3.1 Search Service

Create `lib/weaviate_ex/grpc/services/search.ex`:

```elixir
defmodule WeaviateEx.GRPC.Services.Search do
  @moduledoc """
  gRPC Search service for vector queries.
  """

  alias WeaviateEx.GRPC.Generated.SearchGet

  # Implement:
  # - near_vector/4
  # - near_text/4
  # - near_object/4
  # - bm25/4
  # - hybrid/4
  # - near_image/4
end
```

**Tests first** in `test/weaviate_ex/grpc/services/search_test.exs`:
- `test "near_vector returns objects with distances"`
- `test "near_text with certainty threshold"`
- `test "hybrid search with alpha weighting"`
- `test "handles empty results"`
- `test "returns metadata when requested"`

#### 3.2 Batch Service (Streaming)

Create `lib/weaviate_ex/grpc/services/batch.ex`:

```elixir
defmodule WeaviateEx.GRPC.Services.Batch do
  @moduledoc """
  gRPC Batch service with bidirectional streaming.
  """

  # Implement:
  # - insert_many/4 - Unary batch insert
  # - stream_insert/3 - Bidirectional streaming insert
  # - delete_many/4 - Batch delete
  # - stream_delete/3 - Streaming delete
end
```

**Tests first** in `test/weaviate_ex/grpc/services/batch_test.exs`:
- `test "batch insert 1000 objects"`
- `test "streaming insert with backpressure"`
- `test "batch delete by filter"`
- `test "handles partial failures"`
- `test "returns UUIDs for successful inserts"`

#### 3.3 Aggregate Service

Create `lib/weaviate_ex/grpc/services/aggregate.ex`:

**Tests first**:
- `test "count objects in collection"`
- `test "aggregate numeric properties"`
- `test "aggregate with groupBy"`
- `test "aggregate with filters"`

#### 3.4 Tenants Service

Create `lib/weaviate_ex/grpc/services/tenants.ex`:

**Tests first**:
- `test "list all tenants"`
- `test "get tenant by name"`
- `test "create tenant"`
- `test "update tenant status"`

### Phase 4: Migrate API Modules

#### 4.1 Update Each API Module

For each module in `lib/weaviate_ex/api/`:

1. Remove HTTP request calls
2. Import gRPC service
3. Build protobuf request messages
4. Call gRPC service
5. Parse protobuf response to Elixir maps

Example migration for `lib/weaviate_ex/api/query.ex`:

```elixir
# BEFORE (HTTP)
def near_vector(client, collection, vector, opts) do
  body = build_graphql_query(...)
  Protocol.request(client, :post, "/v1/graphql", body, opts)
end

# AFTER (gRPC)
def near_vector(client, collection, vector, opts) do
  request = %SearchGet.SearchRequest{
    collection: collection,
    near_vector: %SearchGet.NearVector{vector: vector},
    # ... build full request
  }

  case GRPC.Services.Search.search(client.channel, request) do
    {:ok, response} -> {:ok, parse_search_response(response)}
    {:error, error} -> {:error, Error.from_grpc_status(error.status, error.message)}
  end
end
```

#### 4.2 Module Migration Order

1. `meta.ex` - Simple, good for validation
2. `schema.ex` - Collection CRUD
3. `objects.ex` - Object CRUD
4. `query.ex` - Search operations
5. `batch.ex` - Batch operations (complex)
6. `generative.ex` - RAG operations
7. `classification.ex` - Classification
8. `backups.ex` - Backup operations
9. `cluster.ex` - Cluster management

### Phase 5: Update Batch System

#### 5.1 Rewrite Dynamic Batcher

Update `lib/weaviate_ex/batch/dynamic.ex` for gRPC streaming:

```elixir
defmodule WeaviateEx.Batch.Dynamic do
  # Use gRPC bidirectional streaming
  # Implement backpressure handling
  # Support rate limiting via RESOURCE_EXHAUSTED
end
```

**Tests first**:
- `test "streams objects to server"`
- `test "handles backpressure from server"`
- `test "retries on rate limit"`
- `test "reports progress via callback"`

#### 5.2 Remove Rate-Limited Batcher HTTP Logic

The gRPC streaming naturally handles rate limiting via flow control.

### Phase 6: Update Client Module

#### 6.1 Rewrite `lib/weaviate_ex/client.ex`

```elixir
defmodule WeaviateEx.Client do
  defstruct [:channel, :config, :metadata]

  def connect(opts) do
    config = Config.new(opts)

    with {:ok, channel} <- GRPC.Channel.connect(config.host, config.grpc_port, config.credentials),
         :ok <- health_check(channel) do
      {:ok, %__MODULE__{channel: channel, config: config}}
    end
  end

  def disconnect(%__MODULE__{channel: channel}) do
    GRPC.Channel.disconnect(channel)
  end
end
```

### Phase 7: Remove Legacy HTTP Code

#### 7.1 Delete Files

```bash
rm lib/weaviate_ex/protocol.ex
rm lib/weaviate_ex/protocol/http/client.ex
rm -rf lib/weaviate_ex/protocol/
```

#### 7.2 Remove Finch from Application

Update `lib/weaviate_ex/application.ex`:
- Remove Finch child spec
- Add gRPC channel supervisor if needed

#### 7.3 Clean Up Config

Update `lib/weaviate_ex/config.ex`:
- Remove `finch_options`
- Remove `http_pool_size`
- Add `grpc_port` (default: 50051)
- Add `grpc_options` (max message size, etc.)

### Phase 8: Update Tests

#### 8.1 Update Test Helpers

Update `test/support/`:
- Remove HTTP mocking (Bypass, etc.)
- Add gRPC test server or mocking

#### 8.2 Update Integration Tests

All integration tests should use real Weaviate with gRPC:

```elixir
# test/test_helper.exs
WeaviateEx.TestSupport.ensure_weaviate_running(grpc_port: 50051)
```

#### 8.3 Test Categories

Ensure tests cover:
- Unit tests for protobuf message building
- Unit tests for response parsing
- Integration tests for each gRPC service
- Streaming tests for batch operations
- Error handling tests
- Retry logic tests
- Connection management tests

### Phase 9: Update Documentation

#### 9.1 Update README.md

- Remove all HTTP/Finch references
- Update connection examples for gRPC
- Update configuration options
- Add gRPC-specific troubleshooting

#### 9.2 Update Module Documentation

Every `@moduledoc` and `@doc` must reflect gRPC:
- No mentions of HTTP, REST, JSON
- Document protobuf message structures where relevant
- Document streaming behavior for batch operations

#### 9.3 Update Examples

Update all files in `examples/`:
- Connection setup (gRPC port)
- Batch operations (streaming)
- Error handling (gRPC status codes)

#### 9.4 Update CHANGELOG.md

```markdown
## [0.4.0] - 2025-12-28

### Changed
- **BREAKING**: Complete migration from HTTP/REST to gRPC protocol
- **BREAKING**: Removed Finch dependency, added grpc and protobuf dependencies
- **BREAKING**: Configuration changes - replaced `http_port` with `grpc_port`
- Batch operations now use bidirectional streaming for improved performance
- All API calls use Protocol Buffers for serialization

### Removed
- HTTP/REST protocol support
- Finch HTTP client
- JSON serialization for API calls (retained for config files only)
- `WeaviateEx.Protocol` behaviour and HTTP implementation

### Added
- gRPC client with persistent channel management
- Bidirectional streaming for batch operations
- gRPC health checks
- Protocol Buffer message types for all operations
- gRPC-specific error mapping and retry logic

### Fixed
- Batch operations now properly handle backpressure
- Connection management with automatic reconnection
```

### Phase 10: Version Bump

#### 10.1 Update mix.exs

```elixir
def project do
  [
    app: :weaviate_ex,
    version: "0.4.0",
    # ...
  ]
end
```

#### 10.2 Update README.md Version Badge

```markdown
[![Version](https://img.shields.io/hexpm/v/weaviate_ex.svg)](https://hex.pm/packages/weaviate_ex)
```

---

## Quality Gates

### All Must Pass Before Completion

```bash
# 1. All tests pass
mix test

# 2. No compiler warnings
mix compile --warnings-as-errors

# 3. Dialyzer passes
mix dialyzer

# 4. Credo passes (strict mode)
mix credo --strict

# 5. Documentation generates without warnings
mix docs

# 6. Formatter check
mix format --check-formatted
```

### Test Coverage Requirements

- Minimum 90% line coverage
- All public functions have tests
- All error paths tested
- Streaming operations tested with various payload sizes

---

## Files to Create

```
lib/weaviate_ex/grpc/
├── channel.ex                 # Channel management
├── interceptors/
│   ├── auth.ex               # Auth metadata interceptor
│   ├── logging.ex            # Request/response logging
│   └── retry.ex              # Retry interceptor
├── services/
│   ├── weaviate.ex           # Main service
│   ├── search.ex             # Search operations
│   ├── batch.ex              # Batch operations
│   ├── aggregate.ex          # Aggregations
│   ├── tenants.ex            # Multi-tenancy
│   └── health.ex             # Health checks
└── generated/                 # Proto-generated modules
    ├── weaviate.pb.ex
    ├── batch.pb.ex
    ├── search_get.pb.ex
    ├── aggregate.pb.ex
    ├── tenants.pb.ex
    ├── generative.pb.ex
    ├── health.pb.ex
    └── base.pb.ex
```

## Files to Delete

```
lib/weaviate_ex/protocol.ex
lib/weaviate_ex/protocol/http/client.ex
lib/weaviate_ex/protocol/http/
lib/weaviate_ex/connection.ex  # If HTTP-specific
```

## Files to Modify

```
lib/weaviate_ex.ex             # Update main module
lib/weaviate_ex/client.ex      # Complete rewrite
lib/weaviate_ex/config.ex      # Remove HTTP, add gRPC
lib/weaviate_ex/error.ex       # Add gRPC error mapping
lib/weaviate_ex/retry.ex       # Add gRPC retry logic
lib/weaviate_ex/api/*.ex       # All API modules
lib/weaviate_ex/batch/*.ex     # Batch system
lib/weaviate_ex/application.ex # Supervisor changes
mix.exs                        # Dependencies, version
README.md                      # Documentation
CHANGELOG.md                   # Version history
config/config.exs              # If exists
test/**/*_test.exs             # All tests
examples/**/*.ex               # All examples
```

---

## Success Criteria

1. `mix test` - All tests pass (0 failures)
2. `mix compile --warnings-as-errors` - No warnings
3. `mix dialyzer` - No errors
4. `mix credo --strict` - No issues
5. `mix docs` - Generates without warnings
6. All examples in `examples/` directory work
7. README accurately describes gRPC-only architecture
8. CHANGELOG documents breaking changes
9. Version is 0.4.0 in mix.exs and README
10. No references to HTTP, Finch, REST, or JSON (except config parsing) remain in codebase

---

## Estimated Scope

| Component | Files | Estimated Effort |
|-----------|-------|------------------|
| Proto setup & generation | 10-12 | 4-6 hours |
| Channel management | 2-3 | 4-6 hours |
| gRPC services | 6-8 | 16-24 hours |
| API module migration | 12-15 | 16-24 hours |
| Batch streaming | 3-4 | 8-12 hours |
| Error handling | 1-2 | 2-4 hours |
| Test updates | 20-30 | 12-16 hours |
| Documentation | 5-10 | 4-6 hours |
| **Total** | ~70 files | ~70-100 hours |

---

*This prompt provides complete instructions for migrating WeaviateEx from HTTP/Finch to gRPC with full test coverage and documentation.*
