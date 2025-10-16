# Aggregation Example
# Run: mix run examples/04_aggregate.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, Data, Aggregate}
import ExampleHelper

ExampleHelper.check_weaviate!()

section("Aggregation API - Statistics")

{:ok, client} = WeaviateEx.Client.new("http://localhost:8080")

# Setup collection with data
Collections.create(client, %{
  "class" => "Product",
  "vectorizer" => "none",
  "properties" => [
    %{"name" => "name", "dataType" => ["text"]},
    %{"name" => "price", "dataType" => ["number"]},
    %{"name" => "category", "dataType" => ["text"]},
    %{"name" => "inStock", "dataType" => ["boolean"]}
  ]
})

# Insert sample data
products = [
  %{
    properties: %{
      "name" => "Laptop",
      "price" => 999.99,
      "category" => "electronics",
      "inStock" => true
    }
  },
  %{
    properties: %{
      "name" => "Mouse",
      "price" => 29.99,
      "category" => "electronics",
      "inStock" => true
    }
  },
  %{
    properties: %{
      "name" => "Desk",
      "price" => 299.99,
      "category" => "furniture",
      "inStock" => false
    }
  },
  %{
    properties: %{
      "name" => "Chair",
      "price" => 199.99,
      "category" => "furniture",
      "inStock" => true
    }
  }
]

Enum.each(products, &Data.insert(client, "Product", &1))

# Count all
step("Count all products")
command("Aggregate.over_all(client, \"Product\", metrics: [:count])")
{:ok, result} = Aggregate.over_all(client, "Product", metrics: [:count])
result("Count", result)

# Numeric aggregations
step("Aggregate price statistics")

command(
  "Aggregate.over_all(client, \"Product\", properties: [{:price, [:mean, :sum, :maximum, :minimum]}])"
)

{:ok, stats} =
  Aggregate.over_all(client, "Product",
    properties: [{:price, [:mean, :sum, :maximum, :minimum, :count]}]
  )

result("Price Stats", stats)

# Top occurrences
step("Get top categories")

command(
  "Aggregate.over_all(client, \"Product\", properties: [{:category, [:topOccurrences], limit: 10}])"
)

{:ok, categories} =
  Aggregate.over_all(client, "Product", properties: [{:category, [:topOccurrences], limit: 10}])

result("Top Categories", categories)

# Group by
step("Aggregate by category")

command(
  "Aggregate.group_by(client, \"Product\", \"category\", metrics: [:count], properties: [{:price, [:mean]}])"
)

{:ok, grouped} =
  Aggregate.group_by(client, "Product", "category",
    metrics: [:count],
    properties: [{:price, [:mean]}]
  )

result("Grouped Results", grouped)

cleanup(client, "Product")
IO.puts("\n#{green("✓")} Example complete!\n")
