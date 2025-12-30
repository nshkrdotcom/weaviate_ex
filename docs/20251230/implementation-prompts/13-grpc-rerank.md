# Prompt - gRPC Rerank Integration

## Objective

Implement gRPC-based reranking to improve search result quality. Reranking uses a separate model to re-score and reorder search results for better relevance.

## Priority

P2 - Medium (Search quality)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/05-search-query.md`
- `README.md` (search section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/query.ex` - Query module
- `lib/weaviate_ex/query/rerank.ex` - Existing rerank (if exists)
- `lib/weaviate_ex/api/reranker_config.ex` - Reranker configuration
- `lib/weaviate_ex/grpc/services/search.ex` - gRPC search
- `test/weaviate_ex/query_test.exs`
- `test/weaviate_ex/api/reranker_config_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/queries/base.py` - Rerank in queries
- `../weaviate-python-client/weaviate/collections/classes/grpc.py` - gRPC rerank

## Context

### Current State
- Reranker configuration exists for collection setup
- Query may have rerank option but not wired to gRPC
- HTTP/GraphQL reranking may work

### Gap
gRPC search doesn't include reranking parameters. Python uses:
```python
result = collection.query.near_text(
    "query",
    rerank=Rerank(
        property="content",
        query="rerank query"  # Optional, uses original if not provided
    )
)
```

### Supported Rerankers
- `reranker-cohere` - Cohere Rerank API
- `reranker-transformers` - Local transformer models
- `reranker-voyageai` - VoyageAI reranker

## Implementation Instructions (TDD Required)

### Step 1: Create Rerank Query Struct

Create/update `lib/weaviate_ex/query/rerank.ex`:

```elixir
defmodule WeaviateEx.Query.Rerank do
  @moduledoc """
  Configuration for search result reranking.

  Reranking uses a separate model to re-score search results
  based on relevance to the query.
  """

  @type t :: %__MODULE__{
    property: String.t(),
    query: String.t() | nil
  }

  defstruct [:property, :query]

  @doc """
  Creates a rerank configuration.

  ## Parameters

  - `property` - The property to use for reranking (required)
  - `query` - Optional rerank query (uses original search query if not provided)

  ## Examples

      # Rerank using content property
      Rerank.new("content")

      # Rerank with custom query
      Rerank.new("content", query: "specific rerank query")
  """
  @spec new(String.t(), keyword()) :: t()
  def new(property, opts \\ []) do
    %__MODULE__{
      property: property,
      query: opts[:query]
    }
  end

  @doc """
  Converts to gRPC Rerank message.
  """
  @spec to_grpc(t()) :: map()
  def to_grpc(%__MODULE__{property: prop, query: query}) do
    %{
      property: prop,
      query: query
    }
  end
end
```

### Step 2: Add Rerank to Query Builder

Update `lib/weaviate_ex/query.ex`:

```elixir
defmodule WeaviateEx.Query do
  alias WeaviateEx.Query.Rerank

  @type t :: %{
    # ... existing fields
    rerank: Rerank.t() | nil
  }

  @doc """
  Adds reranking to the query.

  Reranking re-scores results using a reranker model configured
  on the collection.

  ## Examples

      Query.get("Articles")
      |> Query.near_text("machine learning", ["content"])
      |> Query.rerank("content")
      |> Query.execute(client)

      # With custom rerank query
      Query.get("Articles")
      |> Query.hybrid("AI", vector)
      |> Query.rerank("content", query: "artificial intelligence applications")
      |> Query.execute(client)
  """
  @spec rerank(t(), String.t(), keyword()) :: t()
  def rerank(query, property, opts \\ []) do
    %{query | rerank: Rerank.new(property, opts)}
  end
end
```

### Step 3: Wire Rerank into gRPC Search

Update `lib/weaviate_ex/grpc/services/search.ex`:

```elixir
defp build_request(collection, params, opts) do
  %SearchRequest{
    collection: collection,
    # ... existing params
    rerank: build_rerank(params[:rerank])
  }
end

defp build_rerank(nil), do: nil
defp build_rerank(%Rerank{} = rerank) do
  %GRPCRerank{
    property: rerank.property,
    query: rerank.query
  }
end
```

### Step 4: Parse Rerank Score in Results

Update result parsing to include rerank score:

```elixir
defp parse_object(obj) do
  %{
    uuid: obj.uuid,
    properties: parse_properties(obj.properties),
    vector: obj.vector,
    metadata: %{
      distance: obj.metadata.distance,
      certainty: obj.metadata.certainty,
      score: obj.metadata.score,
      rerank_score: obj.metadata.rerank_score  # Add rerank score
    }
  }
end
```

### Step 5: Add HTTP/GraphQL Fallback

For servers without gRPC rerank support:

```elixir
defp build_graphql_query(%{rerank: %Rerank{} = rerank} = query) do
  """
  {
    Get {
      #{query.collection}(
        #{search_clause(query)}
        rerank: {
          property: "#{rerank.property}"
          #{optional_field("query", rerank.query)}
        }
      ) {
        #{return_fields(query)}
        _additional {
          rerank {
            score
          }
        }
      }
    }
  }
  """
end
```

## Tests to Write

### Rerank Module Tests (`test/weaviate_ex/query/rerank_test.exs`)

```elixir
describe "new/2" do
  test "creates rerank with property only"
  test "creates rerank with property and query"
  test "query is optional"
end

describe "to_grpc/1" do
  test "converts to gRPC format"
  test "handles nil query"
end
```

### Query Rerank Tests (`test/weaviate_ex/query_test.exs`)

```elixir
describe "rerank/3" do
  test "adds rerank to query"
  test "preserves other query params"
  test "accepts optional query parameter"
end
```

### Integration Tests

```elixir
@tag :integration
describe "search with rerank" do
  setup do
    # Create collection with reranker-cohere or reranker-transformers
  end

  test "reranks near_text results"
  test "reranks hybrid results"
  test "rerank_score included in results"
  test "custom rerank query affects ordering"
end
```

## Docs Updates

### README.md

Add reranking section:

```markdown
### Reranking

Improve search result relevance with reranking:

\`\`\`elixir
# Basic reranking
{:ok, results} = WeaviateEx.Query.get("Articles")
|> WeaviateEx.Query.near_text("machine learning", ["content"])
|> WeaviateEx.Query.rerank("content")
|> WeaviateEx.Query.limit(10)
|> WeaviateEx.Query.execute(client)

# With custom rerank query
{:ok, results} = WeaviateEx.Query.get("Articles")
|> WeaviateEx.Query.hybrid("AI trends", vector)
|> WeaviateEx.Query.rerank("content", query: "latest AI applications in healthcare")
|> WeaviateEx.Query.execute(client)

# Access rerank scores
Enum.each(results.objects, fn obj ->
  IO.puts("Score: \#{obj.metadata.rerank_score}")
end)
\`\`\`

**Note:** Requires a reranker module configured on the collection
(e.g., `reranker-cohere`, `reranker-transformers`).

#### Collection Setup with Reranker

\`\`\`elixir
{:ok, _} = WeaviateEx.Collections.create(client, "Articles",
  reranker: WeaviateEx.API.RerankerConfig.cohere()
)
\`\`\`
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- gRPC-based reranking for search queries
- `WeaviateEx.Query.Rerank` struct for rerank configuration
- `Query.rerank/3` for adding reranking to queries
- Rerank score in result metadata

### Changed
- Search results now include `rerank_score` when reranking is used
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New rerank tests pass
- [ ] Integration tests pass (with reranker-enabled collection)
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `WeaviateEx.Query.Rerank` struct implemented
2. `Query.rerank/3` adds reranking to queries
3. gRPC search includes rerank parameters
4. Rerank score included in result metadata
5. Works with near_text, near_vector, hybrid queries
6. Integration test verifies reranking changes result order
7. All quality gates pass
