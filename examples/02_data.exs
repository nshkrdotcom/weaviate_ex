# Data Operations Example
# Run: mix run examples/02_data.exs

unless Code.ensure_loaded?(WeaviateEx) do
  Mix.install([{:weaviate_ex, path: "."}])
end

Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, Data}

ExampleHelper.check_weaviate!()

ExampleHelper.section("Data Operations - CRUD")

client = ExampleHelper.client!()
class_name = ExampleHelper.unique_class("Article")
ExampleHelper.reset_collection!(client, class_name)

# Setup
Collections.create(client, %{
  "class" => class_name,
  "vectorizer" => "none",
  "properties" => [
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "content", "dataType" => ["text"]},
    %{"name" => "views", "dataType" => ["int"]}
  ]
})

# Create (Insert)
ExampleHelper.step("Insert new object")

data = %{
  properties: %{
    "title" => "Hello Weaviate",
    "content" => "This is a test article",
    "views" => 0
  },
  vector: [0.1, 0.2, 0.3, 0.4, 0.5]
}

ExampleHelper.command(~s/Data.insert(client, "#{class_name}", data)/)
{:ok, object} = Data.insert(client, class_name, data)
uuid = object["id"]
ExampleHelper.result("Created", %{id: uuid, properties: object["properties"]})

# Read
ExampleHelper.step("Get object by ID")
ExampleHelper.command(~s/Data.get_by_id(client, "#{class_name}", uuid)/)
{:ok, retrieved} = Data.get_by_id(client, class_name, uuid)
ExampleHelper.success("Retrieved: #{retrieved["properties"]["title"]}")

# Update (Patch)
ExampleHelper.step("Update object (partial)")

patch_data = %{properties: %{"views" => 42}, vector: [0.1, 0.2, 0.3, 0.4, 0.5]}
ExampleHelper.command(~s/Data.patch(client, "#{class_name}", uuid, patch_data)/)
{:ok, updated} = Data.patch(client, class_name, uuid, patch_data)
ExampleHelper.result("Updated", %{views: updated["properties"]["views"]})

# Check Existence
ExampleHelper.step("Check if object exists")
ExampleHelper.command(~s/Data.exists?(client, "#{class_name}", uuid)/)
{:ok, true} = Data.exists?(client, class_name, uuid)
ExampleHelper.success("Object exists")

# Delete
ExampleHelper.step("Delete object")
ExampleHelper.command(~s/Data.delete_by_id(client, "#{class_name}", uuid)/)
{:ok, _} = Data.delete_by_id(client, class_name, uuid)
ExampleHelper.success("Deleted object")

ExampleHelper.cleanup(client, class_name)
IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
