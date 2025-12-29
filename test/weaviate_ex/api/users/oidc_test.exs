defmodule WeaviateEx.API.Users.OIDCTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Users.OIDC
  alias WeaviateEx.Protocol.Mock
  alias WeaviateEx.Users.User

  setup :verify_on_exit!
  setup :setup_test_client

  describe "get/3" do
    test "gets an OIDC user by ID", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/users/oidc-user%40example.com?user_type=oidc"

        {:ok,
         %{
           "userId" => "oidc-user@example.com",
           "userType" => "oidc",
           "groups" => ["engineering", "admins"]
         }}
      end)

      {:ok, user} = OIDC.get(client, "oidc-user@example.com")

      assert %User.OIDC{} = user
      assert user.user_id == "oidc-user@example.com"
      assert user.groups == ["engineering", "admins"]
    end
  end

  describe "list/2" do
    test "lists all OIDC users", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/users?user_type=oidc"

        {:ok,
         [
           %{"userId" => "user1@example.com", "userType" => "oidc", "groups" => ["team-a"]},
           %{"userId" => "user2@example.com", "userType" => "oidc", "groups" => ["team-b"]}
         ]}
      end)

      {:ok, users} = OIDC.list(client)

      assert length(users) == 2
      assert Enum.all?(users, fn u -> %User.OIDC{} = u end)
    end
  end

  describe "assign_roles/4" do
    test "assigns roles to an OIDC user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/users/oidc-user%40example.com/assign-roles?user_type=oidc"
        assert body["roles"] == ["viewer", "editor"]
        {:ok, %{}}
      end)

      assert :ok = OIDC.assign_roles(client, "oidc-user@example.com", ["viewer", "editor"])
    end
  end

  describe "revoke_roles/4" do
    test "revokes roles from an OIDC user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/users/oidc-user%40example.com/revoke-roles?user_type=oidc"
        assert body["roles"] == ["editor"]
        {:ok, %{}}
      end)

      assert :ok = OIDC.revoke_roles(client, "oidc-user@example.com", ["editor"])
    end
  end

  describe "get_roles/3" do
    test "gets roles assigned to an OIDC user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/users/oidc-user%40example.com/roles?user_type=oidc"
        {:ok, ["viewer", "contributor"]}
      end)

      {:ok, roles} = OIDC.get_roles(client, "oidc-user@example.com")

      assert roles == ["viewer", "contributor"]
    end
  end

  describe "OIDC users cannot be created or deleted" do
    test "OIDC module does not have create function" do
      refute function_exported?(OIDC, :create, 3)
    end

    test "OIDC module does not have delete function" do
      refute function_exported?(OIDC, :delete, 3)
    end

    test "OIDC module does not have rotate_api_key function" do
      refute function_exported?(OIDC, :rotate_api_key, 3)
    end
  end
end
