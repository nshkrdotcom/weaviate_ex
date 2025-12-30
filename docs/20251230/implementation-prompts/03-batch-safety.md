# Prompt - Batch Safety (MAX_STORED_RESULTS + Auto Re-queue)

## Objective

Implement batch safety features: MAX_STORED_RESULTS limit to prevent memory exhaustion, and auto re-queue for failed objects. These are P0 gaps for production reliability at scale.

## Priority

P0 - Critical (Memory safety, error recovery)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/04-batch-operations.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-batch-data.md` (if exists)
- `README.md` (batch section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/batch.ex` - Main batch module
- `lib/weaviate_ex/batch/error_tracking.ex` - Error tracking
- `lib/weaviate_ex/batch/queue.ex` - Batch queue
- `lib/weaviate_ex/batch/dynamic.ex` - Dynamic batching
- `lib/weaviate_ex/batch/background.ex` - Background processing
- `lib/weaviate_ex/batch/stream.ex` - gRPC streaming
- `test/weaviate_ex/batch_test.exs`
- `test/weaviate_ex/batch/*` - All batch tests

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/batch/base.py` - MAX_STORED_RESULTS
- `../weaviate-python-client/weaviate/collections/batch/grpc_batch_objects.py` - Re-queue logic

## Context

### Current State
- Batch error tracking stores all failed object UUIDs indefinitely
- No limit on stored results (memory can grow unbounded)
- Failed objects are tracked but not automatically re-queued
- Python client has `MAX_STORED_RESULTS = 100_000` and auto re-queue

### Gap
1. **Memory Safety**: With 100K+ batch operations, error tracking map grows unbounded
2. **Error Recovery**: Failed objects must be manually handled; no automatic retry

### Python Behavior
```python
# From base.py
MAX_STORED_RESULTS = 100_000

# Evicts oldest entries when limit exceeded
if len(self._results) >= MAX_STORED_RESULTS:
    self._evict_oldest()

# Auto re-queue failed objects for retry
if result.has_errors:
    for failed in result.errors:
        self._retry_queue.append(failed.object)
```

## Implementation Instructions (TDD Required)

### Step 1: Add MAX_STORED_RESULTS to Error Tracking

Update `lib/weaviate_ex/batch/error_tracking.ex`:

```elixir
defmodule WeaviateEx.Batch.ErrorTracking do
  @max_stored_results 100_000

  defstruct [
    :errors,
    :successes,
    :timestamps,  # Track insertion order for eviction
    max_stored: @max_stored_results
  ]

  @spec add_result(t(), uuid(), result()) :: t()
  def add_result(%__MODULE__{} = tracker, uuid, result) do
    tracker
    |> maybe_evict_oldest()
    |> do_add_result(uuid, result)
  end

  defp maybe_evict_oldest(%{errors: errors, timestamps: ts} = tracker)
       when map_size(errors) >= @max_stored_results do
    # Evict oldest 10% of entries
    evict_count = div(@max_stored_results, 10)
    oldest_uuids = ts |> Enum.sort_by(&elem(&1, 1)) |> Enum.take(evict_count) |> Enum.map(&elem(&1, 0))

    %{tracker |
      errors: Map.drop(errors, oldest_uuids),
      timestamps: Map.drop(ts, oldest_uuids)
    }
  end
  defp maybe_evict_oldest(tracker), do: tracker
end
```

Write tests first.

### Step 2: Add Auto Re-queue for Failed Objects

Create `lib/weaviate_ex/batch/retry_queue.ex`:

```elixir
defmodule WeaviateEx.Batch.RetryQueue do
  @moduledoc """
  Manages automatic re-queuing of failed batch objects.
  """

  use GenServer

  @max_retries 3
  @retry_delay_ms 1000

  defstruct [
    :queue,
    :retry_counts,
    :client,
    max_retries: @max_retries
  ]

  @spec enqueue_failed(pid(), [map()]) :: :ok
  def enqueue_failed(pid, failed_objects) do
    GenServer.cast(pid, {:enqueue, failed_objects})
  end

  @spec drain(pid()) :: {:ok, [map()]} | {:error, term()}
  def drain(pid) do
    GenServer.call(pid, :drain)
  end

  # Implement:
  # 1. Track retry count per object UUID
  # 2. Exponential backoff between retries
  # 3. Drop objects after max_retries
  # 4. Callback for permanent failures
end
```

### Step 3: Integrate Re-queue into Batch Processing

Update `lib/weaviate_ex/batch.ex` and `lib/weaviate_ex/batch/stream.ex`:

```elixir
def handle_batch_response(response, state) do
  {successes, failures} = partition_results(response)

  # Track errors with eviction
  state = update_in(state.error_tracker, &ErrorTracking.add_results(&1, failures))

  # Auto re-queue retryable failures
  retryable = Enum.filter(failures, &retryable_error?/1)
  if retryable != [] do
    RetryQueue.enqueue_failed(state.retry_queue, retryable)
  end

  state
end

defp retryable_error?(%{error: %{code: code}}) when code in [:unavailable, :resource_exhausted], do: true
defp retryable_error?(_), do: false
```

### Step 4: Add Configuration Options

Update batch config to allow customization:

```elixir
defmodule WeaviateEx.Batch.Config do
  defstruct [
    max_stored_results: 100_000,
    auto_retry: true,
    max_retries: 3,
    retry_delay_ms: 1000
  ]
end
```

## Tests to Write

### Error Tracking Tests (`test/weaviate_ex/batch/error_tracking_test.exs`)

```elixir
describe "MAX_STORED_RESULTS" do
  test "stores results up to limit"
  test "evicts oldest entries when limit exceeded"
  test "evicts 10% at a time for efficiency"
  test "maintains correct count after eviction"
  test "preserves newest entries during eviction"
end

describe "add_result/3" do
  test "tracks timestamp for eviction ordering"
  test "handles concurrent additions safely"
end
```

### Retry Queue Tests (`test/weaviate_ex/batch/retry_queue_test.exs`)

```elixir
describe "enqueue_failed/2" do
  test "adds objects to retry queue"
  test "tracks retry count per UUID"
  test "drops objects after max_retries"
end

describe "retry processing" do
  test "retries with exponential backoff"
  test "calls callback on permanent failure"
  test "succeeds on retry and removes from queue"
end

describe "drain/1" do
  test "processes all queued retries"
  test "returns summary of results"
end
```

### Integration Tests

Update `test/integration/batch_integration_test.exs`:

```elixir
describe "batch safety at scale" do
  @tag timeout: 120_000
  test "handles 100K+ objects without memory issues"
  test "auto-retries transient failures"
end
```

## Docs Updates

### README.md

Update batch section:

```markdown
### Batch Safety Features

WeaviateEx implements production-grade batch safety:

#### Memory Management
- Maximum 100,000 stored results (configurable)
- Automatic eviction of oldest entries when limit exceeded
- Prevents unbounded memory growth at scale

#### Auto-Retry
- Failed objects automatically re-queued for retry
- Exponential backoff between retry attempts
- Maximum 3 retries before permanent failure callback

\`\`\`elixir
{:ok, results} = WeaviateEx.Batch.create_objects(client, objects,
  max_stored_results: 50_000,
  auto_retry: true,
  max_retries: 5,
  on_permanent_failure: fn objects -> Logger.error("Failed: \#{length(objects)}") end
)
\`\`\`
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- MAX_STORED_RESULTS limit (100,000) for batch error tracking
- Automatic eviction of oldest batch results when limit exceeded
- Auto re-queue for failed batch objects (`WeaviateEx.Batch.RetryQueue`)
- Configurable retry attempts and backoff for batch operations
- Permanent failure callback for objects exceeding retry limit

### Changed
- Batch error tracking now uses timestamp-based eviction
- Improved memory efficiency for large-scale batch operations
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New batch safety tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `MAX_STORED_RESULTS` limit enforced (default 100,000)
2. Oldest entries evicted when limit exceeded
3. `WeaviateEx.Batch.RetryQueue` module implemented
4. Failed objects automatically re-queued
5. Configurable max_retries and retry_delay
6. Permanent failure callback supported
7. All quality gates pass
