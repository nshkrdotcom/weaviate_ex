# Queries Guide

This guide covers searching and querying data in Weaviate using WeaviateEx. Weaviate supports multiple search types including keyword search (BM25), vector similarity search, and hybrid search.

## Overview

WeaviateEx provides the `WeaviateEx.Query` module for building GraphQL queries with a fluent interface:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title", "content"])
  |> WeaviateEx.Query.limit(10)

{:ok, results} = WeaviateEx.Query.execute(query)
```

## Execution Modes (gRPC vs GraphQL)

When you pass a `WeaviateEx.Client`, `Query.execute/2` uses gRPC for supported
features (filters, group_by, target vectors, near_image/near_media, references,
and vector metadata). If you use options not yet supported in gRPC (for example
`rerank`, sorting, cursor pagination, or hybrid vectors), it automatically falls
back to GraphQL. Calling `Query.execute/1` without a client always uses GraphQL.

## Basic Queries

### Fetch Objects

Retrieve objects with specific fields:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title", "content", "author"])
  |> WeaviateEx.Query.limit(10)

{:ok, articles} = WeaviateEx.Query.execute(query)

Enum.each(articles, fn article ->
  IO.puts("#{article["title"]} by #{article["author"]}")
end)
```

### Fetch Objects by IDs

Fetch multiple objects by UUIDs (results preserve input order):

```elixir
alias WeaviateEx.API.Data

ids = [
  "550e8400-e29b-41d4-a716-446655440001",
  "550e8400-e29b-41d4-a716-446655440002"
]

{:ok, objects} =
  Data.fetch_objects_by_ids(client, "Article", ids,
    return_properties: ["title", "content"]
  )
```

### Pagination

Use `limit` and `offset` for pagination:

```elixir
# First page
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.limit(10)
  |> WeaviateEx.Query.offset(0)

# Second page
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.limit(10)
  |> WeaviateEx.Query.offset(10)
```

### Additional Metadata

Request additional metadata about objects:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.additional(["id", "creationTimeUnix", "lastUpdateTimeUnix"])
  |> WeaviateEx.Query.limit(5)

{:ok, results} = WeaviateEx.Query.execute(query)

Enum.each(results, fn article ->
  additional = article["_additional"]
  IO.puts("ID: #{additional["id"]}")
  IO.puts("Created: #{additional["creationTimeUnix"]}")
end)
```

Available additional fields:
- `id` - Object UUID
- `vector` - Object's vector embedding
- `creationTimeUnix` - Creation timestamp
- `lastUpdateTimeUnix` - Last update timestamp
- `distance` - Distance from query (vector search)
- `certainty` - Certainty score (vector search)
- `score` - BM25 or hybrid score
- `explainScore` - Score explanation

## BM25 Keyword Search

BM25 (Best Match 25) is a keyword-based search algorithm:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.bm25("machine learning")
  |> WeaviateEx.Query.fields(["title", "content"])
  |> WeaviateEx.Query.additional(["score"])
  |> WeaviateEx.Query.limit(10)

{:ok, results} = WeaviateEx.Query.execute(query)

Enum.each(results, fn article ->
  IO.puts("#{article["title"]} (score: #{article["_additional"]["score"]})")
end)
```

### BM25 with Property Boosting

Search specific properties:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.bm25("AI safety", properties: ["title^2", "content"])
  |> WeaviateEx.Query.fields(["title", "content"])
  |> WeaviateEx.Query.limit(10)
```

The `^2` syntax boosts the title property by a factor of 2.

## Vector Similarity Search

### Near Text (Semantic Search)

Search using natural language, vectorized by your configured vectorizer:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_text("artificial intelligence applications", certainty: 0.7)
  |> WeaviateEx.Query.fields(["title", "content"])
  |> WeaviateEx.Query.additional(["certainty", "distance"])
  |> WeaviateEx.Query.limit(5)

{:ok, results} = WeaviateEx.Query.execute(query)

Enum.each(results, fn article ->
  IO.puts("#{article["title"]}")
  IO.puts("  Certainty: #{article["_additional"]["certainty"]}")
  IO.puts("  Distance: #{article["_additional"]["distance"]}")
end)
```

### Near Text with Distance

Use `distance` instead of `certainty`:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_text("machine learning tutorials", distance: 0.3)
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.limit(10)
```

### Near Vector

Search with a pre-computed vector:

```elixir
# Your query vector (e.g., from external embedding API)
query_vector = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]

query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_vector(query_vector, certainty: 0.8)
  |> WeaviateEx.Query.fields(["title", "content"])
  |> WeaviateEx.Query.additional(["distance"])
  |> WeaviateEx.Query.limit(5)

{:ok, results} = WeaviateEx.Query.execute(query)
```

### Near Object

Find objects similar to an existing object:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_object("550e8400-e29b-41d4-a716-446655440000", certainty: 0.7)
  |> WeaviateEx.Query.fields(["title", "content"])
  |> WeaviateEx.Query.additional(["distance"])
  |> WeaviateEx.Query.limit(5)

{:ok, similar_articles} = WeaviateEx.Query.execute(query)
```

## Hybrid Search

Hybrid search combines keyword (BM25) and vector search:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.hybrid("machine learning", alpha: 0.5)
  |> WeaviateEx.Query.fields(["title", "content"])
  |> WeaviateEx.Query.additional(["score"])
  |> WeaviateEx.Query.limit(10)

{:ok, results} = WeaviateEx.Query.execute(query)
```

### Alpha Parameter

The `alpha` parameter controls the balance:
- `alpha: 0.0` - Pure keyword search (BM25)
- `alpha: 0.5` - Equal weight to both
- `alpha: 1.0` - Pure vector search

```elixir
# Favor vector search
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.hybrid("neural networks", alpha: 0.75)
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.limit(10)

# Favor keyword search
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.hybrid("API documentation", alpha: 0.25)
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.limit(10)
```

### Fusion Type

Choose the fusion algorithm for combining results:

```elixir
# Ranked fusion (default)
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.hybrid("data science",
       alpha: 0.5,
       fusion_type: "rankedFusion"
     )
  |> WeaviateEx.Query.fields(["title"])

# Relative score fusion
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.hybrid("data science",
       alpha: 0.5,
       fusion_type: "relativeScoreFusion"
     )
  |> WeaviateEx.Query.fields(["title"])
```

## Filters

Use `where` clauses to filter results:

### Simple Filter

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title", "author"])
  |> WeaviateEx.Query.where(%{
    path: ["author"],
    operator: "Equal",
    valueText: "Jane Smith"
  })
  |> WeaviateEx.Query.limit(10)

{:ok, results} = WeaviateEx.Query.execute(query)
```

### Filter Operators

| Operator | Description | Value Types |
|----------|-------------|-------------|
| `Equal` | Exact match | All |
| `NotEqual` | Not equal | All |
| `GreaterThan` | Greater than | int, number, date |
| `GreaterThanEqual` | Greater than or equal | int, number, date |
| `LessThan` | Less than | int, number, date |
| `LessThanEqual` | Less than or equal | int, number, date |
| `Like` | Wildcard match | text |
| `ContainsAny` | Contains any of values | text[], int[], etc. |
| `ContainsAll` | Contains all values | text[], int[], etc. |
| `IsNull` | Is null check | All |

### Numeric Filter

```elixir
query = WeaviateEx.Query.get("Product")
  |> WeaviateEx.Query.fields(["name", "price"])
  |> WeaviateEx.Query.where(%{
    path: ["price"],
    operator: "LessThan",
    valueNumber: 100.0
  })
  |> WeaviateEx.Query.limit(20)
```

### Date Filter

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title", "publishedAt"])
  |> WeaviateEx.Query.where(%{
    path: ["publishedAt"],
    operator: "GreaterThan",
    valueDate: "2024-01-01T00:00:00Z"
  })
  |> WeaviateEx.Query.limit(10)
```

### Wildcard Filter (Like)

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.where(%{
    path: ["title"],
    operator: "Like",
    valueText: "*Elixir*"  # Contains "Elixir"
  })
  |> WeaviateEx.Query.limit(10)
```

### Compound Filters (And/Or)

```elixir
# AND filter
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title", "author", "category"])
  |> WeaviateEx.Query.where(%{
    operator: "And",
    operands: [
      %{path: ["author"], operator: "Equal", valueText: "Jane Smith"},
      %{path: ["category"], operator: "Equal", valueText: "Technology"}
    ]
  })
  |> WeaviateEx.Query.limit(10)

# OR filter
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title", "category"])
  |> WeaviateEx.Query.where(%{
    operator: "Or",
    operands: [
      %{path: ["category"], operator: "Equal", valueText: "Science"},
      %{path: ["category"], operator: "Equal", valueText: "Technology"}
    ]
  })
  |> WeaviateEx.Query.limit(10)
```

### Nested Compound Filters

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.where(%{
    operator: "And",
    operands: [
      %{path: ["status"], operator: "Equal", valueText: "published"},
      %{
        operator: "Or",
        operands: [
          %{path: ["category"], operator: "Equal", valueText: "Tech"},
          %{path: ["category"], operator: "Equal", valueText: "Science"}
        ]
      }
    ]
  })
  |> WeaviateEx.Query.limit(10)
```

### Filter with Vector Search

Combine filters with semantic search:

```elixir
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_text("machine learning", certainty: 0.7)
  |> WeaviateEx.Query.where(%{
    path: ["author"],
    operator: "Equal",
    valueText: "Jane Smith"
  })
  |> WeaviateEx.Query.fields(["title", "content"])
  |> WeaviateEx.Query.additional(["certainty"])
  |> WeaviateEx.Query.limit(5)

{:ok, results} = WeaviateEx.Query.execute(query)
```

## Reference Queries

Query objects and their references:

```elixir
# Assuming Article has a reference to Author
query = """
{
  Get {
    Article(limit: 10) {
      title
      hasAuthor {
        ... on Author {
          name
          email
        }
      }
    }
  }
}
"""

{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url())
{:ok, response} = WeaviateEx.Client.request(client, :post, "/v1/graphql", %{query: query})
```

## Multi-tenant Queries

Query within a specific tenant:

```elixir
# Using raw GraphQL with tenant header
{:ok, client} = WeaviateEx.Client.new(
  base_url: WeaviateEx.base_url(),
  headers: [{"X-Weaviate-Tenant", "tenant-a"}]
)

query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.fields(["title"])
  |> WeaviateEx.Query.limit(10)

# Build and execute with tenant context
# Note: Tenant support in Query module may require tenant parameter
```

## Complete Example

Here's a comprehensive search example:

```elixir
defmodule ArticleSearch do
  def search(search_term, opts \\ []) do
    author = Keyword.get(opts, :author)
    category = Keyword.get(opts, :category)
    limit = Keyword.get(opts, :limit, 10)
    search_type = Keyword.get(opts, :search_type, :hybrid)

    query = WeaviateEx.Query.get("Article")
      |> WeaviateEx.Query.fields(["title", "content", "author", "category", "publishedAt"])
      |> WeaviateEx.Query.additional(["id", "score", "certainty"])
      |> WeaviateEx.Query.limit(limit)

    # Add search based on type
    query = case search_type do
      :hybrid -> WeaviateEx.Query.hybrid(query, search_term, alpha: 0.5)
      :semantic -> WeaviateEx.Query.near_text(query, search_term, certainty: 0.7)
      :keyword -> WeaviateEx.Query.bm25(query, search_term)
    end

    # Add filters
    query = add_filters(query, author, category)

    WeaviateEx.Query.execute(query)
  end

  defp add_filters(query, nil, nil), do: query

  defp add_filters(query, author, nil) do
    WeaviateEx.Query.where(query, %{
      path: ["author"],
      operator: "Equal",
      valueText: author
    })
  end

  defp add_filters(query, nil, category) do
    WeaviateEx.Query.where(query, %{
      path: ["category"],
      operator: "Equal",
      valueText: category
    })
  end

  defp add_filters(query, author, category) do
    WeaviateEx.Query.where(query, %{
      operator: "And",
      operands: [
        %{path: ["author"], operator: "Equal", valueText: author},
        %{path: ["category"], operator: "Equal", valueText: category}
      ]
    })
  end
end

# Usage
{:ok, results} = ArticleSearch.search("machine learning",
  author: "Jane Smith",
  category: "Technology",
  search_type: :hybrid,
  limit: 5
)

Enum.each(results, fn article ->
  IO.puts("#{article["title"]} (score: #{article["_additional"]["score"]})")
end)
```

## Next Steps

- [Generative Search Guide](generative_search.md) - RAG with AI providers
- [References Guide](references.md) - Query cross-references
- [Collections Guide](collections.md) - Configure search settings
