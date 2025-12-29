# Batch Operations Gap Analysis

## WeaviateEx (Elixir) vs Weaviate Python Client

**Date**: 2025-12-29
**Analysis Focus**: Batch Operations
**Python Client Version**: v4.x (collections API)
**Elixir Port Version**: v0.6.0

---

## Executive Summary

The WeaviateEx Elixir port provides a **solid foundation** for batch operations with support for fixed-size, dynamic, and rate-limited batching modes. However, there are **significant gaps** compared to the Python client's advanced capabilities:

### Key Findings

| Aspect | Status | Notes |
|--------|--------|-------|
| Basic batch insert | **Complete** | REST and gRPC supported |
| Basic batch delete | **Complete** | REST and gRPC supported |
| Batch references | **Complete** | REST only (gRPC partial) |
| Fixed-size batching | **Complete** | Well implemented |
| Dynamic batching | **Partial** | Missing background thread model |
| Rate-limited batching | **Partial** | Simpler implementation |
| gRPC streaming | **Partial** | Server-side batching not complete |
| Error tracking | **Good** | Comparable structure |
| Named vectors | **Partial** | Basic support only |
| Multi-target references | **Partial** | Basic support |

### Critical Gaps

1. **No background thread model** - Python uses background threads for continuous batch processing
2. **No server-side batching (experimental)** - Python supports Weaviate 1.34+ streaming batching
3. **No async indexing wait** with shard-level granularity
4. **Simpler rate limit detection** - Python handles multiple vectorizer APIs

---

## Feature-by-Feature Comparison

### 1. Batch Insert Operations

#### Python Client (`/weaviate/collections/batch/`)

```python
# Context manager pattern with automatic batching
with client.batch.dynamic() as batch:
    batch.add_object(collection="Article", properties={"title": "Test"})
    batch.add_object(collection="Article", properties={"title": "Test 2"})

# Fixed size batching
with client.batch.fixed_size(batch_size=100, concurrent_requests=2) as batch:
    batch.add_object(...)

# Rate-limited batching
with client.batch.rate_limit(requests_per_minute=30) as batch:
    batch.add_object(...)

# Server-side batching (experimental, Weaviate 1.34+)
with client.batch.experimental() as batch:
    batch.add_object(...)
```

**Key Features**:
- Background thread model (`_BatchBase`) sends batches asynchronously
- Queue management with backpressure (`__recommended_num_objects`)
- Automatic UUID lookup to handle reference ordering
- Retry logic for rate limit errors from vectorizer APIs
- gRPC primary with REST fallback for references
- Support for `torch.Tensor`, `numpy.ndarray`, `tf.Tensor` vectors

#### Elixir Port (`/lib/weaviate_ex/batch/`)

```elixir
# Context manager pattern
{:ok, results} = WeaviateEx.Batch.with_batch(client, [batch_size: 100], fn batch ->
  batch
  |> WeaviateEx.Batch.add_object("Article", %{title: "Test"})
  |> WeaviateEx.Batch.add_object("Article", %{title: "Test 2"})
end)

# Fixed size batching
{:ok, results} = WeaviateEx.Batch.with_batch(client, [mode: :fixed, batch_size: 100], fn batch ->
  ...
end)

# Dynamic batching
{:ok, results} = WeaviateEx.Batch.with_batch(client, [mode: :dynamic], fn batch ->
  ...
end)

# Rate-limited batching
{:ok, results} = WeaviateEx.Batch.with_batch(client, [
  mode: :rate_limited,
  requests_per_minute: 30
], fn batch ->
  ...
end)
```

**Key Features**:
- GenServer-based state management (Dynamic, RateLimited)
- Synchronous processing with manual flush
- gRPC and REST support
- Error tracking structures
- Callback support (`:on_flush`, `:on_error`)

#### Gap Analysis - Batch Insert

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Background thread processing | Yes | No | **Major** |
| Automatic queue management | Yes | Partial | Moderate |
| UUID lookup for reference ordering | Yes | No | Moderate |
| Vectorizer retry logic (OpenAI, Cohere) | Yes | Partial | Moderate |
| torch/numpy/tf tensor support | Yes | N/A | N/A (Elixir) |
| Named vector support | Yes | Partial | Minor |
| Multi-vector support | Yes | Partial | Minor |
| Server-side batching (streaming) | Yes | Partial | **Major** |
| Consistency level support | Yes | Yes | None |
| Tenant support | Yes | Yes | None |

---

### 2. Batch Delete Operations

#### Python Client

```python
# Delete with filter (gRPC)
result = collection.data.delete_many(
    where=Filter.by_property("category").equal("old"),
    verbose=True,
    dry_run=False
)

# Returns DeleteManyReturn with:
# - matches: int
# - successful: int
# - failed: int
# - objects: List[DeleteManyObject] (if verbose)
```

**Implementation** (`grpc_batch_delete.py`):
- Uses gRPC `BatchDeleteRequest`
- Supports `verbose` mode for per-object status
- Supports `dry_run` for testing
- Filter conversion to gRPC format

#### Elixir Port

```elixir
{:ok, result} = WeaviateEx.Batch.delete_objects(%{
  class: "Article",
  where: %{
    path: ["category"],
    operator: "Equal",
    valueText: "old"
  }
}, verbose: true, dry_run: false)

# Returns map with:
# - results.matches
# - results.successful
# - results.failed
# - results.objects (if verbose)
```

**Implementation** (`api/batch.ex`, `grpc/services/batch.ex`):
- REST and gRPC support
- Filter conversion
- DeleteResult struct for typed parsing

#### Gap Analysis - Batch Delete

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| gRPC delete | Yes | Yes | None |
| REST delete | Yes | Yes | None |
| Verbose output | Yes | Yes | None |
| Dry run | Yes | Yes | None |
| Filter operators | Full | Full | None |
| Consistency level | Yes | Yes | None |
| Typed result struct | Yes | Yes | None |

**Verdict**: Batch delete is at **feature parity**.

---

### 3. Batch Update Operations

#### Python Client

The Python client does not have a dedicated batch update API. Updates are handled by:
1. Re-inserting objects with the same UUID (replace semantics)
2. Using `data.update()` for individual objects

#### Elixir Port

Same approach - no dedicated batch update. Uses:
1. Re-insertion with same UUID
2. Individual updates via Data API

#### Gap Analysis - Batch Update

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Batch update API | No | No | None |
| Replace semantics | Yes | Yes | None |

**Verdict**: **No gap** - neither client has dedicated batch update.

---

### 4. Error Handling Strategies

#### Python Client

```python
# Error structures
@dataclass
class ErrorObject:
    message: str
    object_: BatchObject
    original_uuid: Optional[UUID] = None

@dataclass
class BatchObjectReturn:
    _all_responses: List[Union[uuid_package.UUID, ErrorObject]]
    elapsed_seconds: float
    errors: Dict[int, ErrorObject]
    uuids: Dict[int, uuid_package.UUID]
    has_errors: bool

# Rate limit detection patterns
patterns = [
    "support@cohere.com" + "rate limit",
    "OpenAI" + "Rate limit reached",
    "on tokens per min (TPM)",
    "503 error: Service Unavailable",
    "500 error: The server had an error",
    "failed with status: 503 error"  # huggingface
]
```

**Key Features**:
- Per-object error tracking with original index
- Rate limit detection for multiple vectorizer APIs
- Automatic retry with exponential backoff (2^n seconds)
- Max 5 retries per object
- Memory-bounded result storage (MAX_STORED_RESULTS = 100000)

#### Elixir Port

```elixir
defmodule ErrorObject do
  defstruct [:message, :object, :original_uuid, :retry_count]
end

defmodule Results do
  defstruct failed_objects: [],
            failed_references: [],
            successful_uuids: %{},
            elapsed_seconds: 0.0
end

# Rate limit patterns (batch_retry.ex)
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

**Key Features**:
- ErrorObject and ErrorReference structs
- Results aggregation
- Rate limit detection patterns
- Exponential backoff (2^n * 1000 ms)
- Max 5 retries

#### Gap Analysis - Error Handling

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Per-object error tracking | Yes | Yes | None |
| Original index preservation | Yes | Partial | Minor |
| Rate limit detection | Full | Good | Minor |
| Retry with backoff | Yes | Yes | None |
| Memory-bounded storage | Yes | No | Minor |
| Vectorizer-specific patterns | Full | Partial | Minor |
| Retry count tracking | Yes | Yes | None |

---

### 5. Rate Limiting Implementation

#### Python Client (`_RateLimitedBatching`)

```python
@dataclass
class _RateLimitedBatching:
    requests_per_minute: int

# Timing calculation
# Sends objects in equally spaced batches
self.__concurrent_requests = (rpm + max_batch) // max_batch
self.__recommended_num_objects = rpm // concurrent_requests

# Rate limiting in background thread
if time.time() - self.__time_stamp_last_request < base_time // concurrent:
    time.sleep(1)
    continue
```

**Key Features**:
- Calculates optimal batch distribution across minute
- Adjusts timing after rate limit errors
- Integrates with background thread model
- Increases base time when hitting limits

#### Elixir Port (`WeaviateEx.Batch.RateLimited`)

```elixir
# GenServer-based rate limiting
@rate_window_ms 60_000

defp wait_for_capacity(state) do
  remaining = calculate_remaining_requests(state)
  if remaining > 0 do
    {0, state}
  else
    oldest_request = List.last(state.request_times)
    wait_time = max(0, oldest_request + @rate_window_ms - now)
    {wait_time, state}
  end
end

defp record_request(state) do
  now = System.monotonic_time(:millisecond)
  recent_requests =
    state.request_times
    |> Enum.filter(fn time -> time > now - @rate_window_ms end)
    |> List.insert_at(0, now)
  %{state | request_times: recent_requests}
end
```

**Key Features**:
- Sliding window rate tracking
- GenServer state management
- Configurable requests per minute
- Optional retry on rate limit

#### Gap Analysis - Rate Limiting

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Requests per minute limit | Yes | Yes | None |
| Sliding window tracking | Yes | Yes | None |
| Adaptive timing | Yes | Partial | Minor |
| Background processing | Yes | No | **Major** |
| Rate limit recovery | Yes | Yes | None |
| Retry integration | Yes | Yes | None |

---

### 6. Dynamic Batching

#### Python Client (`_DynamicBatching`, `_BatchBase`)

```python
# Background thread continuously monitors and adjusts
def __dynamic_batching(self) -> None:
    status = self.__cluster.get_nodes_status()
    rate: int = status[0]["batchStats"]["ratePerSecond"]
    batch_length = status[0]["batchStats"]["queueLength"]

    if batch_length == 0:  # scale up if queue is empty
        self.__recommended_num_objects = min(
            self.__recommended_num_objects + 50,
            self.__max_batch_size
        )
        if self.__max_batch_size == self.__recommended_num_objects:
            self.__concurrent_requests += 1
    else:
        ratio = batch_length / rate
        if 2.1 > ratio > 1.9:  # ideal
            self.__recommended_num_objects = math.floor(rate_per_worker)
        elif ratio <= 1.9:  # can send more
            self.__recommended_num_objects *= 1.5
        elif ratio < 10:  # too high, scale down
            self.__recommended_num_objects = math.floor(rate_per_worker * 2 / ratio)
        else:  # way too high, stop
            self.__recommended_num_objects = 0
```

**Key Features**:
- Background thread polls server stats every 1 second
- Adjusts batch size based on queue depth ratio
- Manages concurrent request count (up to 10)
- Handles vectorizer batching mode differently
- Automatic async indexing detection

#### Elixir Port (`WeaviateEx.Batch.Dynamic`)

```elixir
# Simpler queue-based adjustment
@queue_high_threshold 100
@queue_low_threshold 10
@batch_adjustment_factor 1.5

defp adjust_batch_size(current, queue_size, state) do
  cond do
    queue_size > @queue_high_threshold ->
      new_size = trunc(current / @batch_adjustment_factor)
      max(new_size, state.min_batch_size)
    queue_size < @queue_low_threshold ->
      new_size = trunc(current * @batch_adjustment_factor)
      min(new_size, state.max_batch_size)
    true ->
      current
  end
end

# Optional server stats polling
def handle_info(:poll_server_stats, state) do
  state = poll_and_update_stats(state)
  timer_ref = schedule_poll(state.poll_interval)
  {:noreply, %{state | poll_timer_ref: timer_ref}}
end
```

**Key Features**:
- GenServer with optional polling
- Simple threshold-based adjustment
- Configurable min/max batch sizes
- Optional server stats monitoring

#### Gap Analysis - Dynamic Batching

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Background thread model | Yes | No | **Major** |
| Continuous stats polling | Yes | Optional | Moderate |
| Queue ratio algorithm | Sophisticated | Simple | Moderate |
| Concurrent request scaling | Yes (up to 10) | Limited | Moderate |
| Vectorizer batching mode | Yes | No | Minor |
| Async indexing detection | Yes | No | Minor |
| Rate-based adjustment | Yes | No | Moderate |

---

### 7. gRPC vs REST Batch Operations

#### Python Client

```python
# gRPC for objects (primary)
self.__batch_grpc.objects(
    connection=self.__connection,
    objects=objs,
    timeout=DEFAULT_REQUEST_TIMEOUT,  # 180s
    max_retries=MAX_RETRIES,  # ~9.3
)

# REST for references (fallback)
self.__batch_rest.references(
    connection=self.__connection,
    references=refs
)

# gRPC streaming for server-side batching (experimental)
def stream(self, connection, requests):
    return connection.grpc_batch_stream(requests=requests)
```

**Key Features**:
- gRPC primary for objects
- REST for references (gRPC reference batching not fully implemented)
- Bidirectional streaming for server-side batching
- Configurable gRPC message size limits
- Retry logic with exponential backoff

#### Elixir Port

```elixir
# gRPC or REST based on channel availability
defp grpc_available?(client) do
  channel = Client.grpc_channel(client)
  not is_nil(channel)
end

# Objects: gRPC or REST
if grpc_available?(client) do
  create_objects_grpc(client, objects, opts)
else
  create_objects_http(client, objects, opts)
end

# References: REST only
defp flush_references_list(client, references, results, batcher, opts) do
  WeaviateEx.Client.request(client, :post, "/v1/batch/references", ...)
end

# gRPC streaming support (partial)
defmodule WeaviateEx.GRPC.Services.BatchStream do
  def open(channel, opts \\ [])
  def send_objects(stream, objects)
  def receive_results(stream, timeout)
  def close(stream)
end
```

**Key Features**:
- Automatic gRPC/REST selection
- gRPC batch objects
- REST batch references
- Basic gRPC streaming infrastructure

#### Gap Analysis - gRPC vs REST

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| gRPC object batching | Yes | Yes | None |
| gRPC reference batching | Partial | No | Minor |
| gRPC delete | Yes | Yes | None |
| REST fallback | Yes | Yes | None |
| Streaming batching | Yes | Partial | **Major** |
| Message size handling | Yes | Basic | Minor |
| Retry on gRPC | Yes | Basic | Minor |

---

### 8. Callback/Progress Reporting

#### Python Client

```python
# Implicit through results
batch.failed_objects  # List[ErrorObject]
batch.failed_references  # List[ErrorReference]
batch.results  # BatchResult

# Wait for indexing with callback potential
def wait_for_vector_indexing(
    self, shards: Optional[List[Shard]] = None, how_many_failures: int = 5
) -> None:
    while not self.__is_ready(how_many_failures, shards):
        logger.debug("Waiting for async indexing to finish...")
        time.sleep(0.25)
```

#### Elixir Port

```elixir
# Explicit callback options
{:ok, batcher} = RateLimited.start(
  client: client,
  on_flush: fn results -> IO.inspect(results) end,
  on_error: fn error -> Logger.error(error) end
)

# Wait for indexing
:ok = Batch.wait_for_vector_indexing(client, "Article",
  poll_interval: 1000,
  timeout: 60_000,
  max_failures: 5
)
```

**Key Features** (Elixir):
- Explicit `:on_flush` callback
- Explicit `:on_error` callback
- Wait for vector indexing function
- Configurable poll interval and timeout

#### Gap Analysis - Callbacks

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| On flush callback | Implicit | Explicit | None (better) |
| On error callback | Implicit | Explicit | None (better) |
| Failed objects access | Yes | Yes | None |
| Wait for indexing | Yes | Yes | None |
| Shard-level waiting | Yes | Basic | Minor |
| Progress reporting | Basic | Basic | None |

---

### 9. Vector Handling in Batches

#### Python Client

```python
# Vector conversion
def __single_vec(self, vectors: Optional[VECTORS]) -> Optional[bytes]:
    if not _is_1d_vector(vectors):
        return None
    return _Pack.single(vectors)

def __multi_vec(self, vectors: Optional[VECTORS]) -> Optional[List[base_pb2.Vectors]]:
    if vectors is None or _is_1d_vector(vectors):
        return None
    return [
        base_pb2.Vectors(name=name, vector_bytes=packing.bytes_, type=packing.type_)
        for name, vec_or_vecs in vectors.items()
        if (packing := _Pack.parse_single_or_multi_vec(vec_or_vecs))
    ]

# Support for numpy, torch, tensorflow
def _get_vector_v4(vector):
    if hasattr(vector, "numpy"):  # torch tensor
        return vector.numpy().tolist()
    elif hasattr(vector, "tolist"):  # numpy array
        return vector.tolist()
    ...
```

**Key Features**:
- Single vector (list/numpy/torch/tf)
- Named vectors (dict of name -> vector)
- Multi-vectors (multiple vectors per name)
- Automatic conversion to bytes for gRPC
- Type detection and packing

#### Elixir Port

```elixir
# Vector encoding for gRPC
defp encode_vector(nil), do: <<>>

defp encode_vector(vector) when is_list(vector) do
  vector
  |> Enum.map(&<<&1::float-32-little>>)
  |> IO.iodata_to_binary()
end

# Named vectors
defp encode_named_vectors(nil), do: []

defp encode_named_vectors(vectors) when is_map(vectors) do
  Enum.map(vectors, fn {name, vector} ->
    %Weaviate.V1.Vectors{
      name: to_string(name),
      vector_bytes: encode_vector(vector)
    }
  end)
end
```

**Key Features**:
- Single vector (list)
- Named vectors (map)
- Binary encoding for gRPC

#### Gap Analysis - Vector Handling

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Single vector | Yes | Yes | None |
| Named vectors | Yes | Yes | None |
| Multi-vectors | Yes | Basic | Minor |
| Numpy support | Yes | N/A | N/A |
| Torch support | Yes | N/A | N/A |
| Binary encoding | Yes | Yes | None |
| Vector type detection | Yes | Basic | Minor |

---

### 10. Reference Handling in Batches

#### Python Client

```python
class BatchReference(BaseModel):
    from_object_collection: str
    from_object_uuid: UUID
    from_property_name: str
    to_object_uuid: UUID
    to_object_collection: Optional[str] = None  # multi-target
    tenant: Optional[str] = None

    def _to_internal(self) -> _BatchReference:
        return _BatchReference(
            from_=f"{BEACON}{collection}/{uuid}/{property}",
            to=f"{BEACON}{to_collection}{to_uuid}",
            ...
        )

# Reference ordering - wait for object to be processed
uuid_lookup: Set[str] = set()

def pop_items(self, pop_amount: int, uuid_lookup: Set[str]) -> List[Ref]:
    # Only pop references where both from and to objects are processed
    if self._items[i].from_uuid not in uuid_lookup and \
       self._items[i].to_uuid not in uuid_lookup:
        ret.append(self._items.pop(i))
```

#### Elixir Port

```elixir
# Fixed size reference handling
def add_reference(batcher, collection, from_uuid, property, to_uuid, opts)
    when is_binary(to_uuid) do
  reference = %{
    collection: collection,
    from_uuid: from_uuid,
    property: property,
    to_uuid: to_uuid,
    to_collection: collection,
    tenant: Keyword.get(opts, :tenant)
  }
  %{batcher | references_buffer: [reference | batcher.references_buffer]}
end

# Multi-target references
def add_reference(batcher, collection, from_uuid, property, targets, opts)
    when is_list(targets) do
  references = Enum.map(targets, fn target ->
    %{
      collection: collection,
      from_uuid: from_uuid,
      property: property,
      to_uuid: target.uuid,
      to_collection: target.collection,
      tenant: Keyword.get(opts, :tenant)
    }
  end)
  ...
end
```

#### Gap Analysis - Reference Handling

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Single-target refs | Yes | Yes | None |
| Multi-target refs | Yes | Yes | None |
| Reference ordering | Yes | No | Moderate |
| Beacon format | Yes | Yes | None |
| Tenant support | Yes | Yes | None |
| gRPC references | Partial | No | Minor |

---

## Missing Features Summary

### Critical (High Priority)

1. **Background Thread Model**
   - Python: Uses daemon threads for continuous batch processing
   - Elixir: GenServer is synchronous, relies on caller to drive batching
   - Impact: Throughput and user experience
   - Recommendation: Implement using Elixir processes (Task.async_stream or dedicated GenServer with async message passing)

2. **Server-Side Batching (Streaming)**
   - Python: Full bidirectional gRPC streaming with `_BatchBaseNew`
   - Elixir: Basic `BatchStream` module, not integrated into main API
   - Impact: Cannot use Weaviate 1.34+ optimized batching
   - Recommendation: Complete `BatchStream` integration with main Batch API

3. **Reference Ordering (UUID Lookup)**
   - Python: Tracks which objects are in-flight to order reference sends
   - Elixir: No such tracking
   - Impact: References may fail if sent before their target objects
   - Recommendation: Add UUID lookup set to batch state

### Moderate Priority

4. **Queue Ratio Algorithm**
   - Python: Uses rate/queue ratio for sophisticated batch sizing
   - Elixir: Simple threshold-based adjustment
   - Recommendation: Port the ratio-based algorithm

5. **Concurrent Request Scaling**
   - Python: Dynamically scales up to 10 concurrent requests
   - Elixir: Fixed concurrent_requests setting
   - Recommendation: Add dynamic scaling

6. **Memory-Bounded Results**
   - Python: Caps stored results at 100,000
   - Elixir: Unbounded accumulation
   - Recommendation: Add result capping

### Low Priority

7. **Vectorizer-Specific Rate Limit Patterns**
   - Python: Detailed patterns for OpenAI, Cohere, HuggingFace
   - Elixir: Generic patterns
   - Recommendation: Add API-specific patterns

8. **Async Indexing Detection**
   - Python: Detects async indexing and switches to fixed batching
   - Elixir: Manual mode selection
   - Recommendation: Add detection logic

---

## Implementation Recommendations

### Phase 1: Core Gaps (High Impact)

1. **Implement Background Processing Model**

```elixir
defmodule WeaviateEx.Batch.BackgroundBatcher do
  use GenServer

  # State includes:
  # - object queue (ETS or :queue)
  # - reference queue
  # - uuid_lookup set
  # - active_requests counter
  # - sender process
  # - receiver process (for streaming)

  def init(opts) do
    {:ok, sender_pid} = Task.start_link(&sender_loop/1)
    ...
  end

  defp sender_loop(state) do
    receive do
      :send_batch ->
        objs = pop_objects(state.batch_size)
        refs = pop_references_safe(state.uuid_lookup)
        send_async(objs, refs)
        send(self(), :send_batch)
    after
      100 -> send(self(), :send_batch)
    end
  end
end
```

2. **Complete gRPC Streaming Integration**

```elixir
defmodule WeaviateEx.Batch.StreamingBatcher do
  # Integrate BatchStream into main API

  def start_streaming(client, opts) do
    {:ok, stream} = BatchStream.open(client.grpc_channel)
    :ok = GRPC.Stub.send_request(stream, BatchStream.start_message(opts))

    # Start receiver task
    {:ok, receiver} = Task.start_link(fn ->
      receive_loop(stream, self())
    end)

    %{stream: stream, receiver: receiver, ...}
  end
end
```

3. **Add UUID Lookup for Reference Ordering**

```elixir
defmodule WeaviateEx.Batch.FixedSize do
  defstruct ...,
            pending_uuids: MapSet.new()  # UUIDs not yet sent

  def add_object(batcher, ...) do
    uuid = opts[:uuid] || UUID.generate()
    %{batcher |
      objects_buffer: [...],
      pending_uuids: MapSet.put(batcher.pending_uuids, uuid)
    }
  end

  def pop_safe_references(batcher) do
    {safe, pending} = Enum.split_with(batcher.references_buffer, fn ref ->
      not MapSet.member?(batcher.pending_uuids, ref.from_uuid) and
      not MapSet.member?(batcher.pending_uuids, ref.to_uuid)
    end)
    {safe, %{batcher | references_buffer: pending}}
  end
end
```

### Phase 2: Algorithm Improvements

4. **Port Dynamic Batching Algorithm**

```elixir
defp adjust_batch_size_advanced(state, batch_stats) do
  rate = batch_stats.rate_per_second
  queue = batch_stats.queue_length

  cond do
    queue == 0 ->
      # Scale up
      new_size = min(state.batch_size + 50, state.max_batch_size)
      new_concurrent = maybe_increase_concurrent(state, new_size)
      {new_size, new_concurrent}

    queue / rate > 10 ->
      # Way too high, stop
      {0, 2}

    queue / rate in 1.9..2.1 ->
      # Ideal
      {trunc(rate / state.concurrent_requests), state.concurrent_requests}

    queue / rate < 1.9 ->
      # Can send more
      {trunc(state.batch_size * 1.5), state.concurrent_requests}

    true ->
      # Scale down
      {trunc(rate * 2 / (queue / rate)), maybe_decrease_concurrent(state)}
  end
end
```

### Phase 3: Polish

5. **Add Result Capping**

```elixir
@max_stored_results 100_000

def add_success(results, index, uuid) do
  new_uuids = Map.put(results.successful_uuids, index, uuid)

  if map_size(new_uuids) > @max_stored_results do
    # Remove oldest entries
    sorted_keys = Map.keys(new_uuids) |> Enum.sort()
    keys_to_remove = Enum.take(sorted_keys, map_size(new_uuids) - @max_stored_results)
    new_uuids = Map.drop(new_uuids, keys_to_remove)
  end

  %{results | successful_uuids: new_uuids}
end
```

6. **Enhanced Rate Limit Detection**

```elixir
@vectorizer_patterns %{
  openai: [
    ~r/Rate limit reached/,
    ~r/on tokens per min \(TPM\)/,
    ~r/503 error: Service Unavailable/,
    ~r/500 error: The server had an error/
  ],
  cohere: [
    ~r/support@cohere\.com.*rate limit/,
    ~r/support@cohere\.com.*500 error/
  ],
  huggingface: [
    ~r/failed with status: 503 error/
  ]
}

def detect_rate_limit(message) do
  Enum.find(@vectorizer_patterns, fn {_provider, patterns} ->
    Enum.any?(patterns, &Regex.match?(&1, message))
  end)
end
```

---

## Conclusion

The WeaviateEx Elixir port provides a functional batch API that covers the essential use cases. However, to achieve full parity with the Python client, focus should be placed on:

1. **Background processing** - Critical for high-throughput scenarios
2. **Server-side streaming** - Required for Weaviate 1.34+ optimizations
3. **Reference ordering** - Important for data integrity

The existing codebase is well-structured and provides a solid foundation for these enhancements. The GenServer-based approach in Elixir is actually well-suited for implementing the background processing model, potentially even more elegantly than Python's threading approach.

---

## Appendix: File Reference

### Python Client Files Analyzed

| File | Purpose |
|------|---------|
| `/weaviate/collections/batch/__init__.py` | Module exports |
| `/weaviate/collections/batch/base.py` | Core batch logic, `_BatchBase`, `_BatchBaseNew` |
| `/weaviate/collections/batch/batch_wrapper.py` | Context manager, result access |
| `/weaviate/collections/batch/collection.py` | Collection-specific batching |
| `/weaviate/collections/batch/client.py` | Client-level batching |
| `/weaviate/collections/batch/grpc_batch.py` | gRPC batch implementation |
| `/weaviate/collections/batch/grpc_batch_delete.py` | gRPC delete implementation |
| `/weaviate/collections/batch/rest.py` | REST reference batching |
| `/weaviate/collections/classes/batch.py` | Batch data classes |

### Elixir Port Files Analyzed

| File | Purpose |
|------|---------|
| `/lib/weaviate_ex/batch.ex` | Main batch module |
| `/lib/weaviate_ex/api/batch.ex` | API layer for batch ops |
| `/lib/weaviate_ex/batch/fixed_size.ex` | Fixed-size batcher |
| `/lib/weaviate_ex/batch/dynamic.ex` | Dynamic batcher (GenServer) |
| `/lib/weaviate_ex/batch/rate_limited.ex` | Rate-limited batcher (GenServer) |
| `/lib/weaviate_ex/batch/batch_retry.ex` | Retry logic |
| `/lib/weaviate_ex/batch/error_tracking.ex` | Error structures |
| `/lib/weaviate_ex/batch/delete_result.ex` | Delete result parsing |
| `/lib/weaviate_ex/grpc/services/batch.ex` | gRPC batch service |
| `/lib/weaviate_ex/grpc/services/batch_stream.ex` | gRPC streaming |
