defmodule WeaviateEx.Cluster.Node do
  @moduledoc """
  Represents a node in the Weaviate cluster.

  Nodes are the individual servers that make up a Weaviate cluster.
  Each node can host shards from multiple collections.

  ## Node Status Values

  - `:healthy` - Node is operating normally
  - `:unhealthy` - Node is experiencing issues
  - `:unavailable` - Node cannot be reached

  ## Examples

      %Node{
        name: "node-0",
        status: :healthy,
        version: "1.24.0",
        shards: [%Shard{...}]
      }
  """

  alias WeaviateEx.Cluster.Shard

  @type status :: :healthy | :unhealthy | :unavailable

  @type t :: %__MODULE__{
          name: String.t(),
          status: status(),
          version: String.t() | nil,
          git_hash: String.t() | nil,
          stats: map() | nil,
          shards: [Shard.t()] | nil
        }

  defstruct [:name, :status, :version, :git_hash, :stats, :shards]

  @doc """
  Parse node from API response.

  ## Examples

      iex> Node.from_api(%{"name" => "node-0", "status" => "HEALTHY", "version" => "1.24.0"})
      %Node{name: "node-0", status: :healthy, version: "1.24.0"}
  """
  @spec from_api(map()) :: t()
  def from_api(map) when is_map(map) do
    %__MODULE__{
      name: Map.get(map, "name"),
      status: parse_status(Map.get(map, "status", "HEALTHY")),
      version: Map.get(map, "version"),
      git_hash: Map.get(map, "gitHash"),
      stats: parse_stats(Map.get(map, "stats")),
      shards: parse_shards(Map.get(map, "shards"))
    }
  end

  @doc """
  Parse status string to atom.

  ## Examples

      iex> Node.parse_status("HEALTHY")
      :healthy

      iex> Node.parse_status("UNHEALTHY")
      :unhealthy
  """
  @spec parse_status(String.t()) :: status()
  def parse_status("HEALTHY"), do: :healthy
  def parse_status("UNHEALTHY"), do: :unhealthy
  def parse_status("UNAVAILABLE"), do: :unavailable
  def parse_status(_), do: :unavailable

  @doc """
  Convert status atom to API string.

  ## Examples

      iex> Node.status_to_api(:healthy)
      "HEALTHY"
  """
  @spec status_to_api(status()) :: String.t()
  def status_to_api(:healthy), do: "HEALTHY"
  def status_to_api(:unhealthy), do: "UNHEALTHY"
  def status_to_api(:unavailable), do: "UNAVAILABLE"

  @doc """
  Check if node is healthy.

  ## Examples

      iex> Node.healthy?(%Node{status: :healthy})
      true

      iex> Node.healthy?(%Node{status: :unhealthy})
      false
  """
  @spec healthy?(t()) :: boolean()
  def healthy?(%__MODULE__{status: :healthy}), do: true
  def healthy?(_), do: false

  @doc """
  Get total object count across all shards on this node.

  Returns 0 if no shard information is available.

  ## Examples

      iex> node = %Node{shards: [%Shard{object_count: 100}, %Shard{object_count: 200}]}
      iex> Node.total_object_count(node)
      300
  """
  @spec total_object_count(t()) :: non_neg_integer()
  def total_object_count(%__MODULE__{shards: nil}), do: 0

  def total_object_count(%__MODULE__{shards: shards}) do
    Enum.reduce(shards, 0, fn shard, acc -> acc + shard.object_count end)
  end

  @doc """
  Get shards for a specific collection on this node.

  ## Examples

      iex> Node.shards_for_collection(node, "Article")
      [%Shard{collection: "Article", ...}]
  """
  @spec shards_for_collection(t(), String.t()) :: [Shard.t()]
  def shards_for_collection(%__MODULE__{shards: nil}, _collection), do: []

  def shards_for_collection(%__MODULE__{shards: shards}, collection) do
    Enum.filter(shards, fn shard -> shard.collection == collection end)
  end

  # Private helpers

  defp parse_stats(nil), do: nil
  defp parse_stats(stats) when is_map(stats), do: stats

  defp parse_shards(nil), do: nil

  defp parse_shards(shards) when is_list(shards) do
    Enum.map(shards, &Shard.from_api/1)
  end
end
