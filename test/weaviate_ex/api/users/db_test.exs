defmodule WeaviateEx.API.Users.DBTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Users.DB
  alias WeaviateEx.Protocol.Mock
  alias WeaviateEx.Users.User

  setup :verify_on_exit!
  setup :setup_test_client

  describe "create/3" do
    test "creates a new DB user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/users", body, _opts ->
        assert body["userId"] == "new-user"
        assert body["userType"] == "db"

        {:ok,
         %{
           "userId" => "new-user",
           "apiKey" => "generated-api-key-123",
           "userType" => "db",
           "active" => true
         }}
      end)

      {:ok, user} = DB.create(client, "new-user")

      assert %User.DB{} = user
      assert user.user_id == "new-user"
      assert user.api_key == "generated-api-key-123"
      assert user.active == true
    end
  end

  describe "get/3" do
    test "gets a DB user by ID", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/users/test-user?user_type=db"

        {:ok,
         %{
           "userId" => "test-user",
           "userType" => "db",
           "active" => true
         }}
      end)

      {:ok, user} = DB.get(client, "test-user")

      assert %User.DB{} = user
      assert user.user_id == "test-user"
    end
  end

  describe "list/2" do
    test "lists all DB users", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/users?user_type=db"

        {:ok,
         [
           %{"userId" => "user-1", "userType" => "db", "active" => true},
           %{"userId" => "user-2", "userType" => "db", "active" => false}
         ]}
      end)

      {:ok, users} = DB.list(client)

      assert length(users) == 2
      assert Enum.all?(users, fn u -> %User.DB{} = u end)
    end
  end

  describe "delete/3" do
    test "deletes a DB user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, path, _body, _opts ->
        assert path == "/v1/users/test-user?user_type=db"
        {:ok, %{}}
      end)

      assert :ok = DB.delete(client, "test-user")
    end
  end

  describe "rotate_api_key/3" do
    test "rotates a DB user's API key", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path == "/v1/users/test-user/rotate-key?user_type=db"
        {:ok, %{"apiKey" => "new-api-key-456"}}
      end)

      {:ok, new_key} = DB.rotate_api_key(client, "test-user")

      assert new_key == "new-api-key-456"
    end
  end

  describe "assign_roles/4" do
    test "assigns roles to a DB user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/users/test-user/assign-roles?user_type=db"
        assert body["roles"] == ["admin", "editor"]
        {:ok, %{}}
      end)

      assert :ok = DB.assign_roles(client, "test-user", ["admin", "editor"])
    end
  end

  describe "revoke_roles/4" do
    test "revokes roles from a DB user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/users/test-user/revoke-roles?user_type=db"
        assert body["roles"] == ["admin"]
        {:ok, %{}}
      end)

      assert :ok = DB.revoke_roles(client, "test-user", ["admin"])
    end
  end

  describe "get_roles/3" do
    test "gets roles assigned to a DB user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/users/test-user/roles?user_type=db"
        {:ok, ["admin", "viewer"]}
      end)

      {:ok, roles} = DB.get_roles(client, "test-user")

      assert roles == ["admin", "viewer"]
    end
  end

  describe "activate/3" do
    test "activates a DB user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path == "/v1/users/test-user/activate?user_type=db"
        {:ok, %{}}
      end)

      assert :ok = DB.activate(client, "test-user")
    end
  end

  describe "deactivate/3" do
    test "deactivates a DB user", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path == "/v1/users/test-user/deactivate?user_type=db"
        {:ok, %{}}
      end)

      assert :ok = DB.deactivate(client, "test-user")
    end
  end
end
