# Collections API Example
# Run: mix run examples/01_collections.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.Collections
import ExampleHelper

ExampleHelper.check_weaviate!()

section("Collections API - Schema Management")

{:ok, client} = WeaviateEx.Client.new("http://localhost:8080")

# List collections
step("List all collections")
command("Collections.list(client)")
{:ok, collections} = Collections.list(client)
result("Collections", collections)

# Create collection
step("Create new collection")

config = %{
  "class" => "DemoArticle",
  "vectorizer" => "none",
  "properties" => [
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "content", "dataType" => ["text"]},
    %{"name" => "views", "dataType" => ["int"]}
  ]
}

command("Collections.create(client, config)")
{:ok, created} = Collections.create(client, config)
result("Created", Map.take(created, ["class", "properties"]))

# Get collection
step("Get collection details")
command(~s/Collections.get(client, "DemoArticle")/)
{:ok, collection} = Collections.get(client, "DemoArticle")
success("Retrieved #{collection["class"]} with #{length(collection["properties"])} properties")

# Add property
step("Add new property to collection")

property = %{"name" => "publishedAt", "dataType" => ["date"]}
command("Collections.add_property(client, \"DemoArticle\", property)")
{:ok, added} = Collections.add_property(client, "DemoArticle", property)
result("Added Property", added)

# Check existence
step("Check if collection exists")
command(~s/Collections.exists?(client, "DemoArticle")/)
{:ok, true} = Collections.exists?(client, "DemoArticle")
success("Collection exists")

# Delete collection
step("Delete collection")
command(~s/Collections.delete(client, "DemoArticle")/)
{:ok, _} = Collections.delete(client, "DemoArticle")
success("Deleted DemoArticle")

IO.puts("\n#{green("✓")} Example complete!\n")
