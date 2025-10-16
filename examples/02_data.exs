# Data Operations Example
# Run: mix run examples/02_data.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, Data}
import ExampleHelper

ExampleHelper.check_weaviate!()

section("Data Operations - CRUD")

{:ok, client} = WeaviateEx.Client.new("http://localhost:8080")

# Setup
Collections.create(client, %{
  "class" => "Article",
  "vectorizer" => "none",
  "properties" => [
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "content", "dataType" => ["text"]},
    %{"name" => "views", "dataType" => ["int"]}
  ]
})

# Create (Insert)
step("Insert new object")

data = %{
  properties: %{
    "title" => "Hello Weaviate",
    "content" => "This is a test article",
    "views" => 0
  }
}

command("Data.insert(client, \"Article\", data)")
{:ok, object} = Data.insert(client, "Article", data)
uuid = object["id"]
result("Created", %{id: uuid, properties: object["properties"]})

# Read
step("Get object by ID")
command(~s/Data.get_by_id(client, "Article", uuid)/)
{:ok, retrieved} = Data.get_by_id(client, "Article", uuid)
success("Retrieved: #{retrieved["properties"]["title"]}")

# Update (Patch)
step("Update object (partial)")

patch_data = %{properties: %{"views" => 42}}
command("Data.patch(client, \"Article\", uuid, patch_data)")
{:ok, updated} = Data.patch(client, "Article", uuid, patch_data)
result("Updated", %{views: updated["properties"]["views"]})

# Check Existence
step("Check if object exists")
command(~s/Data.exists?(client, "Article", uuid)/)
{:ok, true} = Data.exists?(client, "Article", uuid)
success("Object exists")

# Delete
step("Delete object")
command(~s/Data.delete_by_id(client, "Article", uuid)/)
{:ok, _} = Data.delete_by_id(client, "Article", uuid)
success("Deleted object")

cleanup(client, "Article")
IO.puts("\n#{green("✓")} Example complete!\n")
