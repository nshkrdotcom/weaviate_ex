defmodule WeaviateEx.API.RBAC.PermissionTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.RBAC.Permission
  alias WeaviateEx.API.RBAC.Scope

  describe "new/3" do
    test "creates permission with action and resource" do
      perm = Permission.new(:read, :collections)

      assert perm.action == :read
      assert perm.resource == :collections
      assert perm.scope == nil
    end

    test "creates permission with scope" do
      scope = Scope.collection("Article")
      perm = Permission.new(:read, :data, scope: scope)

      assert perm.action == :read
      assert perm.resource == :data
      assert perm.scope == scope
    end

    test "creates permission with inline scope" do
      perm = Permission.new(:read, :data, collection: "Article")

      assert perm.scope.collections == ["Article"]
    end

    test "creates permission with tenant in scope" do
      perm = Permission.new(:read, :data, collection: "Article", tenant: "tenant-a")

      assert perm.scope.collections == ["Article"]
      assert perm.scope.tenants == ["tenant-a"]
    end
  end

  describe "read_collection/1" do
    test "creates read permission for collection" do
      perm = Permission.read_collection("Article")

      assert perm.action == :read
      assert perm.resource == :collections
      assert perm.scope.collections == ["Article"]
    end
  end

  describe "manage_collection/1" do
    test "creates manage permission for collection" do
      perm = Permission.manage_collection("Article")

      assert perm.action == :manage
      assert perm.resource == :collections
      assert perm.scope.collections == ["Article"]
    end
  end

  describe "read_data/1" do
    test "creates read data permission" do
      perm = Permission.read_data("Article")

      assert perm.action == :read
      assert perm.resource == :data
      assert perm.scope.collections == ["Article"]
    end
  end

  describe "manage_data/1" do
    test "creates manage data permission" do
      perm = Permission.manage_data("Article")

      assert perm.action == :manage
      assert perm.resource == :data
      assert perm.scope.collections == ["Article"]
    end
  end

  describe "create_data/1" do
    test "creates create data permission" do
      perm = Permission.create_data("Article")

      assert perm.action == :create
      assert perm.resource == :data
      assert perm.scope.collections == ["Article"]
    end
  end

  describe "update_data/1" do
    test "creates update data permission" do
      perm = Permission.update_data("Article")

      assert perm.action == :update
      assert perm.resource == :data
      assert perm.scope.collections == ["Article"]
    end
  end

  describe "delete_data/1" do
    test "creates delete data permission" do
      perm = Permission.delete_data("Article")

      assert perm.action == :delete
      assert perm.resource == :data
      assert perm.scope.collections == ["Article"]
    end
  end

  describe "admin/0" do
    test "returns list of admin permissions" do
      perms = Permission.admin()

      assert is_list(perms)
      assert length(perms) > 0

      # Should include manage permissions for all resources
      resources = Enum.map(perms, & &1.resource) |> Enum.uniq()
      assert :collections in resources
      assert :data in resources
      assert :roles in resources
    end
  end

  describe "viewer/0" do
    test "returns list of viewer permissions" do
      perms = Permission.viewer()

      assert is_list(perms)

      # All should be read actions
      assert Enum.all?(perms, fn p -> p.action == :read end)
    end
  end

  describe "to_api/1" do
    test "converts basic permission to API format" do
      perm = Permission.new(:read, :collections)
      api = Permission.to_api(perm)

      assert api["action"] == "read_collections"
    end

    test "converts permission with scope to API format" do
      perm = Permission.read_collection("Article")
      api = Permission.to_api(perm)

      assert api["action"] == "read_collections"
      assert api["collection"] == "Article"
    end

    test "converts data permission with tenant scope" do
      perm = Permission.new(:read, :data, collection: "Article", tenant: "tenant-a")
      api = Permission.to_api(perm)

      assert api["action"] == "read_data"
      assert api["collection"] == "Article"
      assert api["tenant"] == "tenant-a"
    end

    test "converts manage permission" do
      perm = Permission.manage_collection("Article")
      api = Permission.to_api(perm)

      assert api["action"] == "manage_collections"
    end
  end

  describe "from_api/1" do
    test "parses basic permission from API" do
      api = %{"action" => "read_collections"}
      perm = Permission.from_api(api)

      assert perm.action == :read
      assert perm.resource == :collections
    end

    test "parses permission with collection scope" do
      api = %{"action" => "read_data", "collection" => "Article"}
      perm = Permission.from_api(api)

      assert perm.action == :read
      assert perm.resource == :data
      assert perm.scope.collections == ["Article"]
    end

    test "parses permission with tenant scope" do
      api = %{"action" => "read_data", "collection" => "Article", "tenant" => "tenant-a"}
      perm = Permission.from_api(api)

      assert perm.scope.collections == ["Article"]
      assert perm.scope.tenants == ["tenant-a"]
    end

    test "parses manage permission" do
      api = %{"action" => "manage_collections"}
      perm = Permission.from_api(api)

      assert perm.action == :manage
      assert perm.resource == :collections
    end
  end

  describe "action_to_api/2" do
    test "converts action and resource to API string" do
      assert Permission.action_to_api(:read, :collections) == "read_collections"
      assert Permission.action_to_api(:create, :data) == "create_data"
      assert Permission.action_to_api(:manage, :roles) == "manage_roles"
      assert Permission.action_to_api(:delete, :users) == "delete_users"
    end
  end

  describe "action_from_api/1" do
    test "parses action from API string" do
      assert Permission.action_from_api("read_collections") == {:read, :collections}
      assert Permission.action_from_api("create_data") == {:create, :data}
      assert Permission.action_from_api("manage_roles") == {:manage, :roles}
    end

    test "handles complex action strings" do
      assert Permission.action_from_api("assign_and_revoke_users") == {:assign_and_revoke, :users}
    end
  end

  describe "valid_action?/1" do
    test "validates known actions" do
      assert Permission.valid_action?(:create)
      assert Permission.valid_action?(:read)
      assert Permission.valid_action?(:update)
      assert Permission.valid_action?(:delete)
      assert Permission.valid_action?(:manage)
      assert Permission.valid_action?(:assign_and_revoke)
    end

    test "rejects unknown actions" do
      refute Permission.valid_action?(:unknown)
      refute Permission.valid_action?(:hack)
    end
  end

  describe "valid_resource?/1" do
    test "validates known resources" do
      assert Permission.valid_resource?(:collections)
      assert Permission.valid_resource?(:data)
      assert Permission.valid_resource?(:tenants)
      assert Permission.valid_resource?(:roles)
      assert Permission.valid_resource?(:users)
      assert Permission.valid_resource?(:groups)
      assert Permission.valid_resource?(:cluster)
      assert Permission.valid_resource?(:nodes)
      assert Permission.valid_resource?(:backups)
    end

    test "rejects unknown resources" do
      refute Permission.valid_resource?(:unknown)
      refute Permission.valid_resource?(:secrets)
    end
  end

  describe "struct fields" do
    test "permission has all required fields" do
      perm = %Permission{}

      assert Map.has_key?(perm, :action)
      assert Map.has_key?(perm, :resource)
      assert Map.has_key?(perm, :scope)
    end
  end
end
