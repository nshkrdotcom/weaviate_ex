defmodule WeaviateEx.Query.GroupByTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.GroupBy

  describe "new/2" do
    test "creates group_by with string path" do
      group_by = GroupBy.new("category")

      assert group_by.path == "category"
      assert group_by.objects_per_group == 10
      assert group_by.number_of_groups == 10
    end

    test "creates group_by with list path" do
      group_by = GroupBy.new(["metadata", "type"])

      assert group_by.path == ["metadata", "type"]
      assert group_by.objects_per_group == 10
      assert group_by.number_of_groups == 10
    end

    test "creates group_by with custom limits" do
      group_by = GroupBy.new("category", objects_per_group: 5, number_of_groups: 20)

      assert group_by.path == "category"
      assert group_by.objects_per_group == 5
      assert group_by.number_of_groups == 20
    end
  end

  describe "to_graphql/1" do
    test "converts string path to GraphQL format" do
      group_by = GroupBy.new("category")
      result = GroupBy.to_graphql(group_by)

      assert result == ~s({path: ["category"], objectsPerGroup: 10, groups: 10})
    end

    test "converts list path to GraphQL format" do
      group_by = GroupBy.new(["metadata", "type"])
      result = GroupBy.to_graphql(group_by)

      assert result == ~s({path: ["metadata", "type"], objectsPerGroup: 10, groups: 10})
    end

    test "converts custom limits to GraphQL format" do
      group_by = GroupBy.new("category", objects_per_group: 3, number_of_groups: 5)
      result = GroupBy.to_graphql(group_by)

      assert result == ~s({path: ["category"], objectsPerGroup: 3, groups: 5})
    end
  end

  describe "to_map/1" do
    test "converts string path to map format" do
      group_by = GroupBy.new("category")
      result = GroupBy.to_map(group_by)

      assert result == %{
               path: ["category"],
               objects_per_group: 10,
               number_of_groups: 10
             }
    end

    test "converts list path to map format" do
      group_by = GroupBy.new(["meta", "type"])
      result = GroupBy.to_map(group_by)

      assert result == %{
               path: ["meta", "type"],
               objects_per_group: 10,
               number_of_groups: 10
             }
    end
  end

  describe "valid?/1" do
    test "returns true for valid group_by with string path" do
      group_by = GroupBy.new("category")
      assert GroupBy.valid?(group_by) == true
    end

    test "returns true for valid group_by with list path" do
      group_by = GroupBy.new(["meta", "type"])
      assert GroupBy.valid?(group_by) == true
    end

    test "returns false for nil path" do
      group_by = %GroupBy{path: nil, objects_per_group: 10, number_of_groups: 10}
      assert GroupBy.valid?(group_by) == false
    end

    test "returns false for empty string path" do
      group_by = %GroupBy{path: "", objects_per_group: 10, number_of_groups: 10}
      assert GroupBy.valid?(group_by) == false
    end

    test "returns false for empty list path" do
      group_by = %GroupBy{path: [], objects_per_group: 10, number_of_groups: 10}
      assert GroupBy.valid?(group_by) == false
    end

    test "returns false for zero objects_per_group" do
      group_by = %GroupBy{path: "cat", objects_per_group: 0, number_of_groups: 10}
      assert GroupBy.valid?(group_by) == false
    end

    test "returns false for zero number_of_groups" do
      group_by = %GroupBy{path: "cat", objects_per_group: 10, number_of_groups: 0}
      assert GroupBy.valid?(group_by) == false
    end
  end
end
