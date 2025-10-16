# Aggregation Example
# Run: mix run examples/04_aggregate.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, Data, Aggregate}

ExampleHelper.check_weaviate!()

ExampleHelper.section("Aggregation API - Statistics")

{:ok, client} = WeaviateEx.Client.new(base_url: "http://localhost:8080")

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
ExampleHelper.step("Count all products")
ExampleHelper.command("Aggregate.over_all(client, \"Product\", metrics: [:count])")
{:ok, result} = Aggregate.over_all(client, "Product", metrics: [:count])
ExampleHelper.result("Count", result)

# Numeric aggregations
ExampleHelper.step("Aggregate price statistics")

ExampleHelper.command(
  "Aggregate.over_all(client, \"Product\", properties: [{:price, [:mean, :sum, :maximum, :minimum]}])"
)

{:ok, stats} =
  Aggregate.over_all(client, "Product",
    properties: [{:price, [:mean, :sum, :maximum, :minimum, :count]}]
  )

ExampleHelper.result("Price Stats", stats)

# Top occurrences
ExampleHelper.step("Get top categories")

ExampleHelper.command(
  "Aggregate.over_all(client, \"Product\", properties: [{:category, [:topOccurrences], limit: 10}])"
)

{:ok, categories} =
  Aggregate.over_all(client, "Product", properties: [{:category, [:topOccurrences], limit: 10}])

ExampleHelper.result("Top Categories", categories)

# Group by
ExampleHelper.step("Aggregate by category")

ExampleHelper.command(
  "Aggregate.group_by(client, \"Product\", \"category\", metrics: [:count], properties: [{:price, [:mean]}])"
)

{:ok, grouped} =
  Aggregate.group_by(client, "Product", "category",
    metrics: [:count],
    properties: [{:price, [:mean]}]
  )

ExampleHelper.result("Grouped Results", grouped)

ExampleHelper.cleanup(client, "Product")
IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
