defmodule WeaviateEx.FilterTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Filter

  describe "by_property/2" do
    test "creates a property filter with equal operator" do
      filter = Filter.by_property("status", :equal, "published")

      assert filter == %{
               path: ["status"],
               operator: :equal,
               value_text: "published"
             }
    end

    test "creates a property filter with number" do
      filter = Filter.by_property("views", :greater_than, 1000)

      assert filter == %{
               path: ["views"],
               operator: :greater_than,
               value_int: 1000
             }
    end

    test "creates a property filter with boolean" do
      filter = Filter.by_property("active", :equal, true)

      assert filter == %{
               path: ["active"],
               operator: :equal,
               value_boolean: true
             }
    end
  end

  describe "by_id/1" do
    test "creates an ID filter" do
      uuid = "00000000-0000-0000-0000-000000000001"
      filter = Filter.by_id(:equal, uuid)

      assert filter == %{
               path: ["id"],
               operator: :equal,
               value_text: uuid
             }
    end
  end

  describe "by_ref/2" do
    test "creates a reference filter" do
      filter = Filter.by_ref("hasAuthor", "Author", :equal, "John Doe")

      assert filter == %{
               path: ["hasAuthor", "Author", "name"],
               operator: :equal,
               value_text: "John Doe"
             }
    end
  end

  describe "operators" do
    test "equal operator" do
      filter = Filter.equal("name", "test")
      assert filter[:operator] == :equal
    end

    test "not_equal operator" do
      filter = Filter.not_equal("name", "test")
      assert filter[:operator] == :not_equal
    end

    test "less_than operator" do
      filter = Filter.less_than("age", 30)
      assert filter[:operator] == :less_than
    end

    test "less_or_equal operator" do
      filter = Filter.less_or_equal("age", 30)
      assert filter[:operator] == :less_or_equal
    end

    test "greater_than operator" do
      filter = Filter.greater_than("age", 18)
      assert filter[:operator] == :greater_than
    end

    test "greater_or_equal operator" do
      filter = Filter.greater_or_equal("age", 18)
      assert filter[:operator] == :greater_or_equal
    end

    test "like operator" do
      filter = Filter.like("name", "*test*")
      assert filter[:operator] == :like
    end

    test "contains_any operator" do
      filter = Filter.contains_any("tags", ["elixir", "phoenix"])
      assert filter[:operator] == :contains_any
      assert filter[:value_text_array] == ["elixir", "phoenix"]
    end

    test "contains_all operator" do
      filter = Filter.contains_all("tags", ["elixir", "phoenix"])
      assert filter[:operator] == :contains_all
    end

    test "is_null operator" do
      filter = Filter.is_null("description")
      assert filter[:operator] == :is_null
    end
  end

  describe "within_geo_range/3" do
    test "creates a geo filter" do
      filter = Filter.within_geo_range("location", {40.7128, -74.0060}, 5000.0)

      assert filter == %{
               path: ["location"],
               operator: :within_geo_range,
               value_geo_range: %{
                 latitude: 40.7128,
                 longitude: -74.0060,
                 distance: 5000.0
               }
             }
    end
  end

  describe "combinators" do
    test "all_of/1 combines filters with AND" do
      filter1 = Filter.equal("status", "published")
      filter2 = Filter.greater_than("views", 100)

      combined = Filter.all_of([filter1, filter2])

      assert combined == %{
               operator: :and,
               operands: [filter1, filter2]
             }
    end

    test "any_of/1 combines filters with OR" do
      filter1 = Filter.equal("status", "draft")
      filter2 = Filter.equal("status", "published")

      combined = Filter.any_of([filter1, filter2])

      assert combined == %{
               operator: :or,
               operands: [filter1, filter2]
             }
    end

    test "not_/1 negates a filter" do
      filter = Filter.equal("archived", true)
      negated = Filter.not_(filter)

      assert negated == %{
               operator: :not,
               operands: [filter]
             }
    end

    test "nested combinators" do
      # (status = "published" OR status = "draft") AND views > 100
      status_filter =
        Filter.any_of([
          Filter.equal("status", "published"),
          Filter.equal("status", "draft")
        ])

      views_filter = Filter.greater_than("views", 100)

      combined = Filter.all_of([status_filter, views_filter])

      assert combined[:operator] == :and
      assert length(combined[:operands]) == 2
    end
  end

  describe "to_graphql/1" do
    test "converts simple filter to GraphQL" do
      filter = Filter.equal("status", "published")
      graphql = Filter.to_graphql(filter)

      assert graphql == %{
               path: ["status"],
               operator: "Equal",
               valueText: "published"
             }
    end

    test "converts numeric filter to GraphQL" do
      filter = Filter.greater_than("views", 100)
      graphql = Filter.to_graphql(filter)

      assert graphql == %{
               path: ["views"],
               operator: "GreaterThan",
               valueInt: 100
             }
    end

    test "converts AND combinator to GraphQL" do
      filter =
        Filter.all_of([
          Filter.equal("status", "published"),
          Filter.greater_than("views", 100)
        ])

      graphql = Filter.to_graphql(filter)

      assert graphql == %{
               operator: "And",
               operands: [
                 %{path: ["status"], operator: "Equal", valueText: "published"},
                 %{path: ["views"], operator: "GreaterThan", valueInt: 100}
               ]
             }
    end

    test "converts OR combinator to GraphQL" do
      filter =
        Filter.any_of([
          Filter.equal("type", "article"),
          Filter.equal("type", "post")
        ])

      graphql = Filter.to_graphql(filter)

      assert graphql[:operator] == "Or"
      assert length(graphql[:operands]) == 2
    end

    test "converts NOT combinator to GraphQL" do
      filter = Filter.not_(Filter.equal("archived", true))
      graphql = Filter.to_graphql(filter)

      assert graphql[:operator] == "Not"
      assert length(graphql[:operands]) == 1
    end

    test "converts geo filter to GraphQL" do
      filter = Filter.within_geo_range("location", {40.7128, -74.0060}, 5000.0)
      graphql = Filter.to_graphql(filter)

      assert graphql == %{
               path: ["location"],
               operator: "WithinGeoRange",
               valueGeoRange: %{
                 latitude: 40.7128,
                 longitude: -74.0060,
                 distance: 5000.0
               }
             }
    end
  end
end
