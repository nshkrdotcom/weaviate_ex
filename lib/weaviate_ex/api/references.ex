defmodule WeaviateEx.API.References do
  @moduledoc """
  Cross-reference operations for Weaviate objects.

  Provides CRUD operations for managing relationships between objects.

  ## Examples

      # Add a single reference
      References.add(client, "Article", source_uuid, "hasAuthor", author_uuid)

      # Add a multi-target reference using map
      References.add(client, "Article", source_uuid, "relatedTo", %{
        target_collection: "Category",
        uuids: category_uuid
      })

      # Add a multi-target reference using ReferenceToMulti struct
      ref = ReferenceToMulti.new("Category", category_uuid)
      References.add(client, "Article", source_uuid, "relatedTo", ref)

      # Delete a reference
      References.delete(client, "Article", source_uuid, "hasAuthor", author_uuid)

      # Replace all references on a property
      References.replace(client, "Article", source_uuid, "hasAuthors", [uuid1, uuid2, uuid3])

      # Replace with multi-target references
      References.replace(client, "Article", source_uuid, "relatedTo", [
        ReferenceToMulti.new("Person", person_uuid),
        ReferenceToMulti.new("Organization", org_uuid)
      ])

      # Batch add references
      References.add_many(client, "Article", [
        %{from_uuid: "article-1", from_property: "hasAuthor", to_uuid: "author-1"},
        %{from_uuid: "article-2", from_property: "hasAuthor", to_uuid: "author-2"}
      ])
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Data.ReferenceToMulti
  alias WeaviateEx.Error

  @type uuid :: String.t()
  @type reference_input :: uuid() | reference_to_multi() | ReferenceToMulti.t()
  @type reference_to_multi :: %{
          target_collection: String.t(),
          uuids: uuid() | [uuid()]
        }
  @type data_reference :: %{
          :from_uuid => uuid(),
          :from_property => String.t(),
          :to_uuid => uuid(),
          optional(:target_collection) => String.t()
        }

  @doc """
  Add a reference from one object to another.

  ## Parameters

    - `client` - The Weaviate client
    - `collection` - The source collection name
    - `from_uuid` - UUID of the source object
    - `from_property` - Name of the reference property
    - `to` - Target UUID or multi-target reference
    - `opts` - Additional options (tenant, etc.)

  ## Examples

      # Single target reference
      References.add(client, "Article", source_uuid, "hasAuthor", target_uuid)

      # Multi-target reference
      References.add(client, "Article", source_uuid, "relatedTo", %{
        target_collection: "Category",
        uuids: category_uuid
      })
  """
  @spec add(Client.t(), String.t(), uuid(), String.t(), reference_input(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def add(client, collection, from_uuid, from_property, to, opts \\ []) do
    path = "/v1/objects/#{collection}/#{from_uuid}/references/#{from_property}"
    beacon = build_beacon(to)

    Client.request(client, :post, path, beacon, opts)
  end

  @doc """
  Delete a reference from an object.

  ## Parameters

    - `client` - The Weaviate client
    - `collection` - The source collection name
    - `from_uuid` - UUID of the source object
    - `from_property` - Name of the reference property
    - `to` - Target UUID or multi-target reference to delete
    - `opts` - Additional options

  ## Examples

      References.delete(client, "Article", source_uuid, "hasAuthor", target_uuid)
  """
  @spec delete(Client.t(), String.t(), uuid(), String.t(), reference_input(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete(client, collection, from_uuid, from_property, to, opts \\ []) do
    path = "/v1/objects/#{collection}/#{from_uuid}/references/#{from_property}"
    beacon = build_beacon(to)

    Client.request(client, :delete, path, beacon, opts)
  end

  @doc """
  Replace all references on a property.

  This removes all existing references and sets the new ones.

  ## Parameters

    - `client` - The Weaviate client
    - `collection` - The source collection name
    - `from_uuid` - UUID of the source object
    - `from_property` - Name of the reference property
    - `references` - List of target UUIDs or multi-target references
    - `opts` - Additional options

  ## Examples

      References.replace(client, "Article", source_uuid, "hasAuthors", [uuid1, uuid2, uuid3])
  """
  @spec replace(Client.t(), String.t(), uuid(), String.t(), [reference_input()], keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def replace(client, collection, from_uuid, from_property, references, opts \\ []) do
    path = "/v1/objects/#{collection}/#{from_uuid}/references/#{from_property}"
    beacons = Enum.flat_map(references, &build_beacons/1)

    Client.request(client, :put, path, beacons, opts)
  end

  @doc """
  Add multiple references in batch.

  ## Parameters

    - `client` - The Weaviate client
    - `collection` - The source collection name
    - `references` - List of reference specifications
    - `opts` - Additional options

  ## Reference specification

  Each reference should be a map with:
    - `:from_uuid` - UUID of the source object
    - `:from_property` - Name of the reference property
    - `:to_uuid` - Target UUID
    - `:target_collection` - (optional) Target collection for multi-target refs

  ## Examples

      references = [
        %{from_uuid: "article-1", from_property: "hasAuthor", to_uuid: "author-1"},
        %{from_uuid: "article-2", from_property: "hasAuthor", to_uuid: "author-2"}
      ]
      References.add_many(client, "Article", references)
  """
  @spec add_many(Client.t(), String.t(), [data_reference()], keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def add_many(client, collection, references, opts \\ []) do
    batch_refs =
      Enum.map(references, fn ref ->
        %{
          "from" => "weaviate://localhost/#{collection}/#{ref.from_uuid}/#{ref.from_property}",
          "to" => build_beacon_url(ref.to_uuid, ref[:target_collection])
        }
      end)

    Client.request(client, :post, "/v1/batch/references", batch_refs, opts)
  end

  # Private helpers

  defp build_beacon(uuid) when is_binary(uuid) do
    %{"beacon" => "weaviate://localhost/#{uuid}"}
  end

  defp build_beacon(%ReferenceToMulti{} = ref) do
    ReferenceToMulti.to_beacons(ref)
    |> case do
      [single] -> single
      beacons -> beacons
    end
  end

  defp build_beacon(%{target_collection: collection, uuids: uuid}) when is_binary(uuid) do
    %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
  end

  defp build_beacon(%{target_collection: collection, uuids: uuids}) when is_list(uuids) do
    Enum.map(uuids, fn uuid ->
      %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
    end)
  end

  defp build_beacons(ref) do
    case build_beacon(ref) do
      beacons when is_list(beacons) -> beacons
      beacon -> [beacon]
    end
  end

  defp build_beacon_url(uuid, nil), do: "weaviate://localhost/#{uuid}"
  defp build_beacon_url(uuid, collection), do: "weaviate://localhost/#{collection}/#{uuid}"
end
