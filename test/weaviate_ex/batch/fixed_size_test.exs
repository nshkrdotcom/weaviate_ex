defmodule WeaviateEx.Batch.FixedSizeTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.FixedSize

  describe "new/2" do
    test "creates fixed size batcher with defaults" do
      batcher = FixedSize.new()

      assert batcher.batch_size == 100
      assert batcher.concurrent_requests == 2
      assert batcher.objects_buffer == []
    end

    test "creates fixed size batcher with custom batch_size" do
      batcher = FixedSize.new(batch_size: 50)

      assert batcher.batch_size == 50
    end

    test "creates fixed size batcher with custom concurrent_requests" do
      batcher = FixedSize.new(concurrent_requests: 4)

      assert batcher.concurrent_requests == 4
    end
  end

  describe "add_object/4" do
    test "adds object to buffer" do
      batcher = FixedSize.new(batch_size: 10)

      batcher = FixedSize.add_object(batcher, "Article", %{title: "Test"})

      assert length(batcher.objects_buffer) == 1
    end

    test "adds object with uuid and vector" do
      batcher = FixedSize.new(batch_size: 10)

      batcher =
        FixedSize.add_object(batcher, "Article", %{title: "Test"},
          uuid: "uuid-123",
          vector: [0.1, 0.2]
        )

      object = hd(batcher.objects_buffer)
      assert object.uuid == "uuid-123"
      assert object.vector == [0.1, 0.2]
    end

    test "accumulates objects in buffer" do
      batcher =
        FixedSize.new(batch_size: 10)
        |> FixedSize.add_object("Article", %{title: "Test 1"})
        |> FixedSize.add_object("Article", %{title: "Test 2"})
        |> FixedSize.add_object("Article", %{title: "Test 3"})

      assert length(batcher.objects_buffer) == 3
    end
  end

  describe "get_batches/1" do
    test "returns empty list for empty buffer" do
      batcher = FixedSize.new()
      batches = FixedSize.get_batches(batcher)

      assert batches == []
    end

    test "returns single batch for small buffer" do
      batcher =
        FixedSize.new(batch_size: 10)
        |> FixedSize.add_object("Article", %{title: "Test 1"})
        |> FixedSize.add_object("Article", %{title: "Test 2"})

      batches = FixedSize.get_batches(batcher)

      assert length(batches) == 1
      assert length(hd(batches)) == 2
    end

    test "splits into multiple batches" do
      batcher =
        Enum.reduce(1..25, FixedSize.new(batch_size: 10), fn i, acc ->
          FixedSize.add_object(acc, "Article", %{title: "Test #{i}"})
        end)

      batches = FixedSize.get_batches(batcher)

      assert length(batches) == 3
      assert length(Enum.at(batches, 0)) == 10
      assert length(Enum.at(batches, 1)) == 10
      assert length(Enum.at(batches, 2)) == 5
    end
  end

  describe "clear/1" do
    test "clears the buffer" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_object("Article", %{title: "Test"})
        |> FixedSize.clear()

      assert batcher.objects_buffer == []
    end
  end

  describe "buffer_size/1" do
    test "returns number of objects in buffer" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_object("Article", %{title: "Test 1"})
        |> FixedSize.add_object("Article", %{title: "Test 2"})

      assert FixedSize.buffer_size(batcher) == 2
    end
  end

  describe "add_object/4 auto UUID" do
    test "auto-generates UUID when not provided" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_object("Article", %{title: "Test"})

      [object] = batcher.objects_buffer

      assert object.uuid != nil
      assert is_binary(object.uuid)
      # UUID v4 format: 8-4-4-4-12
      assert String.match?(
               object.uuid,
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
             )
    end

    test "generates unique UUIDs for each object" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_object("Article", %{title: "Test 1"})
        |> FixedSize.add_object("Article", %{title: "Test 2"})
        |> FixedSize.add_object("Article", %{title: "Test 3"})

      uuids = Enum.map(batcher.objects_buffer, & &1.uuid)

      # All UUIDs should be unique
      assert length(Enum.uniq(uuids)) == 3
    end

    test "uses explicit UUID when provided" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_object("Article", %{title: "Test"}, uuid: "my-custom-uuid")

      [object] = batcher.objects_buffer
      assert object.uuid == "my-custom-uuid"
    end

    test "adds object with tenant" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_object("Article", %{title: "Test"}, tenant: "TenantA")

      [object] = batcher.objects_buffer
      assert object.tenant == "TenantA"
    end
  end

  describe "add_reference/6 single target" do
    test "adds single target reference" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_reference("Article", "from-uuid", "hasAuthor", "to-uuid")

      assert FixedSize.reference_buffer_size(batcher) == 1

      [ref] = batcher.references_buffer
      assert ref.collection == "Article"
      assert ref.from_uuid == "from-uuid"
      assert ref.property == "hasAuthor"
      assert ref.to_uuid == "to-uuid"
      assert ref.to_collection == "Article"
    end

    test "adds single target reference with tenant" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_reference("Article", "from-uuid", "hasAuthor", "to-uuid",
          tenant: "TenantA"
        )

      [ref] = batcher.references_buffer
      assert ref.tenant == "TenantA"
    end
  end

  describe "add_reference/6 multi-target" do
    test "adds multiple target references" do
      targets = [
        %{collection: "Article", uuid: "article-uuid"},
        %{collection: "Video", uuid: "video-uuid"},
        %{collection: "Podcast", uuid: "podcast-uuid"}
      ]

      batcher =
        FixedSize.new()
        |> FixedSize.add_reference("Content", "from-uuid", "relatedTo", targets)

      assert FixedSize.reference_buffer_size(batcher) == 3

      # All refs share common properties
      assert Enum.all?(batcher.references_buffer, &(&1.collection == "Content"))
      assert Enum.all?(batcher.references_buffer, &(&1.from_uuid == "from-uuid"))
      assert Enum.all?(batcher.references_buffer, &(&1.property == "relatedTo"))

      # Each has its own target collection/uuid
      target_uuids = Enum.map(batcher.references_buffer, & &1.to_uuid)
      target_collections = Enum.map(batcher.references_buffer, & &1.to_collection)

      assert "article-uuid" in target_uuids
      assert "video-uuid" in target_uuids
      assert "podcast-uuid" in target_uuids

      assert "Article" in target_collections
      assert "Video" in target_collections
      assert "Podcast" in target_collections
    end

    test "adds multi-target reference with tenant" do
      targets = [
        %{collection: "Article", uuid: "uuid-1"},
        %{collection: "Video", uuid: "uuid-2"}
      ]

      batcher =
        FixedSize.new()
        |> FixedSize.add_reference("Content", "from-uuid", "related", targets, tenant: "TenantX")

      assert Enum.all?(batcher.references_buffer, &(&1.tenant == "TenantX"))
    end

    test "handles empty targets list" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_reference("Content", "from-uuid", "related", [])

      assert FixedSize.reference_buffer_size(batcher) == 0
    end
  end

  describe "reference_buffer_size/1" do
    test "returns reference buffer count" do
      batcher =
        FixedSize.new()
        |> FixedSize.add_reference("Article", "1", "ref", "a")
        |> FixedSize.add_reference("Article", "2", "ref", "b")

      assert FixedSize.reference_buffer_size(batcher) == 2
    end

    test "counts all references from multi-target add" do
      targets = [
        %{collection: "A", uuid: "1"},
        %{collection: "B", uuid: "2"}
      ]

      batcher =
        FixedSize.new()
        |> FixedSize.add_reference("Article", "from", "rel", targets)

      assert FixedSize.reference_buffer_size(batcher) == 2
    end
  end

  describe "get_reference_batches/1" do
    test "returns empty list for empty buffer" do
      batcher = FixedSize.new()
      assert FixedSize.get_reference_batches(batcher) == []
    end

    test "batches references by batch_size" do
      batcher = FixedSize.new(batch_size: 2)

      batcher =
        batcher
        |> FixedSize.add_reference("Article", "1", "ref", "a")
        |> FixedSize.add_reference("Article", "2", "ref", "b")
        |> FixedSize.add_reference("Article", "3", "ref", "c")

      batches = FixedSize.get_reference_batches(batcher)

      assert length(batches) == 2
    end
  end

  describe "ready_to_send?/1" do
    test "returns false when under threshold" do
      batcher =
        FixedSize.new(batch_size: 10)
        |> FixedSize.add_object("Article", %{title: "1"})

      assert FixedSize.ready_to_send?(batcher) == false
    end

    test "returns true when at threshold" do
      batcher = FixedSize.new(batch_size: 2)

      batcher =
        batcher
        |> FixedSize.add_object("Article", %{title: "1"})
        |> FixedSize.add_object("Article", %{title: "2"})

      assert FixedSize.ready_to_send?(batcher) == true
    end

    test "returns true when over threshold" do
      batcher = FixedSize.new(batch_size: 2)

      batcher =
        batcher
        |> FixedSize.add_object("Article", %{title: "1"})
        |> FixedSize.add_object("Article", %{title: "2"})
        |> FixedSize.add_object("Article", %{title: "3"})

      assert FixedSize.ready_to_send?(batcher) == true
    end
  end
end
