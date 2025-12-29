# Batch Operations Gap Analysis

## Overview

The Elixir client provides batch operations through `WeaviateEx.Batch` but lacks the sophisticated batching modes (dynamic, rate-limited) available in the Python client.

## Batch Modes Comparison

| Mode | Python | Elixir | Notes |
|------|--------|--------|-------|
| Basic batch | Yes | Yes | `WeaviateEx.Batch.create_objects/2` |
| Fixed-size batch | Yes | Yes | `WeaviateEx.Batch.FixedSize` |
| Dynamic batching | Yes | **No** | **GAP**: Auto-adjusting |
| Rate-limited batch | Yes | **No** | **GAP**: Respect rate limits |
| Context manager | Yes | **No** | **GAP**: Auto-flush on exit |

---

## Missing: Dynamic Batching - HIGH PRIORITY

Python's dynamic batching automatically adjusts batch sizes based on server queue:

```python
# Python
with collection.batch.dynamic() as batch:
    for item in items:
        batch.add_object(properties=item)
    # Auto-flushes on context exit
```

**How it works**:
- Monitors `ratePerSecond` from server
- Monitors `queueLength` in batch queue
- Scales batch size up/down based on ratio
- Automatically adjusts concurrent requests (2-10)
- Background threads for async batch sending

**Algorithm**:
```
Ideal ratio: 1.9-2.1 -> batch_size = floor(rate_per_worker)
Ratio <= 1.9 (under capacity) -> scale up
Ratio >= 10 (severe congestion) -> pause sending
```

**Recommendation**: Implement `WeaviateEx.Batch.dynamic/2` context manager

---

## Missing: Rate-Limited Batching - MEDIUM PRIORITY

Throttle batch sending to respect vectorizer rate limits:

```python
# Python
with collection.batch.rate_limit(requests_per_minute=1000) as batch:
    for item in items:
        batch.add_object(properties=item)
```

**How it works**:
- Calculates optimal batch size and concurrency
- Formula: `concurrent_requests = (rpm + max_batch_size) // max_batch_size`
- Base timing: 62 seconds (with buffer)
- Automatic rate-limit error handling with exponential backoff

**Recommendation**: Implement `WeaviateEx.Batch.rate_limit/2`

---

## Missing: Context Manager Pattern

Python uses context managers for automatic cleanup:

```python
# Python - auto-flushes on exit
with collection.batch.fixed_size(100) as batch:
    batch.add_object(...)
# <- Automatically flushes remaining objects here
```

**Elixir Alternative**: Could use try/after or GenServer

```elixir
# Proposed Elixir Pattern
WeaviateEx.Batch.with_batch(client, :dynamic, fn batch ->
  Enum.each(items, fn item ->
    WeaviateEx.Batch.add_object(batch, item)
  end)
end)
# Auto-flushes on function return
```

---

## Batch Insert Methods

| Method | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `insert_many()` | Yes | Yes | `WeaviateEx.Batch.create_objects/2` |
| `add_object()` | Yes | **No** | **GAP**: For context manager use |
| `add_reference()` | Yes | **No** | **GAP**: For context manager use |
| `flush()` | Yes | **No** | **GAP**: Force send |

### Missing: Incremental `add_object()` / `add_reference()`

Python allows adding objects one at a time within a batch context:

```python
# Python
with collection.batch.dynamic() as batch:
    uuid1 = batch.add_object(properties={"name": "obj1"})
    uuid2 = batch.add_object(properties={"name": "obj2"})
    batch.add_reference(from_uuid=uuid1, from_property="ref", to=uuid2)
    batch.flush()  # Optional: force send
    # Continue adding more...
```

**Recommendation**: Implement batch builder pattern with `add_object/3`, `add_reference/4`, `flush/1`

---

## Batch Configuration

### Fixed-Size Batch

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `batch_size` | Yes | Yes | Objects per batch |
| `concurrent_requests` | Yes | **?** | Parallel requests |
| `consistency_level` | Yes | **?** | ONE/QUORUM/ALL |

### Elixir FixedSize Module

```elixir
# Current Elixir
WeaviateEx.Batch.FixedSize.create_objects(client, objects, batch_size: 100)
```

**Status**: Basic fixed-size batching exists

---

## Error Handling

### Python Error Tracking

```python
# Python - after batch completes
batch.number_errors  # int
batch.failed_objects  # List[ErrorObject]
batch.failed_references  # List[ErrorReference]
batch.results  # BatchResult with objs and refs
```

### Elixir Error Tracking

```elixir
# Current Elixir
{:ok, %WeaviateEx.API.Batch.Result{
  successful: [...],
  failed: [...],
  errors: [...],
  statistics: %{...}
}}
```

**Status**: Error tracking exists but structured differently

---

## Rate Limit Detection

Python automatically detects and handles rate limit errors:

| Provider | Detection Pattern |
|----------|------------------|
| Cohere | "support@cohere.com" + "rate limit" |
| OpenAI | "Rate limit" or "TPM" or "503" |
| HuggingFace | "failed with status: 503" |

**Retry Logic**:
- Up to 5 retries per object
- Exponential backoff: `2^retry_count` seconds
- Max total retries: ~9.3 (configurable via `WEAVIATE_BATCH_MAX_RETRIES`)

### Elixir Status

```elixir
# Existing: WeaviateEx.Retry module for general retries
# Existing: WeaviateEx.Batch.BatchRetry for batch-specific retries
```

**Status**: Basic retry exists, may need rate-limit-specific detection

---

## Batch Delete

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Delete by filter | Yes | Yes | `WeaviateEx.Batch.delete_objects/2` |
| `verbose` option | Yes | **?** | Return deleted objects |
| `dry_run` option | Yes | Yes | `dryRun: true` |

### Delete Return Type

**Python**:
```python
@dataclass
class DeleteManyReturn:
    failed: int
    matches: int
    successful: int
    objects: Optional[List[DeleteManyObject]]  # if verbose
```

**Elixir**: Returns similar structure via API response

---

## Concurrency Control

### Python Constants

```python
MAX_CONCURRENT_REQUESTS = 10
DEFAULT_REQUEST_TIMEOUT = 180  # seconds
CONCURRENT_REQUESTS_DYNAMIC_VECTORIZER = 2
BATCH_TIME_TARGET = 10  # seconds
VECTORIZER_BATCHING_STEP_SIZE = 48  # objects
```

### Elixir Status

**Unknown**: Need to verify concurrency configuration options

---

## Background Thread Management

Python uses background threads for async batch operations:

- `BgDynamicBatchRate`: Monitors queue, adjusts parameters (1s refresh)
- `BgBatchScheduler`: Sends batches when conditions met
- `BgBatchSend`: For streaming mode
- `BgBatchRecv`: For streaming mode

**Elixir Alternative**: Could use:
- GenServer for batch accumulation
- Task.async for concurrent sends
- Flow for streaming/parallel processing

---

## gRPC vs REST

| Protocol | Python | Elixir | Notes |
|----------|--------|--------|-------|
| gRPC batch insert | Yes | **No** | Python default for batch |
| REST batch insert | Yes | Yes | Elixir uses REST |
| gRPC batch delete | Yes | **No** | |
| REST batch delete | Yes | Yes | |

**Note**: gRPC is generally faster for batch operations but requires additional dependencies.

---

## Memory Management

Python handles large batches efficiently:

```python
# Max stored results: 100,000 UUIDs
# If exceeded, oldest UUIDs are removed
# _all_responses list only stores last 100k items
```

**Elixir**: Unknown memory management - verify for large batches

---

## Batch References

| Operation | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| Batch add refs | Yes | Yes | `WeaviateEx.Batch.add_references/2` |
| Refs in context | Yes | **No** | `batch.add_reference()` pattern |
| Multi-target refs | Yes | **?** | `ReferenceToMulti` support |

---

## Wait for Indexing

```python
# Python - wait for vector indexing to complete
with collection.batch.dynamic() as batch:
    # ... add objects ...

collection.batch.wait_for_vector_indexing(
    shards=["shard1"],
    how_many_failures=5  # Max failures before error
)
```

**Elixir Status**: Unknown - verify vector indexing wait support

---

## Client-Level vs Collection-Level Batching

### Python

```python
# Collection-level
with collection.batch.dynamic() as batch:
    batch.add_object(properties=...)

# Client-level (multi-collection)
with client.batch.dynamic() as batch:
    batch.add_object(collection="Article", properties=..., tenant="t1")
    batch.add_object(collection="Author", properties=..., tenant="t2")
```

### Elixir

```elixir
# Current: Only client-level batching
WeaviateEx.Batch.create_objects([
  %{class: "Article", properties: ...},
  %{class: "Author", properties: ...}
])
```

**Status**: Elixir has client-level batching, no collection-scoped context

---

## Summary of Batch Operation Gaps

### High Priority
1. **Dynamic batching** - Auto-adjusting batch sizes and concurrency
2. **Context manager pattern** - Auto-flush on exit
3. **Incremental `add_object()`** - Add objects one at a time
4. **`flush()` method** - Force send pending objects

### Medium Priority
1. **Rate-limited batching** - Respect vectorizer rate limits
2. **`add_reference()` in batch** - Incremental reference adding
3. **Wait for vector indexing** - Ensure indexing complete
4. **Concurrency configuration** - Parallel request control

### Low Priority
1. gRPC batch support (performance optimization)
2. Provider-specific rate limit detection
3. Memory management for very large batches

---

## Implementation Recommendations

### 1. Batch Context with GenServer

```elixir
defmodule WeaviateEx.Batch.Context do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def add_object(pid, object) do
    GenServer.call(pid, {:add_object, object})
  end

  def flush(pid) do
    GenServer.call(pid, :flush)
  end

  # Auto-flush on terminate
  def terminate(_reason, state) do
    do_flush(state)
    :ok
  end
end
```

### 2. Dynamic Batching Algorithm

```elixir
defmodule WeaviateEx.Batch.Dynamic do
  def calculate_batch_size(queue_length, rate_per_second, current_batch_size) do
    ratio = queue_length / rate_per_second

    cond do
      ratio >= 10 -> 0  # Pause
      ratio >= 2.1 -> trunc(rate_per_second * 2 / ratio)  # Scale down
      ratio <= 1.9 -> trunc(current_batch_size * 1.5)  # Scale up
      true -> trunc(rate_per_second)  # Optimal
    end
  end
end
```

### 3. Rate Limiting with Token Bucket

```elixir
defmodule WeaviateEx.Batch.RateLimiter do
  def with_rate_limit(requests_per_minute, fun) do
    interval_ms = div(60_000, requests_per_minute)

    # Use :timer.send_interval or similar
    # ...
  end
end
```
