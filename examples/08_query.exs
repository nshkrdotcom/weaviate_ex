# Query Builder Example
# Run: mix run examples/08_query.exs

unless Code.ensure_loaded?(WeaviateEx) do
  Mix.install([{:weaviate_ex, path: "."}])
end

Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, Data}
alias WeaviateEx.{Filter, Query}

ExampleHelper.check_weaviate!()
ExampleHelper.section("Query Builder - BM25, Filters, Near Vector")

client = ExampleHelper.client!()
class_name = ExampleHelper.unique_class("SearchArticle")
ExampleHelper.reset_collection!(client, class_name)

# Schema setup
Collections.create(client, %{
  "class" => class_name,
  "vectorizer" => "none",
  "properties" => [
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "content", "dataType" => ["text"]},
    %{"name" => "category", "dataType" => ["text"]},
    %{"name" => "popularity", "dataType" => ["int"]}
  ]
})

# Seed data with custom vectors
vectors = [
  [0.1, 0.2, 0.3, 0.4, 0.5],
  [0.15, 0.25, 0.35, 0.45, 0.55],
  [0.9, 0.1, 0.2, 0.05, 0.4]
]

articles = [
  %{
    properties: %{
      "title" => "Elixir pipelines for data science",
      "content" => "Learn how to use Elixir for data engineering and analytics.",
      "category" => "tech",
      "popularity" => 5
    },
    vector: Enum.at(vectors, 0)
  },
  %{
    properties: %{
      "title" => "Vector databases in production",
      "content" => "Discussion of Weaviate, Pinecone, and best practices.",
      "category" => "tech",
      "popularity" => 10
    },
    vector: Enum.at(vectors, 1)
  },
  %{
    properties: %{
      "title" => "Cooking with seasonal vegetables",
      "content" => "Healthy recipes with locally sourced ingredients.",
      "category" => "lifestyle",
      "popularity" => 3
    },
    vector: Enum.at(vectors, 2)
  }
]

Enum.each(articles, &Data.insert(client, class_name, &1))

# BM25 keyword search
ExampleHelper.step("BM25 keyword search (\"vector\") with field selection")

bm25_query =
  Query.get(class_name)
  |> Query.fields(["title", "category"])
  |> Query.limit(5)
  |> Query.bm25("vector", properties: ["title", "content"])

ExampleHelper.command("Query.get(...).bm25(\"vector\", properties: [\"title\", \"content\"])")
{:ok, bm25_results} = Query.execute(bm25_query)
ExampleHelper.result("BM25 Results", bm25_results)

# Filtered search with additional metadata
ExampleHelper.step("Filter by category and fetch additional fields")

filter =
  Filter.equal("category", "tech")
  |> Filter.to_graphql()

filtered_query =
  Query.get(class_name)
  |> Query.fields(["title", "popularity"])
  |> Query.where(filter)
  |> Query.additional(["id"])
  |> Query.limit(10)

ExampleHelper.command("Query.get(...).where(Filter.to_graphql(...))")
{:ok, filtered_results} = Query.execute(filtered_query)
ExampleHelper.result("Filtered Results", filtered_results)

# Vector similarity search
ExampleHelper.step("Near vector search using stored embedding")

vector_query =
  Query.get(class_name)
  |> Query.fields(["title", "category"])
  |> Query.near_vector(Enum.at(vectors, 0), certainty: 0.6)
  |> Query.limit(3)
  |> Query.additional(["distance"])

ExampleHelper.command("Query.get(...).near_vector([..], certainty: 0.6)")
{:ok, vector_results} = Query.execute(vector_query)
ExampleHelper.result("Near Vector Results", vector_results)

ExampleHelper.cleanup(client, class_name)
IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
