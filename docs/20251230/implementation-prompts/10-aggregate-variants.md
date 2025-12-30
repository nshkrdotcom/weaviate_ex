# Prompt - Aggregate Variants (near_object, hybrid)

## Objective

Implement aggregate variants `aggregate_near_object` and `aggregate_hybrid` to complete aggregation feature parity with the Python client.

## Priority

P1 - High (Feature completeness)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/05-search-query.md`
- `README.md` (aggregation section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/api/aggregate.ex` - Current aggregate implementation
- `lib/weaviate_ex/grpc/services/aggregate.ex` - gRPC aggregate (if exists)
- `test/weaviate_ex/api/aggregate_test.exs`
- `test/integration/aggregate_integration_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/aggregate.py`
- `../weaviate-python-client/weaviate/collections/queries/aggregate.py`

## Context

### Current State
Existing aggregate methods:
- `over_all/3` - Aggregate entire collection
- `by_property/4` - Aggregate by property
- `with_where/4` - Filtered aggregations
- `with_near_text/4` - Text-based contextual aggregations
- `with_near_vector/4` - Vector-based aggregations

### Gap
Missing aggregate variants:
- `near_object` - Aggregate objects similar to a reference object
- `hybrid` - Aggregate with hybrid (keyword + vector) search

### Python API
```python
# Aggregate near object
result = collection.aggregate.near_object(
    uuid="123...",
    distance=0.5,
    return_metrics=[Metrics("count")]
)

# Aggregate hybrid
result = collection.aggregate.hybrid(
    query="search term",
    alpha=0.5,  # Weight between keyword and vector
    return_metrics=[Metrics("count"), Metrics.text("title", count=True)]
)
```

## Implementation Instructions (TDD Required)

### Step 1: Add near_object Aggregate

Update `lib/weaviate_ex/api/aggregate.ex`:

```elixir
@doc """
Aggregates objects similar to a reference object.

## Parameters

- `client` - WeaviateEx client
- `collection` - Collection name
- `uuid` - Reference object UUID
- `opts` - Options:
  - `:distance` - Maximum distance (float)
  - `:certainty` - Minimum certainty (float)
  - `:metrics` - Metrics to calculate
  - `:group_by` - Property to group by
  - `:object_limit` - Max objects to aggregate

## Examples

    Aggregate.near_object(client, "Articles", "uuid-here",
      distance: 0.5,
      metrics: [:count, {:text, "title", count: true}]
    )
"""
@spec near_object(Client.t(), String.t(), String.t(), keyword()) ::
  {:ok, map()} | {:error, term()}
def near_object(client, collection, uuid, opts \\ []) do
  query = build_aggregate_query(collection, opts)
  |> Map.put(:nearObject, %{
    id: uuid,
    distance: opts[:distance],
    certainty: opts[:certainty]
  })

  execute_aggregate(client, query)
end
```

### Step 2: Add hybrid Aggregate

```elixir
@doc """
Aggregates with hybrid (keyword + vector) search.

## Parameters

- `client` - WeaviateEx client
- `collection` - Collection name
- `query` - Search query string
- `opts` - Options:
  - `:alpha` - Weight between keyword (0) and vector (1), default 0.5
  - `:vector` - Optional explicit vector
  - `:properties` - Properties to search
  - `:fusion_type` - Fusion algorithm (:ranked, :relative_score)
  - `:metrics` - Metrics to calculate
  - `:group_by` - Property to group by
  - `:object_limit` - Max objects to aggregate

## Examples

    Aggregate.hybrid(client, "Articles", "machine learning",
      alpha: 0.7,
      metrics: [:count, {:number, "views", sum: true, mean: true}]
    )
"""
@spec hybrid(Client.t(), String.t(), String.t(), keyword()) ::
  {:ok, map()} | {:error, term()}
def hybrid(client, collection, query, opts \\ []) do
  agg_query = build_aggregate_query(collection, opts)
  |> Map.put(:hybrid, %{
    query: query,
    alpha: opts[:alpha] || 0.5,
    vector: opts[:vector],
    properties: opts[:properties],
    fusionType: fusion_type_to_string(opts[:fusion_type])
  })

  execute_aggregate(client, agg_query)
end

defp fusion_type_to_string(nil), do: nil
defp fusion_type_to_string(:ranked), do: "rankedFusion"
defp fusion_type_to_string(:relative_score), do: "relativeScoreFusion"
```

### Step 3: Build GraphQL Query

Update query building:

```elixir
defp build_graphql_query(%{nearObject: near_obj} = query) do
  """
  {
    Aggregate {
      #{query.collection}(
        nearObject: {
          id: "#{near_obj.id}"
          #{optional_field("distance", near_obj.distance)}
          #{optional_field("certainty", near_obj.certainty)}
        }
        #{object_limit_clause(query)}
      ) {
        #{metrics_clause(query.metrics)}
      }
    }
  }
  """
end

defp build_graphql_query(%{hybrid: hybrid} = query) do
  """
  {
    Aggregate {
      #{query.collection}(
        hybrid: {
          query: "#{hybrid.query}"
          #{optional_field("alpha", hybrid.alpha)}
          #{optional_vector_field(hybrid.vector)}
          #{optional_properties_field(hybrid.properties)}
          #{optional_field("fusionType", hybrid.fusionType)}
        }
        #{object_limit_clause(query)}
      ) {
        #{metrics_clause(query.metrics)}
      }
    }
  }
  """
end
```

### Step 4: Add gRPC Support (if proto supports it)

Check if aggregate proto supports near_object and hybrid, and add gRPC implementation if available.

### Step 5: Add Metrics Helper

Create a metrics builder for cleaner API:

```elixir
defmodule WeaviateEx.Aggregate.Metrics do
  @moduledoc """
  Helper for building aggregate metrics.
  """

  @doc """
  Count metric.
  """
  def count, do: :count

  @doc """
  Text property metrics.
  """
  def text(property, opts \\ []) do
    {:text, property, opts}
  end

  @doc """
  Number property metrics.
  """
  def number(property, opts \\ []) do
    {:number, property, opts}
  end

  @doc """
  Boolean property metrics.
  """
  def boolean(property, opts \\ []) do
    {:boolean, property, opts}
  end
end
```

## Tests to Write

### near_object Tests (`test/weaviate_ex/api/aggregate_test.exs`)

```elixir
describe "near_object/4" do
  test "builds query with UUID"
  test "includes distance parameter"
  test "includes certainty parameter"
  test "includes object_limit"
  test "calculates count metrics"
  test "calculates property metrics"
  test "supports group_by"
end
```

### hybrid Tests

```elixir
describe "hybrid/4" do
  test "builds query with search term"
  test "uses default alpha of 0.5"
  test "accepts custom alpha"
  test "accepts explicit vector"
  test "accepts properties list"
  test "accepts fusion_type :ranked"
  test "accepts fusion_type :relative_score"
  test "calculates metrics correctly"
end
```

### Integration Tests

```elixir
@tag :integration
describe "aggregate near_object" do
  test "aggregates objects similar to reference" do
    # Create collection with objects
    # Get one object UUID
    # Aggregate near that object
    # Verify count > 0
  end
end

@tag :integration
describe "aggregate hybrid" do
  test "aggregates with hybrid search" do
    # Create collection with text content
    # Aggregate with hybrid query
    # Verify results
  end
end
```

## Docs Updates

### README.md

Update aggregation section:

```markdown
### Aggregation

#### Near Object Aggregation

Aggregate objects similar to a reference object:

\`\`\`elixir
alias WeaviateEx.{Aggregate, Aggregate.Metrics}

{:ok, result} = Aggregate.near_object(client, "Articles", reference_uuid,
  distance: 0.5,
  metrics: [
    Metrics.count(),
    Metrics.text("category", count: true, top_occurrences: 5)
  ]
)

IO.inspect(result.count)  # Number of similar objects
\`\`\`

#### Hybrid Aggregation

Aggregate with combined keyword and vector search:

\`\`\`elixir
{:ok, result} = Aggregate.hybrid(client, "Products", "electronics",
  alpha: 0.7,  # 70% vector, 30% keyword
  metrics: [
    Metrics.count(),
    Metrics.number("price", sum: true, mean: true, minimum: true, maximum: true)
  ]
)

IO.inspect(result.price.sum)   # Total price
IO.inspect(result.price.mean)  # Average price
\`\`\`
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- `Aggregate.near_object/4` for similarity-based aggregation
- `Aggregate.hybrid/4` for hybrid search aggregation
- `WeaviateEx.Aggregate.Metrics` helper module for metric building
- Fusion type support for hybrid aggregation (:ranked, :relative_score)
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New aggregate tests pass
- [ ] Integration tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `Aggregate.near_object/4` implemented and tested
2. `Aggregate.hybrid/4` implemented and tested
3. `Aggregate.Metrics` helper module created
4. Distance, certainty, alpha parameters work correctly
5. Fusion type option works
6. Integration tests verify real Weaviate behavior
7. All quality gates pass
