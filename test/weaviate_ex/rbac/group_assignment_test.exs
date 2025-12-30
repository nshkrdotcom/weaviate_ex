defmodule WeaviateEx.RBAC.GroupAssignmentTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.RBAC.GroupAssignment

  describe "new/2" do
    test "creates a GroupAssignment struct" do
      assignment = GroupAssignment.new("engineering", :oidc)

      assert %GroupAssignment{} = assignment
      assert assignment.group_id == "engineering"
      assert assignment.group_type == :oidc
    end
  end

  describe "from_api/1" do
    test "parses camelCase API response" do
      api_data = %{"groupId" => "eng", "groupType" => "oidc"}
      assignment = GroupAssignment.from_api(api_data)

      assert assignment.group_id == "eng"
      assert assignment.group_type == :oidc
    end

    test "parses snake_case API response" do
      api_data = %{"group_id" => "dev", "group_type" => "OIDC"}
      assignment = GroupAssignment.from_api(api_data)

      assert assignment.group_id == "dev"
      assert assignment.group_type == :oidc
    end

    test "parses simple string as group_id with oidc default" do
      assignment = GroupAssignment.from_api("simple_group")

      assert assignment.group_id == "simple_group"
      assert assignment.group_type == :oidc
    end
  end

  describe "parse_group_type/1" do
    test "parses oidc variants" do
      assert GroupAssignment.parse_group_type("oidc") == :oidc
      assert GroupAssignment.parse_group_type("OIDC") == :oidc
    end

    test "defaults to oidc for unknown types" do
      assert GroupAssignment.parse_group_type("unknown") == :oidc
    end
  end

  describe "to_api/1" do
    test "converts to API format" do
      assignment = GroupAssignment.new("engineering", :oidc)
      api_data = GroupAssignment.to_api(assignment)

      assert api_data == %{"groupId" => "engineering", "groupType" => "oidc"}
    end
  end
end
