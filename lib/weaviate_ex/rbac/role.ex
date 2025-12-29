defmodule WeaviateEx.RBAC.Role do
  @moduledoc """
  Represents a role in Weaviate RBAC.

  A role is a named collection of permissions that can be assigned to users or groups.
  Roles provide a convenient way to manage access control by grouping related permissions.

  ## Examples

      # Create a role with permissions
      permissions = [
        Permissions.collections("Article", [:read, :update]),
        Permissions.data("Article", [:read, :create, :update])
      ]
      role = Role.new("article-editor", permissions)

      # Add more permissions
      role = Role.add_permissions(role, [Permissions.nodes(:verbose)])

      # Check if role has a permission
      Role.has_permission?(role, Permissions.data("Article", :read))
      # => true
  """

  alias WeaviateEx.RBAC.Permission
  alias WeaviateEx.RBAC.Permissions

  @type t :: %__MODULE__{
          name: String.t(),
          permissions: [Permission.t()]
        }

  defstruct [:name, permissions: []]

  @doc """
  Create a new role with the given name and optional permissions.

  Permissions can be a single permission, a list of permissions, or nested lists
  (which will be flattened).

  ## Parameters

    * `name` - The role name
    * `permissions` - Optional list of permissions (default: [])

  ## Examples

      Role.new("reader")
      Role.new("editor", [Permissions.data("Article", [:read, :update])])
  """
  @spec new(String.t(), Permission.t() | [Permission.t()] | []) :: t()
  def new(name, permissions \\ []) do
    %__MODULE__{
      name: name,
      permissions: Permissions.flatten(permissions)
    }
  end

  @doc """
  Encode a role to the Weaviate API format.

  ## Examples

      role = Role.new("my-role", [Permissions.data("A", :read)])
      Role.to_api(role)
      # => %{"name" => "my-role", "permissions" => [%{"action" => "read_data", ...}]}
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = role) do
    %{
      "name" => role.name,
      "permissions" => Enum.map(role.permissions, &Permission.to_api/1)
    }
  end

  @doc """
  Decode a role from the Weaviate API response format.

  ## Examples

      {:ok, role} = Role.from_api(%{
        "name" => "my-role",
        "permissions" => [%{"action" => "read_data", "collection" => "Article"}]
      })
  """
  @spec from_api(map()) :: {:ok, t()} | {:error, String.t()}
  def from_api(api_data) when is_map(api_data) do
    name = Map.get(api_data, "name")
    raw_permissions = Map.get(api_data, "permissions", [])

    case decode_permissions(raw_permissions) do
      {:ok, permissions} ->
        {:ok, %__MODULE__{name: name, permissions: permissions}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_permissions(raw_permissions) do
    results =
      Enum.reduce_while(raw_permissions, {:ok, []}, fn perm_data, {:ok, acc} ->
        case Permission.from_api(perm_data) do
          {:ok, permission} -> {:cont, {:ok, [permission | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case results do
      {:ok, permissions} -> {:ok, Enum.reverse(permissions)}
      error -> error
    end
  end

  @doc """
  Add permissions to an existing role.

  ## Examples

      role = Role.new("my-role")
      role = Role.add_permissions(role, [Permissions.data("A", :read)])
  """
  @spec add_permissions(t(), Permission.t() | [Permission.t()]) :: t()
  def add_permissions(%__MODULE__{} = role, permissions) do
    new_permissions = Permissions.flatten(permissions)
    %{role | permissions: role.permissions ++ new_permissions}
  end

  @doc """
  Remove permissions from a role.

  Permissions are matched by content equality (same type, action, and filters).

  ## Examples

      perm = Permissions.data("A", :read)
      role = Role.new("my-role", [perm])
      role = Role.remove_permissions(role, [perm])
  """
  @spec remove_permissions(t(), Permission.t() | [Permission.t()]) :: t()
  def remove_permissions(%__MODULE__{} = role, permissions) do
    to_remove = Permissions.flatten(permissions)

    remaining =
      Enum.reject(role.permissions, fn existing ->
        Enum.any?(to_remove, fn removing -> permission_equals?(existing, removing) end)
      end)

    %{role | permissions: remaining}
  end

  @doc """
  Check if a role has a specific permission.

  ## Examples

      perm = Permissions.data("Article", :read)
      role = Role.new("reader", [perm])
      Role.has_permission?(role, perm)
      # => true
  """
  @spec has_permission?(t(), Permission.t()) :: boolean()
  def has_permission?(%__MODULE__{} = role, %Permission{} = permission) do
    Enum.any?(role.permissions, fn existing ->
      permission_equals?(existing, permission)
    end)
  end

  defp permission_equals?(%Permission{} = a, %Permission{} = b) do
    a.type == b.type &&
      a.action == b.action &&
      a.collection == b.collection &&
      a.tenant == b.tenant &&
      a.object == b.object &&
      a.role == b.role &&
      a.user == b.user &&
      a.group == b.group &&
      a.verbosity == b.verbosity
  end
end
