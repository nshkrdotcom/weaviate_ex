# Prompt - HTTP Transport Retry & Per-Operation Timeouts

## Objective

Implement HTTP transport-level retry logic and per-operation timeout support to match Python client reliability features. Currently, only gRPC has comprehensive retry logic.

## Priority

P0 - Critical (Production reliability)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/01-rest-http-api.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-transport-connection.md`
- `README.md`
- `CHANGELOG.md`

## Required Reading (Source/Tests)

Read existing retry and HTTP implementation:
- `lib/weaviate_ex/grpc/retry.ex` - gRPC retry logic (reference)
- `lib/weaviate_ex/protocol/http/client.ex` - Current HTTP client
- `lib/weaviate_ex/protocol/http/rate_limit.ex` - Rate limiting
- `lib/weaviate_ex/config/timeout.ex` - Timeout configuration
- `lib/weaviate_ex/retry.ex` - General retry (if exists)
- `test/weaviate_ex/retry_test.exs`
- `test/weaviate_ex/protocol/http/client_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/connect/v4.py` - Connection with retry
- `../weaviate-python-client/weaviate/connect/base.py` - Timeout handling

## Context

### Current State
- gRPC has excellent retry logic in `grpc/retry.ex`
- HTTP client (`protocol/http/client.ex`) has no transport-level retry
- Timeout config exists but isn't consistently applied per-operation
- Python uses `urllib3.util.retry.Retry` for HTTP with configurable attempts

### Gap
- HTTP requests fail immediately on transient errors (network blips, 503s)
- No exponential backoff for HTTP
- Per-operation timeouts not used (e.g., batch should have longer timeout)

## Implementation Instructions (TDD Required)

### Step 1: Create HTTP Retry Module

Create `lib/weaviate_ex/protocol/http/retry.ex`:

```elixir
defmodule WeaviateEx.Protocol.HTTP.Retry do
  @moduledoc """
  HTTP transport-level retry with exponential backoff.
  Mirrors gRPC retry behavior for HTTP operations.
  """

  @default_max_retries 3
  @default_base_delay_ms 100
  @default_max_delay_ms 5000
  @retryable_status_codes [408, 429, 500, 502, 503, 504]

  @type retry_opts :: [
    max_retries: non_neg_integer(),
    base_delay_ms: non_neg_integer(),
    max_delay_ms: non_neg_integer(),
    retryable_status_codes: [integer()]
  ]

  @spec with_retry((() -> {:ok, any()} | {:error, any()}), retry_opts()) ::
    {:ok, any()} | {:error, any()}

  # Implement retry logic with:
  # 1. Exponential backoff with jitter
  # 2. Configurable max retries
  # 3. Retryable status code detection
  # 4. Retryable error detection (connection errors, timeouts)
end
```

Write tests first in `test/weaviate_ex/protocol/http/retry_test.exs`.

### Step 2: Create Per-Operation Timeout Helper

Create `lib/weaviate_ex/protocol/http/timeout.ex`:

```elixir
defmodule WeaviateEx.Protocol.HTTP.Timeout do
  @moduledoc """
  Per-operation timeout calculation based on operation type.
  """

  alias WeaviateEx.Config.Timeout

  @spec for_operation(Timeout.t(), atom()) :: non_neg_integer()
  def for_operation(%Timeout{} = config, operation) do
    case operation do
      :query -> config.query
      :insert -> config.insert
      :init -> config.init
      :batch -> config.insert * 10  # Batch gets extended timeout
      _ -> config.query
    end
  end
end
```

### Step 3: Integrate Retry into HTTP Client

Update `lib/weaviate_ex/protocol/http/client.ex`:

1. Add retry wrapper around all HTTP operations
2. Apply per-operation timeouts
3. Respect rate limit responses (429)
4. Log retry attempts for debugging

```elixir
def request(method, url, body, opts) do
  timeout = Timeout.for_operation(opts[:timeout_config], opts[:operation])

  Retry.with_retry(fn ->
    Finch.request(
      build_request(method, url, body, opts),
      WeaviateEx.Finch,
      receive_timeout: timeout
    )
  end, opts[:retry_opts] || [])
end
```

### Step 4: Update API Modules to Pass Operation Type

Update callers in `lib/weaviate_ex/api/` to specify operation type:

```elixir
# In collections.ex
def create(client, params) do
  HTTP.Client.request(:post, url, body, operation: :insert)
end

# In batch.ex
def create_objects(client, objects) do
  HTTP.Client.request(:post, url, body, operation: :batch)
end
```

## Tests to Write

### Retry Tests (`test/weaviate_ex/protocol/http/retry_test.exs`)

```elixir
describe "with_retry/2" do
  test "succeeds on first try without retry"
  test "retries on 503 and succeeds on second attempt"
  test "retries with exponential backoff"
  test "respects max_retries limit"
  test "does not retry on 400 (client error)"
  test "does not retry on 401 (auth error)"
  test "retries on connection error"
  test "retries on timeout error"
  test "adds jitter to backoff delay"
end
```

### Timeout Tests (`test/weaviate_ex/protocol/http/timeout_test.exs`)

```elixir
describe "for_operation/2" do
  test "returns query timeout for :query operation"
  test "returns insert timeout for :insert operation"
  test "returns extended timeout for :batch operation"
  test "uses default for unknown operation"
end
```

### Integration Tests (update existing)

Update `test/integration/*` to verify retry behavior with real server.

## Docs Updates

### README.md

Add section on retry configuration:

```markdown
### HTTP Retry Configuration

WeaviateEx automatically retries failed HTTP requests with exponential backoff:

\`\`\`elixir
{:ok, client} = WeaviateEx.Client.connect("http://localhost:8080",
  retry: [
    max_retries: 3,
    base_delay_ms: 100,
    max_delay_ms: 5000
  ]
)
\`\`\`

Retryable status codes: 408, 429, 500, 502, 503, 504
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- HTTP transport-level retry with exponential backoff (`WeaviateEx.Protocol.HTTP.Retry`)
- Per-operation timeout support for HTTP requests
- Configurable retry options (max_retries, base_delay_ms, max_delay_ms)

### Changed
- HTTP client now retries on transient errors (503, 429, connection errors)
- Batch operations use extended timeouts by default
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New retry tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `WeaviateEx.Protocol.HTTP.Retry` module exists with `with_retry/2`
2. HTTP client automatically retries on 503, 429, connection errors
3. Retry uses exponential backoff with jitter
4. Per-operation timeouts applied correctly
5. Batch operations have extended timeouts
6. All quality gates pass
