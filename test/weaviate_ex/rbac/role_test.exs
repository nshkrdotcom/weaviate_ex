defmodule WeaviateEx.RBAC.RoleTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.RBAC.Permission
  alias WeaviateEx.RBAC.Permissions
  alias WeaviateEx.RBAC.Role

  describe "new/2" do
    test "creates role with name" do
      role = Role.new("article-reader")

      assert role.name == "article-reader"
      assert role.permissions == []
    end

    test "creates role with permissions" do
      permissions = [
        Permissions.collections("Article", :read),
        Permissions.data("Article", :read)
      ]

      role = Role.new("article-reader", permissions)

      assert role.name == "article-reader"
      assert length(role.permissions) == 2
    end

    test "flattens nested permission lists" do
      permissions = [
        Permissions.collections("Article", [:read, :update]),
        Permissions.data("Article", :read)
      ]

      role = Role.new("editor", permissions)

      # 2 from collections + 1 from data = 3
      assert length(role.permissions) == 3
    end
  end

  describe "to_api/1" do
    test "encodes role to API format" do
      permissions = [
        Permissions.collections("Article", :read),
        Permissions.data("Article", :create)
      ]

      role = Role.new("my-role", permissions)
      api = Role.to_api(role)

      assert api["name"] == "my-role"
      assert is_list(api["permissions"])
      assert length(api["permissions"]) == 2

      actions = Enum.map(api["permissions"], & &1["action"])
      assert "read_collections" in actions
      assert "create_data" in actions
    end

    test "encodes empty permissions list" do
      role = Role.new("empty-role")
      api = Role.to_api(role)

      assert api["permissions"] == []
    end
  end

  describe "from_api/1" do
    test "decodes role from API response" do
      api_data = %{
        "name" => "article-reader",
        "permissions" => [
          %{"action" => "read_collections", "collection" => "Article"},
          %{"action" => "read_data", "collection" => "Article"}
        ]
      }

      {:ok, role} = Role.from_api(api_data)

      assert role.name == "article-reader"
      assert length(role.permissions) == 2
      assert Enum.all?(role.permissions, fn p -> is_struct(p, Permission) end)
    end

    test "handles empty permissions" do
      api_data = %{
        "name" => "empty-role",
        "permissions" => []
      }

      {:ok, role} = Role.from_api(api_data)

      assert role.name == "empty-role"
      assert role.permissions == []
    end

    test "handles missing permissions key" do
      api_data = %{"name" => "no-perms-role"}

      {:ok, role} = Role.from_api(api_data)

      assert role.permissions == []
    end

    test "returns error for invalid permission" do
      api_data = %{
        "name" => "bad-role",
        "permissions" => [
          %{"action" => "invalid_action_type"}
        ]
      }

      assert {:error, _} = Role.from_api(api_data)
    end
  end

  describe "add_permissions/2" do
    test "adds permissions to role" do
      role = Role.new("my-role", [Permissions.collections("A", :read)])
      new_perms = [Permissions.data("B", :create)]

      updated = Role.add_permissions(role, new_perms)

      assert length(updated.permissions) == 2
    end

    test "adds single permission" do
      role = Role.new("my-role")
      permission = Permissions.collections("A", :read)

      updated = Role.add_permissions(role, permission)

      assert length(updated.permissions) == 1
    end

    test "flattens nested permission lists when adding" do
      role = Role.new("my-role")
      new_perms = Permissions.collections("A", [:read, :update])

      updated = Role.add_permissions(role, new_perms)

      assert length(updated.permissions) == 2
    end
  end

  describe "remove_permissions/2" do
    test "removes permissions from role" do
      perm1 = Permissions.collections("A", :read)
      perm2 = Permissions.data("B", :create)
      role = Role.new("my-role", [perm1, perm2])

      updated = Role.remove_permissions(role, [perm1])

      assert length(updated.permissions) == 1
      assert hd(updated.permissions).type == :data
    end

    test "handles non-existent permission gracefully" do
      perm1 = Permissions.collections("A", :read)
      role = Role.new("my-role", [perm1])

      non_existent = Permissions.data("X", :delete)
      updated = Role.remove_permissions(role, [non_existent])

      assert length(updated.permissions) == 1
    end
  end

  describe "has_permission?/2" do
    test "returns true when role has exact permission" do
      perm = Permissions.collections("Article", :read)
      role = Role.new("my-role", [perm])

      assert Role.has_permission?(role, perm) == true
    end

    test "returns false when role lacks permission" do
      perm1 = Permissions.collections("Article", :read)
      perm2 = Permissions.collections("Article", :delete)
      role = Role.new("my-role", [perm1])

      assert Role.has_permission?(role, perm2) == false
    end

    test "matches permissions by content, not identity" do
      perm1 = Permissions.collections("Article", :read)
      perm2 = Permissions.collections("Article", :read)
      role = Role.new("my-role", [perm1])

      # perm2 is a different struct instance but has same content
      assert Role.has_permission?(role, perm2) == true
    end
  end

  describe "round-trip encoding/decoding" do
    test "role round-trips correctly" do
      permissions = [
        Permissions.collections("Article", :read),
        Permissions.data("Article", [:create, :update]),
        Permissions.nodes(:verbose)
      ]

      original = Role.new("complex-role", permissions)
      api = Role.to_api(original)
      {:ok, decoded} = Role.from_api(api)

      assert decoded.name == original.name
      assert length(decoded.permissions) == length(original.permissions)
    end
  end
end
