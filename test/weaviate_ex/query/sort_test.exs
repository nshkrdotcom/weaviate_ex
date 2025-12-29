defmodule WeaviateEx.Query.SortTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.Sort

  describe "by_property/2" do
    test "creates ascending sort by property" do
      sort = Sort.by_property("title")

      assert sort == [%{path: ["title"], order: "asc"}]
    end

    test "creates descending sort by property" do
      sort = Sort.by_property("title", :desc)

      assert sort == [%{path: ["title"], order: "desc"}]
    end
  end

  describe "by_creation_time/1" do
    test "creates sort by creation time ascending" do
      sort = Sort.by_creation_time()

      assert sort == [%{path: ["_creationTimeUnix"], order: "asc"}]
    end

    test "creates sort by creation time descending" do
      sort = Sort.by_creation_time(:desc)

      assert sort == [%{path: ["_creationTimeUnix"], order: "desc"}]
    end
  end

  describe "by_update_time/1" do
    test "creates sort by update time ascending" do
      sort = Sort.by_update_time()

      assert sort == [%{path: ["_lastUpdateTimeUnix"], order: "asc"}]
    end

    test "creates sort by update time descending" do
      sort = Sort.by_update_time(:desc)

      assert sort == [%{path: ["_lastUpdateTimeUnix"], order: "desc"}]
    end
  end

  describe "by_id/1" do
    test "creates sort by id ascending" do
      sort = Sort.by_id()

      assert sort == [%{path: ["id"], order: "asc"}]
    end

    test "creates sort by id descending" do
      sort = Sort.by_id(:desc)

      assert sort == [%{path: ["id"], order: "desc"}]
    end
  end

  describe "chaining" do
    test "chains multiple sort criteria" do
      sort =
        Sort.by_property("category")
        |> Sort.then_by_property("title")

      assert length(sort) == 2
      assert Enum.at(sort, 0).path == ["category"]
      assert Enum.at(sort, 1).path == ["title"]
    end

    test "chains different sort types" do
      sort =
        Sort.by_property("category")
        |> Sort.then_by_creation_time(:desc)

      assert length(sort) == 2
    end
  end

  describe "to_graphql/1" do
    test "converts single sort to GraphQL format" do
      sort = Sort.by_property("title", :desc)
      graphql = Sort.to_graphql(sort)

      assert graphql == ~s([{path: ["title"], order: desc}])
    end

    test "converts multiple sorts to GraphQL format" do
      sort =
        Sort.by_property("category")
        |> Sort.then_by_property("title", :desc)

      graphql = Sort.to_graphql(sort)

      assert graphql =~ ~s({path: ["category"], order: asc})
      assert graphql =~ ~s({path: ["title"], order: desc})
    end
  end
end
