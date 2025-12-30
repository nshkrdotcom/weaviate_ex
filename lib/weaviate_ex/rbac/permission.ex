defmodule WeaviateEx.RBAC.Permission do
  @moduledoc """
  Represents a single permission in Weaviate RBAC.

  A permission defines what action can be performed on which resources.
  Permissions are composed of:

  - **type** - The resource type (collections, data, tenants, etc.)
  - **action** - The allowed action (create, read, update, delete, manage, etc.)
  - **filters** - Optional restrictions on the permission scope

  ## Filters by Type

  | Type | Available Filters |
  |------|-------------------|
  | collections | collection |
  | data | collection, tenant, object |
  | tenants | collection, tenant |
  | roles | role |
  | users | user |
  | groups | group |
  | nodes | verbosity (:minimal or :verbose) |
  | cluster | (none) |
  | backups | (none) |
  | replicate | collection |
  | alias | (none) |

  ## Examples

      # Simple permission
      Permission.new(:collections, :read)

      # Permission with collection filter
      Permission.new(:data, :create, collection: "Article")

      # Permission with multiple filters
      Permission.new(:data, :read, collection: "Article", tenant: "tenant-a")

      # Nodes permission with verbosity
      Permission.new(:nodes, :read, verbosity: :verbose)
  """

  alias WeaviateEx.RBAC.Actions

  @type permission_type :: Actions.permission_type()
  @type action :: Actions.action()
  @type verbosity :: :minimal | :verbose
  @type role_scope :: :match | :all

  @type t :: %__MODULE__{
          type: permission_type(),
          action: action(),
          collection: String.t() | nil,
          tenant: String.t() | nil,
          object: String.t() | nil,
          role: String.t() | nil,
          user: String.t() | nil,
          group: String.t() | nil,
          verbosity: verbosity() | nil,
          scope: role_scope() | nil
        }

  defstruct [
    :type,
    :action,
    :collection,
    :tenant,
    :object,
    :role,
    :user,
    :group,
    :verbosity,
    :scope
  ]

  @doc """
  Create a new permission with the given type, action, and optional filters.

  ## Parameters

    * `type` - Permission type (e.g., :collections, :data, :tenants)
    * `action` - Action to allow (e.g., :create, :read, :update, :delete, :manage)
    * `opts` - Optional filters:
      * `:collection` - Filter by collection name
      * `:tenant` - Filter by tenant name
      * `:object` - Filter by object UUID
      * `:role` - Filter by role name
      * `:user` - Filter by user ID
      * `:group` - Filter by group name
      * `:verbosity` - For nodes permission: :minimal or :verbose
      * `:scope` - For roles permission: :match or :all

  ## Examples

      Permission.new(:collections, :read)
      Permission.new(:data, :create, collection: "Article", tenant: "tenant-a")
      Permission.new(:nodes, :read, verbosity: :verbose)
      Permission.new(:roles, :read, role: "admin", scope: :match)
  """
  @spec new(permission_type(), action(), keyword()) :: t()
  def new(type, action, opts \\ []) do
    %__MODULE__{
      type: type,
      action: action,
      collection: Keyword.get(opts, :collection),
      tenant: Keyword.get(opts, :tenant),
      object: Keyword.get(opts, :object),
      role: Keyword.get(opts, :role),
      user: Keyword.get(opts, :user),
      group: Keyword.get(opts, :group),
      verbosity: Keyword.get(opts, :verbosity),
      scope: Keyword.get(opts, :scope)
    }
  end

  @doc """
  Encode a permission to the Weaviate API format.

  ## Examples

      permission = Permission.new(:data, :read, collection: "Article")
      Permission.to_api(permission)
      # => %{"action" => "read_data", "collection" => "Article"}
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = permission) do
    base = %{
      "action" => Actions.to_api_string(permission.type, permission.action)
    }

    base
    |> maybe_put("collection", permission.collection)
    |> maybe_put("tenant", permission.tenant)
    |> maybe_put("object", permission.object)
    |> maybe_put("role", permission.role)
    |> maybe_put("user", permission.user)
    |> maybe_put("group", permission.group)
    |> maybe_put_verbosity(permission.verbosity)
    |> maybe_put_scope(permission.scope)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_verbosity(map, nil), do: map

  defp maybe_put_verbosity(map, verbosity) do
    Map.put(map, "verbosity", to_string(verbosity))
  end

  defp maybe_put_scope(map, nil), do: map

  defp maybe_put_scope(map, scope) do
    Map.put(map, "scope", to_string(scope))
  end

  @doc """
  Decode a permission from the Weaviate API response format.

  ## Examples

      {:ok, permission} = Permission.from_api(%{
        "action" => "read_data",
        "collection" => "Article"
      })
  """
  @spec from_api(map()) :: {:ok, t()} | {:error, String.t()}
  def from_api(api_data) when is_map(api_data) do
    action_string = Map.get(api_data, "action")

    case Actions.from_api_string(action_string) do
      {:ok, {type, action}} ->
        permission = %__MODULE__{
          type: type,
          action: action,
          collection: Map.get(api_data, "collection"),
          tenant: Map.get(api_data, "tenant"),
          object: Map.get(api_data, "object"),
          role: Map.get(api_data, "role"),
          user: Map.get(api_data, "user"),
          group: Map.get(api_data, "group"),
          verbosity: parse_verbosity(Map.get(api_data, "verbosity")),
          scope: parse_scope(Map.get(api_data, "scope"))
        }

        {:ok, permission}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_verbosity(nil), do: nil
  defp parse_verbosity("minimal"), do: :minimal
  defp parse_verbosity("verbose"), do: :verbose
  defp parse_verbosity(other) when is_atom(other), do: other

  defp parse_scope(nil), do: nil
  defp parse_scope("match"), do: :match
  defp parse_scope("all"), do: :all
  defp parse_scope(other) when is_atom(other), do: other
end
