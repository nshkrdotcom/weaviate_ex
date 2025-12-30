# Batch Operations Gap Analysis

## Executive Summary

The Elixir WeaviateEx batch implementation provides solid coverage of core batch operations including both gRPC and REST support, multiple batching modes (fixed, dynamic, rate-limited), and background processing. However, several critical gaps exist compared to the canonical Python client, particularly around server-side batching (experimental mode), sophisticated vectorizer-aware dynamic batching, and comprehensive reference handling through gRPC.

### Overall Assessment

| Category | Python Support | Elixir Support | Gap Severity |
|----------|---------------|----------------|--------------|
| Batch Insert Operations | Full | Good | Minor |
| Batch Delete Operations | Full | Good | Minor |
| Batch Reference Operations | Full (gRPC+REST) | Partial (REST only at high level) | Moderate |
| Dynamic Batching | Sophisticated | Basic | Critical |
| Fixed Size Batching | Full | Full | None |
| Rate Limited Batching | Full | Good | Minor |
| Server-Side Batching | Full (experimental) | Partial | Critical |
| Error Handling & Retry | Full | Good | Minor |
| Background/Async | Full | Good | Minor |
| Progress Callbacks | Full | Good | Minor |

---

## 1. Batch Insert Operations

### Python Implementation

**Location**: `/weaviate-python-client/weaviate/collections/batch/base.py`, `grpc_batch.py`

The Python client supports:

```python
# Collection-level batch
with collection.batch.fixed_size(batch_size=100) as batch:
    batch.add_object(properties={"title": "Test"}, uuid=uuid, vector=vector)

# Client-level batch
with client.batch.dynamic() as batch:
    batch.add_object(collection="Article", properties={"title": "Test"})
```

**Features**:
- Single object insertion with `add_object()`
- Named vectors support via `vector` parameter (Dict[str, list])
- Multi-target references inline via `references` parameter
- Automatic UUID generation if not provided
- Tenant support for multi-tenancy
- Object index tracking for error correlation
- gRPC-first with REST fallback for references

### Elixir Implementation

**Location**: `/lib/weaviate_ex/batch.ex`, `/lib/weaviate_ex/batch/fixed_size.ex`

```elixir
# Context manager style
{:ok, results} = WeaviateEx.Batch.with_batch(client, [batch_size: 100], fn batch ->
  batch
  |> WeaviateEx.Batch.add_object("Article", %{title: "Test"})
  |> WeaviateEx.Batch.add_object("Article", %{title: "Test 2"}, uuid: "custom-uuid")
end)

# Direct API
{:ok, result} = WeaviateEx.Batch.create_objects(objects)
```

**Features**:
- Context manager pattern via `with_batch/3`
- Multiple batch modes: `:fixed`, `:dynamic`, `:rate_limited`
- UUID auto-generation via `WeaviateEx.Types.UUID.generate()`
- Vector support (single vectors)
- Tenant support
- gRPC with HTTP fallback

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| Named vectors in batch | Full support via dict | Partial (vectors field) | Minor |
| Inline references in add_object | Full support | Separate add_reference | Minor |
| numpy/torch/tf tensor support | Native conversion | N/A (Elixir lacks these) | N/A |
| Object retry_count tracking | Full | Partial | Minor |
| gRPC message size chunking | Automatic | Basic | Minor |

**Critical Gap**: None - core batch insert is well-implemented.

---

## 2. Batch Delete Operations

### Python Implementation

**Location**: `/weaviate-python-client/weaviate/collections/batch/grpc_batch_delete.py`

```python
result = collection.data.delete_many(
    where=Filter.by_property("status").equal("draft"),
    verbose=True,
    dry_run=False
)
# Returns: DeleteManyReturn with matches, successful, failed, objects list
```

**Features**:
- gRPC-based batch delete (`_BatchDeleteGRPC`)
- Filter-based deletion
- Verbose mode (returns individual object results)
- Dry run mode (preview without deletion)
- Tenant support
- Consistency level control

### Elixir Implementation

**Location**: `/lib/weaviate_ex/api/batch.ex`, `/lib/weaviate_ex/grpc/services/batch.ex`

```elixir
{:ok, result} = WeaviateEx.Batch.delete_objects(%{
  class: "Article",
  where: %{path: ["status"], operator: "Equal", valueText: "draft"}
}, dry_run: true, verbose: true)
```

**Features**:
- gRPC delete with `GRPCBatch.delete_objects/4`
- HTTP fallback
- Filter conversion to gRPC format
- Verbose and dry_run options
- Tenant support
- Consistency level support

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| DeleteManyObject struct | Dedicated type | Map return | Minor |
| UUID bytes decoding | Full | Full | None |
| Complex filters (And/Or) | Full | Basic path filters | Moderate |
| Filter validation | Full | Basic | Minor |

**Moderate Gap**: Complex nested filters (And/Or operators) need verification in Elixir implementation.

---

## 3. Batch Reference Operations

### Python Implementation

**Location**: `/weaviate-python-client/weaviate/collections/batch/base.py`, `rest.py`

```python
batch.add_reference(
    from_uuid=uuid1,
    from_property="hasAuthor",
    to=ReferenceToMulti(uuids=[uuid2, uuid3], target_collection="Author")
)
```

**Features**:
- Single-target references
- Multi-target references (`ReferenceToMulti`)
- Cross-collection references
- Reference ordering (waits for source objects to be inserted)
- UUID lookup table to prevent sending refs before objects
- gRPC batch references via `BatchReference` proto
- REST fallback with beacon format

### Elixir Implementation

**Location**: `/lib/weaviate_ex/batch.ex`, `/lib/weaviate_ex/batch/fixed_size.ex`

```elixir
# Single target
batcher = FixedSize.add_reference(batcher, "Article", "uuid-1", "hasAuthor", "uuid-2")

# Multi-target (new support)
batcher = FixedSize.add_reference(batcher, "Article", "uuid-1", "relatedTo", [
  %{collection: "Article", uuid: "related-uuid-1"},
  %{collection: "Video", uuid: "video-uuid-1"}
])
```

**Features**:
- Single and multi-target references in FixedSize
- REST-based reference batch sending
- Beacon format generation
- Tenant support

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| Reference ordering (UUID lookup) | Full | Partial (Background only) | Moderate |
| gRPC reference batching | Full | Low-level only | Moderate |
| Reference queue pop with UUID filter | Full | Basic | Moderate |
| Multi-target via ReferenceToMulti | Dedicated type | List of maps | Minor |

**Moderate Gap**: The Python client's sophisticated reference ordering (waiting for source/target objects to be inserted before sending references) is only partially implemented in the Elixir Background batcher.

---

## 4. Dynamic Batching

### Python Implementation

**Location**: `/weaviate-python-client/weaviate/collections/batch/base.py`

```python
with client.batch.dynamic() as batch:
    # Batch size auto-adjusts based on server queue depth
    for obj in objects:
        batch.add_object(...)
```

**Python Dynamic Batching Algorithm**:

1. **Server Queue Monitoring**: Polls `/nodes` endpoint for `batchStats.queueLength` and `ratePerSecond`
2. **Vectorizer-Aware Mode**:
   - Detects if collection uses vectorizer (not `Vectorizers.NONE`)
   - Uses `VECTORIZER_BATCHING_STEP_SIZE = 48` as base
   - Adjusts based on `took_queue` (time taken for batches)
   - Implements sleep time when rate limits are hit
3. **Non-Vectorizer Mode**:
   - Starts with batch size 10
   - Scales up to `max_batch_size = 1000`
   - Adjusts `concurrent_requests` (max 10)
   - Uses ratio of `batch_length / rate` to tune
4. **Concurrent Requests**:
   - Default: 2 concurrent requests
   - Scales based on queue depth
   - `CONCURRENT_REQUESTS_DYNAMIC_VECTORIZER = 2`

**Key Constants**:
```python
MAX_CONCURRENT_REQUESTS = 10
BATCH_TIME_TARGET = 10  # seconds
VECTORIZER_BATCHING_STEP_SIZE = 48
MAX_RETRIES = 9.299  # ~10m30s worst case
```

### Elixir Implementation

**Location**: `/lib/weaviate_ex/batch/dynamic.ex`

```elixir
{:ok, batcher} = Dynamic.start(client: client, monitor_server_stats: true)
Dynamic.add_object(batcher, "Article", %{title: "Test"})
{:ok, results} = Dynamic.stop(batcher)
```

**Elixir Dynamic Batching Algorithm**:

1. **Server Stats Polling**: Optional via `monitor_server_stats: true`
2. **Queue Thresholds**:
   ```elixir
   @queue_high_threshold 100
   @queue_low_threshold 10
   @batch_adjustment_factor 1.5
   ```
3. **Adjustment Logic**:
   - Queue > 100: decrease batch size by factor 1.5
   - Queue < 10: increase batch size by factor 1.5
   - Bounded by `min_batch_size` (10) and `max_batch_size` (1000)

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| Vectorizer-aware batching | Full (detects vectorizer config) | None | Critical |
| Took-based adjustment | Full (tracks batch duration) | None | Critical |
| Rate-per-second from server | Full | Partial (via Cluster.batch_stats) | Moderate |
| Concurrent requests scaling | Full (2-10) | Fixed | Moderate |
| Dynamic sleep time | Full | None | Critical |
| Async indexing detection | Full (switches to fixed 1000/10) | None | Critical |
| Background rate adjustment thread | Full | Timer-based polling | Moderate |

**Critical Gaps**:

1. **No Vectorizer Detection**: Python detects if collections use vectorizers and adjusts behavior accordingly. Elixir doesn't check collection configuration.

2. **No Time-Based Adjustment**: Python tracks how long batches take and adjusts batch size to target 10-second batches. Elixir only uses queue depth.

3. **No Sleep Time Management**: Python dynamically sleeps when hitting rate limits. Elixir relies on explicit rate-limited mode.

4. **No Async Indexing Detection**: Python detects async indexing mode (no queueLength in stats) and switches to aggressive fixed batching. Elixir doesn't handle this case.

---

## 5. Fixed Size Batching

### Python Implementation

```python
with client.batch.fixed_size(batch_size=100, concurrent_requests=2) as batch:
    batch.add_object(...)
```

**Features**:
- Configurable batch size
- Configurable concurrent requests
- Automatic batching when threshold reached
- Thread-safe with locks

### Elixir Implementation

```elixir
{:ok, results} = WeaviateEx.Batch.with_batch(client, [mode: :fixed, batch_size: 100], fn batch ->
  batch |> WeaviateEx.Batch.add_object("Article", %{title: "Test"})
end)
```

**Features**:
- `FixedSize` struct for buffer management
- `batch_size` and `concurrent_requests` options
- Auto-flush when buffer full
- `ready_to_send?/1` check

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| Fixed batch size | Full | Full | None |
| Concurrent requests | Full | Partial (not used in flush) | Minor |
| Thread-safe locks | Full | Process-based isolation | None |

**Minor Gap**: The `concurrent_requests` option in FixedSize is stored but not actively used during flushing. The flush happens sequentially.

---

## 6. Rate Limited Batching

### Python Implementation

```python
with client.batch.rate_limit(requests_per_minute=30) as batch:
    batch.add_object(...)
```

**Algorithm**:
1. Calculate batches to send per minute: `rpm / max_batch_size`
2. Calculate optimal batch size: `rpm / concurrent_requests`
3. Space batches evenly: sleep for `62s / concurrent_requests` between batches
4. Handles rate limit errors from vectorizers (OpenAI, Cohere, HuggingFace)
5. Re-queues objects with retry count on rate limit
6. Exponential backoff: `2^retry_count` seconds

**Rate Limit Detection Patterns**:
```python
"support@cohere.com" + "rate limit"
"OpenAI" + "Rate limit reached"
"tokens per min (TPM)"
"503 error: Service Unavailable"
"500 error: internal server error"
```

### Elixir Implementation

**Location**: `/lib/weaviate_ex/batch/rate_limited.ex`, `/lib/weaviate_ex/batch/batch_retry.ex`

```elixir
{:ok, batcher} = RateLimited.start(client: client, requests_per_minute: 30)
RateLimited.add_object(batcher, "Article", %{title: "Test"})
{:ok, results} = RateLimited.stop(batcher)
```

**Features**:
- `requests_per_minute` limit
- Request time tracking (sliding window)
- Wait for capacity before sending
- Retry support via `BatchRetry.with_retry/2`

**Rate Limit Detection** (`batch_retry.ex`):
```elixir
patterns = [
  ~r/rate limit/i,
  ~r/Rate limit reached/i,
  ~r/tokens per min/i,
  ~r/support@cohere\.com/,
  ~r/503 error/i,
  ~r/too many requests/i,
  ~r/retry after/i
]
```

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| Requests per minute tracking | Full | Full | None |
| Rate limit error detection | Full (specific patterns) | Full (regex patterns) | None |
| Object re-queue on rate limit | Full | None | Moderate |
| Retry count per object | Full (max 5) | Basic (global max) | Moderate |
| Base time adjustment | Full (increases on limit) | None | Minor |
| Exponential backoff | Full | Full | None |

**Moderate Gap**: Python re-queues individual failed objects (up to 5 retries per object) while Elixir retries the entire batch operation. This means Elixir can't partially succeed on rate-limited batches.

---

## 7. Error Handling and Retry Logic

### Python Implementation

**Location**: `/weaviate-python-client/weaviate/collections/batch/base.py`

```python
MAX_RETRIES = 9.299  # ~10m30s worst case
```

**Error Tracking**:
```python
@dataclass
class _BatchDataWrapper:
    results: BatchResult
    failed_objects: List[ErrorObject]
    failed_references: List[ErrorReference]
    imported_shards: Set[Shard]
```

**Features**:
- `ErrorObject` with message, object, original_uuid, retry_count
- `ErrorReference` with message, reference
- Per-object retry tracking
- Failed object re-queue with `prepend()`
- 30 error log limit to prevent spam
- Shard tracking for indexing wait

### Elixir Implementation

**Location**: `/lib/weaviate_ex/batch/error_tracking.ex`, `/lib/weaviate_ex/batch/batch_retry.ex`

```elixir
defmodule ErrorObject do
  defstruct [:message, :object, :original_uuid, :retry_count]
end

defmodule Results do
  @max_stored_results 100_000
  defstruct failed_objects: [], failed_references: [], successful_uuids: %{}, elapsed_seconds: 0.0
end
```

**Features**:
- `ErrorObject` and `ErrorReference` structs
- `Results` struct with statistics
- Max stored results limit (100,000)
- Eviction of oldest entries when limit exceeded
- `BatchRetry.with_retry/2` for retryable operations
- Rate limit pattern detection

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| ErrorObject struct | Full | Full | None |
| ErrorReference struct | Full | Full | None |
| Max stored results | 100,000 | 100,000 | None |
| Per-object retry count | Full | Struct field only | Moderate |
| Object re-queue (prepend) | Full | Queue module only | Moderate |
| Log limit (30 errors) | Full | None | Minor |
| Shard tracking | Full | Separate function | None |

**Moderate Gap**: While Elixir has the `retry_count` field in `ErrorObject`, the actual re-queuing logic for individual failed objects isn't integrated into the main batch flow like Python.

---

## 8. Background/Async Batching

### Python Implementation

**Location**: `/weaviate-python-client/weaviate/collections/batch/base.py`

```python
# Background threads
self.__bg_thread = self.__start_bg_threads()
# Creates: BgDynamicBatchRate, BgBatchScheduler threads
```

**Features**:
- Daemon threads for batch sending
- Separate thread for dynamic rate adjustment
- Thread-safe locks for queue access
- `ThreadPoolExecutor` for concurrent batch execution
- `contextvars` for context propagation
- Background thread exception handling

### Elixir Implementation

**Location**: `/lib/weaviate_ex/batch/background.ex`

```elixir
defmodule Background do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def add_object(server, properties, opts \\ []) do
    GenServer.cast(server, {:add_object, properties, opts})
  end
end
```

**Features**:
- GenServer-based background processing
- `object_queue` and `reference_queue` using `:queue`
- `pending_uuids` and `processed_uuids` MapSets for reference ordering
- Configurable flush interval
- `on_flush` and `on_error` callbacks
- Task-based concurrent batch sending
- Graceful shutdown with final flush

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| Background processing | Threads | GenServer | None (idiomatic) |
| Queue management | Thread-safe lists | :queue | None |
| UUID tracking for refs | Full | Full | None |
| Callbacks | None explicit | on_flush, on_error | Better |
| Concurrent sending | ThreadPoolExecutor | Task.start | Similar |
| Flush timer | While loop | Process.send_after | Similar |

**No Critical Gaps**: The Elixir Background implementation is actually quite complete and uses appropriate OTP patterns.

---

## 9. Progress Callbacks and Monitoring

### Python Implementation

**Implicit Monitoring**:
```python
# Via batch wrapper properties
batch.failed_objects  # List[ErrorObject]
batch.failed_references  # List[ErrorReference]
batch.results  # BatchResult
batch.number_errors  # int
```

**Features**:
- `wait_for_vector_indexing()` polls shard status
- `BatchResult` accumulation
- No explicit progress callbacks

### Elixir Implementation

```elixir
# Callback options
opts = [
  on_flush: fn results -> IO.puts("Flushed: #{length(results)}") end,
  on_error: fn error -> Logger.error("Error: #{error}") end
]

# Explicit results access
results = Background.get_results(batcher)
state = Background.get_state(batcher)
```

**Features**:
- `on_flush` callback after each batch
- `on_error` callback on failures
- `get_results/1` and `get_state/1` for inspection
- `wait_for_vector_indexing/3` with configurable polling

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| Progress callbacks | None explicit | on_flush, on_error | Better |
| Failed objects access | Property | Function | Similar |
| Vector indexing wait | Full | Full | None |
| Shard status polling | Full | Full | None |

**Better in Elixir**: Elixir actually provides more explicit callback support than Python.

---

## 10. gRPC vs REST Batch Operations

### Python Implementation

**gRPC First**:
```python
# Objects: gRPC BatchObjects
self.__batch_grpc.objects(connection=connection, objects=objs, timeout=180, max_retries=9.299)

# References: REST still
self.__batch_rest.references(connection=connection, references=refs)
```

**Server-Side Batching (Experimental)**:
```python
def experimental(self) -> BatchingContextManager:
    """Server-side batching mode (Weaviate 1.34+)"""
    if self._connection._weaviate_version.is_lower_than(1, 34, 0):
        raise WeaviateUnsupportedFeatureError(...)
    self._batch_mode = _ServerSideBatching(concurrency=1)
    return self.__create_batch_and_reset(_BatchCollectionNew)
```

**Features**:
- Bidirectional gRPC streaming
- Server controls batch size via `Backoff` messages
- `BatchStreamRequest` with Start/Data/Stop messages
- `BatchStreamReply` with Started/Results/ShuttingDown/Shutdown
- Automatic reconnection on shutdown
- Object/reference caching for re-send on failure

### Elixir Implementation

**Location**: `/lib/weaviate_ex/grpc/services/batch.ex`, `/lib/weaviate_ex/grpc/services/batch_stream.ex`, `/lib/weaviate_ex/batch/stream.ex`

```elixir
# Unary gRPC
{:ok, result} = GRPCBatch.insert_objects(channel, objects, opts)
{:ok, result} = GRPCBatch.insert_references(channel, references, opts)
{:ok, result} = GRPCBatch.delete_objects(channel, collection, filter, opts)

# Streaming (low-level)
{:ok, stream} = BatchStream.open(channel)
:ok = GRPC.Stub.send_request(stream, BatchStream.start_message())
BatchStream.send_objects(stream, objects)
{:ok, reply} = BatchStream.receive_results(stream)

# High-level stream
{:ok, stream} = WeaviateEx.Batch.Stream.new(client, "Article", buffer_size: 100)
{:ok, stream} = WeaviateEx.Batch.Stream.add(stream, %{properties: %{title: "Test"}})
{:ok, results} = WeaviateEx.Batch.Stream.close(stream)
```

**Features**:
- Unary gRPC for objects, references, delete
- Low-level streaming service (`BatchStream`)
- High-level Stream wrapper with buffering
- Message parsing for Backoff, Acks, Results
- Reconnection support
- Named vectors encoding

### Gaps

| Feature | Python | Elixir | Gap Type |
|---------|--------|--------|----------|
| Unary gRPC batch | Full | Full | None |
| gRPC batch delete | Full | Full | None |
| gRPC batch references | Full | Full | None |
| Bidirectional streaming | Full | Full (low-level) | None |
| Server-side batching mode | Full (experimental) | Partial | Critical |
| Stream reconnection | Full | Basic | Moderate |
| Object caching for re-send | Full | None | Critical |
| Backoff handling | Full (adjusts batch size) | Logged only | Moderate |
| Version check (1.34+) | Full | None | Moderate |

**Critical Gaps**:

1. **Server-Side Batching Integration**: Python's `experimental()` mode integrates server-side batching into the context manager pattern with full `_BatchBaseNew` implementation. Elixir has the low-level pieces but no integrated high-level API.

2. **Object Caching for Re-send**: Python caches objects in `__objs_cache` and re-sends them on stream failure. Elixir's Stream module doesn't cache for re-transmission.

---

## Summary of Critical Gaps

### Must Fix (Critical)

1. **Vectorizer-Aware Dynamic Batching**: Detect collection vectorizer configuration and adjust batching strategy accordingly. Python uses `VECTORIZER_BATCHING_STEP_SIZE = 48` and tracks batch duration.

2. **Server-Side Batching Mode**: Implement a high-level `experimental()` API that wraps the streaming batch with proper context manager semantics, version checking, and integration with the batch result system.

3. **Object Caching for Stream Recovery**: Cache sent objects to re-queue on stream failure, matching Python's `__objs_cache` pattern.

4. **Async Indexing Detection**: Detect when Weaviate is using async indexing (no queueLength in stats) and switch to aggressive fixed batching (1000 objects, 10 concurrent).

### Should Fix (Moderate)

1. **Reference Ordering**: Extend the UUID lookup pattern from Background to other batch modes to ensure references aren't sent before their source/target objects.

2. **Per-Object Re-queue on Rate Limit**: Allow individual failed objects to be re-queued with retry counts instead of failing entire batches.

3. **Concurrent Requests in Fixed Size**: Actually use the `concurrent_requests` option to send multiple batches in parallel.

4. **Complex Filters for Batch Delete**: Verify and enhance support for And/Or filter operators in batch delete.

5. **Stream Backoff Response**: Adjust buffer size or sending rate when receiving Backoff messages from server.

### Nice to Have (Minor)

1. **Log Limit for Errors**: Cap error logging at 30 per session like Python.
2. **Base Time Adjustment**: Increase wait time between rate-limited batches when limits are hit.
3. **Named Vectors Validation**: Ensure named vectors are properly handled in all batch paths.

---

## API Comparison

### Batch Creation

| Operation | Python | Elixir |
|-----------|--------|--------|
| Fixed size batch | `collection.batch.fixed_size(batch_size=100)` | `Batch.with_batch(client, [mode: :fixed, batch_size: 100], fn)` |
| Dynamic batch | `collection.batch.dynamic()` | `Batch.with_batch(client, [mode: :dynamic], fn)` |
| Rate limited | `collection.batch.rate_limit(requests_per_minute=30)` | `Batch.with_batch(client, [mode: :rate_limited, requests_per_minute: 30], fn)` |
| Server-side (experimental) | `collection.batch.experimental()` | Not integrated |
| Background | Context manager exit | `Batch.background(client, "Collection")` |

### Object Addition

| Operation | Python | Elixir |
|-----------|--------|--------|
| Add object | `batch.add_object(properties=..., uuid=..., vector=...)` | `Batch.add_object(ctx, "Collection", %{...}, uuid: ..., vector: ...)` |
| With named vectors | `batch.add_object(vector={"vec1": [...], "vec2": [...]})` | `Background.add_object(batcher, %{...}, vectors: %{...})` |
| With inline refs | `batch.add_object(references={"prop": uuid})` | Separate `add_reference` call |

### Reference Addition

| Operation | Python | Elixir |
|-----------|--------|--------|
| Single ref | `batch.add_reference(from_uuid, "prop", to_uuid)` | `Batch.add_reference(ctx, "Coll", from_uuid, "prop", to_uuid)` |
| Multi-target | `batch.add_reference(..., to=ReferenceToMulti(...))` | `FixedSize.add_reference(..., [%{collection: .., uuid: ..}])` |

### Results Access

| Operation | Python | Elixir |
|-----------|--------|--------|
| Failed objects | `batch.failed_objects` | `results.failed_objects` |
| Failed refs | `batch.failed_references` | `results.failed_references` |
| Number errors | `batch.number_errors` | `Results.number_errors(results)` |
| Statistics | Via results properties | `Results.statistics(results)` |

---

## Recommendations

### Priority 1: Server-Side Batching Integration

Create a high-level API that mirrors Python's `experimental()` mode:

```elixir
defmodule WeaviateEx.Batch.ServerSide do
  @moduledoc """
  Server-side batching mode (Weaviate 1.34+).
  """

  def with_batch(client, opts, fun) do
    # Check version >= 1.34.0
    # Open bidirectional stream
    # Cache objects for re-send
    # Handle backoff messages
    # Integrate with batch result system
  end
end
```

### Priority 2: Vectorizer-Aware Dynamic Batching

Enhance `Dynamic` module to:

1. Fetch collection config to detect vectorizer
2. Track batch execution time
3. Implement time-based adjustment (target 10s batches)
4. Add sleep time management for vectorizer rate limits

### Priority 3: Complete gRPC Reference Batching

Integrate gRPC reference batching into the high-level API, not just as a low-level service:

```elixir
# In API.Batch or similar
def add_references_grpc(client, references, opts) do
  # Use GRPCBatch.insert_references instead of REST
end
```

---

## Files Modified for Implementation

### New Files Needed
- `/lib/weaviate_ex/batch/server_side.ex` - Server-side batching mode

### Files to Enhance
- `/lib/weaviate_ex/batch/dynamic.ex` - Add vectorizer detection, time-based adjustment
- `/lib/weaviate_ex/batch/stream.ex` - Add object caching for re-send
- `/lib/weaviate_ex/api/batch.ex` - Add gRPC reference batching
- `/lib/weaviate_ex/batch.ex` - Add `experimental()` or `server_side()` mode
