defmodule WeaviateEx.RBAC.UserAssignmentTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.RBAC.UserAssignment

  describe "new/2" do
    test "creates a UserAssignment struct" do
      assignment = UserAssignment.new("john.doe", :db_user)

      assert %UserAssignment{} = assignment
      assert assignment.user_id == "john.doe"
      assert assignment.user_type == :db_user
    end

    test "accepts different user types" do
      assert %UserAssignment{user_type: :db_user} = UserAssignment.new("u1", :db_user)
      assert %UserAssignment{user_type: :db_env_user} = UserAssignment.new("u2", :db_env_user)
      assert %UserAssignment{user_type: :oidc} = UserAssignment.new("u3", :oidc)
    end
  end

  describe "from_api/1" do
    test "parses camelCase API response" do
      api_data = %{"userId" => "john", "userType" => "db_user"}
      assignment = UserAssignment.from_api(api_data)

      assert assignment.user_id == "john"
      assert assignment.user_type == :db_user
    end

    test "parses snake_case API response" do
      api_data = %{"user_id" => "jane", "user_type" => "oidc"}
      assignment = UserAssignment.from_api(api_data)

      assert assignment.user_id == "jane"
      assert assignment.user_type == :oidc
    end

    test "parses simple string as user_id with db_user default" do
      assignment = UserAssignment.from_api("simple_user")

      assert assignment.user_id == "simple_user"
      assert assignment.user_type == :db_user
    end
  end

  describe "parse_user_type/1" do
    test "parses db_user variants" do
      assert UserAssignment.parse_user_type("db_user") == :db_user
      assert UserAssignment.parse_user_type("db-user") == :db_user
      assert UserAssignment.parse_user_type("dbUser") == :db_user
    end

    test "parses db_env_user variants" do
      assert UserAssignment.parse_user_type("db_env_user") == :db_env_user
      assert UserAssignment.parse_user_type("db-env-user") == :db_env_user
      assert UserAssignment.parse_user_type("dbEnvUser") == :db_env_user
    end

    test "parses oidc variants" do
      assert UserAssignment.parse_user_type("oidc") == :oidc
      assert UserAssignment.parse_user_type("OIDC") == :oidc
    end

    test "defaults to db_user for unknown types" do
      assert UserAssignment.parse_user_type("unknown") == :db_user
    end
  end

  describe "to_api/1" do
    test "converts to API format" do
      assignment = UserAssignment.new("john", :db_user)
      api_data = UserAssignment.to_api(assignment)

      assert api_data == %{"userId" => "john", "userType" => "db_user"}
    end
  end

  describe "db_user?/1" do
    test "returns true for db_user" do
      assert UserAssignment.db_user?(UserAssignment.new("u", :db_user))
    end

    test "returns true for db_env_user" do
      assert UserAssignment.db_user?(UserAssignment.new("u", :db_env_user))
    end

    test "returns false for oidc" do
      refute UserAssignment.db_user?(UserAssignment.new("u", :oidc))
    end
  end

  describe "oidc_user?/1" do
    test "returns true for oidc" do
      assert UserAssignment.oidc_user?(UserAssignment.new("u", :oidc))
    end

    test "returns false for db_user" do
      refute UserAssignment.oidc_user?(UserAssignment.new("u", :db_user))
    end
  end
end
