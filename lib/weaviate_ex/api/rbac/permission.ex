defmodule WeaviateEx.API.RBAC.Permission do
  @moduledoc """
  Permission definitions for RBAC.

  Permissions define what actions can be taken on what resources,
  optionally scoped to specific collections, tenants, or shards.

  ## Actions

  - `:create` - Create new resources
  - `:read` - Read/view resources
  - `:update` - Modify existing resources
  - `:delete` - Delete resources
  - `:manage` - Full control (create, read, update, delete)
  - `:assign_and_revoke` - Assign/revoke roles (for users/groups)

  ## Resources

  - `:collections` - Collection schema operations
  - `:data` - Object CRUD operations
  - `:tenants` - Multi-tenancy management
  - `:roles` - Role management
  - `:users` - User management
  - `:groups` - OIDC group management
  - `:cluster` - Cluster information
  - `:nodes` - Node information
  - `:backups` - Backup operations

  ## Examples

      # Basic permission
      perm = Permission.new(:read, :collections)

      # Permission with scope
      perm = Permission.new(:read, :data, collection: "Article")

      # Convenience constructors
      perm = Permission.read_collection("Article")
      perm = Permission.manage_data("Article")

      # Admin permissions
      perms = Permission.admin()
  """

  alias WeaviateEx.API.RBAC.Scope

  @type action :: :create | :read | :update | :delete | :manage | :assign_and_revoke
  @type resource ::
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

  @type t :: %__MODULE__{
          action: action(),
          resource: resource(),
          scope: Scope.t() | nil
        }

  defstruct action: nil,
            resource: nil,
            scope: nil

  @valid_actions [:create, :read, :update, :delete, :manage, :assign_and_revoke]
  @valid_resources [
    :collections,
    :data,
    :tenants,
    :roles,
    :users,
    :groups,
    :cluster,
    :nodes,
    :backups,
    :replicate,
    :alias
  ]

  @doc """
  Creates a new permission.

  ## Options

  - `:scope` - A `Scope` struct to restrict the permission
  - `:collection` - Shorthand to create a collection scope
  - `:tenant` - Shorthand to add a tenant to the scope

  ## Examples

      Permission.new(:read, :collections)
      Permission.new(:read, :data, scope: Scope.collection("Article"))
      Permission.new(:read, :data, collection: "Article", tenant: "tenant-a")
  """
  @spec new(action(), resource(), keyword()) :: t()
  def new(action, resource, opts \\ []) do
    scope = build_scope(opts)

    %__MODULE__{
      action: action,
      resource: resource,
      scope: scope
    }
  end

  @doc """
  Creates a read permission for a collection schema.
  """
  @spec read_collection(String.t()) :: t()
  def read_collection(name) do
    new(:read, :collections, collection: name)
  end

  @doc """
  Creates a manage permission for a collection schema.
  """
  @spec manage_collection(String.t()) :: t()
  def manage_collection(name) do
    new(:manage, :collections, collection: name)
  end

  @doc """
  Creates a read permission for data in a collection.
  """
  @spec read_data(String.t()) :: t()
  def read_data(name) do
    new(:read, :data, collection: name)
  end

  @doc """
  Creates a manage permission for data in a collection.
  """
  @spec manage_data(String.t()) :: t()
  def manage_data(name) do
    new(:manage, :data, collection: name)
  end

  @doc """
  Creates a create permission for data in a collection.
  """
  @spec create_data(String.t()) :: t()
  def create_data(name) do
    new(:create, :data, collection: name)
  end

  @doc """
  Creates an update permission for data in a collection.
  """
  @spec update_data(String.t()) :: t()
  def update_data(name) do
    new(:update, :data, collection: name)
  end

  @doc """
  Creates a delete permission for data in a collection.
  """
  @spec delete_data(String.t()) :: t()
  def delete_data(name) do
    new(:delete, :data, collection: name)
  end

  @doc """
  Returns a list of permissions for full admin access.
  """
  @spec admin() :: [t()]
  def admin do
    [
      new(:manage, :collections, scope: Scope.all_collections()),
      new(:manage, :data, scope: Scope.all_collections()),
      new(:manage, :tenants, scope: Scope.all_collections()),
      new(:manage, :roles),
      new(:manage, :users),
      new(:manage, :backups),
      new(:read, :cluster),
      new(:read, :nodes)
    ]
  end

  @doc """
  Returns a list of permissions for read-only access.
  """
  @spec viewer() :: [t()]
  def viewer do
    [
      new(:read, :collections, scope: Scope.all_collections()),
      new(:read, :data, scope: Scope.all_collections()),
      new(:read, :cluster),
      new(:read, :nodes)
    ]
  end

  @doc """
  Converts a permission to API format.

  ## Example

      Permission.read_collection("Article") |> Permission.to_api()
      # => %{"action" => "read_collections", "collection" => "Article"}
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{action: action, resource: resource, scope: scope}) do
    base = %{"action" => action_to_api(action, resource)}

    case scope do
      nil -> base
      %Scope{} -> Map.merge(base, Scope.to_api(scope))
    end
  end

  @doc """
  Parses a permission from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"action" => action_str} = api) do
    {action, resource} = action_from_api(action_str)

    scope = build_scope_from_api(api)

    %__MODULE__{
      action: action,
      resource: resource,
      scope: scope
    }
  end

  @doc """
  Converts an action and resource to API string format.

  ## Examples

      action_to_api(:read, :collections)
      # => "read_collections"
  """
  @spec action_to_api(action(), resource()) :: String.t()
  def action_to_api(action, resource) do
    "#{action}_#{resource}"
  end

  @doc """
  Parses an action string from API format.

  ## Examples

      action_from_api("read_collections")
      # => {:read, :collections}
  """
  @spec action_from_api(String.t()) :: {action(), resource()}
  def action_from_api(action_str) when is_binary(action_str) do
    # Handle special cases like "assign_and_revoke_users"
    if String.starts_with?(action_str, "assign_and_revoke_") do
      resource = String.replace_prefix(action_str, "assign_and_revoke_", "")
      {:assign_and_revoke, String.to_atom(resource)}
    else
      [action | rest] = String.split(action_str, "_", parts: 2)
      resource = Enum.join(rest, "_")
      {String.to_atom(action), String.to_atom(resource)}
    end
  end

  @doc """
  Checks if an action is valid.
  """
  @spec valid_action?(atom()) :: boolean()
  def valid_action?(action), do: action in @valid_actions

  @doc """
  Checks if a resource is valid.
  """
  @spec valid_resource?(atom()) :: boolean()
  def valid_resource?(resource), do: resource in @valid_resources

  # Private helpers

  defp build_scope(opts) do
    scope = Keyword.get(opts, :scope)
    collection = Keyword.get(opts, :collection)
    tenant = Keyword.get(opts, :tenant)

    cond do
      scope != nil ->
        scope

      collection != nil ->
        base = Scope.collection(collection)

        if tenant do
          Scope.with_tenants(base, [tenant])
        else
          base
        end

      true ->
        nil
    end
  end

  defp build_scope_from_api(api) do
    # Check if there are any scope-related fields
    has_scope =
      Map.has_key?(api, "collection") or
        Map.has_key?(api, "collections") or
        Map.has_key?(api, "tenant") or
        Map.has_key?(api, "tenants") or
        Map.has_key?(api, "shard") or
        Map.has_key?(api, "shards")

    if has_scope do
      Scope.from_api(api)
    else
      nil
    end
  end
end
