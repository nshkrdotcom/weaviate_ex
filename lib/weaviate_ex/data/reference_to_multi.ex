defmodule WeaviateEx.Data.ReferenceToMulti do
  @moduledoc """
  Multi-target reference specification.

  Use this when you have a reference property that can point to
  multiple different collections (multi-target reference).

  ## Examples

      # Single target in a multi-target property
      ref = ReferenceToMulti.new("Category", "cat-uuid")

      # Multiple targets
      ref = ReferenceToMulti.new("Category", ["uuid1", "uuid2"])

      # Use with References API
      References.add(client, "Article", source_uuid, "relatedTo",
        ReferenceToMulti.to_map(ref))
  """

  @type t :: %__MODULE__{
          target_collection: String.t(),
          uuids: String.t() | [String.t()]
        }

  defstruct [:target_collection, :uuids]

  @doc """
  Create a new multi-target reference.

  ## Parameters

    - `target_collection` - The target collection name
    - `uuids` - Single UUID or list of UUIDs

  ## Examples

      ReferenceToMulti.new("Category", "cat-uuid")
      ReferenceToMulti.new("Category", ["uuid1", "uuid2"])
  """
  @spec new(String.t(), String.t() | [String.t()]) :: t()
  def new(target_collection, uuids) when is_binary(target_collection) do
    %__MODULE__{
      target_collection: target_collection,
      uuids: uuids
    }
  end

  @doc """
  Convert to beacon format for API requests.

  Returns a list of beacon maps suitable for the Weaviate API.

  ## Examples

      ref = ReferenceToMulti.new("Category", "cat-uuid")
      ReferenceToMulti.to_beacons(ref)
      # => [%{"beacon" => "weaviate://localhost/Category/cat-uuid"}]
  """
  @spec to_beacons(t()) :: [map()]
  def to_beacons(%__MODULE__{target_collection: col, uuids: uuids}) do
    uuids
    |> List.wrap()
    |> Enum.map(fn uuid ->
      %{"beacon" => "weaviate://localhost/#{col}/#{uuid}"}
    end)
  end

  @doc """
  Convert to map format for use with References API.

  ## Examples

      ref = ReferenceToMulti.new("Category", "cat-uuid")
      ReferenceToMulti.to_map(ref)
      # => %{target_collection: "Category", uuids: "cat-uuid"}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = ref) do
    %{
      target_collection: ref.target_collection,
      uuids: ref.uuids
    }
  end
end
