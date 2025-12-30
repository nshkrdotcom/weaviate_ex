# Batch Operations - Deep Gap Analysis

## Executive Summary

This document provides a comprehensive comparison between the Python Weaviate client's batch operations and the Elixir port (WeaviateEx). The analysis covers 12 key batch operation features and provides implementation status, code examples, and priority recommendations.

**Overall Status:**
- **Fully Implemented:** 7 features
- **Partially Implemented:** 4 features
- **Missing:** 1 feature

---

## Table of Contents

1. [Fixed Size Batching](#1-fixed-size-batching)
2. [Dynamic Batching](#2-dynamic-batching)
3. [Rate-Limited Batching](#3-rate-limited-batching)
4. [Concurrent/Parallel Batching](#4-concurrentparallel-batching)
5. [Batch Error Handling and Callbacks](#5-batch-error-handling-and-callbacks)
6. [Batch Insert/Upsert Operations](#6-batch-insertupsert-operations)
7. [Batch Delete (by Filter, by ID)](#7-batch-delete-by-filter-by-id)
8. [Reference Batch Operations](#8-reference-batch-operations)
9. [Background Batching](#9-background-batching)
10. [Batch Result Tracking and Statistics](#10-batch-result-tracking-and-statistics)
11. [Vector Handling in Batches](#11-vector-handling-in-batches)
12. [Multi-Vector Batch Support](#12-multi-vector-batch-support)

---

## Feature Comparison Matrix

| Feature | Python Status | Elixir Status | Priority |
|---------|--------------|---------------|----------|
| Fixed Size Batching | Full | **Implemented** | - |
| Dynamic Batching | Full | **Implemented** | Low |
| Rate-Limited Batching | Full | **Implemented** | - |
| Concurrent/Parallel Batching | Full | **Implemented** | - |
| Error Handling/Callbacks | Full | **Partial** | Medium |
| Batch Insert/Upsert | Full | **Partial** | High |
| Batch Delete (Filter/ID) | Full | **Implemented** | - |
| Reference Batch Operations | Full | **Implemented** | - |
| Background Batching | Full | **Implemented** | - |
| Result Tracking/Statistics | Full | **Partial** | Medium |
| Vector Handling | Full | **Implemented** | - |
| Multi-Vector Support | Full | **Missing** | High |

---

## 1. Fixed Size Batching

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/collection.py`, `base.py`

```python
# Python: Fixed size batching configuration
class _FixedSizeBatching:
    batch_size: int
    concurrent_requests: int

# Usage
with collection.batch.fixed_size(batch_size=100, concurrent_requests=2) as batch:
    for obj in objects:
        batch.add_object(properties=obj["properties"])
```

**Key Features:**
- Configurable `batch_size` (default: 100)
- Configurable `concurrent_requests` (default: 2)
- Context manager pattern with automatic flush on exit
- Thread-safe queue management with locks

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/fixed_size.ex`

```elixir
# Elixir: Fixed size batching
defmodule WeaviateEx.Batch.FixedSize do
  defstruct batch_size: 100,
            concurrent_requests: 2,
            objects_buffer: [],
            references_buffer: []

  def new(opts \\ []) do
    %__MODULE__{
      batch_size: Keyword.get(opts, :batch_size, 100),
      concurrent_requests: Keyword.get(opts, :concurrent_requests, 2)
    }
  end

  def add_object(%__MODULE__{} = batcher, collection, properties, opts \\ []) do
    uuid = Keyword.get_lazy(opts, :uuid, fn -> UUID.generate() end)
    object = %{collection: collection, properties: properties, uuid: uuid, ...}
    %{batcher | objects_buffer: [object | batcher.objects_buffer]}
  end
end

# Usage via with_batch context manager pattern
{:ok, results} = WeaviateEx.Batch.with_batch(client, [mode: :fixed, batch_size: 100], fn batch ->
  batch
  |> WeaviateEx.Batch.add_object("Article", %{title: "Test 1"})
  |> WeaviateEx.Batch.add_object("Article", %{title: "Test 2"})
end)
```

### Status: **IMPLEMENTED**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Configurable batch size | Yes | Yes | Default 100 |
| Concurrent requests | Yes | Yes | Default 2 |
| Context manager | Yes | Yes | `with_batch/3` |
| Auto UUID generation | Yes | Yes | |
| Buffer management | Thread-safe | Functional | Different paradigms |

---

## 2. Dynamic Batching

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/base.py`

```python
# Python: Dynamic batching with automatic adjustment
class _DynamicBatching:
    pass

# The _BatchBase class handles dynamic adjustment based on:
# - Server queue length from /nodes endpoint
# - Rate of processing (batchStats.ratePerSecond)
# - Automatic scaling up/down of batch sizes

def __dynamic_batching(self) -> None:
    status = self.__cluster.get_nodes_status()
    rate = status[0]["batchStats"]["ratePerSecond"]
    batch_length = status[0]["batchStats"]["queueLength"]

    # Adjust batch size based on queue depth
    if batch_length == 0:
        self.__recommended_num_objects = min(
            self.__recommended_num_objects + 50, self.__max_batch_size
        )
    # ... scaling logic based on ratio
```

**Key Features:**
- Polls `/nodes` endpoint for batch stats
- Adjusts batch size based on queue depth
- Auto-scales concurrent requests (up to 10)
- Rate queue for smoothing adjustments
- Vectorizer-aware batching mode

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/dynamic.ex`

```elixir
defmodule WeaviateEx.Batch.Dynamic do
  use GenServer

  @queue_high_threshold 100
  @queue_low_threshold 10
  @batch_adjustment_factor 1.5

  # Polling for server stats
  defp poll_and_update_stats(state) do
    case Cluster.batch_stats(state.client) do
      {:ok, stats} ->
        queue_size = stats.queue_length
        new_batch_size = adjust_batch_size(state.batch_size, queue_size, state)
        %{state | queue_size: queue_size, batch_size: new_batch_size}
      {:error, _} -> state
    end
  end

  defp adjust_batch_size(current, queue_size, state) do
    cond do
      queue_size > @queue_high_threshold ->
        max(trunc(current / @batch_adjustment_factor), state.min_batch_size)
      queue_size < @queue_low_threshold ->
        min(trunc(current * @batch_adjustment_factor), state.max_batch_size)
      true -> current
    end
  end
end
```

### Status: **IMPLEMENTED**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Server stats polling | Yes | Yes | Via Cluster.batch_stats |
| Auto batch size adjustment | Yes | Yes | Based on queue depth |
| Min/max batch size limits | Yes | Yes | 10-1000 defaults |
| Concurrent request scaling | Yes | Partial | Fixed in Elixir |
| Vectorizer-aware mode | Yes | No | Missing special handling |
| Rate smoothing queue | Yes | No | Python uses deque |

**Gap:** Python has more sophisticated rate smoothing and vectorizer-aware batching mode that sleeps between batches for slow vectorizers.

---

## 3. Rate-Limited Batching

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/base.py`

```python
@dataclass
class _RateLimitedBatching:
    requests_per_minute: int

# Rate limiting logic
if isinstance(self.__batching_mode, _RateLimitedBatching):
    if (time.time() - self.__time_stamp_last_request
        < self.__fix_rate_batching_base_time // self.__concurrent_requests):
        time.sleep(1)
        continue
```

**Key Features:**
- Configurable requests per minute
- Automatic retry on rate limit errors (OpenAI, Cohere, HuggingFace)
- Pattern matching for rate limit error messages
- Exponential backoff on rate limit errors

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/rate_limited.ex`

```elixir
defmodule WeaviateEx.Batch.RateLimited do
  use GenServer

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

  defp send_object_batch_with_retry(client, objects, state) do
    if state.retry_on_rate_limit do
      BatchRetry.with_retry(
        fn -> send_object_batch(client, objects, state) end,
        max_retries: state.max_retries,
        sleep: state.retry_sleep
      )
    else
      send_object_batch(client, objects, state)
    end
  end
end

# BatchRetry module
defmodule WeaviateEx.Batch.BatchRetry do
  def rate_limit_error?(message) when is_binary(message) do
    patterns = [
      ~r/rate limit/i,
      ~r/Rate limit reached/i,
      ~r/tokens per min/i,
      ~r/support@cohere\.com/,
      ~r/503 error/i
    ]
    Enum.any?(patterns, &Regex.match?(&1, message))
  end

  def calculate_backoff(attempt) do
    min(trunc(:math.pow(2, attempt) * 1000), @max_backoff_ms)
  end
end
```

### Status: **IMPLEMENTED**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Requests per minute limit | Yes | Yes | |
| Rate limit error detection | Yes | Yes | Same patterns |
| Exponential backoff | Yes | Yes | 2^n formula |
| Auto retry | Yes | Yes | Via BatchRetry |
| Request time tracking | Yes | Yes | Sliding window |

---

## 4. Concurrent/Parallel Batching

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/base.py`

```python
# Python uses ThreadPoolExecutor for concurrent batch sending
self.__executor = ThreadPoolExecutor()

# Concurrent batch submission
ctx = contextvars.copy_context()
self.__executor.submit(
    ctx.run,
    functools.partial(
        self.__send_batch,
        objs,
        refs,
        readd_rate_limit=isinstance(self.__batching_mode, _RateLimitedBatching),
    ),
)
```

**Key Features:**
- ThreadPoolExecutor for parallel request execution
- Context variable propagation
- Active request tracking with locks
- MAX_CONCURRENT_REQUESTS limit (10)

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/concurrent.ex`

```elixir
defmodule WeaviateEx.Batch.Concurrent do
  def insert_many(client, collection, objects, opts \\ []) do
    opts = merge_options(opts)
    batches = split_into_batches(objects, opts)

    batch_results =
      batches
      |> Enum.with_index()
      |> Task.async_stream(
        fn {batch, index} ->
          execute_batch(client, collection, batch, index, opts)
        end,
        max_concurrency: opts[:max_concurrency],
        timeout: opts[:timeout],
        on_timeout: :kill_task
      )
      |> Enum.map(...)

    {:ok, aggregate_results(batch_results, opts)}
  end
end
```

### Status: **IMPLEMENTED**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Parallel execution | ThreadPoolExecutor | Task.async_stream | Native patterns |
| Configurable concurrency | Yes | Yes | max_concurrency option |
| Active request tracking | Yes | Yes | Via GenServer state |
| Timeout handling | Yes | Yes | on_timeout: :kill_task |
| Result aggregation | Yes | Yes | |

---

## 5. Batch Error Handling and Callbacks

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/classes/batch.py`

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
    errors: Dict[int, ErrorObject]
    uuids: Dict[int, uuid_package.UUID]
    has_errors: bool

    def add_errors(self, errors: Dict[int, ErrorObject]) -> None:
        self.has_errors = True
        self.errors.update(errors)
        self._all_responses.extend(errors.values())

# Rate limit error detection and re-queuing
for i, err in response_obj.errors.items():
    if ("rate limit" in err.message or "OpenAI" in err.message ...):
        if err.object_.retry_count > 5:
            continue
        err.object_.retry_count += 1
        readded_objects.append(i)

self.__batch_objects.prepend(readd_objects)  # Re-queue for retry
```

**Key Features:**
- Detailed error tracking per object/reference
- Original UUID preservation
- Retry count tracking
- Automatic re-queuing for rate limit errors
- MAX_STORED_RESULTS limit (100,000)
- Error logging with threshold (30 batches)

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/error_tracking.ex`

```elixir
defmodule WeaviateEx.Batch.ErrorTracking do
  defmodule ErrorObject do
    defstruct [:message, :object, :original_uuid, :retry_count]
  end

  defmodule Results do
    defstruct failed_objects: [],
              failed_references: [],
              successful_uuids: %{},
              elapsed_seconds: 0.0

    def add_error(%__MODULE__{} = results, %ErrorObject{} = error) do
      %{results | failed_objects: [error | results.failed_objects]}
    end

    def has_errors?(%__MODULE__{} = results) do
      length(results.failed_objects) > 0 or length(results.failed_references) > 0
    end
  end
end

# Callbacks in Dynamic batcher
if state.on_flush, do: state.on_flush.(merged_results)
if state.on_error, do: state.on_error.(error)
```

### Status: **PARTIAL**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Error tracking per object | Yes | Yes | ErrorObject struct |
| Original UUID preservation | Yes | Yes | |
| Retry count tracking | Yes | Partial | In ErrorObject but not used |
| Auto re-queue for retry | Yes | **No** | Manual retry only |
| on_flush callback | Yes | Yes | |
| on_error callback | Yes | Yes | |
| MAX_STORED_RESULTS | Yes (100k) | **No** | No limit in Elixir |
| Error log throttling | Yes (30) | **No** | No throttling |

**Gaps:**
1. No automatic re-queuing of failed objects for retry
2. No MAX_STORED_RESULTS limit (potential memory issue)
3. No error log throttling

---

## 6. Batch Insert/Upsert Operations

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/base.py`

```python
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
        references=references,
        uuid=uuid,
        vector=vector,
        tenant=tenant,
        index=self.__objs_count,
    )
    self.__batch_objects.add(batch_object._to_internal())
    return batch_object.uuid
```

**Note:** Python batch insert is effectively upsert - if UUID exists, object is replaced.

### Elixir Implementation

```elixir
# WeaviateEx.Batch module
def add_object(%{mode: :fixed} = ctx, collection, properties, opts) do
  batcher = FixedSize.add_object(ctx.batcher, collection, properties, opts)
  # Auto-flush check
  if FixedSize.ready_to_send?(batcher) do
    case flush_fixed_batch(ctx.client, batcher, ctx.opts) do
      {:ok, new_results, _} ->
        %{ctx | batcher: FixedSize.clear(batcher), results: merge_results(ctx.results, new_results)}
      {:error, _} ->
        %{ctx | batcher: batcher}
    end
  else
    %{ctx | batcher: batcher}
  end
end
```

### Status: **PARTIAL**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Batch insert | Yes | Yes | |
| Upsert behavior | Yes | Yes | Via Weaviate server |
| UUID auto-generation | Yes | Yes | |
| Index tracking | Yes | Partial | Not fully consistent |
| Inline references | Yes | **No** | References added separately |
| Tenant support | Yes | Yes | |

**Gap:** Python allows adding references inline with objects. Elixir requires separate reference batch operations.

---

## 7. Batch Delete (by Filter, by ID)

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/grpc_batch_delete.py`

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
    ) -> executor.Result[Union[DeleteManyReturn[List[DeleteManyObject]], DeleteManyReturn[None]]]:
        request = batch_delete_pb2.BatchDeleteRequest(
            collection=name,
            consistency_level=self._consistency_level,
            verbose=verbose,
            dry_run=dry_run,
            tenant=tenant,
            filters=_FilterToGRPC.convert(filters),
        )
        return executor.execute(...)
```

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/batch.ex`

```elixir
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

### Status: **IMPLEMENTED**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Delete by filter | Yes | Yes | gRPC support |
| Dry run | Yes | Yes | |
| Verbose mode | Yes | Yes | |
| Tenant support | Yes | Yes | |
| Consistency level | Yes | Yes | |
| Delete by ID | Yes | **No** | Must use filter with ID |

**Note:** Batch delete by specific IDs requires using an ID filter in Elixir, while Python has more direct support.

---

## 8. Reference Batch Operations

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/rest.py`

```python
class _BatchREST:
    def references(
        self, connection: Connection, *, references: List[_BatchReference]
    ) -> executor.Result[BatchReferenceReturn]:
        refs = [
            {"from": ref.from_, "to": ref.to, "tenant": ref.tenant}
            for ref in references
        ]
        return executor.execute(
            method=connection.post,
            path="/batch/references",
            weaviate_object=refs,
        )
```

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/fixed_size.ex`

```elixir
# Multi-target reference support
def add_reference(%__MODULE__{} = batcher, collection, from_uuid, property, targets, opts)
    when is_list(targets) do
  references =
    Enum.map(targets, fn target ->
      %{
        collection: collection,
        from_uuid: from_uuid,
        property: property,
        to_uuid: target.uuid,
        to_collection: target.collection,
        tenant: Keyword.get(opts, :tenant)
      }
    end)
  %{batcher | references_buffer: references ++ batcher.references_buffer}
end
```

### Status: **IMPLEMENTED**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Single target references | Yes | Yes | |
| Multi-target references | Yes | Yes | |
| Reference batching | Yes | Yes | |
| Tenant support | Yes | Yes | |
| Cross-collection refs | Yes | Yes | |

---

## 9. Background Batching

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/base.py`

```python
def __start_bg_threads(self) -> threading.Thread:
    self.__shut_background_thread_down = threading.Event()

    # Dynamic rate adjustment thread
    demonDynamic = threading.Thread(
        target=self.__dynamic_batch_rate_loop,
        daemon=True,
        name="BgDynamicBatchRate",
    )
    demonDynamic.start()

    # Batch sending thread
    demonBatchSend = threading.Thread(
        target=self.__batch_send,
        daemon=True,
        name="BgBatchScheduler",
    )
    demonBatchSend.start()

    return demonBatchSend
```

**Key Features:**
- Daemon threads for background processing
- Automatic batch sending based on queue size
- UUID lookup table for reference ordering
- Thread synchronization with locks and events

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/background.ex`

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
    # ...
  ]

  # Automatic flush timer
  defp schedule_flush(interval) do
    Process.send_after(self(), :flush_timer, interval)
  end

  # UUID tracking for reference ordering
  defp partition_ready_references(state) do
    all_refs = :queue.to_list(state.reference_queue)
    Enum.split_with(all_refs, fn ref ->
      not MapSet.member?(state.pending_uuids, ref.from_uuid) and
        not MapSet.member?(state.pending_uuids, ref.to_uuid)
    end)
  end
end
```

### Status: **IMPLEMENTED**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Background processing | Daemon threads | GenServer | OTP pattern |
| Auto flush by size | Yes | Yes | |
| Auto flush by time | Yes | Yes | flush_interval |
| UUID lookup for refs | Yes | Yes | pending_uuids MapSet |
| Concurrent requests | Yes | Yes | active_requests tracking |
| Graceful shutdown | Yes | Yes | stop_with_flush |

---

## 10. Batch Result Tracking and Statistics

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/classes/batch.py`

```python
@dataclass
class BatchObjectReturn:
    _all_responses: List[Union[uuid_package.UUID, ErrorObject]]
    elapsed_seconds: float
    errors: Dict[int, ErrorObject]
    uuids: Dict[int, uuid_package.UUID]
    has_errors: bool

MAX_STORED_RESULTS = 100000

def add_uuids(self, uuids: Dict[int, uuid_package.UUID]) -> None:
    self.uuids.update(uuids)
    self._all_responses.extend(uuids.values())

    # Enforce max stored results
    if len(self.uuids) >= MAX_STORED_RESULTS:
        old_max = max(self.uuids.keys())
        old_min = min(self.uuids.keys())
        for k in range(old_min, old_max - MAX_STORED_RESULTS + 1):
            if k in self.uuids:
                del self.uuids[k]
```

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/error_tracking.ex`

```elixir
defmodule Results do
  defstruct failed_objects: [],
            failed_references: [],
            successful_uuids: %{},
            elapsed_seconds: 0.0

  def statistics(%__MODULE__{} = results) do
    successful = map_size(results.successful_uuids)
    failed = length(results.failed_objects) + length(results.failed_references)

    %{
      processed: successful + failed,
      successful: successful,
      failed: failed
    }
  end
end
```

### Status: **PARTIAL**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| UUID tracking by index | Yes | Yes | Map-based |
| Error tracking | Yes | Yes | |
| Elapsed time | Yes | Yes | |
| has_errors flag | Yes | Yes | has_errors?/1 function |
| all_responses list | Yes | **No** | Only uuids map |
| MAX_STORED_RESULTS | Yes (100k) | **No** | Potential memory issue |
| Statistics summary | Yes | Yes | statistics/1 function |

**Gap:** No MAX_STORED_RESULTS limit could lead to memory issues with very large batches.

---

## 11. Vector Handling in Batches

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/grpc_batch.py`

```python
def __single_vec(self, vectors: Optional[VECTORS]) -> Optional[bytes]:
    if not _is_1d_vector(vectors):
        return None
    return _Pack.single(vectors)

def grpc_object(self, obj: _BatchObject) -> batch_pb2.BatchObject:
    return batch_pb2.BatchObject(
        collection=obj.collection,
        uuid=str(obj.uuid),
        properties=...,
        vector_bytes=self.__single_vec(obj.vector),
        vectors=self.__multi_vec(obj.vector),
    )
```

**Key Features:**
- Support for numpy arrays, torch tensors, tf tensors
- Binary packing for efficiency
- Single vector and named vector support

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/grpc/services/batch.ex`

```elixir
defp build_batch_object(object) do
  case object[:vector] || object["vector"] do
    nil -> batch_obj
    vector when is_list(vector) ->
      vector_bytes =
        vector
        |> Enum.map(&<<&1::float-little-32>>)
        |> IO.iodata_to_binary()
      %{batch_obj | vector_bytes: vector_bytes}
  end
end
```

### Status: **IMPLEMENTED**

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| List vectors | Yes | Yes | |
| Binary packing | Yes | Yes | float-little-32 |
| Numpy arrays | Yes | N/A | Python-specific |
| Torch/TF tensors | Yes | N/A | Python-specific |

---

## 12. Multi-Vector Batch Support

### Python Implementation

**Location:** `weaviate-python-client/weaviate/collections/batch/grpc_batch.py`

```python
def __multi_vec(self, vectors: Optional[VECTORS]) -> Optional[List[base_pb2.Vectors]]:
    if vectors is None or _is_1d_vector(vectors):
        return None
    # Named vectors as dict
    vectors = cast(Mapping[str, Union[Sequence[float], Sequence[Sequence[float]]]], vectors)
    return [
        base_pb2.Vectors(name=name, vector_bytes=packing.bytes_, type=packing.type_)
        for name, vec_or_vecs in vectors.items()
        if (packing := _Pack.parse_single_or_multi_vec(vec_or_vecs))
    ]
```

**Key Features:**
- Named vectors as dictionary
- Multi-target vectors (vectors with multiple embeddings per name)
- Type detection and packing

### Elixir Implementation

**Location:** `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/grpc/services/batch_stream.ex`

```elixir
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

### Status: **MISSING** (Partial in BatchStream only)

| Capability | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Named vectors | Yes | Partial | Only in BatchStream |
| Multi-target vectors | Yes | **No** | Not supported |
| Vector type detection | Yes | **No** | |
| Main batch API support | Yes | **No** | Only in stream |

**Gap:** Named/multi-vector support exists in BatchStream but not in the main batch APIs (`WeaviateEx.Batch`, `WeaviateEx.API.Batch`).

---

## Priority Recommendations

### High Priority

1. **Multi-Vector Batch Support**
   - Add named vector support to main batch APIs
   - Implement multi-target vector handling
   - Add vector type detection

2. **Batch Upsert with Inline References**
   - Allow references to be added inline with objects like Python

### Medium Priority

3. **Auto Re-queue for Rate Limit Errors**
   - Implement automatic re-queuing of failed objects
   - Add retry_count tracking and usage

4. **MAX_STORED_RESULTS Limit**
   - Add configurable limit to prevent memory issues
   - Implement rolling window for large batches

5. **Error Log Throttling**
   - Add threshold-based error logging (like Python's 30 batch limit)

### Low Priority

6. **Vectorizer-Aware Dynamic Batching**
   - Special handling for slow vectorizers
   - Sleep between batches when vectorizer is overloaded

7. **Rate Smoothing Queue**
   - Implement deque-based rate smoothing for dynamic batching

---

## Code Examples: API Differences

### Fixed Size Batching

**Python:**
```python
with collection.batch.fixed_size(batch_size=100, concurrent_requests=2) as batch:
    for item in items:
        batch.add_object(properties={"title": item["title"]})
# Automatic flush on context exit
```

**Elixir:**
```elixir
{:ok, results} = WeaviateEx.Batch.with_batch(client, [
  mode: :fixed,
  batch_size: 100,
  concurrent_requests: 2
], fn batch ->
  Enum.reduce(items, batch, fn item, b ->
    WeaviateEx.Batch.add_object(b, "Collection", %{title: item.title})
  end)
end)
# Automatic flush on callback return
```

### Dynamic Batching

**Python:**
```python
with collection.batch.dynamic() as batch:
    for item in items:
        batch.add_object(properties=item)
```

**Elixir:**
```elixir
{:ok, results} = WeaviateEx.Batch.with_batch(client, [mode: :dynamic], fn batch ->
  Enum.reduce(items, batch, fn item, b ->
    WeaviateEx.Batch.add_object(b, "Collection", item)
  end)
end)
```

### Background Batching

**Python:**
```python
# Python uses context manager with daemon threads
with client.batch.dynamic() as batch:
    for item in items:
        batch.add_object(collection="Article", properties=item)
# Background threads handle sending automatically
```

**Elixir:**
```elixir
# Elixir uses GenServer process
{:ok, batcher} = WeaviateEx.Batch.background(client, "Article",
  batch_size: 100,
  concurrent_requests: 2
)

for item <- items do
  :ok = WeaviateEx.Batch.Background.add_object(batcher, item)
end

results = WeaviateEx.Batch.Background.stop(batcher, flush: true)
```

### Error Handling

**Python:**
```python
with collection.batch.fixed_size() as batch:
    for item in items:
        batch.add_object(properties=item)

# After context exit
print(f"Errors: {len(batch.failed_objects)}")
for error in batch.failed_objects:
    print(f"Failed: {error.message}")
```

**Elixir:**
```elixir
{:ok, results} = WeaviateEx.Batch.with_batch(client, [
  on_error: fn error -> Logger.error("Batch error: #{error.message}") end
], fn batch ->
  # ...
end)

if WeaviateEx.Batch.ErrorTracking.Results.has_errors?(results) do
  errors = WeaviateEx.Batch.ErrorTracking.Results.errors(results)
  Enum.each(errors, &Logger.error("Failed: #{&1.message}"))
end
```

---

## Summary

The Elixir WeaviateEx batch operations provide solid coverage of the Python client's functionality, with key features like fixed-size batching, dynamic batching, rate limiting, and background processing all well-implemented using idiomatic Elixir patterns (GenServer, Task.async_stream, etc.).

The main gaps are:
1. **Multi-vector support in main batch APIs** - High priority
2. **Auto re-queue for rate limit errors** - Medium priority
3. **MAX_STORED_RESULTS limit** - Medium priority
4. **Inline references with objects** - High priority

The architectural differences (OTP vs threading) are appropriate for each language and don't represent gaps per se, but rather different approaches to solving the same problems.
