# Aggregation Example
# Run: mix run examples/04_aggregate.exs

unless Code.ensure_loaded?(WeaviateEx) do
  Mix.install([{:weaviate_ex, path: "."}])
end

Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, Data, Aggregate}

ExampleHelper.check_weaviate!()

ExampleHelper.section("Aggregation API - Statistics")

client = ExampleHelper.client!()
class_name = ExampleHelper.unique_class("Product")
ExampleHelper.reset_collection!(client, class_name)

# Setup collection with data
Collections.create(client, %{
  "class" => class_name,
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

Enum.each(products, &Data.insert(client, class_name, &1))

# Count all
ExampleHelper.step("Count all products")
ExampleHelper.command(~s/Aggregate.over_all(client, "#{class_name}", metrics: [:count])/)
{:ok, result} = Aggregate.over_all(client, class_name, metrics: [:count])
ExampleHelper.result("Count", result)

# Numeric aggregations
ExampleHelper.step("Aggregate price statistics")

ExampleHelper.command(
  ~s/Aggregate.over_all(client, "#{class_name}", properties: [{:price, [:mean, :sum, :maximum, :minimum]}])/
)

{:ok, stats} =
  Aggregate.over_all(client, class_name,
    properties: [{:price, [:mean, :sum, :maximum, :minimum, :count]}]
  )

ExampleHelper.result("Price Stats", stats)

# Top occurrences
ExampleHelper.step("Get top categories")

ExampleHelper.command(
  ~s/Aggregate.over_all(client, "#{class_name}", properties: [{:category, [:topOccurrences], limit: 10}])/
)

{:ok, categories} =
  Aggregate.over_all(client, class_name, properties: [{:category, [:topOccurrences], limit: 10}])

ExampleHelper.result("Top Categories", categories)

# Group by
ExampleHelper.step("Aggregate by category")

ExampleHelper.command(
  ~s/Aggregate.group_by(client, "#{class_name}", "category", metrics: [:count], properties: [{:price, [:mean]}])/
)

{:ok, grouped} =
  Aggregate.group_by(client, class_name, "category",
    metrics: [:count],
    properties: [{:price, [:mean]}]
  )

ExampleHelper.result("Grouped Results", grouped)

ExampleHelper.cleanup(client, class_name)
IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
