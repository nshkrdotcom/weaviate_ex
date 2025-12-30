defmodule WeaviateEx.RBAC.Permissions do
  @moduledoc """
  Builder API for constructing RBAC permissions.

  This module provides a fluent API for creating permissions that can be assigned
  to roles. Each builder function returns either a single `Permission` struct or
  a list of `Permission` structs (when multiple actions are specified).

  ## Examples

      # Full access to a collection
      Permissions.collections("Article", [:create, :read, :update, :delete])

      # Read data from specific tenant
      Permissions.data("Article", :read, tenant: "tenant-a")

      # Manage all backups
      Permissions.backups(:manage)

      # Verbose node info
      Permissions.nodes(:verbose)

      # Multiple permissions for a role
      permissions = [
        Permissions.collections("Article", [:read, :update]),
        Permissions.data("Article", [:read, :create]),
        Permissions.cluster()
      ]

  ## Wildcards

  Use `:all` to create permissions that apply to all resources:

      Permissions.collections(:all, :read)  # Read all collections
      Permissions.data(:all, :read)         # Read data from all collections
      Permissions.users(:all, :read)        # Read all users
  """

  alias WeaviateEx.RBAC.Permission

  @type actions :: atom() | [atom()]
  @type collection_or_all :: String.t() | :all
  @type name_or_all :: String.t() | :all

  @doc """
  Create collections permission(s).

  ## Parameters

    * `collection` - Collection name or `:all` for wildcard. Defaults to `"*"`.
    * `actions` - Single action atom or list of actions

  ## Examples

      Permissions.collections("Article", :read)
      Permissions.collections("Article", [:create, :read, :update])
      Permissions.collections(:all, :manage)
      Permissions.collections(:read)  # All collections, single action
  """
  @spec collections(actions()) :: Permission.t() | [Permission.t()]
  @spec collections(collection_or_all(), actions()) :: Permission.t() | [Permission.t()]
  def collections(actions) when is_atom(actions) or is_list(actions) do
    collections("*", actions)
  end

  def collections(collection, actions) do
    collection_name = normalize_wildcard(collection)
    build_permissions(:collections, actions, collection: collection_name)
  end

  @doc """
  Create data permission(s).

  ## Parameters

    * `collection` - Collection name or `:all` for wildcard. Defaults to `"*"`.
    * `actions` - Single action atom or list of actions
    * `opts` - Optional filters:
      * `:tenant` - Filter by tenant (or `:all` for wildcard)
      * `:object` - Filter by object UUID

  ## Examples

      Permissions.data("Article", :read)
      Permissions.data("Article", :read, tenant: "tenant-a")
      Permissions.data("Article", [:create, :update], tenant: :all)
  """
  @spec data(actions()) :: Permission.t() | [Permission.t()]
  @spec data(collection_or_all(), actions()) :: Permission.t() | [Permission.t()]
  @spec data(collection_or_all(), actions(), keyword()) :: Permission.t() | [Permission.t()]
  def data(actions) when is_atom(actions) or is_list(actions) do
    data("*", actions, [])
  end

  def data(collection, actions) when is_atom(actions) or is_list(actions) do
    data(collection, actions, [])
  end

  def data(collection, actions, opts) do
    collection_name = normalize_wildcard(collection)
    tenant = normalize_wildcard(Keyword.get(opts, :tenant))
    object = Keyword.get(opts, :object)

    build_permissions(:data, actions, collection: collection_name, tenant: tenant, object: object)
  end

  @doc """
  Create tenants permission(s).

  ## Parameters

    * `collection` - Collection name or `:all` for wildcard. Defaults to `"*"`.
    * `actions` - Single action atom or list of actions
    * `opts` - Optional filters:
      * `:tenant` - Filter by specific tenant

  ## Examples

      Permissions.tenants("MyCollection", :create)
      Permissions.tenants("MyCollection", [:create, :read, :delete])
      Permissions.tenants(:all, :read, tenant: "tenant-a")
  """
  @spec tenants(actions()) :: Permission.t() | [Permission.t()]
  @spec tenants(collection_or_all(), actions()) :: Permission.t() | [Permission.t()]
  @spec tenants(collection_or_all(), actions(), keyword()) :: Permission.t() | [Permission.t()]
  def tenants(actions) when is_atom(actions) or is_list(actions) do
    tenants("*", actions, [])
  end

  def tenants(collection, actions) when is_atom(actions) or is_list(actions) do
    tenants(collection, actions, [])
  end

  def tenants(collection, actions, opts) do
    collection_name = normalize_wildcard(collection)
    tenant = normalize_wildcard(Keyword.get(opts, :tenant))

    build_permissions(:tenants, actions, collection: collection_name, tenant: tenant)
  end

  @doc """
  Create roles permission(s).

  ## Parameters

    * `role` - Role name or `:all` for wildcard. Defaults to `"*"`.
    * `actions` - Single action atom or list of actions
    * `opts` - Optional filters:
      * `:scope` - Permission scope: `:match` or `:all`

  ## Examples

      Permissions.roles("admin", :read)
      Permissions.roles(:all, [:create, :read, :delete])
      Permissions.roles("admin", :read, scope: :match)
      Permissions.roles("*", :manage, scope: :all)
  """
  @spec roles(actions()) :: Permission.t() | [Permission.t()]
  @spec roles(name_or_all(), actions()) :: Permission.t() | [Permission.t()]
  @spec roles(name_or_all(), actions(), keyword()) :: Permission.t() | [Permission.t()]
  def roles(actions) when is_atom(actions) or is_list(actions) do
    roles("*", actions, [])
  end

  def roles(role, actions) when is_atom(actions) or is_list(actions) do
    roles(role, actions, [])
  end

  def roles(role, actions, opts) do
    role_name = normalize_wildcard(role)
    scope = Keyword.get(opts, :scope)
    build_permissions(:roles, actions, role: role_name, scope: scope)
  end

  @doc """
  Create users permission(s).

  ## Parameters

    * `user` - User ID or `:all` for wildcard. Defaults to `"*"`.
    * `actions` - Single action atom or list of actions

  ## Examples

      Permissions.users("john", :read)
      Permissions.users(:all, :assign_and_revoke)
  """
  @spec users(actions()) :: Permission.t() | [Permission.t()]
  @spec users(name_or_all(), actions()) :: Permission.t() | [Permission.t()]
  def users(actions) when is_atom(actions) or is_list(actions) do
    users("*", actions)
  end

  def users(user, actions) do
    user_name = normalize_wildcard(user)
    build_permissions(:users, actions, user: user_name)
  end

  @doc """
  Create groups permission(s) (OIDC groups).

  ## Parameters

    * `group` - Group name or `:all` for wildcard. Defaults to `"*"`.
    * `actions` - Single action atom or list of actions

  ## Examples

      Permissions.groups("engineering", :read)
      Permissions.groups(:all, :assign_and_revoke)
  """
  @spec groups(actions()) :: Permission.t() | [Permission.t()]
  @spec groups(name_or_all(), actions()) :: Permission.t() | [Permission.t()]
  def groups(actions) when is_atom(actions) or is_list(actions) do
    groups("*", actions)
  end

  def groups(group, actions) do
    group_name = normalize_wildcard(group)
    build_permissions(:groups, actions, group: group_name)
  end

  @doc """
  Create cluster permission.

  ## Parameters

    * `action` - Action atom (typically `:read`). Defaults to `:read`.

  ## Examples

      Permissions.cluster()
      Permissions.cluster(:read)
  """
  @spec cluster() :: Permission.t()
  @spec cluster(atom()) :: Permission.t()
  def cluster(action \\ :read) do
    Permission.new(:cluster, action)
  end

  @doc """
  Create nodes permission.

  ## Parameters

    * `verbosity` - `:minimal` or `:verbose`. Defaults to `:minimal`.
    * `opts` - Optional keyword list:
      - `:collection` - Filter to specific collection (only valid with `:verbose`)

  ## Examples

      Permissions.nodes()          # Minimal verbosity
      Permissions.nodes(:minimal)
      Permissions.nodes(:verbose)

      # With collection filter (verbose only)
      Permissions.nodes(:verbose, collection: "Article")
  """
  @spec nodes() :: Permission.t()
  @spec nodes(:minimal | :verbose) :: Permission.t()
  @spec nodes(:minimal | :verbose, keyword()) :: Permission.t()
  def nodes(verbosity \\ :minimal, opts \\ [])

  def nodes(verbosity, opts) when is_atom(verbosity) and is_list(opts) do
    collection = Keyword.get(opts, :collection)

    if collection && verbosity == :verbose do
      Permission.new(:nodes, :read, verbosity: verbosity, collection: collection)
    else
      Permission.new(:nodes, :read, verbosity: verbosity)
    end
  end

  @doc """
  Create backups permission.

  ## Parameters

    * `action` - Action atom (typically `:manage`). Defaults to `:manage`.

  ## Examples

      Permissions.backups()
      Permissions.backups(:manage)
  """
  @spec backups() :: Permission.t()
  @spec backups(atom()) :: Permission.t()
  def backups(action \\ :manage) do
    Permission.new(:backups, action)
  end

  @doc """
  Create replicate permission(s).

  ## Parameters

    * `collection` - Collection name or `:all` for wildcard. Defaults to `"*"`.
    * `actions` - Single action atom or list of actions

  ## Examples

      Permissions.replicate("Article", :create)
      Permissions.replicate(:all, [:create, :read])
  """
  @spec replicate(actions()) :: Permission.t() | [Permission.t()]
  @spec replicate(collection_or_all(), actions()) :: Permission.t() | [Permission.t()]
  def replicate(actions) when is_atom(actions) or is_list(actions) do
    replicate("*", actions)
  end

  def replicate(collection, actions) do
    collection_name = normalize_wildcard(collection)
    build_permissions(:replicate, actions, collection: collection_name)
  end

  @doc """
  Create alias permission(s).

  Named `alias_permission` because `alias` is a reserved word in Elixir.

  ## Parameters

    * `alias_name` - Alias name or `:all` for wildcard. Defaults to `"*"`.
    * `actions` - Single action atom or list of actions

  ## Examples

      Permissions.alias_permission("my-alias", :create)
      Permissions.alias_permission(:all, [:create, :read, :delete])
  """
  @spec alias_permission(actions()) :: Permission.t() | [Permission.t()]
  @spec alias_permission(name_or_all(), actions()) :: Permission.t() | [Permission.t()]
  def alias_permission(actions) when is_atom(actions) or is_list(actions) do
    alias_permission("*", actions)
  end

  def alias_permission(_alias_name, actions) do
    # Alias permissions don't have a specific filter, just the action
    # The alias_name is unused as the API doesn't support filtering by alias name
    build_permissions(:alias, actions, [])
  end

  @doc """
  Flatten a nested structure of permissions into a single list.

  Useful when combining multiple permission builders.

  ## Examples

      nested = [
        Permissions.collections("A", [:read, :update]),
        [Permissions.cluster(), Permissions.nodes()]
      ]
      Permissions.flatten(nested)
      # => [%Permission{}, %Permission{}, %Permission{}, %Permission{}]
  """
  @spec flatten(Permission.t() | [Permission.t() | [Permission.t()]]) :: [Permission.t()]
  def flatten(%Permission{} = permission), do: [permission]

  def flatten(permissions) when is_list(permissions) do
    List.flatten(permissions)
  end

  # Private helpers

  defp normalize_wildcard(:all), do: "*"
  defp normalize_wildcard(nil), do: nil
  defp normalize_wildcard(value), do: value

  defp build_permissions(type, actions, opts) when is_list(actions) do
    Enum.map(actions, fn action ->
      Permission.new(type, action, opts)
    end)
  end

  defp build_permissions(type, action, opts) when is_atom(action) do
    Permission.new(type, action, opts)
  end
end
