defmodule WeaviateEx.API.RBACTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.RBAC
  alias WeaviateEx.Protocol.Mock
  alias WeaviateEx.RBAC.{Permissions, Role}

  setup :verify_on_exit!
  setup :setup_test_client

  describe "list_roles/1" do
    test "returns empty list when no roles exist", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/roles", nil, _opts ->
        {:ok, []}
      end)

      assert {:ok, []} = RBAC.list_roles(client)
    end

    test "returns list of Role structs", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/roles", nil, _opts ->
        {:ok,
         [
           %{
             "name" => "role-1",
             "permissions" => [%{"action" => "read_collections", "collection" => "A"}]
           },
           %{
             "name" => "role-2",
             "permissions" => []
           }
         ]}
      end)

      assert {:ok, roles} = RBAC.list_roles(client)
      assert length(roles) == 2
      assert Enum.all?(roles, fn r -> is_struct(r, Role) end)
      assert Enum.map(roles, & &1.name) == ["role-1", "role-2"]
    end
  end

  describe "exists?/2" do
    test "returns true when role exists", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/roles/admin", nil, _opts ->
        {:ok, %{"name" => "admin", "permissions" => []}}
      end)

      assert {:ok, true} = RBAC.exists?(client, "admin")
    end

    test "returns false when role does not exist", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/roles/nonexistent", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:ok, false} = RBAC.exists?(client, "nonexistent")
    end
  end

  describe "get_role/2" do
    test "returns role with permissions", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/roles/editor", nil, _opts ->
        {:ok,
         %{
           "name" => "editor",
           "permissions" => [
             %{"action" => "read_collections", "collection" => "Article"},
             %{"action" => "update_data", "collection" => "Article"}
           ]
         }}
      end)

      assert {:ok, role} = RBAC.get_role(client, "editor")
      assert role.name == "editor"
      assert length(role.permissions) == 2
    end

    test "returns error for non-existent role", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/roles/missing", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Role not found"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} = RBAC.get_role(client, "missing")
    end
  end

  describe "create_role/3" do
    test "creates role with single permission", %{client: client} do
      permission = Permissions.collections("Article", :read)

      Mox.expect(Mock, :request, fn _client, :post, "/v1/authz/roles", body, _opts ->
        assert body["name"] == "reader"
        assert length(body["permissions"]) == 1

        {:ok, %{"name" => "reader", "permissions" => body["permissions"]}}
      end)

      assert {:ok, role} = RBAC.create_role(client, "reader", [permission])
      assert role.name == "reader"
    end

    test "creates role with multiple permissions", %{client: client} do
      permissions = [
        Permissions.collections("Article", [:read, :update]),
        Permissions.data("Article", :create)
      ]

      Mox.expect(Mock, :request, fn _client, :post, "/v1/authz/roles", body, _opts ->
        assert body["name"] == "editor"
        # 2 from collections + 1 from data = 3
        assert length(body["permissions"]) == 3

        {:ok, %{"name" => "editor", "permissions" => body["permissions"]}}
      end)

      assert {:ok, role} = RBAC.create_role(client, "editor", permissions)
      assert length(role.permissions) == 3
    end

    test "returns error for duplicate role name", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/authz/roles", _body, _opts ->
        {:error, %WeaviateEx.Error{type: :conflict, message: "Role already exists"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :conflict}} =
               RBAC.create_role(client, "existing", [])
    end
  end

  describe "delete_role/2" do
    test "deletes existing role", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, "/v1/authz/roles/old-role", nil, _opts ->
        {:ok, %{}}
      end)

      assert :ok = RBAC.delete_role(client, "old-role")
    end

    test "returns error for non-existent role", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, "/v1/authz/roles/missing", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} = RBAC.delete_role(client, "missing")
    end

    test "returns error for built-in role", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, "/v1/authz/roles/admin", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :forbidden, message: "Cannot delete built-in role"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :forbidden}} = RBAC.delete_role(client, "admin")
    end
  end

  describe "add_permissions/3" do
    test "adds permissions to existing role", %{client: client} do
      permissions = [Permissions.data("Product", :read)]

      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/authz/roles/editor/add-permissions",
                                    body,
                                    _opts ->
        assert length(body["permissions"]) == 1
        {:ok, %{}}
      end)

      assert :ok = RBAC.add_permissions(client, "editor", permissions)
    end

    test "is idempotent for duplicate permissions", %{client: client} do
      permissions = [Permissions.collections("A", :read)]

      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/authz/roles/role/add-permissions",
                                    _body,
                                    _opts ->
        {:ok, %{}}
      end)

      assert :ok = RBAC.add_permissions(client, "role", permissions)
    end
  end

  describe "remove_permissions/3" do
    test "removes permissions from role", %{client: client} do
      permissions = [Permissions.data("Product", :delete)]

      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/authz/roles/editor/remove-permissions",
                                    body,
                                    _opts ->
        assert length(body["permissions"]) == 1
        {:ok, %{}}
      end)

      assert :ok = RBAC.remove_permissions(client, "editor", permissions)
    end
  end

  describe "has_permissions?/3" do
    test "returns true when role has all permissions", %{client: client} do
      permissions = [Permissions.collections("A", :read)]

      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/authz/roles/role/has-permissions",
                                    _body,
                                    _opts ->
        {:ok, %{"hasPermission" => true}}
      end)

      assert {:ok, true} = RBAC.has_permissions?(client, "role", permissions)
    end

    test "returns false when role missing permission", %{client: client} do
      permissions = [Permissions.collections("A", :delete)]

      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/authz/roles/role/has-permissions",
                                    _body,
                                    _opts ->
        {:ok, %{"hasPermission" => false}}
      end)

      assert {:ok, false} = RBAC.has_permissions?(client, "role", permissions)
    end
  end

  describe "get_users_for_role/2" do
    test "returns list of user IDs assigned to role", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/roles/editor/users", nil, _opts ->
        {:ok, ["user-1", "user-2", "user-3"]}
      end)

      assert {:ok, users} = RBAC.get_users_for_role(client, "editor")
      assert users == ["user-1", "user-2", "user-3"]
    end

    test "returns empty list when no users assigned", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :get,
                                    "/v1/authz/roles/empty-role/users",
                                    nil,
                                    _opts ->
        {:ok, []}
      end)

      assert {:ok, []} = RBAC.get_users_for_role(client, "empty-role")
    end
  end

  describe "get_groups_for_role/2" do
    test "returns list of group IDs assigned to role", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/roles/editor/groups", nil, _opts ->
        {:ok, ["engineering", "qa"]}
      end)

      assert {:ok, groups} = RBAC.get_groups_for_role(client, "editor")
      assert groups == ["engineering", "qa"]
    end

    test "returns empty list when no groups assigned", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :get,
                                    "/v1/authz/roles/no-groups-role/groups",
                                    nil,
                                    _opts ->
        {:ok, []}
      end)

      assert {:ok, []} = RBAC.get_groups_for_role(client, "no-groups-role")
    end
  end
end
