# Filter System Example
# Run: mix run examples/03_filter.exs

unless Code.ensure_loaded?(WeaviateEx) do
  Mix.install([{:weaviate_ex, path: "."}])
end

Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.Filter

ExampleHelper.section("Filter System - Query Filters")

# Simple equality filter
ExampleHelper.step("Create equality filter")
ExampleHelper.command(~s/Filter.equal("status", "published")/)
filter1 = Filter.equal("status", "published")
ExampleHelper.result("Filter", filter1)

# Numeric comparison
ExampleHelper.step("Create numeric comparison filter")
ExampleHelper.command("Filter.greater_than(\"views\", 100)")
filter2 = Filter.greater_than("views", 100)
ExampleHelper.result("Filter", filter2)

# Text pattern matching
ExampleHelper.step("Create LIKE filter")
ExampleHelper.command(~s/Filter.like("title", "*AI*")/)
filter3 = Filter.like("title", "*AI*")
ExampleHelper.result("Filter", filter3)

# Array filters
ExampleHelper.step("Create array filter")
ExampleHelper.command(~s/Filter.contains_any("tags", ["elixir", "phoenix"])/)
filter4 = Filter.contains_any("tags", ["elixir", "phoenix"])
ExampleHelper.result("Filter", filter4)

# Geo filter
ExampleHelper.step("Create geospatial filter")
ExampleHelper.command("Filter.within_geo_range(\"location\", {40.7128, -74.0060}, 5000.0)")
filter5 = Filter.within_geo_range("location", {40.7128, -74.0060}, 5000.0)
ExampleHelper.result("Filter", filter5)

# Combined filters (AND)
ExampleHelper.step("Combine filters with AND")

combined =
  Filter.all_of([
    Filter.equal("status", "published"),
    Filter.greater_than("views", 100)
  ])

ExampleHelper.command("Filter.all_of([filter1, filter2])")
ExampleHelper.result("Combined Filter", combined)

# Combined filters (OR)
ExampleHelper.step("Combine filters with OR")

or_filter =
  Filter.any_of([
    Filter.equal("category", "tech"),
    Filter.equal("category", "science")
  ])

ExampleHelper.command("Filter.any_of([...])")
ExampleHelper.result("OR Filter", or_filter)

# Convert to GraphQL
ExampleHelper.step("Convert filter to GraphQL format")
ExampleHelper.command("Filter.to_graphql(combined)")
graphql = Filter.to_graphql(combined)
ExampleHelper.result("GraphQL", graphql)

IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
