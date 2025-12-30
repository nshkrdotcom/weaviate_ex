# Batch Operations Gap Analysis: Python Client vs Elixir Port

**Date:** 2025-12-29
**Author:** Claude Code Analysis
**Scope:** Batch API, gRPC batch operations, streaming, concurrency, error handling

---

## Executive Summary

The Elixir port (`WeaviateEx`) has made significant progress implementing batch operations with feature parity in core batch insert/delete functionality via both HTTP and gRPC. However, several advanced features from the Python client remain missing or partially implemented:

### Key Findings

| Category | Status | Impact |
|----------|--------|--------|
| Basic batch insert/delete | Complete | Low risk |
| Fixed-size batching | Complete | Low risk |
| Dynamic batching | Partial | Medium risk |
| Rate-limited batching | Complete | Low risk |
| Background processing | Complete | Low risk |
| Server-side batching (streaming) | Partial | High risk |
| Progress callbacks | Partial | Medium risk |
| Vectorizer rate limit detection | Basic | Medium risk |
| Context manager pattern | N/A (Elixir uses GenServers) | None |

### Critical Gaps

1. **Server-side batching stream reconnection** - Python handles node failover and stream reconnection; Elixir implementation is simpler
2. **Vectorizer batching step size** - Python dynamically adjusts for vectorizer APIs; Elixir has fixed sizing
3. **Object caching for recovery** - Python caches in-flight objects for stream recovery; Elixir does not
4. **Wait for vector indexing** - Python can wait for async indexing completion; missing in Elixir

---

## Feature Comparison Table

| Feature | Python Client | Elixir Port | Gap Level |
|---------|---------------|-------------|-----------|
| **Batch Insert Operations** ||||
| Basic batch insert via HTTP | Yes | Yes | None |
| Basic batch insert via gRPC | Yes | Yes | None |
| Batch insert with consistency level | Yes | Yes | None |
| Batch insert with tenant | Yes | Yes | None |
| Batch insert with custom vector | Yes | Yes | None |
| Batch insert with named vectors | Yes | Yes | None |
| Auto UUID generation | Yes | Yes | None |
| Deterministic UUID generation | Yes | Yes | None |
| **Batch Delete Operations** ||||
| Delete by filter (HTTP) | Yes | Yes | None |
| Delete by filter (gRPC) | Yes | Yes | None |
| Dry run mode | Yes | Yes | None |
| Verbose output mode | Yes | Yes | None |
| **Batching Strategies** ||||
| Fixed-size batching | Yes | Yes | None |
| Dynamic batching | Yes | Partial | Medium |
| Rate-limited batching | Yes | Yes | None |
| Server-side batching | Yes | Partial | High |
| **Rate Limiting** ||||
| Requests per minute limit | Yes | Yes | None |
| Provider-specific detection (OpenAI, Cohere) | Yes | Yes | None |
| Exponential backoff | Yes | Yes | None |
| Retry-After header parsing | Yes | Yes | None |
| Automatic retry on rate limit | Yes | Yes | None |
| **Error Handling** ||||
| Per-object error tracking | Yes | Yes | None |
| Error aggregation | Yes | Yes | None |
| Failed object collection | Yes | Yes | None |
| Failed reference collection | Yes | Yes | None |
| Max stored results limit | Yes (100,000) | Yes (100,000) | None |
| **Concurrent Processing** ||||
| Parallel batch requests | Yes | Yes | None |
| Configurable concurrency | Yes | Yes | None |
| Task-based async | Yes (threading) | Yes (Task.async_stream) | None |
| **Streaming Operations** ||||
| gRPC bidirectional streaming | Yes | Yes | None |
| Server backoff handling | Yes | Yes | None |
| Stream reconnection | Yes | Partial | High |
| Object caching for recovery | Yes | No | High |
| Graceful shutdown | Yes | Partial | Medium |
| **Progress/Callbacks** ||||
| On flush callback | Yes | Yes | None |
| On error callback | Yes | Yes | None |
| Progress reporting | Limited | Limited | Low |
| **Reference Batching** ||||
| Basic reference batching | Yes | Yes | None |
| Reference ordering (wait for objects) | Yes | Yes | None |
| Multi-target references | Yes | Yes | None |
| **Wait Operations** ||||
| Wait for vector indexing | Yes | No | High |
| Shard status checking | Yes | No | High |

---

## Detailed Gap Analysis

### 1. Batch Insert Operations

#### Python Implementation
```python
# From weaviate/collections/batch/base.py
class _BatchBase:
    def _add_object(
        self,
        collection: str,
        properties: Optional[WeaviateProperties] = None,
        references: Optional[ReferenceInputs] = None,
        uuid: Optional[UUID] = None,
        vector: Optional[VECTORS] = None,
        tenant: Optional[str] = None,
    ) -> UUID:
        # Validates with pydantic
        batch_object = BatchObject(
            collection=collection,
            properties=properties,
            references=references,
            uuid=uuid,
            vector=vector,
            tenant=tenant,
            index=self.__objs_count,
        )
        # Track shard for later indexing check
        self.__results_for_wrapper.imported_shards.add(
            Shard(collection=collection, tenant=tenant)
        )
        # Block if queue too long
        while self.__recommended_num_objects == 0 or \
              len(self.__batch_objects) >= self.__recommended_num_objects * 2:
            time.sleep(0.01)
```

#### Elixir Implementation
```elixir
# From lib/weaviate_ex/batch/dynamic.ex
def handle_call({:add_object, collection, properties, opts}, _from, state) do
  object = %{
    collection: collection,
    properties: properties,
    uuid: Keyword.get(opts, :uuid),
    vector: Keyword.get(opts, :vector),
    tenant: Keyword.get(opts, :tenant)
  }

  new_state = %{state | objects_buffer: [object | state.objects_buffer]}

  # Auto-flush if needed
  if new_state.auto_flush and length(new_state.objects_buffer) >= new_state.batch_size do
    case do_flush(new_state) do
      {:ok, flushed_state} -> {:reply, :ok, flushed_state}
      {:error, _error, flushed_state} -> {:reply, :ok, flushed_state}
    end
  else
    {:reply, :ok, new_state}
  end
end
```

#### Gap Analysis
- **Shard tracking**: Python tracks imported shards for later indexing verification; Elixir does not
- **Backpressure**: Both implement backpressure but Python ties it to server queue status
- **Pydantic validation**: Python uses Pydantic for object validation; Elixir relies on type specs

### 2. Batch Delete Operations

Both implementations are feature-complete for batch delete operations.

#### Python Implementation
```python
# From weaviate/collections/batch/grpc_batch_delete.py
class _BatchDeleteGRPC(_BaseGRPC):
    def batch_delete(
        self,
        connection: Connection,
        name: str,
        filters: _Filters,
        verbose: bool,
        dry_run: bool,
        tenant: Optional[str],
    ) -> executor.Result[DeleteManyReturn]:
        request = batch_delete_pb2.BatchDeleteRequest(
            collection=name,
            consistency_level=self._consistency_level,
            verbose=verbose,
            dry_run=dry_run,
            tenant=tenant,
            filters=_FilterToGRPC.convert(filters),
        )
```

#### Elixir Implementation
```elixir
# From lib/weaviate_ex/api/batch.ex
def delete_objects(client, criteria, opts \\ []) when is_map(criteria) do
  if grpc_available?(client) do
    delete_objects_grpc(client, criteria, opts)
  else
    delete_objects_http(client, criteria, opts)
  end
end
```

#### Gap Analysis
- Both support dry_run, verbose output, consistency levels
- Elixir has dedicated `DeleteResult` struct with helper functions
- **No gaps identified**

### 3. Rate Limiting Strategies

#### Python Implementation
```python
# From weaviate/collections/batch/base.py
@dataclass
class _RateLimitedBatching:
    requests_per_minute: int

# Rate limit handling in __send_batch
if ("support@cohere.com" in err.message and
    ("rate limit" in err.message or "500 error" in err.message)) or \
   ("OpenAI" in err.message and
    ("Rate limit reached" in err.message or "on tokens per min" in err.message)):
    if err.object_.retry_count > 5:
        continue  # too many retries
    err.object_.retry_count += 1
    readded_objects.append(i)
```

#### Elixir Implementation
```elixir
# From lib/weaviate_ex/batch/rate_limit.ex
@rate_limit_patterns [
  "rate limit",
  "rate_limit",
  "rate-limit",
  "too many requests",
  "quota exceeded",
  "insufficient_quota",
  "throttl"
]

def rate_limited?(%{status: 429}), do: true

# From lib/weaviate_ex/batch/batch_retry.ex
def rate_limit_error?(message) when is_binary(message) do
  patterns = [
    ~r/rate limit/i,
    ~r/Rate limit reached/i,
    ~r/tokens per min/i,
    ~r/support@cohere\.com/,
    ~r/503 error/i,
    ~r/too many requests/i,
    ~r/retry after/i
  ]
  Enum.any?(patterns, &Regex.match?(&1, message))
end
```

#### Gap Analysis
- **OpenAI/Cohere specific patterns**: Python has more specific pattern matching; Elixir uses regex
- **Retry count per object**: Python tracks retry count per object; Elixir's approach is simpler
- **Provider-specific handling**: Both detect rate limits similarly

### 4. Error Handling and Retries

#### Python Implementation
```python
# From weaviate/collections/batch/base.py
MAX_RETRIES = float(os.getenv("WEAVIATE_BATCH_MAX_RETRIES", "9.299"))

# Error tracking
@dataclass
class ErrorObject:
    message: str
    object_: BatchObject
    original_uuid: Optional[UUID] = None

@dataclass
class BatchObjectReturn:
    _all_responses: List[Union[uuid_package.UUID, ErrorObject]]
    elapsed_seconds: float = 0.0
    errors: Dict[int, ErrorObject] = field(default_factory=dict)
    uuids: Dict[int, uuid_package.UUID] = field(default_factory=dict)
    has_errors: bool = False
```

#### Elixir Implementation
```elixir
# From lib/weaviate_ex/batch/error_tracking.ex
defmodule ErrorObject do
  @enforce_keys [:message, :object]
  defstruct [:message, :object, :original_uuid, :retry_count]
end

defmodule Results do
  @max_stored_results 100_000

  defstruct failed_objects: [],
            failed_references: [],
            successful_uuids: %{},
            elapsed_seconds: 0.0
end
```

#### Gap Analysis
- Both implement 100,000 max stored results limit
- **Retry count**: Python tracks per-object retry count; Elixir tracks in ErrorObject
- **Environment variable config**: Python allows MAX_RETRIES via env var; Elixir uses module attribute

### 5. Fixed Size vs Dynamic Batching

#### Python Dynamic Batching
```python
# From weaviate/collections/batch/base.py
def __dynamic_batching(self) -> None:
    status = self.__cluster.get_nodes_status()

    # Check for async indexing
    if "batchStats" not in status[0] or "queueLength" not in status[0]["batchStats"]:
        self.__batching_mode = _FixedSizeBatching(1000, 10)
        return

    rate: int = status[0]["batchStats"]["ratePerSecond"]
    batch_length = status[0]["batchStats"]["queueLength"]

    if self.__vectorizer_batching:
        # Adjust for slow vectorizers
        if len(self.__took_queue) > 0:
            max_took = max(self.__took_queue)
            if max_took > 2 * BATCH_TIME_TARGET:
                self.__concurrent_requests = 1
                self.__recommended_num_objects = VECTORIZER_BATCHING_STEP_SIZE
```

#### Elixir Dynamic Batching
```elixir
# From lib/weaviate_ex/batch/dynamic.ex
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

# Server stats polling
defp poll_and_update_stats(state) do
  case Cluster.batch_stats(state.client) do
    {:ok, stats} ->
      queue_size = stats.queue_length
      new_batch_size = adjust_batch_size(state.batch_size, queue_size, state)
      %{state | queue_size: queue_size, batch_size: new_batch_size}
    {:error, _} ->
      state
  end
end
```

#### Gap Analysis
- **Vectorizer batching detection**: Python detects vectorizer-based batching and uses step sizes; Elixir does not
- **Time-based adjustment**: Python tracks request timing (`took_queue`); Elixir adjusts only on queue size
- **Concurrent request scaling**: Python scales concurrent requests based on conditions; Elixir is simpler
- **Batch time target**: Python uses 10-second target; Elixir does not have time-based targets

### 6. Concurrent Batch Processing

#### Python Implementation
```python
# From weaviate/collections/batch/base.py
MAX_CONCURRENT_REQUESTS = 10
CONCURRENT_REQUESTS_DYNAMIC_VECTORIZER = 2

# Background thread approach
def __batch_send(self) -> None:
    while not self.__shut_background_thread_down.is_set():
        if self.__active_requests < self.__concurrent_requests:
            # Pop and send batch
            ctx = contextvars.copy_context()
            self.__executor.submit(
                ctx.run,
                functools.partial(self.__send_batch, objs, refs)
            )
```

#### Elixir Implementation
```elixir
# From lib/weaviate_ex/batch/concurrent.ex
@default_options [
  max_concurrency: 4,
  batch_size: 100,
  ordered: false,
  timeout: 30_000
]

def insert_many(client, collection, objects, opts \\ []) do
  batches = split_into_batches(objects, opts)

  batch_results =
    batches
    |> Enum.with_index()
    |> Task.async_stream(
      fn {batch, index} -> execute_batch(client, collection, batch, index, opts) end,
      max_concurrency: opts[:max_concurrency],
      timeout: opts[:timeout],
      on_timeout: :kill_task
    )
```

#### Gap Analysis
- **Threading model**: Python uses ThreadPoolExecutor; Elixir uses Task.async_stream
- **Context preservation**: Python uses contextvars; Elixir has process-based isolation naturally
- **Default concurrency**: Python uses 2-10; Elixir defaults to 4

### 7. Streaming Batch Operations

#### Python Implementation
```python
# From weaviate/collections/batch/base.py
class _BatchBaseNew:
    """Server-side batching with bidirectional streaming"""

    def __batch_recv(self) -> None:
        for message in self.__batch_grpc.stream(
            connection=self.__connection,
            requests=self.__generate_stream_requests_for_grpc(),
        ):
            if message.HasField("started"):
                for threads in self.__bg_threads:
                    threads.start_send()
            if message.HasField("backoff"):
                self.__batch_size = message.backoff.batch_size
            if message.HasField("results"):
                # Process results...
            elif message.HasField("shutting_down"):
                self.__is_shutting_down.set()
            elif message.HasField("shutdown"):
                self.__is_shutdown.set()
                self.__reconnect()

    def __reconnect(self, retry: int = 0) -> None:
        if self.__consistency_level == ConsistencyLevel.ALL:
            # Wait for all nodes healthy
            while len(nodes := cluster.get_nodes_status()) != 3:
                time.sleep(5)
        try:
            self.__connection.close("sync")
            self.__connection.connect(force=True)
        except (WeaviateStartUpError, WeaviateGRPCUnavailableError):
            if retry < 5:
                time.sleep(2**retry)
                self.__reconnect(retry + 1)
```

#### Elixir Implementation
```elixir
# From lib/weaviate_ex/batch/stream.ex
def flush(%__MODULE__{state: state} = stream) when state in [:connected, :streaming] do
  objects = Enum.reverse(stream.buffer)

  case send_batch(stream, objects) do
    {:ok, results} ->
      {:ok, %{stream | buffer: [], results: stream.results ++ results}}
    {:error, reason} ->
      maybe_reconnect(stream, reason)
  end
end

defp maybe_reconnect(stream, _reason) do
  if stream.reconnect_attempts >= stream.max_reconnect_attempts do
    {:error, :max_reconnect_attempts_exceeded}
  else
    case reconnect(stream, stream.max_reconnect_attempts) do
      {:ok, reconnected} -> flush(reconnected)
      error -> error
    end
  end
end
```

#### Gap Analysis
- **Object caching for recovery**: Python caches objects in `__objs_cache` for recovery on stream failure; Elixir does not
- **Consistency-aware reconnection**: Python waits for all nodes healthy when CL=ALL; Elixir does not
- **Separate send/receive threads**: Python has dedicated threads; Elixir manages both in one flow
- **Graceful shutdown handling**: Python handles `shutting_down` and `shutdown` messages separately; Elixir simpler

### 8. gRPC Batch Implementation

Both implementations support gRPC batch operations with similar capabilities.

#### Python Implementation
```python
# From weaviate/collections/batch/grpc_batch.py
class _BatchGRPC(_BaseGRPC):
    def objects(
        self,
        connection: Connection,
        objects: List[_BatchObject],
        timeout: Union[int, float],
        max_retries: float,
    ) -> executor.Result[BatchObjectReturn]:
        weaviate_objs = self.grpc_objects(objects)
        request = batch_pb2.BatchObjectsRequest(
            objects=weaviate_objs,
            consistency_level=self._consistency_level,
        )
        return executor.execute(
            response_callback=resp,
            method=connection.grpc_batch_objects,
            request=request,
            timeout=timeout,
            max_retries=max_retries,
        )
```

#### Elixir Implementation
```elixir
# From lib/weaviate_ex/grpc/services/batch.ex
def insert_objects(channel, objects, opts \\ []) when is_list(objects) do
  batch_objects = Enum.map(objects, &build_batch_object/1)

  request = %BatchObjectsRequest{
    objects: batch_objects,
    consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level))
  }

  Retry.with_retry(
    fn ->
      WeaviateStub.batch_objects(channel, request, timeout: timeout, metadata: metadata)
    end,
    retry_opts
  )
end
```

#### Gap Analysis
- **Executor pattern**: Python uses an executor abstraction; Elixir uses direct gRPC calls with retry wrapper
- **Named vectors**: Both support named vectors
- **Multi-target references**: Both support multi-target references

### 9. Progress Callbacks/Reporting

#### Python Implementation
```python
# Limited callback support via context manager
class _BatchWrapper:
    @property
    def results(self) -> BatchResult:
        return self._batch_data.results

    @property
    def failed_objects(self) -> List[ErrorObject]:
        return self._batch_data.failed_objects
```

#### Elixir Implementation
```elixir
# From lib/weaviate_ex/batch/dynamic.ex and background.ex
state = %{
  on_flush: Keyword.get(opts, :on_flush),
  on_error: Keyword.get(opts, :on_error),
}

# Called after flush
if state.on_flush, do: state.on_flush.(merged_results)

# Called on error
if state.on_error, do: state.on_error.(error)
```

#### Gap Analysis
- Both support on_flush and on_error callbacks
- Neither has real-time progress percentage reporting
- **No significant gaps**

---

## Missing Features in Elixir

### 1. Wait for Vector Indexing (HIGH PRIORITY)

Python provides `wait_for_vector_indexing()` to block until async indexing completes:

```python
def wait_for_vector_indexing(
    self, shards: Optional[List[Shard]] = None, how_many_failures: int = 5
) -> None:
    """Wait for all vectors of batch imported objects to be indexed."""
    while not self.__is_ready(how_many_failures, shards):
        time.sleep(0.25)
```

**Elixir needs:**
```elixir
# Proposed implementation
def wait_for_vector_indexing(client, shards, opts \\ []) do
  max_failures = Keyword.get(opts, :how_many_failures, 5)
  poll_interval = Keyword.get(opts, :poll_interval, 250)

  do_wait(client, shards, max_failures, poll_interval)
end
```

### 2. Object Caching for Stream Recovery (HIGH PRIORITY)

Python caches in-flight objects for recovery:

```python
with self.__objs_cache_lock:
    self.__objs_cache[uuid] = batch_object

# On stream failure
with self.__objs_cache_lock:
    self.__batch_objects.prepend([
        self.__batch_grpc.grpc_object(o._to_internal())
        for o in self.__objs_cache.values()
    ])
```

**Elixir needs:**
- Add object/reference caching in Stream module
- On reconnection, re-queue cached items

### 3. Vectorizer Batching Detection (MEDIUM PRIORITY)

Python detects and adjusts for vectorizer-based workloads:

```python
VECTORIZER_BATCHING_STEP_SIZE = 48  # cohere max batch size is 96

if self.__vectorizer_batching:
    if max_took > 2 * BATCH_TIME_TARGET:
        self.__concurrent_requests = 1
        self.__recommended_num_objects = VECTORIZER_BATCHING_STEP_SIZE
```

**Elixir needs:**
- Detection of vectorizer-based modules
- Step-size based batch adjustment
- Time-based tuning

### 4. Shard Status Checking (MEDIUM PRIORITY)

Python tracks and checks shard status:

```python
def __get_shards_readiness(self, shard: Shard) -> List[bool]:
    path = f"/schema/{shard.collection}/shards"
    response = self._connection.get(path=path)
    return [
        (shard.get("status") == "READY") &
        (shard.get("vectorQueueSize") == 0)
        for shard in res
    ]
```

**Elixir needs:**
- Shard status API call
- Integration with batch result tracking

---

## Priority Recommendations

### P0 - Critical (Implement Before Production Use)

1. **Wait for Vector Indexing**
   - Required for data integrity verification
   - Estimated effort: 2-4 hours

2. **Object Caching for Stream Recovery**
   - Required for reliable server-side batching
   - Estimated effort: 4-8 hours

### P1 - High (Implement for Feature Parity)

3. **Improved Stream Reconnection**
   - Consistency-level aware reconnection
   - Separate shutting_down/shutdown handling
   - Estimated effort: 4-6 hours

4. **Shard Status Checking**
   - Required for wait_for_vector_indexing
   - Estimated effort: 2-4 hours

### P2 - Medium (Nice to Have)

5. **Vectorizer Batching Detection**
   - Improves performance with vectorizer APIs
   - Estimated effort: 4-6 hours

6. **Time-based Batch Adjustment**
   - Track batch execution time
   - Adjust based on BATCH_TIME_TARGET
   - Estimated effort: 2-4 hours

### P3 - Low (Future Enhancement)

7. **Environment Variable Configuration**
   - MAX_RETRIES via env var
   - Estimated effort: 1-2 hours

8. **Imported Shards Tracking**
   - Track collections/tenants inserted into
   - Estimated effort: 2-3 hours

---

## Code Examples Showing Differences

### Dynamic Batching Comparison

**Python (sophisticated):**
```python
def __dynamic_batching(self) -> None:
    status = self.__cluster.get_nodes_status()
    rate: int = status[0]["batchStats"]["ratePerSecond"]
    batch_length = status[0]["batchStats"]["queueLength"]

    self.__rate_queue.append(rate)

    if self.__vectorizer_batching:
        max_took = max(self.__took_queue)
        if max_took > 2 * BATCH_TIME_TARGET:
            self.__concurrent_requests = 1
            self.__recommended_num_objects = VECTORIZER_BATCHING_STEP_SIZE
        elif max_took > BATCH_TIME_TARGET:
            # Scale down
            if self.__concurrent_requests > 1:
                self.__concurrent_requests -= 1
            else:
                self.__dynamic_batching_sleep_time = max_took - BATCH_TIME_TARGET
    else:
        if batch_length == 0:
            self.__recommended_num_objects = min(
                self.__recommended_num_objects + 50,
                self.__max_batch_size
            )
        else:
            ratio = batch_length / rate
            if 2.1 > ratio > 1.9:
                self.__recommended_num_objects = math.floor(rate_per_worker)
```

**Elixir (simpler):**
```elixir
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
```

### Stream Recovery Comparison

**Python (comprehensive):**
```python
def __batch_recv(self) -> None:
    for message in self.__batch_grpc.stream(...):
        if message.HasField("shutting_down"):
            self.__is_shutting_down.set()
        elif message.HasField("shutdown"):
            self.__is_shutdown.set()
            self.__reconnect()

    if self.__is_shutdown.is_set():
        self.__is_shutdown.clear()
        return self.__batch_recv()  # Restart

def __reconnect(self, retry: int = 0) -> None:
    if self.__consistency_level == ConsistencyLevel.ALL:
        while len(nodes := cluster.get_nodes_status()) != 3:
            time.sleep(5)
    try:
        self.__connection.close("sync")
        self.__connection.connect(force=True)
    except WeaviateStartUpError:
        if retry < 5:
            time.sleep(2**retry)
            self.__reconnect(retry + 1)
```

**Elixir (basic):**
```elixir
defp maybe_reconnect(stream, _reason) do
  if stream.reconnect_attempts >= stream.max_reconnect_attempts do
    {:error, :max_reconnect_attempts_exceeded}
  else
    case reconnect(stream, stream.max_reconnect_attempts) do
      {:ok, reconnected} -> flush(reconnected)
      error -> error
    end
  end
end

def reconnect(%__MODULE__{} = stream, max_attempts \\ 3) do
  if stream.reconnect_attempts >= max_attempts do
    {:error, :max_reconnect_attempts_exceeded}
  else
    reset_stream = %{stream | stream_handle: nil, state: :initialized}
    connect(reset_stream)
  end
end
```

---

## Conclusion

The Elixir port has achieved good feature parity for core batch operations. The main gaps are in advanced resilience features (stream recovery with object caching), monitoring features (wait for indexing), and sophisticated dynamic batching for vectorizer workloads.

For production use with server-side batching, the P0 items should be implemented. For basic batch operations with fixed or rate-limited batching, the current implementation is fully functional.

---

## Appendix: File References

### Python Client Files Analyzed
- `weaviate/collections/batch/base.py` - Core batch implementation (~1400 lines)
- `weaviate/collections/batch/grpc_batch.py` - gRPC batch operations (~350 lines)
- `weaviate/collections/batch/grpc_batch_delete.py` - gRPC batch delete (~76 lines)
- `weaviate/collections/batch/batch_wrapper.py` - Batch context manager (~277 lines)
- `weaviate/collections/classes/batch.py` - Batch data classes (~338 lines)

### Elixir Port Files Analyzed
- `lib/weaviate_ex/api/batch.ex` - API layer (~371 lines)
- `lib/weaviate_ex/batch/background.ex` - Background processor (~580 lines)
- `lib/weaviate_ex/batch/concurrent.ex` - Concurrent batch (~274 lines)
- `lib/weaviate_ex/batch/dynamic.ex` - Dynamic batching (~626 lines)
- `lib/weaviate_ex/batch/fixed_size.ex` - Fixed-size batching (~232 lines)
- `lib/weaviate_ex/batch/rate_limited.ex` - Rate-limited batching (~572 lines)
- `lib/weaviate_ex/batch/stream.ex` - Streaming batch (~564 lines)
- `lib/weaviate_ex/batch/batch_retry.ex` - Retry logic (~123 lines)
- `lib/weaviate_ex/batch/rate_limit.ex` - Rate limit detection (~203 lines)
- `lib/weaviate_ex/batch/error_tracking.ex` - Error tracking (~215 lines)
- `lib/weaviate_ex/batch/delete_result.ex` - Delete result (~187 lines)
- `lib/weaviate_ex/batch/queue.ex` - Object queue (~267 lines)
- `lib/weaviate_ex/grpc/services/batch.ex` - gRPC batch service (~418 lines)
- `lib/weaviate_ex/grpc/services/batch_stream.ex` - gRPC streaming (~348 lines)
