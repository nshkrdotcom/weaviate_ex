defmodule WeaviateEx.RBAC.Actions do
  @moduledoc """
  Permission action types for Weaviate RBAC.

  This module defines all supported actions for each permission type in Weaviate's
  RBAC system and provides conversion functions between Elixir atoms and API strings.

  ## Permission Types and Actions

  | Type | Actions |
  |------|---------|
  | collections | create, read, update, delete, manage |
  | data | create, read, update, delete, manage |
  | tenants | create, read, update, delete |
  | roles | create, read, update, delete |
  | users | create, read, update, delete, assign_and_revoke |
  | groups | read, assign_and_revoke |
  | cluster | read |
  | nodes | read |
  | backups | manage |
  | replicate | create, read, update, delete |
  | alias | create, read, update, delete |

  ## Examples

      iex> Actions.to_api_string(:collections, :create)
      "create_collections"

      iex> Actions.from_api_string("read_data")
      {:ok, {:data, :read}}

      iex> Actions.valid_action?(:users, :assign_and_revoke)
      true
  """

  @type permission_type ::
          :collections
          | :data
          | :tenants
          | :roles
          | :users
          | :groups
          | :cluster
          | :nodes
          | :backups
          | :replicate
          | :alias

  @type collections_action :: :create | :read | :update | :delete | :manage
  @type data_action :: :create | :read | :update | :delete | :manage
  @type tenants_action :: :create | :read | :update | :delete
  @type roles_action :: :create | :read | :update | :delete
  @type users_action :: :create | :read | :update | :delete | :assign_and_revoke
  @type groups_action :: :read | :assign_and_revoke
  @type cluster_action :: :read
  @type nodes_action :: :read
  @type backups_action :: :manage
  @type replicate_action :: :create | :read | :update | :delete
  @type alias_action :: :create | :read | :update | :delete

  @type action ::
          collections_action()
          | data_action()
          | tenants_action()
          | roles_action()
          | users_action()
          | groups_action()
          | cluster_action()
          | nodes_action()
          | backups_action()
          | replicate_action()
          | alias_action()

  # Define which actions are valid for each permission type
  @actions_by_type %{
    collections: [:create, :read, :update, :delete, :manage],
    data: [:create, :read, :update, :delete, :manage],
    tenants: [:create, :read, :update, :delete],
    roles: [:create, :read, :update, :delete],
    users: [:create, :read, :update, :delete, :assign_and_revoke],
    groups: [:read, :assign_and_revoke],
    cluster: [:read],
    nodes: [:read],
    backups: [:manage],
    replicate: [:create, :read, :update, :delete],
    alias: [:create, :read, :update, :delete]
  }

  @doc """
  Convert a permission type and action to the API string format.

  ## Examples

      iex> Actions.to_api_string(:collections, :create)
      "create_collections"

      iex> Actions.to_api_string(:users, :assign_and_revoke)
      "assign_and_revoke_users"
  """
  @spec to_api_string(permission_type(), action()) :: String.t()
  def to_api_string(type, action) do
    "#{action}_#{type}"
  end

  @doc """
  Parse an API string to permission type and action tuple.

  ## Examples

      iex> Actions.from_api_string("create_collections")
      {:ok, {:collections, :create}}

      iex> Actions.from_api_string("unknown_action")
      {:error, "Unknown action: unknown_action"}
  """
  @spec from_api_string(String.t()) :: {:ok, {permission_type(), action()}} | {:error, String.t()}
  def from_api_string(api_string) do
    # Handle special case: assign_and_revoke_* actions
    if String.starts_with?(api_string, "assign_and_revoke_") do
      type = String.replace_prefix(api_string, "assign_and_revoke_", "")
      parse_type_action(type, :assign_and_revoke)
    else
      # Split on first underscore for action_type pattern
      case String.split(api_string, "_", parts: 2) do
        [action_str, type] ->
          parse_type_action(type, String.to_atom(action_str))

        _ ->
          {:error, "Unknown action: #{api_string}"}
      end
    end
  end

  defp parse_type_action(type_str, action) do
    type = String.to_atom(type_str)

    if valid_action?(type, action) do
      {:ok, {type, action}}
    else
      {:error, "Unknown action: #{action}_#{type}"}
    end
  end

  @doc """
  Check if an action is valid for the given permission type.

  ## Examples

      iex> Actions.valid_action?(:collections, :create)
      true

      iex> Actions.valid_action?(:nodes, :delete)
      false
  """
  @spec valid_action?(permission_type(), action()) :: boolean()
  def valid_action?(type, action) do
    case Map.get(@actions_by_type, type) do
      nil -> false
      actions -> action in actions
    end
  end

  @doc """
  Get all valid actions for a permission type.

  ## Examples

      iex> Actions.actions_for_type(:collections)
      [:create, :read, :update, :delete, :manage]

      iex> Actions.actions_for_type(:cluster)
      [:read]
  """
  @spec actions_for_type(permission_type()) :: [action()]
  def actions_for_type(type) do
    Map.get(@actions_by_type, type, [])
  end

  @doc """
  Get all permission types.

  ## Examples

      iex> Actions.permission_types()
      [:collections, :data, :tenants, :roles, :users, :groups, :cluster, :nodes, :backups, :replicate, :alias]
  """
  @spec permission_types() :: [permission_type()]
  def permission_types do
    Map.keys(@actions_by_type)
  end
end
