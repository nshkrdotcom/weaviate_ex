defmodule WeaviateEx.API.UsersTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Users
  alias WeaviateEx.Protocol.Mock
  alias WeaviateEx.Users.User

  setup :verify_on_exit!
  setup :setup_test_client

  describe "create/2" do
    test "creates user and returns API key", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/users", body, _opts ->
        assert body["userId"] == "new-user"

        {:ok,
         %{
           "userId" => "new-user",
           "apiKey" => "generated-api-key-123",
           "active" => true,
           "userType" => "db_user"
         }}
      end)

      assert {:ok, user} = Users.create(client, "new-user")
      assert %User.DB{} = user
      assert user.user_id == "new-user"
      assert user.api_key == "generated-api-key-123"
      assert user.active == true
    end

    test "returns error for duplicate user_id", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/users", _body, _opts ->
        {:error, %WeaviateEx.Error{type: :conflict, message: "User already exists"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :conflict}} = Users.create(client, "existing")
    end
  end

  describe "get/2" do
    test "returns DB user details", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/users/john.doe", nil, _opts ->
        {:ok,
         %{
           "userId" => "john.doe",
           "active" => true,
           "roles" => ["editor", "viewer"],
           "userType" => "db_user"
         }}
      end)

      assert {:ok, user} = Users.get(client, "john.doe")
      assert %User.DB{} = user
      assert user.user_id == "john.doe"
      assert user.roles == ["editor", "viewer"]
    end

    test "returns OIDC user details", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert path == "/v1/users/oauth%40company.com"

        {:ok,
         %{
           "userId" => "oauth@company.com",
           "groups" => ["engineering"],
           "roles" => ["developer"],
           "userType" => "oidc"
         }}
      end)

      assert {:ok, user} = Users.get(client, "oauth@company.com")
      assert %User.OIDC{} = user
      assert user.groups == ["engineering"]
    end

    test "returns error for non-existent user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/users/missing", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "User not found"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} = Users.get(client, "missing")
    end
  end

  describe "get_my_user/1" do
    test "returns current user info", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/users/own", nil, _opts ->
        {:ok,
         %{
           "userId" => "current-user",
           "userType" => "db_user",
           "roles" => ["admin"],
           "groups" => []
         }}
      end)

      assert {:ok, user} = Users.get_my_user(client)
      assert %User.Own{} = user
      assert user.user_id == "current-user"
      assert user.user_type == :db_user
    end

    test "includes roles and groups", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/users/own", nil, _opts ->
        {:ok,
         %{
           "userId" => "oidc-user",
           "userType" => "oidc",
           "roles" => ["developer", "viewer"],
           "groups" => ["engineering", "platform"]
         }}
      end)

      assert {:ok, user} = Users.get_my_user(client)
      assert user.roles == ["developer", "viewer"]
      assert user.groups == ["engineering", "platform"]
    end
  end

  describe "list_all/1" do
    test "returns all users", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/users", nil, _opts ->
        {:ok,
         [
           %{
             "userId" => "db-user-1",
             "active" => true,
             "roles" => [],
             "userType" => "db_user"
           },
           %{
             "userId" => "oidc-user-1",
             "groups" => ["engineering"],
             "roles" => [],
             "userType" => "oidc"
           }
         ]}
      end)

      assert {:ok, users} = Users.list_all(client)
      assert length(users) == 2
    end

    test "includes both DB and OIDC users", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/users", nil, _opts ->
        {:ok,
         [
           %{"userId" => "db-user", "userType" => "db_user", "active" => true},
           %{"userId" => "oidc-user", "userType" => "oidc", "groups" => []}
         ]}
      end)

      assert {:ok, users} = Users.list_all(client)
      assert Enum.any?(users, fn u -> is_struct(u, User.DB) end)
      assert Enum.any?(users, fn u -> is_struct(u, User.OIDC) end)
    end
  end

  describe "delete/2" do
    test "deletes existing user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, "/v1/users/old-user", nil, _opts ->
        {:ok, %{}}
      end)

      assert :ok = Users.delete(client, "old-user")
    end

    test "returns error for non-existent user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, "/v1/users/missing", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} = Users.delete(client, "missing")
    end
  end

  describe "activate/2" do
    test "activates deactivated user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/users/user-1/activate", nil, _opts ->
        {:ok, %{}}
      end)

      assert :ok = Users.activate(client, "user-1")
    end
  end

  describe "deactivate/2" do
    test "deactivates active user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/users/user-1/deactivate", nil, _opts ->
        {:ok, %{}}
      end)

      assert :ok = Users.deactivate(client, "user-1")
    end
  end

  describe "rotate_key/2" do
    test "returns new API key", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/users/user-1/rotate-key", nil, _opts ->
        {:ok, %{"apiKey" => "new-api-key-456"}}
      end)

      assert {:ok, "new-api-key-456"} = Users.rotate_key(client, "user-1")
    end

    test "returns error for OIDC user", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/users/oidc-user/rotate-key",
                                    nil,
                                    _opts ->
        {:error,
         %WeaviateEx.Error{type: :bad_request, message: "Cannot rotate key for OIDC user"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :bad_request}} =
               Users.rotate_key(client, "oidc-user")
    end
  end

  describe "assign_roles/3" do
    test "assigns single role", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/users/user-1/assign-roles",
                                    body,
                                    _opts ->
        assert body["roles"] == ["editor"]
        {:ok, %{}}
      end)

      assert :ok = Users.assign_roles(client, "user-1", ["editor"])
    end

    test "assigns multiple roles", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/users/user-1/assign-roles",
                                    body,
                                    _opts ->
        assert body["roles"] == ["admin", "editor", "viewer"]
        {:ok, %{}}
      end)

      assert :ok = Users.assign_roles(client, "user-1", ["admin", "editor", "viewer"])
    end

    test "returns error for non-existent role", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/users/user-1/assign-roles",
                                    _body,
                                    _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Role not found"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Users.assign_roles(client, "user-1", ["nonexistent"])
    end
  end

  describe "revoke_roles/3" do
    test "revokes roles from user", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/users/user-1/revoke-roles",
                                    body,
                                    _opts ->
        assert body["roles"] == ["admin"]
        {:ok, %{}}
      end)

      assert :ok = Users.revoke_roles(client, "user-1", ["admin"])
    end
  end

  describe "get_assigned_roles/2" do
    test "returns list of role names", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/users/user-1/roles", nil, _opts ->
        {:ok, ["admin", "editor", "viewer"]}
      end)

      assert {:ok, roles} = Users.get_assigned_roles(client, "user-1")
      assert roles == ["admin", "editor", "viewer"]
    end

    test "returns empty list for user with no roles", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/users/no-roles-user/roles", nil, _opts ->
        {:ok, []}
      end)

      assert {:ok, []} = Users.get_assigned_roles(client, "no-roles-user")
    end
  end
end
