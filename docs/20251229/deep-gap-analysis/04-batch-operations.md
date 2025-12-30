# Deep Gap Analysis: Batch Operations

## Executive Summary

This document provides an in-depth comparison of batch operations between the canonical Python Weaviate client and the WeaviateEx Elixir implementation. The analysis focuses on seven key areas: batch insert/upsert, batch delete, dynamic batching, rate limiting, error handling, background processing, and callbacks/progress reporting.

### Overall Assessment

| Area | Python Maturity | Elixir Status | Gap Severity |
|------|-----------------|---------------|--------------|
| Batch Insert/Upsert | Mature | Good | Medium |
| Batch Delete | Mature | Good | Low |
| Dynamic Batching | Sophisticated | Partial | Medium |
| Rate Limiting/Throttling | Comprehensive | Good | Low |
| Error Handling & Recovery | Excellent | Partial | High |
| Background Processing | Excellent | Good | Medium |
| Callbacks & Progress | Good | Good | Low |

**Critical Gaps Identified:**
1. No automatic re-queuing of failed objects for retry (Python has this)
2. Missing server-side batch streaming support (Weaviate 1.34+ feature)
3. No MAX_STORED_RESULTS limit (potential memory issues)
4. Vectorizer-aware batching mode missing
5. Named vectors not supported in main batch APIs

---

## 1. Batch Insert/Upsert Operations

### Python Implementation

**Files:**
- `/weaviate-python-client/weaviate/collections/batch/base.py` - Core batch logic
- `/weaviate-python-client/weaviate/collections/batch/grpc_batch.py` - gRPC batch insertion
- `/weaviate-python-client/weaviate/collections/classes/batch.py` - Data classes

**Key Functions:**

```python
# base.py - _BatchBase._add_object()
def _add_object(
    self,
    collection: str,
    properties: Optional[WeaviateProperties] = None,
    references: Optional[ReferenceInputs] = None,
    uuid: Optional[UUID] = None,
    vector: Optional[VECTORS] = None,
    tenant: Optional[str] = None,
) -> UUID:
    batch_object = BatchObject(
        collection=collection,
        properties=properties,
        references=references,  # <-- Inline references!
        uuid=uuid,
        vector=vector,
        tenant=tenant,
        index=self.__objs_count,
    )
    self.__uuid_lookup.add(str(batch_object.uuid))
    self.__batch_objects.add(batch_object._to_internal())
    return batch_object.uuid
```

**Features:**
- Thread-safe queue with locks (`self._lock`)
- Inline reference support (references added with objects)
- UUID lookup table for reference ordering
- Auto-UUID generation via `uuid_package.uuid4()`
- Backpressure: blocks when `recommended_num_objects == 0` or queue is 2x recommended
- Index tracking per object
- Retry count tracking on BatchObject

### Elixir Implementation

**Files:**
- `/lib/weaviate_ex/batch.ex` - Main batch module
- `/lib/weaviate_ex/batch/fixed_size.ex` - Fixed size batcher
- `/lib/weaviate_ex/api/batch.ex` - API layer
- `/lib/weaviate_ex/grpc/services/batch.ex` - gRPC service

**Key Functions:**

```elixir
# batch.ex - add_object/4
def add_object(%{mode: :fixed} = ctx, collection, properties, opts) do
  batcher = FixedSize.add_object(ctx.batcher, collection, properties, opts)

  if FixedSize.ready_to_send?(batcher) do
    case flush_fixed_batch(ctx.client, batcher, ctx.opts) do
      {:ok, new_results, _} ->
        %{ctx | batcher: FixedSize.clear(batcher), results: merge_results(...)}
      {:error, _} ->
        %{ctx | batcher: batcher}
    end
  else
    %{ctx | batcher: batcher}
  end
end
```

### Gap Analysis: Batch Insert

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Basic object batching | Yes | Yes | None |
| Auto-flush on size threshold | Yes | Yes | None |
| Inline references | Yes | **No** | **Medium** |
| UUID lookup for ref ordering | Yes | Partial | Low |
| Backpressure/blocking | Yes | **No** | **Medium** |
| Index tracking | Yes | Yes | None |
| Retry count on object | Yes | Struct exists | Not used |
| Named vectors | Yes | **No** (stream only) | **High** |
| Consistency level | Yes | Yes | None |
| Tenant support | Yes | Yes | None |

**Gap Details:**

1. **Inline References** (Medium Priority)
   - Python: `batch.add_object(properties=..., references={"author": author_uuid})`
   - Elixir: Must call `add_reference/5` separately
   - Impact: Less convenient API, requires separate reference batch

2. **Backpressure** (Medium Priority)
   - Python blocks when Weaviate is overloaded (`recommended_num_objects == 0`)
   - Elixir has no blocking mechanism
   - Impact: Could overwhelm server with too many objects

3. **Named Vectors** (High Priority)
   - Python: Full support via `__multi_vec()` in grpc_batch.py
   - Elixir: Only in `BatchStream` module, not main batch APIs
   - Impact: Cannot batch insert objects with named vectors

---

## 2. Batch Delete Operations

### Python Implementation

**File:** `/weaviate-python-client/weaviate/collections/batch/grpc_batch_delete.py`

```python
class _BatchDeleteGRPC(_BaseGRPC):
    def batch_delete(
        self,
        connection: Connection,
        *,
        name: str,
        filters: _Filters,
        verbose: bool,
        dry_run: bool,
        tenant: Optional[str],
    ) -> executor.Result[Union[DeleteManyReturn[...], ...]]:
        request = batch_delete_pb2.BatchDeleteRequest(
            collection=name,
            consistency_level=self._consistency_level,
            verbose=verbose,
            dry_run=dry_run,
            tenant=tenant,
            filters=_FilterToGRPC.convert(filters),
        )
```

**Return Type:**

```python
@dataclass
class DeleteManyReturn(Generic[T]):
    failed: int
    matches: int
    objects: T  # List[DeleteManyObject] when verbose, None otherwise
    successful: int
```

### Elixir Implementation

**Files:**
- `/lib/weaviate_ex/api/batch.ex` - `delete_objects/3`
- `/lib/weaviate_ex/grpc/services/batch.ex` - `delete_objects/4`

```elixir
# api/batch.ex
def delete_objects_grpc(client, criteria, opts) do
  collection = criteria["class"] || criteria[:class]
  filter = criteria["where"] || criteria[:where]

  grpc_opts = [
    consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level)),
    tenant: Keyword.get(opts, :tenant),
    verbose: Keyword.get(opts, :verbose, false),
    dry_run: Keyword.get(opts, :dry_run, false)
  ]

  grpc_filter = convert_where_filter(filter)
  GRPCBatch.delete_objects(channel, collection, grpc_filter, grpc_opts)
end
```

### Gap Analysis: Batch Delete

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Delete by filter | Yes | Yes | None |
| gRPC support | Yes | Yes | None |
| HTTP fallback | Yes | Yes | None |
| Verbose mode | Yes | Yes | None |
| Dry run | Yes | Yes | None |
| Consistency level | Yes | Yes | None |
| Tenant support | Yes | Yes | None |
| Delete by UUID list | Via filter | Via filter | None |
| Return type (matches/failed) | Yes | Yes | None |
| Object list on verbose | Yes | Yes | None |

**Status: Fully Implemented**

No significant gaps in batch delete functionality.

---

## 3. Dynamic Batching (Auto-Batching Based on Size/Count)

### Python Implementation

**File:** `/weaviate-python-client/weaviate/collections/batch/base.py`

**Constants:**

```python
MAX_CONCURRENT_REQUESTS = 10
BATCH_TIME_TARGET = 10  # seconds
VECTORIZER_BATCHING_STEP_SIZE = 48  # cohere max batch size
MAX_RETRIES = 9.299  # ~10m30s worst case for server scale up
```

**Dynamic Adjustment Logic:**

```python
def __dynamic_batching(self) -> None:
    status = self.__cluster.get_nodes_status()

    # Check for async indexing mode
    if "batchStats" not in status[0]:
        # Switch to fixed high-throughput mode
        self.__batching_mode = _FixedSizeBatching(1000, 10)
        return

    rate = status[0]["batchStats"]["ratePerSecond"]
    batch_length = status[0]["batchStats"]["queueLength"]

    if self.__vectorizer_batching:
        # Slow vectorizer mode - larger batches, fewer concurrent
        if len(self.__took_queue) > 0:
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
            elif max_took < 0.75 * BATCH_TIME_TARGET:
                # Scale up
                if self.__concurrent_requests < 3:
                    self.__concurrent_requests += 1
    else:
        # Normal mode - scale based on queue depth
        if batch_length == 0:
            self.__recommended_num_objects = min(
                self.__recommended_num_objects + 50, self.__max_batch_size
            )
        else:
            ratio = batch_length / rate
            if 1.9 < ratio < 2.1:  # Ideal
                self.__recommended_num_objects = math.floor(rate / self.__concurrent_requests)
            elif ratio <= 1.9:  # Can send more
                self.__recommended_num_objects = min(
                    self.__recommended_num_objects * 1.5,
                    rate * 2 / ratio
                )
            elif ratio > 10:  # Way too high
                self.__recommended_num_objects = 0  # Stop sending
```

**Background Thread:**

```python
def __start_bg_threads(self) -> threading.Thread:
    # Dynamic rate adjustment thread (1s refresh)
    demonDynamic = threading.Thread(
        target=self.__dynamic_batch_rate_loop,
        daemon=True,
        name="BgDynamicBatchRate",
    )

    # Batch sending thread (0.01s refresh)
    demonBatchSend = threading.Thread(
        target=self.__batch_send,
        daemon=True,
        name="BgBatchScheduler",
    )
```

### Elixir Implementation

**File:** `/lib/weaviate_ex/batch/dynamic.ex`

```elixir
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

# Server stats polling
defp poll_and_update_stats(state) do
  case Cluster.batch_stats(state.client) do
    {:ok, stats} ->
      queue_size = stats.queue_length
      new_batch_size = adjust_batch_size(state.batch_size, queue_size, state)
      %{state | queue_size: queue_size, batch_size: new_batch_size}
    {:error, _} -> state
  end
end
```

### Gap Analysis: Dynamic Batching

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Server stats polling | Yes | Yes | None |
| Queue depth-based sizing | Yes | Yes | None |
| Rate-based adjustment | Yes | **No** | **Medium** |
| Concurrent request scaling | 1-10 dynamic | Fixed | **Medium** |
| Vectorizer-aware mode | Yes | **No** | **High** |
| Rate smoothing (deque) | Yes (50-sample) | **No** | Low |
| Took time tracking | Yes | **No** | Medium |
| Async indexing detection | Yes | **No** | Low |
| Stop sending when overloaded | Yes (num=0) | **No** | **Medium** |
| Sleep between batches | Yes (vectorizer) | **No** | Medium |

**Gap Details:**

1. **Vectorizer-Aware Mode** (High Priority)
   - Python detects when a vectorizer is configured and adjusts behavior
   - Uses `VECTORIZER_BATCHING_STEP_SIZE` (48) for Cohere compatibility
   - Adds sleep time when vectorizer is slow
   - Elixir has no vectorizer awareness

2. **Rate-Based Adjustment** (Medium Priority)
   - Python uses `batchStats.ratePerSecond` for fine-tuned adjustment
   - Calculates ideal batch size as `rate / concurrent_requests`
   - Elixir only uses queue depth thresholds

3. **Concurrent Request Scaling** (Medium Priority)
   - Python scales `concurrent_requests` from 2 to MAX_CONCURRENT_REQUESTS (10)
   - Elixir uses fixed `concurrent_requests` option

4. **Stop Sending When Overloaded** (Medium Priority)
   - Python sets `recommended_num_objects = 0` when queue ratio > 10
   - This blocks the add_object call until queue clears
   - Elixir has no equivalent mechanism

---

## 4. Rate Limiting and Throttling

### Python Implementation

**File:** `/weaviate-python-client/weaviate/collections/batch/base.py`

**Rate-Limited Batching Mode:**

```python
@dataclass
class _RateLimitedBatching:
    requests_per_minute: int

# In __batch_send():
if isinstance(self.__batching_mode, _RateLimitedBatching):
    if (time.time() - self.__time_stamp_last_request
        < self.__fix_rate_batching_base_time // self.__concurrent_requests):
        time.sleep(1)
        continue
```

**Rate Limit Error Detection and Retry:**

```python
# In __send_batch():
for i, err in response_obj.errors.items():
    if (
        ("support@cohere.com" in err.message and
         ("rate limit" in err.message or "500 error" in err.message))
        or ("OpenAI" in err.message and
            ("Rate limit reached" in err.message or
             "on tokens per min (TPM)" in err.message or
             "503 error" in err.message or
             "500 error" in err.message))
        or ("failed with status: 503 error" in err.message)  # huggingface
    ):
        if err.object_.retry_count > 5:
            continue  # Give up after 5 retries
        err.object_.retry_count += 1
        readded_objects.append(i)

if len(readded_objects) > 0:
    # Re-queue failed objects at front of queue
    self.__batch_objects.prepend(readd_objects)

    if readd_rate_limit:
        self.__time_stamp_last_request = time.time() + base_time * (retry_count + 1)
        self.__fix_rate_batching_base_time += 1  # Increase base time
    else:
        time.sleep(2**highest_retry_count)  # Exponential backoff
```

### Elixir Implementation

**Files:**
- `/lib/weaviate_ex/batch/rate_limited.ex` - Rate-limited GenServer
- `/lib/weaviate_ex/batch/batch_retry.ex` - Retry logic

```elixir
# rate_limited.ex
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

# batch_retry.ex
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

def calculate_backoff(attempt) do
  min(trunc(:math.pow(2, attempt) * 1000), @max_backoff_ms)
end
```

### Gap Analysis: Rate Limiting

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Requests per minute limit | Yes | Yes | None |
| Sliding window tracking | Yes | Yes | None |
| Rate limit error detection | Yes | Yes | None |
| OpenAI pattern matching | Yes | Yes | None |
| Cohere pattern matching | Yes | Yes | None |
| HuggingFace pattern matching | Yes | Yes | None |
| Exponential backoff | Yes | Yes | None |
| Max retries limit | 5 | 5 | None |
| Auto re-queue failed objects | Yes | **No** | **High** |
| Retry count on objects | Yes | Struct only | **Medium** |
| Adaptive base time increase | Yes | **No** | Medium |

**Gap Details:**

1. **Auto Re-queue Failed Objects** (High Priority)
   - Python's `prepend()` re-adds failed objects to front of queue
   - Objects are automatically retried after backoff
   - Elixir reports errors but doesn't re-queue
   - User must manually retry failed objects

2. **Retry Count Tracking** (Medium Priority)
   - Python tracks `retry_count` and stops after 5 attempts
   - Elixir has the field in `ErrorObject` but doesn't increment/use it
   - Impact: No way to know how many retries occurred

---

## 5. Error Handling and Partial Failure Recovery

### Python Implementation

**Files:**
- `/weaviate-python-client/weaviate/collections/classes/batch.py` - Error types
- `/weaviate-python-client/weaviate/collections/batch/base.py` - Error handling

**Error Types:**

```python
@dataclass
class ErrorObject:
    message: str
    object_: BatchObject
    original_uuid: Optional[UUID] = None

@dataclass
class BatchObjectReturn:
    _all_responses: List[Union[uuid_package.UUID, ErrorObject]]
    elapsed_seconds: float
    errors: Dict[int, ErrorObject]  # index -> error
    uuids: Dict[int, uuid_package.UUID]  # index -> uuid
    has_errors: bool
```

**Key Features:**

```python
MAX_STORED_RESULTS = 100000

# Memory management
def add_uuids(self, uuids: Dict[int, uuid_package.UUID]) -> None:
    self.uuids.update(uuids)
    if len(self.uuids) >= MAX_STORED_RESULTS:
        # Remove oldest entries
        old_max = max(self.uuids.keys())
        old_min = min(self.uuids.keys())
        for k in range(old_min, old_max - MAX_STORED_RESULTS + 1):
            if k in self.uuids:
                del self.uuids[k]

# Error logging throttling
if (n_obj_errs := len(response_obj.errors)) > 0 and self.__objs_logs_count < 30:
    logger.error({
        "message": f"Failed to send {n_obj_errs} objects...",
    })
    self.__objs_logs_count += 1
if self.__objs_logs_count > 30:
    logger.error({
        "message": "There have been more than 30 failed object batches..."
    })
```

### Elixir Implementation

**File:** `/lib/weaviate_ex/batch/error_tracking.ex`

```elixir
defmodule ErrorObject do
  @enforce_keys [:message, :object]
  defstruct [:message, :object, :original_uuid, :retry_count]
end

defmodule Results do
  defstruct failed_objects: [],
            failed_references: [],
            successful_uuids: %{},
            elapsed_seconds: 0.0

  def has_errors?(%__MODULE__{} = results) do
    length(results.failed_objects) > 0 or length(results.failed_references) > 0
  end

  def number_errors(%__MODULE__{} = results) do
    length(results.failed_objects) + length(results.failed_references)
  end

  def statistics(%__MODULE__{} = results) do
    %{
      processed: successful + failed,
      successful: map_size(results.successful_uuids),
      failed: number_errors(results)
    }
  end
end
```

### Gap Analysis: Error Handling

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Per-object error tracking | Yes | Yes | None |
| Original UUID preservation | Yes | Yes | None |
| Error message capture | Yes | Yes | None |
| Index-based error lookup | Yes | Yes | None |
| has_errors flag/function | Yes | Yes | None |
| Statistics summary | Yes | Yes | None |
| MAX_STORED_RESULTS (100k) | Yes | **No** | **High** |
| Rolling window eviction | Yes | **No** | **High** |
| Error log throttling | Yes (30) | **No** | Medium |
| Auto re-queue for retry | Yes | **No** | **High** |
| Retry count increment | Yes | **No** | Medium |
| Reference error tracking | Yes | Yes | None |

**Gap Details:**

1. **MAX_STORED_RESULTS Limit** (High Priority)
   - Python limits to 100,000 stored results to prevent memory issues
   - Elixir has no limit - could OOM on very large batches
   - Critical for production use with millions of objects

2. **Auto Re-queue for Retry** (High Priority)
   - Python's `prepend()` adds failed objects back to front of queue
   - Automatic retry with exponential backoff
   - Elixir reports errors but user must handle retry manually

3. **Error Log Throttling** (Medium Priority)
   - Python stops logging after 30 failed batches
   - Elixir logs every error
   - Could flood logs in high-error scenarios

---

## 6. Background Batch Processing

### Python Implementation

**File:** `/weaviate-python-client/weaviate/collections/batch/base.py`

**Architecture:**

```python
# Two daemon threads running concurrently:

# Thread 1: Dynamic rate adjustment (1s refresh)
def __dynamic_batch_rate_loop(self) -> None:
    refresh_time = 1
    while not self.__shut_background_thread_down.is_set():
        self.__dynamic_batching()
        time.sleep(refresh_time)

# Thread 2: Batch sending (0.01s refresh)
def __batch_send(self) -> None:
    refresh_time = 0.01
    while not self.__shut_background_thread_down.is_set():
        if self.__active_requests < self.__concurrent_requests and len(...) > 0:
            # Wait for batch to fill up to recommended size (max 1s)
            while len(self.__batch_objects) < self.__recommended_num_objects:
                time.sleep(0.01)
                if self.__shut_background_thread_down.is_set():
                    break

            # Pop items and send in background
            objs = self.__batch_objects.pop_items(self.__recommended_num_objects)
            refs = self.__batch_references.pop_items(self.__recommended_num_refs, ...)

            # Submit to thread pool
            self.__executor.submit(self.__send_batch, objs, refs, ...)

        time.sleep(refresh_time)
```

**Server-Side Batching (Weaviate 1.34+):**

```python
class _BatchBaseNew:
    """New streaming-based batch implementation"""

    def _start(self) -> None:
        self.__bg_threads = [
            self.__start_bg_threads() for _ in range(self.__batch_mode.concurrency)
        ]

    def __batch_recv(self) -> None:
        for message in self.__batch_grpc.stream(connection, requests=...):
            if message.HasField("started"):
                # Stream started
            if message.HasField("backoff"):
                self.__batch_size = message.backoff.batch_size  # Server-controlled
            if message.HasField("results"):
                # Process successes and errors
            if message.HasField("shutting_down"):
                self.__is_shutting_down.set()
            if message.HasField("shutdown"):
                self.__reconnect()
```

### Elixir Implementation

**File:** `/lib/weaviate_ex/batch/background.ex`

```elixir
defmodule WeaviateEx.Batch.Background do
  use GenServer

  defstruct [
    :client, :collection, :tenant,
    object_queue: :queue.new(),
    reference_queue: :queue.new(),
    pending_uuids: MapSet.new(),
    processed_uuids: MapSet.new(),
    active_requests: 0,
    flush_count: 0
  ]

  # Auto-flush timer
  def handle_info(:flush_timer, state) do
    state = do_flush(state)
    timer_ref = schedule_flush(state.flush_interval)
    {:noreply, %{state | flush_timer_ref: timer_ref}}
  end

  # UUID tracking for reference ordering
  defp partition_ready_references(state) do
    Enum.split_with(:queue.to_list(state.reference_queue), fn ref ->
      not MapSet.member?(state.pending_uuids, ref.from_uuid) and
        not MapSet.member?(state.pending_uuids, ref.to_uuid)
    end)
  end
end
```

**Batch Stream Support:**

```elixir
# lib/weaviate_ex/grpc/services/batch_stream.ex
defmodule WeaviateEx.GRPC.Services.BatchStream do
  @spec open(GRPC.Channel.t(), keyword()) :: {:ok, stream_handle()} | {:error, term()}
  def open(channel, opts \\ []) do
    stream = Weaviate.V1.Weaviate.Stub.batch_stream(channel, ...)
    {:ok, stream}
  end

  def start_message(opts \\ []) do
    %Weaviate.V1.BatchStreamRequest{
      message: {:start, %{consistency_level: ...}}
    }
  end

  def data_message(objects, references) do
    %Weaviate.V1.BatchStreamRequest{
      message: {:data, %{objects: ..., references: ...}}
    }
  end
end
```

### Gap Analysis: Background Processing

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Background/daemon threads | Yes | GenServer | Architectural |
| Auto-flush by time | Yes | Yes | None |
| Auto-flush by size | Yes | Yes | None |
| Concurrent request limit | Yes | Yes | None |
| UUID tracking for refs | Yes | Yes | None |
| Graceful shutdown | Yes | Yes | None |
| Wait for completion | Yes | Yes | None |
| Server-side batching (1.34+) | Yes | **Partial** | **High** |
| Bidirectional streaming | Yes | **Partial** | **High** |
| Server backoff handling | Yes | **Partial** | **High** |
| Reconnect on shutdown | Yes | **No** | **High** |
| Multiple stream concurrency | Yes | **No** | Medium |

**Gap Details:**

1. **Server-Side Batching** (High Priority)
   - Python has full `_BatchBaseNew` implementation
   - Uses bidirectional gRPC streaming for efficiency
   - Server controls batch size via backoff messages
   - Elixir has `BatchStream` module but no high-level integration

2. **Reconnect on Server Shutdown** (High Priority)
   - Python detects `shutting_down` and `shutdown` messages
   - Automatically reconnects to new node
   - Re-queues cached objects/references
   - Elixir has no equivalent

3. **Multiple Stream Concurrency** (Medium Priority)
   - Python creates multiple streams based on cluster size
   - Each stream handles send/receive independently
   - Elixir has single connection model

---

## 7. Batch Callbacks and Progress Reporting

### Python Implementation

**Callbacks via Wrapper Properties:**

```python
class _BatchWrapper:
    @property
    def failed_objects(self) -> List[ErrorObject]:
        return self._batch_data.failed_objects

    @property
    def failed_references(self) -> List[ErrorReference]:
        return self._batch_data.failed_references

    @property
    def results(self) -> BatchResult:
        return self._batch_data.results

# Wait for indexing
def wait_for_vector_indexing(
    self, shards: Optional[List[Shard]] = None, how_many_failures: int = 5
) -> None:
    while not self.__is_ready(how_many_failures, shards):
        time.sleep(0.25)
```

### Elixir Implementation

**Callback Options:**

```elixir
# dynamic.ex, rate_limited.ex, background.ex all support:
state = %{
  on_flush: Keyword.get(opts, :on_flush),  # Called after each flush
  on_error: Keyword.get(opts, :on_error),  # Called on each error
}

# Usage in flush
if state.on_flush, do: state.on_flush.(merged_results)
if state.on_error, do: state.on_error.(error)

# Wait for indexing
def wait_for_vector_indexing(client, collection, opts \\ []) do
  poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
  timeout = Keyword.get(opts, :timeout, @default_timeout)

  do_wait_for_indexing(client, collection, target_shards, ...)
end
```

### Gap Analysis: Callbacks

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| on_flush callback | Via properties | Yes | None |
| on_error callback | Via error lists | Yes | None |
| Failed objects access | Yes | Yes | None |
| Failed references access | Yes | Yes | None |
| Wait for indexing | Yes | Yes | None |
| Shard-specific waiting | Yes | Yes | None |
| Progress percentage | **No** | **No** | Same |
| Batch count tracking | Implicit | Yes | None |
| Elapsed time | Yes | Yes | None |

**Status: Fully Implemented**

Elixir actually has more explicit callback support than Python (which relies on accessing properties after the batch context exits).

---

## Recommendations

### High Priority Gaps to Address

1. **Auto Re-queue for Rate Limit Errors**
   - Location: `/lib/weaviate_ex/batch/dynamic.ex`, `/lib/weaviate_ex/batch/rate_limited.ex`
   - Action: Implement `prepend/2` function to re-add failed objects to front of queue
   - Track retry count on objects, give up after 5 attempts

2. **MAX_STORED_RESULTS Limit**
   - Location: `/lib/weaviate_ex/batch/error_tracking.ex`
   - Action: Add rolling window eviction when results exceed 100,000
   - Make limit configurable via application config

3. **Server-Side Batch Streaming**
   - Location: Create new `/lib/weaviate_ex/batch/stream.ex` high-level module
   - Action: Integrate `BatchStream` into `with_batch/3` as `:experimental` mode
   - Handle backoff, reconnect, and shutdown messages

4. **Named Vector Support in Main Batch APIs**
   - Location: `/lib/weaviate_ex/grpc/services/batch.ex`
   - Action: Add `encode_named_vectors/1` from `BatchStream` to main batch builder

### Medium Priority Gaps

5. **Inline References with Objects**
   - Location: `/lib/weaviate_ex/batch.ex`
   - Action: Accept `:references` option in `add_object/4`
   - Automatically queue reference additions

6. **Vectorizer-Aware Dynamic Batching**
   - Location: `/lib/weaviate_ex/batch/dynamic.ex`
   - Action: Detect vectorizer configuration
   - Use smaller step sizes (48) for Cohere/OpenAI
   - Add sleep time when batches take too long

7. **Backpressure/Blocking**
   - Location: `/lib/weaviate_ex/batch/dynamic.ex`
   - Action: Block `add_object` when queue is too large
   - Set `recommended_num_objects = 0` when server is overloaded

### Low Priority Gaps

8. **Error Log Throttling**
   - Location: `/lib/weaviate_ex/batch/background.ex`
   - Action: Stop logging after 30 failed batches

9. **Rate Smoothing Queue**
   - Location: `/lib/weaviate_ex/batch/dynamic.ex`
   - Action: Use circular buffer for rate samples

---

## File Reference Summary

### Python Files Analyzed

| File | Purpose |
|------|---------|
| `weaviate/collections/batch/__init__.py` | Module exports |
| `weaviate/collections/batch/base.py` | Core batch logic, dynamic batching, background threads |
| `weaviate/collections/batch/batch_wrapper.py` | Wrapper with callbacks and wait_for_indexing |
| `weaviate/collections/batch/client.py` | Client-level batch interface |
| `weaviate/collections/batch/collection.py` | Collection-level batch interface |
| `weaviate/collections/batch/grpc_batch.py` | gRPC batch insertion |
| `weaviate/collections/batch/grpc_batch_delete.py` | gRPC batch deletion |
| `weaviate/collections/batch/rest.py` | REST batch references |
| `weaviate/collections/classes/batch.py` | Data classes (BatchObject, ErrorObject, etc.) |

### Elixir Files Analyzed

| File | Purpose |
|------|---------|
| `lib/weaviate_ex/batch.ex` | Main batch module with context manager |
| `lib/weaviate_ex/api/batch.ex` | API layer with gRPC/HTTP fallback |
| `lib/weaviate_ex/batch/fixed_size.ex` | Fixed-size batch buffer |
| `lib/weaviate_ex/batch/dynamic.ex` | Dynamic batching GenServer |
| `lib/weaviate_ex/batch/rate_limited.ex` | Rate-limited GenServer |
| `lib/weaviate_ex/batch/background.ex` | Background processor GenServer |
| `lib/weaviate_ex/batch/batch_retry.ex` | Retry logic and rate limit detection |
| `lib/weaviate_ex/batch/error_tracking.ex` | Error and result structs |
| `lib/weaviate_ex/grpc/services/batch.ex` | gRPC batch service |
| `lib/weaviate_ex/grpc/services/batch_stream.ex` | gRPC streaming service |
