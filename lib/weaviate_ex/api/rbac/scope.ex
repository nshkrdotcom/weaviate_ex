defmodule WeaviateEx.API.RBAC.Scope do
  @moduledoc """
  Role scope permissions for fine-grained RBAC.

  Scopes define the boundary of permissions, allowing you to restrict
  access to specific collections, tenants, or shards.

  ## Examples

      # All collections
      scope = Scope.all_collections()

      # Single collection
      scope = Scope.collection("Article")

      # Multiple collections
      scope = Scope.collections(["Article", "Author"])

      # Collection with tenant restriction
      scope =
        Scope.collection("Article")
        |> Scope.with_tenants(["tenant-a", "tenant-b"])

      # Use in permission
      perm = Permission.new(:read, :data, scope: scope)
  """

  @type t :: %__MODULE__{
          collections: [String.t()] | :all | nil,
          tenants: [String.t()] | :all | nil,
          shards: [String.t()] | :all | nil
        }

  defstruct collections: nil,
            tenants: nil,
            shards: nil

  @doc """
  Creates a new scope with the given options.

  ## Options

  - `:collections` - List of collection names or `:all`
  - `:tenants` - List of tenant names or `:all`
  - `:shards` - List of shard names or `:all`

  ## Examples

      Scope.new(collections: :all)
      Scope.new(collections: ["Article"], tenants: ["tenant-a"])
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      collections: Keyword.get(opts, :collections),
      tenants: Keyword.get(opts, :tenants),
      shards: Keyword.get(opts, :shards)
    }
  end

  @doc """
  Creates a scope matching all collections.

  ## Example

      Scope.all_collections()
  """
  @spec all_collections() :: t()
  def all_collections do
    %__MODULE__{collections: :all}
  end

  @doc """
  Creates a scope for a single collection.

  ## Example

      Scope.collection("Article")
  """
  @spec collection(String.t()) :: t()
  def collection(name) when is_binary(name) do
    %__MODULE__{collections: [name]}
  end

  @doc """
  Creates a scope for multiple collections.

  ## Example

      Scope.collections(["Article", "Author", "Comment"])
  """
  @spec collections([String.t()]) :: t()
  def collections(names) when is_list(names) do
    %__MODULE__{collections: names}
  end

  @doc """
  Adds tenant restrictions to a scope.

  ## Examples

      Scope.collection("Article")
      |> Scope.with_tenants(["tenant-a"])

      Scope.collection("Article")
      |> Scope.with_tenants(:all)
  """
  @spec with_tenants(t(), [String.t()] | :all) :: t()
  def with_tenants(%__MODULE__{} = scope, tenants) do
    %{scope | tenants: tenants}
  end

  @doc """
  Adds shard restrictions to a scope.

  ## Example

      Scope.collection("Article")
      |> Scope.with_shards(["shard-0", "shard-1"])
  """
  @spec with_shards(t(), [String.t()] | :all) :: t()
  def with_shards(%__MODULE__{} = scope, shards) do
    %{scope | shards: shards}
  end

  @doc """
  Converts a scope to API format.

  ## Examples

      Scope.all_collections() |> Scope.to_api()
      # => %{"collection" => "*"}

      Scope.collection("Article") |> Scope.to_api()
      # => %{"collection" => "Article"}
  """
  @spec to_api(t() | nil) :: map()
  def to_api(nil), do: %{}

  def to_api(%__MODULE__{} = scope) do
    %{}
    |> add_collections_to_api(scope.collections)
    |> add_tenants_to_api(scope.tenants)
    |> add_shards_to_api(scope.shards)
  end

  @doc """
  Parses a scope from API response.

  ## Example

      Scope.from_api(%{"collection" => "Article", "tenant" => "tenant-a"})
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(api) when api == %{}, do: nil

  def from_api(api) when is_map(api) do
    %__MODULE__{
      collections: parse_collections(api),
      tenants: parse_tenants(api),
      shards: parse_shards(api)
    }
  end

  # Private helpers

  defp add_collections_to_api(api, nil), do: api
  defp add_collections_to_api(api, :all), do: Map.put(api, "collection", "*")

  defp add_collections_to_api(api, [name]) when is_binary(name),
    do: Map.put(api, "collection", name)

  defp add_collections_to_api(api, names) when is_list(names) and length(names) > 1 do
    Map.put(api, "collections", names)
  end

  defp add_tenants_to_api(api, nil), do: api
  defp add_tenants_to_api(api, :all), do: Map.put(api, "tenant", "*")
  defp add_tenants_to_api(api, [name]) when is_binary(name), do: Map.put(api, "tenant", name)
  defp add_tenants_to_api(api, names) when is_list(names), do: Map.put(api, "tenants", names)

  defp add_shards_to_api(api, nil), do: api
  defp add_shards_to_api(api, :all), do: Map.put(api, "shard", "*")
  defp add_shards_to_api(api, [name]) when is_binary(name), do: Map.put(api, "shard", name)
  defp add_shards_to_api(api, names) when is_list(names), do: Map.put(api, "shards", names)

  defp parse_collections(api) do
    cond do
      Map.get(api, "collection") == "*" -> :all
      name = Map.get(api, "collection") -> [name]
      names = Map.get(api, "collections") -> names
      true -> nil
    end
  end

  defp parse_tenants(api) do
    cond do
      Map.get(api, "tenant") == "*" -> :all
      name = Map.get(api, "tenant") -> [name]
      names = Map.get(api, "tenants") -> names
      true -> nil
    end
  end

  defp parse_shards(api) do
    cond do
      Map.get(api, "shard") == "*" -> :all
      name = Map.get(api, "shard") -> [name]
      names = Map.get(api, "shards") -> names
      true -> nil
    end
  end
end
