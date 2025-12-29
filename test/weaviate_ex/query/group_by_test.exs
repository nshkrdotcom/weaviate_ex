defmodule WeaviateEx.Query.GroupByTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.GroupBy

  describe "new/2" do
    test "creates group by with defaults" do
      group_by = GroupBy.new("category")

      assert group_by.prop == "category"
      assert group_by.objects_per_group == 10
      assert group_by.number_of_groups == 10
    end

    test "creates group by with custom objects_per_group" do
      group_by = GroupBy.new("category", objects_per_group: 3)

      assert group_by.objects_per_group == 3
    end

    test "creates group by with custom number_of_groups" do
      group_by = GroupBy.new("category", number_of_groups: 5)

      assert group_by.number_of_groups == 5
    end

    test "creates group by with all options" do
      group_by = GroupBy.new("category", objects_per_group: 3, number_of_groups: 5)

      assert group_by.prop == "category"
      assert group_by.objects_per_group == 3
      assert group_by.number_of_groups == 5
    end
  end

  describe "to_graphql/1" do
    test "converts group by to graphql" do
      group_by = GroupBy.new("category", objects_per_group: 3, number_of_groups: 5)
      graphql = GroupBy.to_graphql(group_by)

      assert graphql =~ ~s(path: ["category"])
      assert graphql =~ "objectsPerGroup: 3"
      assert graphql =~ "groups: 5"
    end
  end
end
