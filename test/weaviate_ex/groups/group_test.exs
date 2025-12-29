defmodule WeaviateEx.Groups.GroupTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Groups.Group

  describe "struct" do
    test "creates group struct with name and roles" do
      group = %Group{
        name: "engineering",
        roles: ["developer", "viewer"]
      }

      assert group.name == "engineering"
      assert group.roles == ["developer", "viewer"]
    end

    test "defaults to empty roles list" do
      group = %Group{name: "test"}

      assert group.roles == []
    end
  end

  describe "from_api/1" do
    test "decodes group from API response" do
      api_data = %{
        "name" => "platform-team",
        "roles" => ["admin", "developer"]
      }

      {:ok, group} = Group.from_api(api_data)

      assert group.name == "platform-team"
      assert group.roles == ["admin", "developer"]
    end

    test "handles missing roles" do
      api_data = %{"name" => "empty-group"}

      {:ok, group} = Group.from_api(api_data)

      assert group.name == "empty-group"
      assert group.roles == []
    end
  end
end
