defmodule WeaviateEx.RBAC.PermissionsTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.RBAC.Permission
  alias WeaviateEx.RBAC.Permissions

  describe "collections/2" do
    test "creates single action permission" do
      permission = Permissions.collections("Article", :read)

      assert %Permission{} = permission
      assert permission.type == :collections
      assert permission.action == :read
      assert permission.collection == "Article"
    end

    test "creates multiple action permissions" do
      permissions = Permissions.collections("Article", [:create, :read, :update])

      assert length(permissions) == 3
      assert Enum.all?(permissions, fn p -> p.type == :collections end)
      assert Enum.all?(permissions, fn p -> p.collection == "Article" end)
      assert Enum.map(permissions, & &1.action) == [:create, :read, :update]
    end

    test "uses wildcard for all collections" do
      permission = Permissions.collections(:all, :read)

      assert permission.collection == "*"
    end

    test "defaults to wildcard when no collection specified" do
      permission = Permissions.collections(:read)

      assert permission.collection == "*"
      assert permission.action == :read
    end
  end

  describe "data/3" do
    test "creates data permission with single action" do
      permission = Permissions.data("Product", :read)

      assert permission.type == :data
      assert permission.action == :read
      assert permission.collection == "Product"
    end

    test "creates data permissions with multiple actions" do
      permissions = Permissions.data("Product", [:create, :read])

      assert length(permissions) == 2
      assert Enum.all?(permissions, fn p -> p.type == :data end)
    end

    test "creates data permission with tenant option" do
      permission = Permissions.data("Product", :read, tenant: "tenant-a")

      assert permission.tenant == "tenant-a"
    end

    test "creates data permission with object option" do
      permission = Permissions.data("Product", :update, object: "uuid-123")

      assert permission.object == "uuid-123"
    end

    test "creates data permission with both tenant and object" do
      permission = Permissions.data("Product", :delete, tenant: "tenant-a", object: "uuid-123")

      assert permission.tenant == "tenant-a"
      assert permission.object == "uuid-123"
    end

    test "uses wildcard tenant" do
      permission = Permissions.data("Product", :read, tenant: :all)

      assert permission.tenant == "*"
    end

    test "defaults to wildcard collection" do
      permission = Permissions.data(:read)

      assert permission.collection == "*"
    end
  end

  describe "tenants/3" do
    test "creates tenants permission" do
      permission = Permissions.tenants("MyCollection", :create)

      assert permission.type == :tenants
      assert permission.action == :create
      assert permission.collection == "MyCollection"
    end

    test "creates tenants permission with tenant filter" do
      permission = Permissions.tenants("MyCollection", :read, tenant: "tenant-a")

      assert permission.tenant == "tenant-a"
    end

    test "creates multiple tenant permissions" do
      permissions = Permissions.tenants("MyCollection", [:create, :read, :delete])

      assert length(permissions) == 3
    end
  end

  describe "roles/2" do
    test "creates roles permission" do
      permission = Permissions.roles("admin", :read)

      assert permission.type == :roles
      assert permission.action == :read
      assert permission.role == "admin"
    end

    test "creates roles permissions with multiple actions" do
      permissions = Permissions.roles(:all, [:create, :read, :delete])

      assert length(permissions) == 3
      assert Enum.all?(permissions, fn p -> p.role == "*" end)
    end
  end

  describe "users/2" do
    test "creates users permission" do
      permission = Permissions.users("john", :read)

      assert permission.type == :users
      assert permission.action == :read
      assert permission.user == "john"
    end

    test "creates users permissions with assign_and_revoke action" do
      permission = Permissions.users(:all, :assign_and_revoke)

      assert permission.action == :assign_and_revoke
      assert permission.user == "*"
    end
  end

  describe "groups/2" do
    test "creates groups permission" do
      permission = Permissions.groups("engineering", :read)

      assert permission.type == :groups
      assert permission.action == :read
      assert permission.group == "engineering"
    end

    test "creates groups permission with assign_and_revoke" do
      permission = Permissions.groups(:all, :assign_and_revoke)

      assert permission.action == :assign_and_revoke
      assert permission.group == "*"
    end
  end

  describe "cluster/1" do
    test "creates cluster read permission" do
      permission = Permissions.cluster(:read)

      assert permission.type == :cluster
      assert permission.action == :read
    end

    test "defaults to read action" do
      permission = Permissions.cluster()

      assert permission.action == :read
    end
  end

  describe "nodes/1" do
    test "creates nodes permission with verbose verbosity" do
      permission = Permissions.nodes(:verbose)

      assert permission.type == :nodes
      assert permission.action == :read
      assert permission.verbosity == :verbose
    end

    test "creates nodes permission with minimal verbosity" do
      permission = Permissions.nodes(:minimal)

      assert permission.verbosity == :minimal
    end

    test "defaults to minimal verbosity" do
      permission = Permissions.nodes()

      assert permission.verbosity == :minimal
    end
  end

  describe "backups/1" do
    test "creates backups manage permission" do
      permission = Permissions.backups(:manage)

      assert permission.type == :backups
      assert permission.action == :manage
    end

    test "defaults to manage action" do
      permission = Permissions.backups()

      assert permission.action == :manage
    end
  end

  describe "replicate/2" do
    test "creates replicate permission" do
      permission = Permissions.replicate("Article", :create)

      assert permission.type == :replicate
      assert permission.action == :create
      assert permission.collection == "Article"
    end

    test "creates multiple replicate permissions" do
      permissions = Permissions.replicate(:all, [:create, :read])

      assert length(permissions) == 2
      assert Enum.all?(permissions, fn p -> p.collection == "*" end)
    end
  end

  describe "alias_permission/2" do
    test "creates alias permission" do
      permission = Permissions.alias_permission("my-alias", :create)

      assert permission.type == :alias
      assert permission.action == :create
    end

    test "creates multiple alias permissions" do
      permissions = Permissions.alias_permission(:all, [:create, :read, :delete])

      assert length(permissions) == 3
    end
  end

  describe "all permission builders return valid Permission structs" do
    test "all builders return Permission structs" do
      permissions = [
        Permissions.collections("A", :read),
        Permissions.data("A", :read),
        Permissions.tenants("A", :read),
        Permissions.roles("r", :read),
        Permissions.users("u", :read),
        Permissions.groups("g", :read),
        Permissions.cluster(),
        Permissions.nodes(),
        Permissions.backups(),
        Permissions.replicate("A", :read),
        Permissions.alias_permission("a", :read)
      ]

      assert Enum.all?(permissions, fn p -> is_struct(p, Permission) end)
    end

    test "all permissions can be encoded to API format" do
      permissions = [
        Permissions.collections("Article", :read),
        Permissions.data("Product", :create, tenant: "tenant-a"),
        Permissions.tenants("Collection", :delete),
        Permissions.roles("admin", :update),
        Permissions.users("john", :assign_and_revoke),
        Permissions.groups("engineering", :read),
        Permissions.cluster(),
        Permissions.nodes(:verbose),
        Permissions.backups(),
        Permissions.replicate("Article", :create),
        Permissions.alias_permission("my-alias", :delete)
      ]

      for permission <- permissions do
        api = Permission.to_api(permission)
        assert is_map(api)
        assert Map.has_key?(api, "action")
      end
    end
  end

  describe "flatten/1" do
    test "flattens nested permission lists" do
      nested = [
        Permissions.collections("A", [:read, :update]),
        Permissions.data("B", :create),
        [Permissions.cluster(), Permissions.nodes()]
      ]

      flat = Permissions.flatten(nested)

      assert length(flat) == 5
      assert Enum.all?(flat, fn p -> is_struct(p, Permission) end)
    end

    test "handles single permission" do
      single = Permissions.collections("A", :read)

      flat = Permissions.flatten(single)

      assert length(flat) == 1
    end
  end
end
