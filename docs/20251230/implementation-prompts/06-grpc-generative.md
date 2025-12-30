# Prompt - gRPC Generative Search (RAG)

## Objective

Implement gRPC-based generative search to improve RAG performance. Currently, generative search uses HTTP/GraphQL. gRPC provides better latency and throughput for production RAG workloads.

## Priority

P1 - High (Performance, feature completeness)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/05-search-query.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-query-generative.md`
- `README.md` (generative/RAG section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/api/generative.ex` - Current generative implementation
- `lib/weaviate_ex/query/generate.ex` - Generate query builder
- `lib/weaviate_ex/query/generative_result.ex` - Result parsing
- `lib/weaviate_ex/generative/config.ex` - Generative config
- `lib/weaviate_ex/grpc/services/search.ex` - gRPC search service
- `lib/weaviate_ex/grpc/generated/v1/search.pb.ex` - gRPC search proto
- `test/weaviate_ex/api/generative_test.exs`
- `test/weaviate_ex/grpc/services/search_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/grpc/query.py` - gRPC generative
- `../weaviate-python-client/weaviate/proto/v1/search_get_pb2.py` - Proto definitions

## Context

### Current State
- Generative search works via HTTP/GraphQL
- gRPC search exists for vector/hybrid queries without generation
- Generative config structures exist but aren't wired to gRPC
- Proto definitions support generative in `SearchRequest.generative`

### Gap
- gRPC search doesn't include generative parameters
- No streaming generative support
- Performance gap vs Python gRPC implementation

### Python gRPC Generative
```python
# From grpc/query.py
def _create_search_request(..., generative: _Generative | None) -> search_get_pb2.SearchRequest:
    request = search_get_pb2.SearchRequest(
        # ... search params
        generative=search_get_pb2.GenerativeSearch(
            single_response_prompt=generative.single_prompt,
            grouped_response_task=generative.grouped_task,
            grouped_properties=generative.grouped_properties,
        ) if generative else None
    )
```

## Implementation Instructions (TDD Required)

### Step 1: Examine Proto Definitions

Read the generated proto files:
- `lib/weaviate_ex/grpc/generated/v1/search_get.pb.ex`

Look for `GenerativeSearch` message structure:
```protobuf
message GenerativeSearch {
  string single_response_prompt = 1;
  string grouped_response_task = 2;
  repeated string grouped_properties = 3;
}
```

### Step 2: Create gRPC Generative Builder

Create `lib/weaviate_ex/grpc/generative.ex`:

```elixir
defmodule WeaviateEx.GRPC.Generative do
  @moduledoc """
  Builds gRPC GenerativeSearch message from WeaviateEx generative config.
  """

  alias WeaviateEx.GRPC.Generated.V1.SearchGet.GenerativeSearch

  @spec build(map() | nil) :: GenerativeSearch.t() | nil
  def build(nil), do: nil

  def build(%{single_prompt: prompt}) when is_binary(prompt) do
    %GenerativeSearch{
      single_response_prompt: prompt
    }
  end

  def build(%{grouped_task: task, grouped_properties: props}) do
    %GenerativeSearch{
      grouped_response_task: task,
      grouped_properties: props || []
    }
  end

  def build(%{single_prompt: prompt, grouped_task: task, grouped_properties: props}) do
    %GenerativeSearch{
      single_response_prompt: prompt,
      grouped_response_task: task,
      grouped_properties: props || []
    }
  end
end
```

### Step 3: Update gRPC Search Service

Update `lib/weaviate_ex/grpc/services/search.ex`:

```elixir
defmodule WeaviateEx.GRPC.Services.Search do
  alias WeaviateEx.GRPC.Generative

  def search(channel, collection, params, opts \\ []) do
    request = build_request(collection, params, opts)
    # ... execute gRPC call
  end

  defp build_request(collection, params, opts) do
    %SearchRequest{
      collection: collection,
      # ... existing params
      generative: Generative.build(opts[:generative])
    }
  end

  defp parse_response(%{results: results, generative_grouped_result: grouped}) do
    %{
      objects: parse_objects(results),
      generated: %{
        grouped: grouped,
        single: extract_single_generations(results)
      }
    }
  end

  defp extract_single_generations(results) do
    results
    |> Enum.map(& &1.metadata.generative)
    |> Enum.reject(&is_nil/1)
  end
end
```

### Step 4: Update Query Module

Update `lib/weaviate_ex/query.ex` to use gRPC for generative:

```elixir
def execute(%{generate: gen_config} = query, client, opts) when not is_nil(gen_config) do
  # Use gRPC when generative is requested
  GRPC.Services.Search.search(
    client.grpc_channel,
    query.collection,
    query_params(query),
    generative: gen_config
  )
end
```

### Step 5: Parse Generative Results

Update `lib/weaviate_ex/query/generative_result.ex`:

```elixir
defmodule WeaviateEx.Query.GenerativeResult do
  @moduledoc """
  Parses generative search results from gRPC responses.
  """

  defstruct [:objects, :generated_text, :grouped_result, :single_results]

  @spec from_grpc_response(map()) :: t()
  def from_grpc_response(%{objects: objs, generated: gen}) do
    %__MODULE__{
      objects: objs,
      grouped_result: gen[:grouped],
      single_results: gen[:single]
    }
  end
end
```

### Step 6: Add Streaming Generative (Optional)

If proto supports streaming, add streaming generative support:

```elixir
defmodule WeaviateEx.GRPC.Services.GenerativeStream do
  @moduledoc """
  Streaming generative search for large responses.
  """

  def stream_generate(channel, collection, params, opts) do
    # Stream response chunks as they arrive
  end
end
```

## Tests to Write

### gRPC Generative Tests (`test/weaviate_ex/grpc/generative_test.exs`)

```elixir
describe "build/1" do
  test "builds single prompt generative config"
  test "builds grouped task generative config"
  test "builds combined single + grouped config"
  test "returns nil for nil input"
end
```

### gRPC Search with Generative (`test/weaviate_ex/grpc/services/search_test.exs`)

```elixir
describe "search with generative" do
  test "includes generative in request when provided"
  test "parses single generation results"
  test "parses grouped generation result"
  test "handles empty generative response"
end
```

### Integration Tests

Add to `test/integration/search_integration_test.exs`:

```elixir
@tag :integration
describe "gRPC generative search" do
  test "generates single response for each object"
  test "generates grouped response for collection"
  test "works with near_text + generative"
  test "works with hybrid + generative"
end
```

## Docs Updates

### README.md

Update generative section:

```markdown
### Generative Search (RAG)

WeaviateEx uses gRPC for high-performance generative search:

\`\`\`elixir
# Single object generation
{:ok, results} = WeaviateEx.Query.get("Articles")
|> WeaviateEx.Query.near_text("machine learning", ["content"])
|> WeaviateEx.Query.generate(single_prompt: "Summarize this article: {content}")
|> WeaviateEx.Query.execute(client)

# Grouped generation
{:ok, results} = WeaviateEx.Query.get("Articles")
|> WeaviateEx.Query.near_text("AI trends", ["content"])
|> WeaviateEx.Query.generate(
    grouped_task: "Synthesize the key themes from these articles",
    grouped_properties: ["title", "content"]
  )
|> WeaviateEx.Query.execute(client)

# Access generated text
results.grouped_result  # Grouped generation
results.single_results  # Per-object generations
\`\`\`

gRPC provides ~2-3x better latency compared to HTTP for generative queries.
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- gRPC-based generative search for improved RAG performance
- `WeaviateEx.GRPC.Generative` module for building generative requests
- Single prompt and grouped task generative support via gRPC
- `WeaviateEx.Query.GenerativeResult` struct with typed results

### Changed
- Generative queries now use gRPC instead of HTTP by default
- ~2-3x latency improvement for generative search operations
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New gRPC generative tests pass
- [ ] Integration tests pass: `WEAVIATE_INTEGRATION=true mix test --include integration`
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `WeaviateEx.GRPC.Generative` module implements builder
2. gRPC search includes generative parameters when provided
3. Single prompt generation works via gRPC
4. Grouped task generation works via gRPC
5. Results properly parsed into `GenerativeResult` struct
6. Integration tests verify real Weaviate behavior
7. All quality gates pass
