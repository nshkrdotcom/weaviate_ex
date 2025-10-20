# Batch Operations Example
# Run: mix run examples/07_batch.exs

unless Code.ensure_loaded?(WeaviateEx) do
  Mix.install([{:weaviate_ex, path: "."}])
end

Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Batch, Collections}
alias WeaviateEx.Query

ExampleHelper.check_weaviate!()
ExampleHelper.section("Batch API - Bulk Create & Delete")

client = ExampleHelper.client!()
class_name = ExampleHelper.unique_class("BatchArticle")
ExampleHelper.reset_collection!(client, class_name)

# Prepare schema
Collections.create(client, %{
  "class" => class_name,
  "vectorizer" => "none",
  "properties" => [
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "category", "dataType" => ["text"]},
    %{"name" => "priority", "dataType" => ["int"]}
  ]
})

# Batch insert
ExampleHelper.step("Batch insert three objects with summary")

objects =
  Enum.map(1..3, fn idx ->
    %{
      "class" => class_name,
      "properties" => %{
        "title" => "Batch item #{idx}",
        "category" => if(idx <= 2, do: "news", else: "archive"),
        "priority" => idx
      },
      "vector" => Enum.map(1..5, fn n -> idx * n / 10 end)
    }
  end)

ExampleHelper.command("Batch.create_objects(client, objects, wait_for_completion: true)")

{:ok, response} = Batch.create_objects(client, objects, wait_for_completion: true)

results = Map.get(response, "results", [])

success_count =
  Enum.count(results, fn
    %{"result" => %{"status" => status}} -> String.upcase(status) == "SUCCESS"
    _ -> false
  end)

error_details =
  results
  |> Enum.filter(fn
    %{"result" => %{"status" => status}} -> String.upcase(status) != "SUCCESS"
    _ -> true
  end)
  |> Enum.map(fn result ->
    %{
      id: result["id"] || result["uuid"],
      status: get_in(result, ["result", "status"]),
      errors: get_in(result, ["result", "errors"]) || []
    }
  end)

ExampleHelper.result("Batch Response", %{
  processed: length(results),
  successful: success_count,
  failed: length(error_details)
})

if error_details != [] do
  ExampleHelper.result("Failures", error_details)
end

# Confirm total objects
query_all =
  Query.get(class_name)
  |> Query.fields(["title", "category", "priority"])
  |> Query.limit(10)

{:ok, all_objects} = Query.execute(query_all)
ExampleHelper.result("Current Objects", all_objects)
ExampleHelper.success("Total objects after batch insert: #{length(all_objects)}")

# Batch delete by criteria
ExampleHelper.step("Batch delete using match filter")

match_payload = %{
  "class" => class_name,
  "where" => %{
    "path" => ["category"],
    "operator" => "Equal",
    "valueText" => "archive"
  }
}

ExampleHelper.command("Batch.delete_objects(client, match_payload)")
{:ok, delete_result} = Batch.delete_objects(client, match_payload, wait_for_completion: true)
ExampleHelper.result("Delete Result", delete_result)

# Verify remaining objects
{:ok, remaining} = Query.execute(query_all)

ExampleHelper.result(
  "Remaining Objects",
  Enum.map(remaining, &Map.take(&1, ["title", "category", "priority"]))
)

ExampleHelper.cleanup(client, class_name)
IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
