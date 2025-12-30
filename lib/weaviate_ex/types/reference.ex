defmodule WeaviateEx.Types.Reference do
  @moduledoc """
  Cross-reference handling with multi-target vector support.

  Represents a reference to another object in Weaviate, supporting both
  simple references and multi-target references for named vectors.

  ## Simple Reference

      ref = Reference.to("Author", "uuid-123")
      # => %Reference{beacon: "weaviate://localhost/Author/uuid-123"}

  ## Multi-Target Reference

  When using named vectors, you can specify which target vectors to use:

      ref = Reference.multi_target("Author", "uuid-123", ["title_vector", "content_vector"])
      # => %Reference{beacon: "...", target_vectors: ["title_vector", "content_vector"]}
  """

  @type t :: %__MODULE__{
          beacon: String.t(),
          target_collection: String.t() | nil,
          target_vectors: list(String.t())
        }

  defstruct [:beacon, :target_collection, target_vectors: []]

  alias WeaviateEx.Types.{Beacon, UUID}

  @doc """
  Creates a reference to an object.

  ## Options

  - `:target_vectors` - List of named vectors to use (for multi-target references)

  ## Examples

      Reference.to("Author", "uuid-123")
      # => %Reference{beacon: "weaviate://localhost/Author/uuid-123"}

      Reference.to("Author", "uuid-123", target_vectors: ["title_vector"])
      # => %Reference{beacon: "...", target_vectors: ["title_vector"]}
  """
  @spec to(String.t(), String.t(), keyword()) :: t()
  def to(collection, id, opts \\ []) when is_binary(collection) and is_binary(id) do
    %__MODULE__{
      beacon: "weaviate://localhost/#{collection}/#{id}",
      target_collection: collection,
      target_vectors: Keyword.get(opts, :target_vectors, [])
    }
  end

  @doc """
  Creates a multi-target reference specifying which named vectors to use.

  Use this when you need to specify target vectors for ref2vec-centroid
  or other multi-vector scenarios.

  ## Examples

      Reference.multi_target("Author", "uuid-123", ["title_vector", "content_vector"])
  """
  @spec multi_target(String.t(), String.t(), list(String.t())) :: t()
  def multi_target(collection, id, target_vectors)
      when is_binary(collection) and is_binary(id) and is_list(target_vectors) do
    %__MODULE__{
      beacon: "weaviate://localhost/#{collection}/#{id}",
      target_collection: collection,
      target_vectors: target_vectors
    }
  end

  @doc """
  Creates a reference from a beacon URL string.

  Automatically extracts and populates the target collection from the beacon.

  ## Examples

      Reference.from_beacon("weaviate://localhost/Author/uuid-123")
      # => %Reference{beacon: "weaviate://localhost/Author/uuid-123", target_collection: "Author"}

      Reference.from_beacon("weaviate://localhost/uuid-123")
      # => %Reference{beacon: "weaviate://localhost/uuid-123", target_collection: nil}
  """
  @spec from_beacon(String.t()) :: t()
  def from_beacon(beacon) when is_binary(beacon) do
    parsed = Beacon.parse(beacon)

    %__MODULE__{
      beacon: beacon,
      target_collection: parsed.collection
    }
  end

  @doc """
  Converts the reference to a map for the Weaviate API.

  ## Examples

      ref = Reference.to("Author", "uuid-123")
      Reference.to_map(ref)
      # => %{"beacon" => "weaviate://localhost/Author/uuid-123"}

      ref = Reference.multi_target("Author", "uuid-123", ["title_vector"])
      Reference.to_map(ref)
      # => %{"beacon" => "...", "targetVectors" => ["title_vector"]}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = ref) do
    base = %{"beacon" => ref.beacon}

    if ref.target_vectors != [] do
      Map.put(base, "targetVectors", ref.target_vectors)
    else
      base
    end
  end

  @doc """
  Creates a Reference from a map (e.g., from API response).

  Automatically extracts the target collection from the beacon.

  ## Examples

      Reference.from_map(%{"beacon" => "weaviate://localhost/Author/uuid-123"})
      # => %Reference{beacon: "...", target_collection: "Author", target_vectors: []}

      Reference.from_map(%{"beacon" => "weaviate://localhost/uuid-123"})
      # => %Reference{beacon: "...", target_collection: nil, target_vectors: []}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"beacon" => beacon} = map) do
    parsed = Beacon.parse(beacon)

    %__MODULE__{
      beacon: beacon,
      target_collection: parsed.collection,
      target_vectors: Map.get(map, "targetVectors", [])
    }
  end

  @doc """
  Extracts the object ID from the reference beacon.

  ## Examples

      ref = Reference.to("Author", "uuid-123")
      Reference.extract_id(ref)
      # => {:ok, "uuid-123"}
  """
  @spec extract_id(t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_id(%__MODULE__{beacon: beacon}) do
    case UUID.extract_from_beacon(beacon) do
      {:ok, id} -> {:ok, id}
      {:error, _} = error -> error
    end
  end

  @doc """
  Extracts the collection name from the reference beacon.

  ## Examples

      ref = Reference.to("Author", "uuid-123")
      Reference.extract_collection(ref)
      # => {:ok, "Author"}
  """
  @spec extract_collection(t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_collection(%__MODULE__{target_collection: collection})
      when is_binary(collection) and collection != "" do
    {:ok, collection}
  end

  def extract_collection(%__MODULE__{beacon: beacon}) do
    case String.split(beacon, "/") do
      ["weaviate:", "", "localhost", collection, _id] when collection != "" ->
        {:ok, collection}

      _ ->
        {:error, "Unable to extract collection from beacon: #{beacon}"}
    end
  end
end
