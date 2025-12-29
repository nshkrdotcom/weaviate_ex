defmodule WeaviateEx.Cluster.Shard do
  @moduledoc """
  Represents a shard in a Weaviate collection.

  Shards are the unit of data distribution in Weaviate. Each collection
  can have multiple shards distributed across nodes.

  ## Shard Status Values

  - `:ready` - Shard is ready for queries
  - `:readonly` - Shard is in read-only mode
  - `:indexing` - Shard is building indexes
  - `:loading` - Shard is loading data

  ## Examples

      %Shard{
        name: "shard-0",
        collection: "Article",
        status: :ready,
        object_count: 1000,
        vector_queue_size: 0
      }
  """

  @type status :: :ready | :readonly | :indexing | :loading

  @type t :: %__MODULE__{
          name: String.t(),
          collection: String.t() | nil,
          status: status(),
          object_count: non_neg_integer(),
          vector_queue_size: non_neg_integer(),
          vector_indexing_status: String.t() | nil,
          compressed: boolean()
        }

  defstruct [
    :name,
    :collection,
    :status,
    :vector_indexing_status,
    object_count: 0,
    vector_queue_size: 0,
    compressed: false
  ]

  @doc """
  Parse shard from API response.

  ## Examples

      iex> Shard.from_api(%{"name" => "shard-0", "status" => "READY", "objectCount" => 100})
      %Shard{name: "shard-0", status: :ready, object_count: 100}
  """
  @spec from_api(map()) :: t()
  def from_api(map) when is_map(map) do
    %__MODULE__{
      name: Map.get(map, "name"),
      collection: Map.get(map, "class"),
      status: parse_status(Map.get(map, "status", "READY")),
      object_count: Map.get(map, "objectCount", 0),
      vector_queue_size: Map.get(map, "vectorQueueSize", 0),
      vector_indexing_status: Map.get(map, "vectorIndexingStatus"),
      compressed: Map.get(map, "compressed", false)
    }
  end

  @doc """
  Parse status string to atom.

  ## Examples

      iex> Shard.parse_status("READY")
      :ready

      iex> Shard.parse_status("INDEXING")
      :indexing
  """
  @spec parse_status(String.t()) :: status()
  def parse_status("READY"), do: :ready
  def parse_status("READONLY"), do: :readonly
  def parse_status("INDEXING"), do: :indexing
  def parse_status("LOADING"), do: :loading
  def parse_status(_), do: :ready

  @doc """
  Convert status atom to API string.

  ## Examples

      iex> Shard.status_to_api(:ready)
      "READY"
  """
  @spec status_to_api(status()) :: String.t()
  def status_to_api(:ready), do: "READY"
  def status_to_api(:readonly), do: "READONLY"
  def status_to_api(:indexing), do: "INDEXING"
  def status_to_api(:loading), do: "LOADING"

  @doc """
  Check if shard is ready for queries.

  A shard is considered ready when its status is `:ready` and there
  are no pending vectors in the indexing queue.

  ## Examples

      iex> Shard.ready?(%Shard{status: :ready, vector_queue_size: 0})
      true

      iex> Shard.ready?(%Shard{status: :ready, vector_queue_size: 100})
      false

      iex> Shard.ready?(%Shard{status: :indexing, vector_queue_size: 0})
      false
  """
  @spec ready?(t()) :: boolean()
  def ready?(%__MODULE__{status: :ready, vector_queue_size: 0}), do: true
  def ready?(_), do: false

  @doc """
  Check if vectors are fully indexed.

  Returns true when the vector queue is empty, meaning all vectors
  have been processed by the async indexing system.

  ## Examples

      iex> Shard.vectors_indexed?(%Shard{vector_queue_size: 0})
      true

      iex> Shard.vectors_indexed?(%Shard{vector_queue_size: 50})
      false
  """
  @spec vectors_indexed?(t()) :: boolean()
  def vectors_indexed?(%__MODULE__{vector_queue_size: 0}), do: true
  def vectors_indexed?(_), do: false
end
