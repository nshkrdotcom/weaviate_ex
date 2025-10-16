# Collections API Example
# Run: mix run examples/01_collections.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.Collections

ExampleHelper.check_weaviate!()

ExampleHelper.section("Collections API - Schema Management")

{:ok, client} = WeaviateEx.Client.new(base_url: "http://localhost:8080")

# List collections
ExampleHelper.step("List all collections")
ExampleHelper.command("Collections.list(client)")
{:ok, collections} = Collections.list(client)
ExampleHelper.result("Collections", collections)

# Create collection
ExampleHelper.step("Create new collection")

config = %{
  "class" => "DemoArticle",
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
ExampleHelper.command(~s/Collections.get(client, "DemoArticle")/)
{:ok, collection} = Collections.get(client, "DemoArticle")

ExampleHelper.success(
  "Retrieved #{collection["class"]} with #{length(collection["properties"])} properties"
)

# Add property
ExampleHelper.step("Add new property to collection")

property = %{"name" => "publishedAt", "dataType" => ["date"]}
ExampleHelper.command("Collections.add_property(client, \"DemoArticle\", property)")
{:ok, added} = Collections.add_property(client, "DemoArticle", property)
ExampleHelper.result("Added Property", added)

# Check existence
ExampleHelper.step("Check if collection exists")
ExampleHelper.command(~s/Collections.exists?(client, "DemoArticle")/)
{:ok, true} = Collections.exists?(client, "DemoArticle")
ExampleHelper.success("Collection exists")

# Delete collection
ExampleHelper.step("Delete collection")
ExampleHelper.command(~s/Collections.delete(client, "DemoArticle")/)
{:ok, _} = Collections.delete(client, "DemoArticle")
ExampleHelper.success("Deleted DemoArticle")

IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
