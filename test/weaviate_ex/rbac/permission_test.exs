defmodule WeaviateEx.RBAC.PermissionTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.RBAC.Permission

  describe "new/2" do
    test "creates a simple collections permission" do
      permission = Permission.new(:collections, :read)

      assert permission.type == :collections
      assert permission.action == :read
      assert permission.collection == nil
    end

    test "creates collections permission with collection filter" do
      permission = Permission.new(:collections, :read, collection: "Article")

      assert permission.type == :collections
      assert permission.action == :read
      assert permission.collection == "Article"
    end

    test "creates data permission with collection and tenant" do
      permission = Permission.new(:data, :create, collection: "Article", tenant: "tenant-a")

      assert permission.type == :data
      assert permission.action == :create
      assert permission.collection == "Article"
      assert permission.tenant == "tenant-a"
    end

    test "creates nodes permission with verbosity" do
      permission = Permission.new(:nodes, :read, verbosity: :verbose)

      assert permission.type == :nodes
      assert permission.action == :read
      assert permission.verbosity == :verbose
    end

    test "creates roles permission with role filter" do
      permission = Permission.new(:roles, :read, role: "admin")

      assert permission.type == :roles
      assert permission.action == :read
      assert permission.role == "admin"
    end

    test "creates users permission with user filter" do
      permission = Permission.new(:users, :read, user: "john")

      assert permission.type == :users
      assert permission.action == :read
      assert permission.user == "john"
    end

    test "creates roles permission with scope filter" do
      permission = Permission.new(:roles, :read, role: "admin", scope: :match)

      assert permission.type == :roles
      assert permission.action == :read
      assert permission.role == "admin"
      assert permission.scope == :match
    end

    test "creates roles permission with all scope" do
      permission = Permission.new(:roles, :delete, role: "*", scope: :all)

      assert permission.scope == :all
    end
  end

  describe "to_api/1" do
    test "encodes collections permission to API format" do
      permission = Permission.new(:collections, :read, collection: "Article")

      api = Permission.to_api(permission)

      assert api["action"] == "read_collections"
      assert api["collection"] == "Article"
    end

    test "encodes collections permission with wildcard" do
      permission = Permission.new(:collections, :create, collection: "*")

      api = Permission.to_api(permission)

      assert api["action"] == "create_collections"
      assert api["collection"] == "*"
    end

    test "encodes data permission with tenant" do
      permission = Permission.new(:data, :read, collection: "Article", tenant: "tenant-a")

      api = Permission.to_api(permission)

      assert api["action"] == "read_data"
      assert api["collection"] == "Article"
      assert api["tenant"] == "tenant-a"
    end

    test "encodes data permission with object filter" do
      permission = Permission.new(:data, :update, collection: "Article", object: "uuid-123")

      api = Permission.to_api(permission)

      assert api["action"] == "update_data"
      assert api["collection"] == "Article"
      assert api["object"] == "uuid-123"
    end

    test "encodes nodes permission with verbosity" do
      permission = Permission.new(:nodes, :read, verbosity: :verbose)

      api = Permission.to_api(permission)

      assert api["action"] == "read_nodes"
      assert api["verbosity"] == "verbose"
    end

    test "encodes nodes permission with minimal verbosity" do
      permission = Permission.new(:nodes, :read, verbosity: :minimal)

      api = Permission.to_api(permission)

      assert api["action"] == "read_nodes"
      assert api["verbosity"] == "minimal"
    end

    test "encodes roles permission with role filter" do
      permission = Permission.new(:roles, :delete, role: "custom-role")

      api = Permission.to_api(permission)

      assert api["action"] == "delete_roles"
      assert api["role"] == "custom-role"
    end

    test "encodes roles permission with match scope" do
      permission = Permission.new(:roles, :read, role: "admin", scope: :match)

      api = Permission.to_api(permission)

      assert api["action"] == "read_roles"
      assert api["role"] == "admin"
      assert api["scope"] == "match"
    end

    test "encodes roles permission with all scope" do
      permission = Permission.new(:roles, :delete, role: "*", scope: :all)

      api = Permission.to_api(permission)

      assert api["scope"] == "all"
    end

    test "omits scope when nil" do
      permission = Permission.new(:roles, :read, role: "admin")

      api = Permission.to_api(permission)

      refute Map.has_key?(api, "scope")
    end

    test "encodes users permission with user filter" do
      permission = Permission.new(:users, :assign_and_revoke, user: "john")

      api = Permission.to_api(permission)

      assert api["action"] == "assign_and_revoke_users"
      assert api["user"] == "john"
    end

    test "encodes groups permission with group filter" do
      permission = Permission.new(:groups, :assign_and_revoke, group: "engineering")

      api = Permission.to_api(permission)

      assert api["action"] == "assign_and_revoke_groups"
      assert api["group"] == "engineering"
    end

    test "encodes backups permission" do
      permission = Permission.new(:backups, :manage)

      api = Permission.to_api(permission)

      assert api["action"] == "manage_backups"
    end

    test "encodes cluster permission" do
      permission = Permission.new(:cluster, :read)

      api = Permission.to_api(permission)

      assert api["action"] == "read_cluster"
    end

    test "omits nil values from API output" do
      permission = Permission.new(:collections, :read)

      api = Permission.to_api(permission)

      assert api["action"] == "read_collections"
      refute Map.has_key?(api, "collection")
      refute Map.has_key?(api, "tenant")
    end
  end

  describe "from_api/1" do
    test "decodes collections permission from API response" do
      api_data = %{
        "action" => "read_collections",
        "collection" => "Article"
      }

      {:ok, permission} = Permission.from_api(api_data)

      assert permission.type == :collections
      assert permission.action == :read
      assert permission.collection == "Article"
    end

    test "decodes data permission with tenant from API response" do
      api_data = %{
        "action" => "create_data",
        "collection" => "Product",
        "tenant" => "tenant-b"
      }

      {:ok, permission} = Permission.from_api(api_data)

      assert permission.type == :data
      assert permission.action == :create
      assert permission.collection == "Product"
      assert permission.tenant == "tenant-b"
    end

    test "decodes nodes permission with verbosity" do
      api_data = %{
        "action" => "read_nodes",
        "verbosity" => "verbose"
      }

      {:ok, permission} = Permission.from_api(api_data)

      assert permission.type == :nodes
      assert permission.action == :read
      assert permission.verbosity == :verbose
    end

    test "handles wildcard collections" do
      api_data = %{
        "action" => "manage_collections",
        "collection" => "*"
      }

      {:ok, permission} = Permission.from_api(api_data)

      assert permission.type == :collections
      assert permission.action == :manage
      assert permission.collection == "*"
    end

    test "handles wildcard tenants" do
      api_data = %{
        "action" => "read_data",
        "collection" => "Article",
        "tenant" => "*"
      }

      {:ok, permission} = Permission.from_api(api_data)

      assert permission.tenant == "*"
    end

    test "returns error for invalid action" do
      api_data = %{"action" => "invalid_action"}

      assert {:error, _} = Permission.from_api(api_data)
    end

    test "decodes roles permission with match scope" do
      api_data = %{
        "action" => "read_roles",
        "role" => "admin",
        "scope" => "match"
      }

      {:ok, permission} = Permission.from_api(api_data)

      assert permission.type == :roles
      assert permission.role == "admin"
      assert permission.scope == :match
    end

    test "decodes roles permission with all scope" do
      api_data = %{
        "action" => "delete_roles",
        "role" => "*",
        "scope" => "all"
      }

      {:ok, permission} = Permission.from_api(api_data)

      assert permission.scope == :all
    end
  end

  describe "round-trip encoding/decoding" do
    test "collections permission round-trips correctly" do
      permission = Permission.new(:collections, :update, collection: "Article")

      api = Permission.to_api(permission)
      {:ok, decoded} = Permission.from_api(api)

      assert decoded.type == permission.type
      assert decoded.action == permission.action
      assert decoded.collection == permission.collection
    end

    test "data permission with tenant round-trips correctly" do
      permission = Permission.new(:data, :delete, collection: "Product", tenant: "tenant-x")

      api = Permission.to_api(permission)
      {:ok, decoded} = Permission.from_api(api)

      assert decoded.type == permission.type
      assert decoded.action == permission.action
      assert decoded.collection == permission.collection
      assert decoded.tenant == permission.tenant
    end

    test "nodes permission with verbosity round-trips correctly" do
      permission = Permission.new(:nodes, :read, verbosity: :verbose)

      api = Permission.to_api(permission)
      {:ok, decoded} = Permission.from_api(api)

      assert decoded.type == permission.type
      assert decoded.action == permission.action
      assert decoded.verbosity == permission.verbosity
    end

    test "roles permission with scope round-trips correctly" do
      permission = Permission.new(:roles, :read, role: "admin", scope: :match)

      api = Permission.to_api(permission)
      {:ok, decoded} = Permission.from_api(api)

      assert decoded.type == permission.type
      assert decoded.action == permission.action
      assert decoded.role == permission.role
      assert decoded.scope == permission.scope
    end
  end

  describe "equality" do
    test "permissions with same fields are equal" do
      p1 = Permission.new(:data, :read, collection: "Article", tenant: "tenant-a")
      p2 = Permission.new(:data, :read, collection: "Article", tenant: "tenant-a")

      assert p1 == p2
    end

    test "permissions with different fields are not equal" do
      p1 = Permission.new(:data, :read, collection: "Article")
      p2 = Permission.new(:data, :read, collection: "Product")

      refute p1 == p2
    end
  end
end
