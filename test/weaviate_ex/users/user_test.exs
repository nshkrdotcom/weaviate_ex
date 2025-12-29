defmodule WeaviateEx.Users.UserTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Users.User

  describe "User.DB" do
    test "creates DB user struct" do
      user = %User.DB{
        user_id: "john.doe",
        api_key: "secret-key",
        active: true,
        roles: ["admin", "editor"]
      }

      assert user.user_id == "john.doe"
      assert user.api_key == "secret-key"
      assert user.active == true
      assert user.roles == ["admin", "editor"]
    end

    test "defaults to empty roles list" do
      user = %User.DB{user_id: "test", active: true}

      assert user.roles == []
    end
  end

  describe "User.OIDC" do
    test "creates OIDC user struct" do
      user = %User.OIDC{
        user_id: "oauth-user",
        groups: ["engineering", "qa"],
        roles: ["developer"]
      }

      assert user.user_id == "oauth-user"
      assert user.groups == ["engineering", "qa"]
      assert user.roles == ["developer"]
    end

    test "defaults to empty lists" do
      user = %User.OIDC{user_id: "test"}

      assert user.groups == []
      assert user.roles == []
    end
  end

  describe "User.Own" do
    test "creates Own user struct" do
      user = %User.Own{
        user_id: "current-user",
        user_type: :db_user,
        roles: ["admin"],
        groups: []
      }

      assert user.user_id == "current-user"
      assert user.user_type == :db_user
      assert user.roles == ["admin"]
      assert user.groups == []
    end
  end

  describe "from_api/1" do
    test "decodes DB user from API response" do
      api_data = %{
        "userId" => "john.doe",
        "apiKey" => "secret-123",
        "active" => true,
        "roles" => ["editor", "viewer"],
        "userType" => "db_user"
      }

      {:ok, user} = User.from_api(api_data)

      assert %User.DB{} = user
      assert user.user_id == "john.doe"
      assert user.api_key == "secret-123"
      assert user.active == true
      assert user.roles == ["editor", "viewer"]
    end

    test "decodes DB environment user from API response" do
      api_data = %{
        "userId" => "env-user",
        "active" => true,
        "roles" => ["admin"],
        "userType" => "db_env_user"
      }

      {:ok, user} = User.from_api(api_data)

      assert %User.DB{} = user
      assert user.user_id == "env-user"
    end

    test "decodes OIDC user from API response" do
      api_data = %{
        "userId" => "oauth-user@company.com",
        "groups" => ["engineering", "platform"],
        "roles" => ["developer", "viewer"],
        "userType" => "oidc"
      }

      {:ok, user} = User.from_api(api_data)

      assert %User.OIDC{} = user
      assert user.user_id == "oauth-user@company.com"
      assert user.groups == ["engineering", "platform"]
      assert user.roles == ["developer", "viewer"]
    end

    test "handles missing optional fields" do
      api_data = %{
        "userId" => "minimal-user",
        "userType" => "db_user"
      }

      {:ok, user} = User.from_api(api_data)

      assert user.user_id == "minimal-user"
      assert user.roles == []
      assert user.api_key == nil
    end

    test "decodes user without explicit type as DB user" do
      api_data = %{
        "userId" => "legacy-user",
        "active" => true,
        "roles" => []
      }

      {:ok, user} = User.from_api(api_data)

      assert %User.DB{} = user
    end
  end

  describe "from_api_own/1" do
    test "decodes own user response" do
      api_data = %{
        "userId" => "me",
        "userType" => "db_user",
        "roles" => ["admin", "developer"],
        "groups" => []
      }

      {:ok, user} = User.from_api_own(api_data)

      assert %User.Own{} = user
      assert user.user_id == "me"
      assert user.user_type == :db_user
      assert user.roles == ["admin", "developer"]
    end

    test "parses OIDC user type correctly" do
      api_data = %{
        "userId" => "oidc-me",
        "userType" => "oidc",
        "roles" => [],
        "groups" => ["engineering"]
      }

      {:ok, user} = User.from_api_own(api_data)

      assert user.user_type == :oidc
      assert user.groups == ["engineering"]
    end
  end

  describe "user_type parsing" do
    test "parses db_user" do
      assert User.parse_user_type("db_user") == :db_user
    end

    test "parses db_env_user" do
      assert User.parse_user_type("db_env_user") == :db_env_user
    end

    test "parses oidc" do
      assert User.parse_user_type("oidc") == :oidc
    end

    test "defaults to db_user for nil" do
      assert User.parse_user_type(nil) == :db_user
    end

    test "defaults to db_user for unknown" do
      assert User.parse_user_type("unknown") == :db_user
    end
  end
end
