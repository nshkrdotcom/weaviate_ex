# Collections API Example
# Run: mix run examples/01_collections.exs

unless Code.ensure_loaded?(WeaviateEx) do
  Mix.install([{:weaviate_ex, path: "."}])
end

Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.Collections

ExampleHelper.check_weaviate!()

ExampleHelper.section("Collections API - Schema Management")

client = ExampleHelper.client!()
class_name = ExampleHelper.unique_class("DemoArticle")
ExampleHelper.reset_collection!(client, class_name)

# List collections
ExampleHelper.step("List all collections")
ExampleHelper.command("Collections.list(client)")
{:ok, collections} = Collections.list(client)
ExampleHelper.result("Collections", collections)

# Create collection
ExampleHelper.step("Create new collection")

config = %{
  "class" => class_name,
  "vectorizer" => "none",
  "properties" => [
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "content", "dataType" => ["text"]},
    %{"name" => "views", "dataType" => ["int"]}
  ]
}

ExampleHelper.command("Collections.create(client, config)")
{:ok, created} = Collections.create(client, config)
ExampleHelper.result("Created", Map.take(created, ["class", "properties"]))

# Get collection
ExampleHelper.step("Get collection details")
ExampleHelper.command(~s/Collections.get(client, "#{class_name}")/)
{:ok, collection} = Collections.get(client, class_name)

ExampleHelper.success(
  "Retrieved #{collection["class"]} with #{length(collection["properties"])} properties"
)

# Add property
ExampleHelper.step("Add new property to collection")

property = %{"name" => "publishedAt", "dataType" => ["date"]}
ExampleHelper.command(~s/Collections.add_property(client, "#{class_name}", property)/)
{:ok, added} = Collections.add_property(client, class_name, property)
ExampleHelper.result("Added Property", added)

# Check existence
ExampleHelper.step("Check if collection exists")
ExampleHelper.command(~s/Collections.exists?(client, "#{class_name}")/)
{:ok, true} = Collections.exists?(client, class_name)
ExampleHelper.success("Collection exists")

# Delete collection
ExampleHelper.step("Delete collection")
ExampleHelper.command(~s/Collections.delete(client, "#{class_name}")/)
{:ok, _} = Collections.delete(client, class_name)
ExampleHelper.success("Deleted #{class_name}")

IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
