# Prompt - Journey Tests (Phoenix/Plug Integration)

## Objective

Implement journey tests that validate WeaviateEx works correctly when embedded in Phoenix and Plug web applications. This mirrors the Python client's `journey_tests/` which tests FastAPI, Flask, and Litestar integrations.

## Priority

P0 - Critical (blocks parity claim)

## Required Reading (Docs)

Read these files to understand the gap and requirements:
- `docs/20251230/integration-test-gaps/00-overview.md`
- `docs/20251230/integration-test-gaps/01-journey-tests-gap.md`
- `docs/20251230/integration-test-gaps/05-quick-start-guide.md`
- `README.md` (testing section, lines 2166-2365)
- `CONTRIBUTING.md`
- `CHANGELOG.md`

## Required Reading (Source/Tests)

Read these to understand current implementation:
- `lib/weaviate_ex/client.ex` - Client lifecycle
- `lib/weaviate_ex/collections.ex` - Collection operations
- `lib/weaviate_ex/batch.ex` - Batch operations
- `lib/weaviate_ex/query.ex` - Query operations
- `test/support/integration_case.ex` - Integration test helpers
- `test/test_helper.exs` - Test configuration
- `mix.exs` - Dependencies

## Required Reading (Python Reference)

Read the canonical Python journey tests to understand what we're porting:
- `../weaviate-python-client/journey_tests/journeys.py` - Shared scenarios
- `../weaviate-python-client/journey_tests/test_fastapi.py` - FastAPI integration
- `../weaviate-python-client/journey_tests/test_flask.py` - Flask integration

## Context

Journey tests validate that the SDK works correctly when:
1. Initialized at application startup and closed at shutdown
2. Used from both sync and async contexts (in Elixir: different processes)
3. Handling concurrent requests from multiple web requests
4. Managing connection lifecycle within web framework patterns

The Python client tests three scenarios:
- sync-in-sync: Sync handler using sync client
- sync-in-async: Async handler using sync client
- async-in-async: Async handler using async client

In Elixir, we test:
- Client shared via Application env
- Client passed through Plug assigns
- Concurrent requests via Phoenix.ConnTest

## Implementation Instructions (TDD Required)

### Step 1: Add Test Dependencies

Update `mix.exs` to add Phoenix test dependencies:

```elixir
defp deps do
  [
    # ... existing deps
    {:phoenix, "~> 1.7", only: :test},
    {:phoenix_html, "~> 4.0", only: :test},
    {:bandit, "~> 1.0", only: :test}
  ]
end
```

Run `mix deps.get`.

### Step 2: Create Journey Scenarios Module

Create `test/journey/scenarios.ex` with shared test scenarios:

```elixir
defmodule WeaviateEx.Journey.Scenarios do
  @moduledoc """
  Shared journey test scenarios ported from Python client.
  Each scenario exercises a complete workflow using the WeaviateEx SDK.
  """

  # Implement these scenarios:
  # 1. simple/1 - Create collection, insert 100 objects, query, cleanup
  # 2. batch_insert_and_search/1 - Batch 1000 objects, vector search
  # 3. concurrent_operations/1 - Multiple simultaneous operations
end
```

Write tests in `test/journey/scenarios_test.exs` first (TDD).

### Step 3: Create Phoenix Integration Test

Create `test/journey/phoenix_test.exs`:

1. Define a minimal Phoenix Router with test endpoints
2. Create a WeaviateClientPlug that injects client into conn.assigns
3. Create controller actions that use the SDK
4. Write tests that:
   - Start real Weaviate (via `mix weaviate.start`)
   - Start Phoenix endpoint
   - Make HTTP requests to endpoints
   - Verify SDK operations succeed
   - Clean up on exit

### Step 4: Create Plug Integration Test

Create `test/journey/plug_test.exs`:

1. Define a Plug.Router with test routes
2. Use Plug.Test for in-process testing
3. Test same scenarios as Phoenix but without full endpoint

### Step 5: Configure Test Tags

Update `test/test_helper.exs`:

```elixir
ExUnit.configure(
  exclude: [:integration, :property, :performance, :journey]
)
```

### Step 6: Create Mix Task Integration (Optional)

Update `lib/mix/tasks/weaviate.ex` to support:

```bash
mix weaviate.test --include journey
```

## Tests to Write

### Scenarios Tests (`test/journey/scenarios_test.exs`)

```elixir
@moduletag :journey
@moduletag :integration

describe "simple/1" do
  test "creates collection, inserts objects, queries, and cleans up"
end

describe "batch_insert_and_search/1" do
  test "batch inserts 1000 objects and performs vector search"
end

describe "concurrent_operations/1" do
  test "handles 10 concurrent operations without errors"
end
```

### Phoenix Tests (`test/journey/phoenix_test.exs`)

```elixir
@moduletag :journey
@moduletag :integration

describe "Phoenix integration" do
  test "client initialized at startup survives multiple requests"
  test "concurrent requests share client safely"
  test "client properly cleaned up on shutdown"
end
```

### Plug Tests (`test/journey/plug_test.exs`)

```elixir
@moduletag :journey
@moduletag :integration

describe "Plug integration" do
  test "client accessible via conn.assigns"
  test "journey scenarios work through Plug router"
end
```

## Docs Updates

### README.md

Add section under Testing:

```markdown
### Journey Tests

Journey tests validate WeaviateEx integration with Phoenix and Plug web frameworks:

\`\`\`bash
# Start Weaviate
mix weaviate.start

# Run journey tests
WEAVIATE_INTEGRATION=true mix test --include journey

# Stop Weaviate
mix weaviate.stop
\`\`\`

See `test/journey/` for Phoenix and Plug integration examples.
```

### Update docs/20251230/integration-test-gaps/01-journey-tests-gap.md

Mark implementation complete with link to test files.

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- Journey tests for Phoenix and Plug web framework integration
- `WeaviateEx.Journey.Scenarios` module with shared test scenarios
- Journey test tag (`:journey`) for selective test execution
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] Journey tests pass: `WEAVIATE_INTEGRATION=true mix test --include journey`
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated with journey test documentation
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `test/journey/` directory exists with at least 3 test files
2. `WeaviateEx.Journey.Scenarios` implements at least 3 scenarios
3. Phoenix integration test passes
4. Plug integration test passes
5. Journey tests excluded by default, run with `--include journey`
6. All quality gates pass
