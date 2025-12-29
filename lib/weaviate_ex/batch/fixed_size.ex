defmodule WeaviateEx.Batch.FixedSize do
  @moduledoc """
  Fixed-size batch processor for Weaviate batch operations.

  Collects objects into a buffer and splits them into fixed-size batches
  for sending to Weaviate.

  ## Examples

      # Create a batcher with batch size of 100
      batcher = FixedSize.new(batch_size: 100)

      # Add objects
      batcher =
        batcher
        |> FixedSize.add_object("Article", %{title: "Article 1"})
        |> FixedSize.add_object("Article", %{title: "Article 2"})

      # Get batches for sending
      batches = FixedSize.get_batches(batcher)

      # Send each batch
      Enum.each(batches, fn batch ->
        WeaviateEx.Batch.create_objects(client, batch)
      end)
  """

  alias WeaviateEx.Types.UUID

  @type batch_object :: %{
          collection: String.t(),
          properties: map(),
          uuid: String.t() | nil,
          vector: [float()] | nil,
          tenant: String.t() | nil
        }

  @type t :: %__MODULE__{
          batch_size: pos_integer(),
          concurrent_requests: pos_integer(),
          objects_buffer: [batch_object()],
          references_buffer: [map()]
        }

  defstruct batch_size: 100,
            concurrent_requests: 2,
            objects_buffer: [],
            references_buffer: []

  @doc """
  Create a new fixed-size batcher.

  ## Options

    - `:batch_size` - Number of objects per batch (default: 100)
    - `:concurrent_requests` - Number of concurrent requests (default: 2)

  ## Examples

      FixedSize.new()
      FixedSize.new(batch_size: 50, concurrent_requests: 4)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      batch_size: Keyword.get(opts, :batch_size, 100),
      concurrent_requests: Keyword.get(opts, :concurrent_requests, 2),
      objects_buffer: [],
      references_buffer: []
    }
  end

  @doc """
  Add an object to the batch buffer.

  UUID is auto-generated if not provided.

  ## Options

    - `:uuid` - Custom UUID for the object (auto-generated if not provided)
    - `:vector` - Custom vector for the object
    - `:tenant` - Tenant name for multi-tenant collections

  ## Examples

      # Auto-generate UUID
      batcher
      |> FixedSize.add_object("Article", %{title: "Test"})

      # With explicit UUID
      batcher
      |> FixedSize.add_object("Article", %{title: "Test 2"}, uuid: "custom-uuid")

      # Deterministic UUID from value
      uuid = WeaviateEx.Types.UUID.from_string("Article", "unique-id")
      batcher
      |> FixedSize.add_object("Article", %{title: "Test"}, uuid: uuid)
  """
  @spec add_object(t(), String.t(), map(), keyword()) :: t()
  def add_object(%__MODULE__{} = batcher, collection, properties, opts \\ []) do
    # Auto-generate UUID if not provided
    uuid = Keyword.get_lazy(opts, :uuid, fn -> UUID.generate() end)

    object = %{
      collection: collection,
      properties: properties,
      uuid: uuid,
      vector: Keyword.get(opts, :vector),
      tenant: Keyword.get(opts, :tenant)
    }

    %{batcher | objects_buffer: [object | batcher.objects_buffer]}
  end

  @doc """
  Add a reference to the batch buffer.

  Supports both single-target and multi-target references.

  ## Single Target

      batcher
      |> FixedSize.add_reference("Article", "uuid-1", "hasAuthor", "uuid-2")

  ## Multi-Target References

      batcher
      |> FixedSize.add_reference("Article", "uuid-1", "relatedTo", [
        %{collection: "Article", uuid: "related-uuid-1"},
        %{collection: "Video", uuid: "video-uuid-1"}
      ])

  ## Options

    - `:tenant` - Tenant name for multi-tenant collections
  """
  @spec add_reference(t(), String.t(), String.t(), String.t(), String.t() | [map()], keyword()) ::
          t()
  def add_reference(batcher, collection, from_uuid, property, to_target, opts \\ [])

  # Single target reference (existing behavior)
  def add_reference(%__MODULE__{} = batcher, collection, from_uuid, property, to_uuid, opts)
      when is_binary(to_uuid) do
    reference = %{
      collection: collection,
      from_uuid: from_uuid,
      property: property,
      to_uuid: to_uuid,
      to_collection: collection,
      tenant: Keyword.get(opts, :tenant)
    }

    %{batcher | references_buffer: [reference | batcher.references_buffer]}
  end

  # Multi-target references (new behavior)
  def add_reference(%__MODULE__{} = batcher, collection, from_uuid, property, targets, opts)
      when is_list(targets) do
    references =
      Enum.map(targets, fn target ->
        %{
          collection: collection,
          from_uuid: from_uuid,
          property: property,
          to_uuid: target.uuid,
          to_collection: target.collection,
          tenant: Keyword.get(opts, :tenant)
        }
      end)

    %{batcher | references_buffer: references ++ batcher.references_buffer}
  end

  @doc """
  Get batches of objects from the buffer.

  Returns a list of batches, each containing up to `batch_size` objects.
  The buffer order is preserved (first added = first in batch).
  """
  @spec get_batches(t()) :: [[batch_object()]]
  def get_batches(%__MODULE__{objects_buffer: []}), do: []

  def get_batches(%__MODULE__{} = batcher) do
    batcher.objects_buffer
    |> Enum.reverse()
    |> Enum.chunk_every(batcher.batch_size)
  end

  @doc """
  Get batches of references from the buffer.
  """
  @spec get_reference_batches(t()) :: [[map()]]
  def get_reference_batches(%__MODULE__{references_buffer: []}), do: []

  def get_reference_batches(%__MODULE__{} = batcher) do
    batcher.references_buffer
    |> Enum.reverse()
    |> Enum.chunk_every(batcher.batch_size)
  end

  @doc """
  Clear the object buffer.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = batcher) do
    %{batcher | objects_buffer: [], references_buffer: []}
  end

  @doc """
  Get the number of objects currently in the buffer.
  """
  @spec buffer_size(t()) :: non_neg_integer()
  def buffer_size(%__MODULE__{} = batcher) do
    length(batcher.objects_buffer)
  end

  @doc """
  Get the number of references currently in the buffer.
  """
  @spec reference_buffer_size(t()) :: non_neg_integer()
  def reference_buffer_size(%__MODULE__{} = batcher) do
    length(batcher.references_buffer)
  end

  @doc """
  Check if the buffer has reached the batch size threshold.
  """
  @spec ready_to_send?(t()) :: boolean()
  def ready_to_send?(%__MODULE__{} = batcher) do
    buffer_size(batcher) >= batcher.batch_size
  end
end
