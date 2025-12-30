defmodule WeaviateEx.Cluster.ShardingState do
  @moduledoc """
  Represents the sharding state of a collection.

  Contains information about which shards exist and their replica nodes.

  ## Examples

      %ShardingState{
        collection: "Article",
        shards: [
          %ShardReplicas{name: "shard-0", replicas: ["node-0", "node-1"]},
          %ShardReplicas{name: "shard-1", replicas: ["node-1", "node-2"]}
        ]
      }
  """

  alias __MODULE__.ShardReplicas

  @type t :: %__MODULE__{
          collection: String.t(),
          shards: [ShardReplicas.t()]
        }

  defstruct [:collection, :shards]

  @doc """
  Parse sharding state from API response.

  ## Examples

      iex> ShardingState.from_api(%{
      ...>   "shardingState" => %{
      ...>     "collection" => "Article",
      ...>     "shards" => [%{"shard" => "shard-0", "replicas" => ["node-0"]}]
      ...>   }
      ...> })
      %ShardingState{collection: "Article", shards: [%ShardReplicas{name: "shard-0", replicas: ["node-0"]}]}
  """
  @spec from_api(map()) :: t()
  def from_api(%{"shardingState" => %{"collection" => collection, "shards" => shards}}) do
    %__MODULE__{
      collection: collection,
      shards: Enum.map(shards, &ShardReplicas.from_api/1)
    }
  end

  def from_api(%{"collection" => collection, "shards" => shards}) do
    %__MODULE__{
      collection: collection,
      shards: Enum.map(shards, &ShardReplicas.from_api/1)
    }
  end

  defmodule ShardReplicas do
    @moduledoc """
    Represents a shard and its replica nodes.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            replicas: [String.t()]
          }

    defstruct [:name, :replicas]

    @doc """
    Parse shard replicas from API response.
    """
    @spec from_api(map()) :: t()
    def from_api(%{"shard" => name, "replicas" => replicas}) do
      %__MODULE__{name: name, replicas: replicas}
    end

    def from_api(%{"name" => name, "replicas" => replicas}) do
      %__MODULE__{name: name, replicas: replicas}
    end
  end
end
