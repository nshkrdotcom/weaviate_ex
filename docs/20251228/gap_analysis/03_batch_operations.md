# Batch Operations Gap Analysis: Python vs Elixir Client

## Executive Summary

The Python Weaviate client provides a **highly sophisticated batch system** with advanced features including:
- Multiple batching modes (dynamic, fixed-size, rate-limited, server-side)
- Context manager patterns for automatic lifecycle management
- Background threading with concurrent request handling
- Automatic rate limiting and backoff for vectorizer APIs
- Real-time dynamic batch size optimization
- Comprehensive error tracking and retry logic
- gRPC and REST protocol support

The Elixir client currently provides **basic batch functionality** through simple REST API calls, lacking the advanced batching infrastructure. This represents one of the **most significant gaps** between the two clients.

### Gap Severity Assessment

| Category | Gap Severity | Impact |
|----------|--------------|--------|
| Batching Modes | **Critical** | No dynamic, fixed-size, or rate-limited modes |
| Context Manager | **Critical** | No automatic lifecycle management |
| Concurrency | **Critical** | No concurrent batch processing |
| Error Handling | **High** | Limited error tracking and retry |
| Rate Limiting | **High** | No built-in rate limiting support |
| gRPC Support | **High** | No gRPC batch streaming |
| Progress Tracking | **Medium** | No progress callbacks |
| Wait for Indexing | **Medium** | No wait_for_vector_indexing |

---

## Detailed Comparison Table

| Feature | Python Client | Elixir Client | Gap |
|---------|--------------|---------------|-----|
| **Batching Modes** |
| Dynamic batching | Full support with auto-optimization | Not implemented | Critical |
| Fixed-size batching | Full support | Not implemented | Critical |
| Rate-limited batching | Full support with requests/minute | Not implemented | Critical |
| Server-side batching (experimental) | Full support with gRPC streaming | Not implemented | Critical |
| **Batch Context Manager** |
| Context manager pattern | `with collection.batch.dynamic() as batch:` | Not implemented | Critical |
| Automatic flush on exit | Yes | Not implemented | Critical |
| Automatic lifecycle management | Yes | Not implemented | Critical |
| **Concurrent Processing** |
| Background threads | Multiple background threads | Not implemented | Critical |
| Concurrent requests | Configurable (default 2-10) | Not implemented | Critical |
| ThreadPoolExecutor | Used for parallel sends | Not implemented | Critical |
| **Error Handling** |
| Failed objects tracking | `batch.failed_objects` property | Basic via Result struct | Partial |
| Failed references tracking | `batch.failed_references` property | Not implemented | High |
| Error object details | Full BatchObject + message | Limited error info | High |
| Original UUID preservation | Yes | Not implemented | Medium |
| **Retry Logic** |
| Automatic retry | Up to 5 retries with backoff | Not implemented | High |
| Rate limit detection | Cohere/OpenAI specific handling | Not implemented | High |
| Exponential backoff | 2^n seconds | Not implemented | High |
| Re-queue failed objects | `prepend()` to batch queue | Not implemented | High |
| **Rate Limiting** |
| Requests per minute control | `rate_limit(requests_per_minute=N)` | Not implemented | High |
| Vectorizer batching detection | Automatic detection | Not implemented | High |
| Sleep/backoff coordination | Dynamic sleep timing | Not implemented | High |
| **Dynamic Optimization** |
| Batch size optimization | Auto-scales 10-1000 objects | Not implemented | High |
| Queue length monitoring | Via cluster batch stats | Not implemented | High |
| Server load adaptation | Based on queueLength/rate | Not implemented | High |
| Concurrent request scaling | 2-10 based on load | Not implemented | High |
| **Reference Handling** |
| Batch add references | Full support | Basic support | Partial |
| UUID lookup for ordering | References wait for objects | Not implemented | High |
| Multi-target references | Full support | Not implemented | High |
| **Progress & Monitoring** |
| number_errors property | Real-time count | Not implemented | Medium |
| Logging | Structured logging with limits | Not implemented | Medium |
| Progress callbacks | Not implemented (neither client) | N/A | N/A |
| **Protocol Support** |
| gRPC batch objects | Full support | Not implemented | High |
| gRPC batch streaming | Full support (server-side mode) | Not implemented | High |
| REST batch | Full support | Basic support | Partial |
| **Batch Delete** |
| Filter-based delete | Full gRPC support | Basic REST support | Partial |
| Verbose mode | Returns deleted objects | Supported | OK |
| Dry run | Supported | Supported | OK |
| **Wait for Indexing** |
| wait_for_vector_indexing | Full support with retries | Not implemented | Medium |
| Shard readiness checking | Full support | Not implemented | Medium |
| **Memory Management** |
| MAX_STORED_RESULTS (100k) | Automatic pruning | Not implemented | Low |
| Result aggregation | Efficient memory handling | Not implemented | Low |

---

## Missing Features with Implementation Details

### 1. Dynamic Batching Mode (Critical)

**Python Implementation:**
```python
with client.batch.dynamic() as batch:
    for item in items:
        batch.add_object(
            collection="Article",
            properties={"title": item["title"]},
            vector=item["vector"]
        )
# Automatically flushes and optimizes batch size
```

**Python Internals:**
- Monitors Weaviate's batch queue length via `/nodes` endpoint
- Adjusts `recommended_num_objects` from 10 to 1000 based on server capacity
- Scales `concurrent_requests` from 2 to 10 based on throughput
- Background thread continuously optimizes batch parameters

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.Dynamic do
  use GenServer

  defstruct [
    :connection,
    :consistency_level,
    :objects_queue,
    :references_queue,
    :recommended_batch_size,
    :concurrent_requests,
    :results,
    :failed_objects,
    :failed_references
  ]

  @initial_batch_size 10
  @max_batch_size 1000
  @max_concurrent_requests 10

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def add_object(pid, collection, properties, opts \\ []) do
    GenServer.call(pid, {:add_object, collection, properties, opts})
  end

  def flush(pid) do
    GenServer.call(pid, :flush, :infinity)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      connection: opts[:connection],
      consistency_level: opts[:consistency_level],
      objects_queue: :queue.new(),
      references_queue: :queue.new(),
      recommended_batch_size: @initial_batch_size,
      concurrent_requests: 2,
      results: %{objects: [], references: []},
      failed_objects: [],
      failed_references: []
    }

    # Start background optimization process
    schedule_optimization()
    schedule_batch_send()

    {:ok, state}
  end

  defp schedule_optimization do
    Process.send_after(self(), :optimize_batch_size, 1000)
  end

  defp schedule_batch_send do
    Process.send_after(self(), :send_batch, 100)
  end

  @impl true
  def handle_info(:optimize_batch_size, state) do
    # Fetch node stats and adjust batch size
    new_state = optimize_batch_parameters(state)
    schedule_optimization()
    {:noreply, new_state}
  end

  defp optimize_batch_parameters(state) do
    case fetch_cluster_stats(state.connection) do
      {:ok, %{"batchStats" => %{"queueLength" => queue_len, "ratePerSecond" => rate}}} ->
        adjust_for_queue(state, queue_len, rate)
      _ ->
        state
    end
  end

  defp adjust_for_queue(state, queue_length, rate) when queue_length == 0 do
    # Server has capacity, increase batch size
    new_size = min(state.recommended_batch_size + 50, @max_batch_size)
    %{state | recommended_batch_size: new_size}
  end

  defp adjust_for_queue(state, queue_length, rate) do
    ratio = queue_length / rate
    cond do
      ratio > 10 -> %{state | recommended_batch_size: 0}  # Pause sending
      ratio > 2 -> %{state | recommended_batch_size: trunc(rate / state.concurrent_requests)}
      true -> state
    end
  end
end
```

---

### 2. Fixed-Size Batching Mode (Critical)

**Python Implementation:**
```python
with client.batch.fixed_size(batch_size=100, concurrent_requests=2) as batch:
    for item in items:
        batch.add_object(collection="Article", properties=item)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.FixedSize do
  @moduledoc """
  Fixed-size batch processor that sends objects in fixed-size batches.
  """

  defstruct [
    :batch_size,
    :concurrent_requests,
    :objects_buffer,
    :task_supervisor,
    :results
  ]

  def new(batch_size \\ 100, concurrent_requests \\ 2) do
    {:ok, sup} = Task.Supervisor.start_link()
    %__MODULE__{
      batch_size: batch_size,
      concurrent_requests: concurrent_requests,
      objects_buffer: [],
      task_supervisor: sup,
      results: %{successful: [], errors: []}
    }
  end

  def add_object(state, collection, properties, opts \\ []) do
    object = build_batch_object(collection, properties, opts)
    new_buffer = [object | state.objects_buffer]

    if length(new_buffer) >= state.batch_size do
      {batch, remaining} = Enum.split(new_buffer, state.batch_size)
      send_batch_async(state, Enum.reverse(batch))
      %{state | objects_buffer: remaining}
    else
      %{state | objects_buffer: new_buffer}
    end
  end

  def flush(state) do
    if length(state.objects_buffer) > 0 do
      send_batch_async(state, Enum.reverse(state.objects_buffer))
      %{state | objects_buffer: []}
    else
      state
    end
  end

  defp send_batch_async(state, batch) do
    # Use semaphore to limit concurrent requests
    Task.Supervisor.async_nolink(state.task_supervisor, fn ->
      WeaviateEx.API.Batch.create_objects(batch)
    end)
  end
end
```

---

### 3. Rate-Limited Batching (Critical)

**Python Implementation:**
```python
# For use with rate-limited vectorizers (OpenAI, Cohere, etc.)
with client.batch.rate_limit(requests_per_minute=100) as batch:
    for item in items:
        batch.add_object(collection="Article", properties=item)
```

**Python Internals:**
- Calculates sleep time: `62 seconds / concurrent_requests`
- Spreads batches evenly across the minute
- Automatically detects rate limit errors from OpenAI/Cohere
- Re-queues failed objects with incremented retry_count

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.RateLimited do
  @moduledoc """
  Rate-limited batch processor for use with vectorizer APIs.
  """
  use GenServer

  @base_time_seconds 62  # Buffer from 60 seconds

  defstruct [
    :requests_per_minute,
    :batch_size,
    :concurrent_requests,
    :last_request_time,
    :objects_queue,
    :results
  ]

  def start_link(requests_per_minute) do
    max_batch_size = 1000
    concurrent_requests = div(requests_per_minute + max_batch_size, max_batch_size)
    batch_size = div(requests_per_minute, concurrent_requests)

    state = %__MODULE__{
      requests_per_minute: requests_per_minute,
      batch_size: batch_size,
      concurrent_requests: concurrent_requests,
      last_request_time: 0,
      objects_queue: :queue.new(),
      results: %{successful: [], errors: []}
    }

    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def handle_info(:send_next_batch, state) do
    sleep_time = calculate_sleep_time(state)

    if sleep_time > 0 do
      Process.sleep(trunc(sleep_time * 1000))
    end

    {batch, remaining} = pop_batch(state.objects_queue, state.batch_size)

    case send_batch_with_retry(batch) do
      {:ok, results} ->
        handle_results(state, results, remaining)
      {:error, :rate_limited, failed_objects} ->
        # Re-queue with incremented retry count
        requeue_failed(state, failed_objects, remaining)
    end
  end

  defp calculate_sleep_time(state) do
    interval = @base_time_seconds / state.concurrent_requests
    elapsed = System.monotonic_time(:second) - state.last_request_time
    max(0, interval - elapsed)
  end

  defp send_batch_with_retry(batch, retry_count \\ 0) do
    case WeaviateEx.API.Batch.create_objects(batch) do
      {:ok, results} ->
        handle_rate_limit_errors(results, batch, retry_count)
      error ->
        error
    end
  end

  defp handle_rate_limit_errors(results, batch, retry_count) do
    rate_limited = Enum.filter(results, fn r ->
      r.error_message =~ "rate limit" or r.error_message =~ "Rate limit"
    end)

    if length(rate_limited) > 0 and retry_count < 5 do
      sleep_time = :math.pow(2, retry_count)
      Process.sleep(trunc(sleep_time * 1000))

      failed_objects = Enum.map(rate_limited, & &1.object)
      send_batch_with_retry(failed_objects, retry_count + 1)
    else
      {:ok, results}
    end
  end
end
```

---

### 4. Batch Context Manager Pattern (Critical)

**Python Implementation:**
```python
# Collection-level batching
with collection.batch.dynamic() as batch:
    batch.add_object(properties={"title": "Article 1"})
    batch.add_object(properties={"title": "Article 2"})
    batch.add_reference(from_uuid=uuid1, from_property="author", to=uuid2)
# Automatically flushes on exit, handles errors

# Client-level batching (across collections)
with client.batch.dynamic() as batch:
    batch.add_object(collection="Article", properties={"title": "Article 1"})
    batch.add_object(collection="Author", properties={"name": "John"})
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.Context do
  @moduledoc """
  Provides context manager-like functionality for batch operations.
  Uses try/after pattern for automatic cleanup.
  """

  defmacro with_batch(mode, opts \\ [], do: block) do
    quote do
      {:ok, batch} = WeaviateEx.Batch.Context.start(unquote(mode), unquote(opts))

      try do
        var!(batch) = batch
        unquote(block)
        WeaviateEx.Batch.Context.flush(batch)
      after
        WeaviateEx.Batch.Context.shutdown(batch)
      end

      WeaviateEx.Batch.Context.get_results(batch)
    end
  end

  def start(:dynamic, opts) do
    WeaviateEx.Batch.Dynamic.start_link(opts)
  end

  def start(:fixed_size, opts) do
    batch_size = Keyword.get(opts, :batch_size, 100)
    concurrent = Keyword.get(opts, :concurrent_requests, 2)
    WeaviateEx.Batch.FixedSize.start_link(batch_size, concurrent)
  end

  def start(:rate_limit, opts) do
    rpm = Keyword.fetch!(opts, :requests_per_minute)
    WeaviateEx.Batch.RateLimited.start_link(rpm)
  end
end

# Usage:
import WeaviateEx.Batch.Context

with_batch :dynamic do
  batch |> add_object("Article", %{title: "Article 1"})
  batch |> add_object("Article", %{title: "Article 2"})
end
```

---

### 5. Concurrent Request Processing (Critical)

**Python Implementation:**
- Uses `ThreadPoolExecutor` for concurrent batch sends
- Background thread manages queue and dispatches work
- Semaphore-like control via `concurrent_requests` limit
- Lock-protected shared state for thread safety

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.Executor do
  @moduledoc """
  Concurrent batch executor using Task.Supervisor and async_stream.
  """

  def send_concurrent(batches, max_concurrency \\ 2) do
    Task.Supervisor.start_link(name: __MODULE__.TaskSupervisor)

    batches
    |> Task.async_stream(
      fn batch -> send_batch(batch) end,
      max_concurrency: max_concurrency,
      timeout: 180_000,  # 3 minutes
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{successful: [], errors: []}, &merge_results/2)
  end

  defp send_batch(batch) do
    case WeaviateEx.API.Batch.create_objects(batch.objects) do
      {:ok, results} ->
        {:ok, process_results(results, batch)}
      {:error, reason} ->
        {:error, {batch, reason}}
    end
  end

  defp merge_results({:ok, {:ok, results}}, acc) do
    %{
      successful: acc.successful ++ results.successful,
      errors: acc.errors ++ results.errors
    }
  end

  defp merge_results({:ok, {:error, {batch, reason}}}, acc) do
    errors = Enum.map(batch.objects, fn obj ->
      %{object: obj, error: reason}
    end)
    %{acc | errors: acc.errors ++ errors}
  end
end
```

---

### 6. Retry Logic with Backoff (High)

**Python Implementation:**
```python
MAX_RETRIES = 9.299  # ~10m30s with exponential backoff

# Automatic detection and retry for rate limits
if "rate limit" in err.message or "Rate limit reached" in err.message:
    if err.object_.retry_count > 5:
        continue  # Give up
    err.object_.retry_count += 1
    readd_objects.append(obj)
    time.sleep(2**highest_retry_count)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.Retry do
  @max_retries 5
  @rate_limit_patterns [
    ~r/rate limit/i,
    ~r/Rate limit reached/i,
    ~r/tokens per min/i,
    ~r/support@cohere\.com/,
    ~r/503 error/i
  ]

  def with_retry(fun, max_retries \\ @max_retries) do
    do_retry(fun, 0, max_retries)
  end

  defp do_retry(fun, attempt, max_retries) when attempt >= max_retries do
    {:error, :max_retries_exceeded}
  end

  defp do_retry(fun, attempt, max_retries) do
    case fun.() do
      {:ok, results} ->
        {successful, rate_limited} = partition_rate_limited(results)

        if length(rate_limited) > 0 do
          backoff_sleep(attempt)
          retry_results = retry_objects(rate_limited, attempt + 1, max_retries)
          {:ok, merge_results(successful, retry_results)}
        else
          {:ok, results}
        end

      {:error, :rate_limited} ->
        backoff_sleep(attempt)
        do_retry(fun, attempt + 1, max_retries)

      error ->
        error
    end
  end

  defp partition_rate_limited(results) do
    Enum.split_with(results, fn r ->
      not is_rate_limit_error?(r.error_message)
    end)
  end

  defp is_rate_limit_error?(nil), do: false
  defp is_rate_limit_error?(message) do
    Enum.any?(@rate_limit_patterns, &Regex.match?(&1, message))
  end

  defp backoff_sleep(attempt) do
    sleep_ms = trunc(:math.pow(2, attempt) * 1000)
    Process.sleep(sleep_ms)
  end
end
```

---

### 7. Failed Objects/References Tracking (High)

**Python Implementation:**
```python
# Access failed objects after batch
with collection.batch.dynamic() as batch:
    for item in items:
        batch.add_object(...)

failed = collection.batch.failed_objects  # List[ErrorObject]
failed_refs = collection.batch.failed_references  # List[ErrorReference]

# Each ErrorObject contains:
# - message: str
# - object_: BatchObject (full original object)
# - original_uuid: Optional[UUID]
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.ErrorTracking do
  @moduledoc """
  Tracks failed objects and references during batch operations.
  """

  defmodule ErrorObject do
    @enforce_keys [:message, :object]
    defstruct [:message, :object, :original_uuid, :retry_count]

    @type t :: %__MODULE__{
      message: String.t(),
      object: map(),
      original_uuid: String.t() | nil,
      retry_count: non_neg_integer()
    }
  end

  defmodule ErrorReference do
    @enforce_keys [:message, :reference]
    defstruct [:message, :reference]

    @type t :: %__MODULE__{
      message: String.t(),
      reference: map()
    }
  end

  defmodule Results do
    defstruct [
      failed_objects: [],
      failed_references: [],
      successful_uuids: %{},
      elapsed_seconds: 0.0
    ]

    def add_error(%__MODULE__{} = results, %ErrorObject{} = error) do
      %{results | failed_objects: [error | results.failed_objects]}
    end

    def add_error(%__MODULE__{} = results, %ErrorReference{} = error) do
      %{results | failed_references: [error | results.failed_references]}
    end

    def add_success(%__MODULE__{} = results, index, uuid) do
      %{results | successful_uuids: Map.put(results.successful_uuids, index, uuid)}
    end

    def has_errors?(%__MODULE__{} = results) do
      length(results.failed_objects) > 0 or length(results.failed_references) > 0
    end

    def number_errors(%__MODULE__{} = results) do
      length(results.failed_objects) + length(results.failed_references)
    end
  end
end
```

---

### 8. Wait for Vector Indexing (Medium)

**Python Implementation:**
```python
with collection.batch.dynamic() as batch:
    for item in items:
        batch.add_object(...)

# Wait for all vectors to be indexed
collection.batch.wait_for_vector_indexing()
# Or with specific shards
collection.batch.wait_for_vector_indexing(
    shards=[Shard(collection="Article", tenant="tenant1")]
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.Indexing do
  @moduledoc """
  Utilities for waiting on vector indexing completion.
  """

  @default_poll_interval 250  # ms
  @default_max_retries 5

  def wait_for_vector_indexing(collection, opts \\ []) do
    tenant = Keyword.get(opts, :tenant)
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)

    do_wait(collection, tenant, max_retries, 0)
  end

  defp do_wait(_collection, _tenant, max_retries, attempt) when attempt >= max_retries do
    {:error, :max_retries_exceeded}
  end

  defp do_wait(collection, tenant, max_retries, attempt) do
    case check_shards_ready(collection, tenant) do
      {:ok, true} ->
        :ok
      {:ok, false} ->
        Process.sleep(@default_poll_interval)
        do_wait(collection, tenant, max_retries, attempt)
      {:error, _reason} ->
        # Exponential backoff on errors
        Process.sleep(trunc(:math.pow(2, attempt) * 1000))
        do_wait(collection, tenant, max_retries, attempt + 1)
    end
  end

  defp check_shards_ready(collection, tenant) do
    path = build_shards_path(collection, tenant)

    case WeaviateEx.request(:get, path) do
      {:ok, shards} when is_list(shards) ->
        ready = Enum.all?(shards, fn shard ->
          shard["status"] == "READY" and shard["vectorQueueSize"] == 0
        end)
        {:ok, ready}
      error ->
        error
    end
  end

  defp build_shards_path(collection, nil) do
    "/v1/schema/#{collection}/shards"
  end

  defp build_shards_path(collection, tenant) do
    "/v1/schema/#{collection}/shards?tenant=#{tenant}"
  end
end
```

---

### 9. gRPC Batch Streaming (High)

**Python Implementation:**
```python
# Server-side batching uses gRPC streaming
with client.batch.experimental() as batch:
    for item in items:
        batch.add_object(...)
# Uses bidirectional gRPC streaming for efficient data transfer
```

**Note:** This requires implementing gRPC support in the Elixir client first. The gRPC batch API provides:
- Streaming object insertion
- Server-side backpressure signaling
- Graceful shutdown handling
- Result streaming back to client

**Proposed Elixir Implementation:**
```elixir
# Requires gun or grpc-elixir library
defmodule WeaviateEx.Batch.GRPC do
  @moduledoc """
  gRPC batch streaming implementation.
  Requires gRPC support to be added to the client.
  """

  alias WeaviateEx.Proto.Batch

  def stream(connection, objects, opts \\ []) do
    consistency_level = Keyword.get(opts, :consistency_level, :QUORUM)

    # Start the stream
    start_request = Batch.BatchStreamRequest.new(
      start: Batch.BatchStreamRequest.Start.new(
        consistency_level: consistency_level
      )
    )

    {:ok, stream} = GRPC.Stub.batch_stream(connection, [start_request])

    # Stream objects
    objects
    |> Enum.chunk_every(100)
    |> Enum.each(fn chunk ->
      data_request = build_data_request(chunk)
      GRPC.Stub.send(stream, data_request)
    end)

    # Send stop and collect results
    stop_request = Batch.BatchStreamRequest.new(
      stop: Batch.BatchStreamRequest.Stop.new()
    )
    GRPC.Stub.send(stream, stop_request)

    collect_results(stream)
  end
end
```

---

### 10. Cluster Batch Stats Monitoring (High)

**Python Implementation:**
```python
class _ClusterBatch:
    def get_nodes_status(self) -> List[Node]:
        response = self._connection.get(path="/nodes")
        return response["nodes"]

# Used for dynamic batch optimization:
# - batchStats.queueLength
# - batchStats.ratePerSecond
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Batch.ClusterMonitor do
  @moduledoc """
  Monitors cluster batch statistics for dynamic optimization.
  """

  def get_batch_stats do
    case WeaviateEx.request(:get, "/v1/nodes") do
      {:ok, %{"nodes" => nodes}} ->
        parse_batch_stats(nodes)
      error ->
        error
    end
  end

  defp parse_batch_stats(nodes) do
    stats = Enum.map(nodes, fn node ->
      case node["batchStats"] do
        nil -> nil
        stats -> %{
          queue_length: stats["queueLength"],
          rate_per_second: stats["ratePerSecond"],
          node_name: node["name"],
          status: node["status"]
        }
      end
    end)
    |> Enum.reject(&is_nil/1)

    {:ok, stats}
  end

  def async_indexing_enabled?(stats) do
    # If batchStats is missing, async indexing is enabled
    Enum.empty?(stats)
  end
end
```

---

## Priority Recommendations

### Critical Priority (Must Have)

1. **Batch Context Manager Pattern**
   - Enables clean API: `with_batch :dynamic do ... end`
   - Automatic flush on exit
   - Error accumulation during batch

2. **Dynamic Batching Mode**
   - Auto-optimization based on server capacity
   - Essential for production workloads
   - GenServer-based implementation

3. **Concurrent Request Processing**
   - Task.Supervisor for parallel sends
   - Configurable concurrency limit
   - Proper error isolation

### High Priority (Should Have)

4. **Rate-Limited Batching**
   - Critical for vectorizer API rate limits
   - Prevents OpenAI/Cohere throttling
   - Exponential backoff

5. **Retry Logic with Backoff**
   - Automatic retry for transient failures
   - Rate limit detection and handling
   - Re-queue failed objects

6. **Failed Objects/References Tracking**
   - Detailed error information
   - Original object preservation
   - Easy error inspection

7. **Fixed-Size Batching**
   - Simple and predictable
   - Good for controlled environments

### Medium Priority (Nice to Have)

8. **Wait for Vector Indexing**
   - Poll shard status
   - Ensure indexing completion
   - Useful for query consistency

9. **gRPC Batch Support**
   - Higher performance
   - Server-side streaming
   - Requires gRPC infrastructure

10. **Cluster Monitoring**
    - Enable dynamic optimization
    - Node status awareness

### Low Priority (Future)

11. **Memory Management**
    - Result pruning for large batches
    - MAX_STORED_RESULTS limiting

12. **Progress Callbacks**
    - Not in Python either
    - Nice for UI/progress bars

---

## Implementation Roadmap

### Phase 1: Foundation (2-3 weeks)
- [ ] Batch Context module with with_batch macro
- [ ] Fixed-Size batching mode (simplest)
- [ ] Enhanced error tracking structs
- [ ] Basic concurrent processing

### Phase 2: Dynamic Batching (2-3 weeks)
- [ ] GenServer-based dynamic batcher
- [ ] Cluster stats monitoring
- [ ] Auto-optimization logic
- [ ] Background send process

### Phase 3: Rate Limiting & Retry (1-2 weeks)
- [ ] Rate-limited batching mode
- [ ] Retry with exponential backoff
- [ ] Rate limit error detection
- [ ] Object re-queuing

### Phase 4: Advanced Features (2-3 weeks)
- [ ] Wait for vector indexing
- [ ] Failed objects/references API
- [ ] number_errors property
- [ ] gRPC preparation (if adding gRPC support)

---

## Conclusion

The batch operations represent the **largest functional gap** between the Python and Elixir clients. The Python client provides a sophisticated, production-ready batching system while the Elixir client offers only basic REST API wrappers.

Key missing components:
1. **No automatic batching lifecycle management**
2. **No dynamic batch size optimization**
3. **No concurrent request handling**
4. **No rate limiting or retry logic**
5. **Limited error tracking**

Implementing these features would require approximately **8-11 weeks** of development effort and would significantly improve the Elixir client's production readiness for bulk data operations.
