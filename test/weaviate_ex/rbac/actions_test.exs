defmodule WeaviateEx.RBAC.ActionsTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.RBAC.Actions

  describe "to_api_string/2" do
    test "converts collections actions to API strings" do
      assert Actions.to_api_string(:collections, :create) == "create_collections"
      assert Actions.to_api_string(:collections, :read) == "read_collections"
      assert Actions.to_api_string(:collections, :update) == "update_collections"
      assert Actions.to_api_string(:collections, :delete) == "delete_collections"
      assert Actions.to_api_string(:collections, :manage) == "manage_collections"
    end

    test "converts data actions to API strings" do
      assert Actions.to_api_string(:data, :create) == "create_data"
      assert Actions.to_api_string(:data, :read) == "read_data"
      assert Actions.to_api_string(:data, :update) == "update_data"
      assert Actions.to_api_string(:data, :delete) == "delete_data"
      assert Actions.to_api_string(:data, :manage) == "manage_data"
    end

    test "converts tenants actions to API strings" do
      assert Actions.to_api_string(:tenants, :create) == "create_tenants"
      assert Actions.to_api_string(:tenants, :read) == "read_tenants"
      assert Actions.to_api_string(:tenants, :update) == "update_tenants"
      assert Actions.to_api_string(:tenants, :delete) == "delete_tenants"
    end

    test "converts roles actions to API strings" do
      assert Actions.to_api_string(:roles, :create) == "create_roles"
      assert Actions.to_api_string(:roles, :read) == "read_roles"
      assert Actions.to_api_string(:roles, :update) == "update_roles"
      assert Actions.to_api_string(:roles, :delete) == "delete_roles"
    end

    test "converts users actions to API strings" do
      assert Actions.to_api_string(:users, :create) == "create_users"
      assert Actions.to_api_string(:users, :read) == "read_users"
      assert Actions.to_api_string(:users, :update) == "update_users"
      assert Actions.to_api_string(:users, :delete) == "delete_users"
      assert Actions.to_api_string(:users, :assign_and_revoke) == "assign_and_revoke_users"
    end

    test "converts groups actions to API strings" do
      assert Actions.to_api_string(:groups, :read) == "read_groups"
      assert Actions.to_api_string(:groups, :assign_and_revoke) == "assign_and_revoke_groups"
    end

    test "converts cluster actions to API strings" do
      assert Actions.to_api_string(:cluster, :read) == "read_cluster"
    end

    test "converts nodes actions to API strings" do
      assert Actions.to_api_string(:nodes, :read) == "read_nodes"
    end

    test "converts backups actions to API strings" do
      assert Actions.to_api_string(:backups, :manage) == "manage_backups"
    end

    test "converts replicate actions to API strings" do
      assert Actions.to_api_string(:replicate, :create) == "create_replicate"
      assert Actions.to_api_string(:replicate, :read) == "read_replicate"
      assert Actions.to_api_string(:replicate, :update) == "update_replicate"
      assert Actions.to_api_string(:replicate, :delete) == "delete_replicate"
    end

    test "converts alias actions to API strings" do
      assert Actions.to_api_string(:alias, :create) == "create_alias"
      assert Actions.to_api_string(:alias, :read) == "read_alias"
      assert Actions.to_api_string(:alias, :update) == "update_alias"
      assert Actions.to_api_string(:alias, :delete) == "delete_alias"
    end
  end

  describe "from_api_string/1" do
    test "parses collections action strings" do
      assert Actions.from_api_string("create_collections") == {:ok, {:collections, :create}}
      assert Actions.from_api_string("read_collections") == {:ok, {:collections, :read}}
      assert Actions.from_api_string("update_collections") == {:ok, {:collections, :update}}
      assert Actions.from_api_string("delete_collections") == {:ok, {:collections, :delete}}
      assert Actions.from_api_string("manage_collections") == {:ok, {:collections, :manage}}
    end

    test "parses data action strings" do
      assert Actions.from_api_string("create_data") == {:ok, {:data, :create}}
      assert Actions.from_api_string("read_data") == {:ok, {:data, :read}}
      assert Actions.from_api_string("update_data") == {:ok, {:data, :update}}
      assert Actions.from_api_string("delete_data") == {:ok, {:data, :delete}}
      assert Actions.from_api_string("manage_data") == {:ok, {:data, :manage}}
    end

    test "parses users action strings" do
      assert Actions.from_api_string("assign_and_revoke_users") ==
               {:ok, {:users, :assign_and_revoke}}
    end

    test "parses groups action strings" do
      assert Actions.from_api_string("assign_and_revoke_groups") ==
               {:ok, {:groups, :assign_and_revoke}}
    end

    test "returns error for unknown action strings" do
      assert {:error, _} = Actions.from_api_string("unknown_action")
      assert {:error, _} = Actions.from_api_string("invalid")
    end
  end

  describe "round-trip conversions" do
    test "all actions round-trip correctly" do
      all_actions = [
        {:collections, :create},
        {:collections, :read},
        {:collections, :update},
        {:collections, :delete},
        {:collections, :manage},
        {:data, :create},
        {:data, :read},
        {:data, :update},
        {:data, :delete},
        {:data, :manage},
        {:tenants, :create},
        {:tenants, :read},
        {:tenants, :update},
        {:tenants, :delete},
        {:roles, :create},
        {:roles, :read},
        {:roles, :update},
        {:roles, :delete},
        {:users, :create},
        {:users, :read},
        {:users, :update},
        {:users, :delete},
        {:users, :assign_and_revoke},
        {:groups, :read},
        {:groups, :assign_and_revoke},
        {:cluster, :read},
        {:nodes, :read},
        {:backups, :manage},
        {:replicate, :create},
        {:replicate, :read},
        {:replicate, :update},
        {:replicate, :delete},
        {:alias, :create},
        {:alias, :read},
        {:alias, :update},
        {:alias, :delete}
      ]

      for {type, action} <- all_actions do
        api_string = Actions.to_api_string(type, action)
        assert {:ok, {^type, ^action}} = Actions.from_api_string(api_string)
      end
    end
  end

  describe "valid_action?/2" do
    test "returns true for valid actions" do
      assert Actions.valid_action?(:collections, :create) == true
      assert Actions.valid_action?(:collections, :manage) == true
      assert Actions.valid_action?(:data, :read) == true
      assert Actions.valid_action?(:users, :assign_and_revoke) == true
      assert Actions.valid_action?(:nodes, :read) == true
      assert Actions.valid_action?(:backups, :manage) == true
    end

    test "returns false for invalid actions" do
      assert Actions.valid_action?(:collections, :invalid) == false
      assert Actions.valid_action?(:data, :manage_invalid) == false
      assert Actions.valid_action?(:unknown_type, :read) == false
      assert Actions.valid_action?(:nodes, :delete) == false
      assert Actions.valid_action?(:cluster, :update) == false
    end
  end

  describe "actions_for_type/1" do
    test "returns actions for collections" do
      assert Actions.actions_for_type(:collections) == [:create, :read, :update, :delete, :manage]
    end

    test "returns actions for data" do
      assert Actions.actions_for_type(:data) == [:create, :read, :update, :delete, :manage]
    end

    test "returns actions for tenants" do
      assert Actions.actions_for_type(:tenants) == [:create, :read, :update, :delete]
    end

    test "returns actions for roles" do
      assert Actions.actions_for_type(:roles) == [:create, :read, :update, :delete]
    end

    test "returns actions for users" do
      assert Actions.actions_for_type(:users) == [
               :create,
               :read,
               :update,
               :delete,
               :assign_and_revoke
             ]
    end

    test "returns actions for groups" do
      assert Actions.actions_for_type(:groups) == [:read, :assign_and_revoke]
    end

    test "returns actions for cluster" do
      assert Actions.actions_for_type(:cluster) == [:read]
    end

    test "returns actions for nodes" do
      assert Actions.actions_for_type(:nodes) == [:read]
    end

    test "returns actions for backups" do
      assert Actions.actions_for_type(:backups) == [:manage]
    end

    test "returns actions for replicate" do
      assert Actions.actions_for_type(:replicate) == [:create, :read, :update, :delete]
    end

    test "returns actions for alias" do
      assert Actions.actions_for_type(:alias) == [:create, :read, :update, :delete]
    end

    test "returns empty list for unknown type" do
      assert Actions.actions_for_type(:unknown) == []
    end
  end
end
