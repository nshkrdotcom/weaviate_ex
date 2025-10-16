# Filter System Example
# Run: mix run examples/03_filter.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.Filter
import ExampleHelper

section("Filter System - Query Filters")

# Simple equality filter
step("Create equality filter")
command(~s/Filter.equal("status", "published")/)
filter1 = Filter.equal("status", "published")
result("Filter", filter1)

# Numeric comparison
step("Create numeric comparison filter")
command("Filter.greater_than(\"views\", 100)")
filter2 = Filter.greater_than("views", 100)
result("Filter", filter2)

# Text pattern matching
step("Create LIKE filter")
command(~s/Filter.like("title", "*AI*")/)
filter3 = Filter.like("title", "*AI*")
result("Filter", filter3)

# Array filters
step("Create array filter")
command(~s/Filter.contains_any("tags", ["elixir", "phoenix"])/)
filter4 = Filter.contains_any("tags", ["elixir", "phoenix"])
result("Filter", filter4)

# Geo filter
step("Create geospatial filter")
command("Filter.within_geo_range(\"location\", {40.7128, -74.0060}, 5000.0)")
filter5 = Filter.within_geo_range("location", {40.7128, -74.0060}, 5000.0)
result("Filter", filter5)

# Combined filters (AND)
step("Combine filters with AND")

combined =
  Filter.all_of([
    Filter.equal("status", "published"),
    Filter.greater_than("views", 100)
  ])

command("Filter.all_of([filter1, filter2])")
result("Combined Filter", combined)

# Combined filters (OR)
step("Combine filters with OR")

or_filter =
  Filter.any_of([
    Filter.equal("category", "tech"),
    Filter.equal("category", "science")
  ])

command("Filter.any_of([...])")
result("OR Filter", or_filter)

# Convert to GraphQL
step("Convert filter to GraphQL format")
command("Filter.to_graphql(combined)")
graphql = Filter.to_graphql(combined)
result("GraphQL", graphql)

IO.puts("\n#{green("✓")} Example complete!\n")
