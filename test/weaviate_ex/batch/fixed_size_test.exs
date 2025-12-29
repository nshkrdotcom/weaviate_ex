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
end
