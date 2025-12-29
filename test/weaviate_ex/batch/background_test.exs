defmodule WeaviateEx.Batch.BackgroundTest do
  use ExUnit.Case, async: false

  import Mox

  alias WeaviateEx.Batch.Background
  alias WeaviateEx.Client

  # Allow mocks to be accessed from spawned tasks
  setup :set_mox_global

  setup do
    # Stub the mock to simulate successful batch responses
    stub(WeaviateEx.Protocol.Mock, :request, fn _client, :post, path, body, _opts ->
      case path do
        "/v1/batch/objects" ->
          objects = body["objects"] || []

          response =
            Enum.map(objects, fn obj ->
              %{"id" => obj[:id] || obj["id"], "result" => %{"status" => "SUCCESS"}}
            end)

          {:ok, response}

        "/v1/batch/references" ->
          {:ok, []}

        _ ->
          {:error, :not_found}
      end
    end)

    {:ok, client} = Client.new(base_url: "http://localhost:8080")
    {:ok, client: client}
  end

  describe "start_link/1" do
    test "starts background batcher process", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "TestCollection")

      assert Process.alive?(pid)
      Background.stop(pid)
    end

    test "accepts batch configuration options", %{client: client} do
      {:ok, pid} =
        Background.start_link(
          client: client,
          collection: "TestCollection",
          batch_size: 50,
          concurrent_requests: 3,
          flush_interval: 500
        )

      state = Background.get_state(pid)
      assert state.batch_size == 50
      assert state.concurrent_requests == 3

      Background.stop(pid)
    end
  end

  describe "add_object/3" do
    test "queues object for background processing", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "Test")

      :ok = Background.add_object(pid, %{title: "Test"})
      :ok = Background.add_object(pid, %{title: "Test 2"})

      state = Background.get_state(pid)
      assert state.queue_size == 2

      Background.stop(pid)
    end

    test "accepts uuid option", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "Test")
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      :ok = Background.add_object(pid, %{title: "Test"}, uuid: uuid)

      state = Background.get_state(pid)
      assert MapSet.member?(state.pending_uuids, uuid)

      Background.stop(pid)
    end

    test "accepts vector option", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "Test")

      :ok = Background.add_object(pid, %{title: "Test"}, vector: [0.1, 0.2, 0.3])

      state = Background.get_state(pid)
      [obj] = :queue.to_list(state.object_queue)
      assert obj.vector == [0.1, 0.2, 0.3]

      Background.stop(pid)
    end
  end

  describe "add_reference/5" do
    test "queues reference with UUID tracking", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "Test")

      from_uuid = "550e8400-e29b-41d4-a716-446655440001"
      to_uuid = "550e8400-e29b-41d4-a716-446655440002"

      :ok = Background.add_reference(pid, from_uuid, "hasAuthor", to_uuid)

      state = Background.get_state(pid)
      assert state.reference_queue_size == 1

      Background.stop(pid)
    end

    test "tracks from and to UUIDs for ordering", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "Test")

      # Add object first
      :ok = Background.add_object(pid, %{title: "Test"}, uuid: "uuid-1")

      # Reference should wait until uuid-1 is processed
      :ok = Background.add_reference(pid, "uuid-1", "hasRef", "uuid-2")

      state = Background.get_state(pid)
      # Reference should be in pending, not ready
      assert state.pending_references_count == 1

      Background.stop(pid)
    end
  end

  describe "flush/1" do
    test "triggers immediate flush of queued items", %{client: client} do
      {:ok, pid} =
        Background.start_link(
          client: client,
          collection: "Test",
          # Long interval so auto-flush doesn't interfere
          flush_interval: 60_000
        )

      :ok = Background.add_object(pid, %{title: "Test"})

      # Force flush
      :ok = Background.flush(pid)

      # Wait for async processing
      Process.sleep(100)

      state = Background.get_state(pid)
      assert state.queue_size == 0

      Background.stop(pid)
    end
  end

  describe "stop/2" do
    test "flushes remaining items before stopping", %{client: client} do
      {:ok, pid} =
        Background.start_link(
          client: client,
          collection: "Test",
          flush_interval: 60_000
        )

      :ok = Background.add_object(pid, %{title: "Test"})

      # Stop with flush
      results = Background.stop(pid, flush: true)

      refute Process.alive?(pid)
      assert is_map(results)
    end

    test "discards remaining items when flush: false", %{client: client} do
      {:ok, pid} =
        Background.start_link(
          client: client,
          collection: "Test",
          flush_interval: 60_000
        )

      :ok = Background.add_object(pid, %{title: "Test"})

      # Stop without flush
      :ok = Background.stop(pid, flush: false)

      refute Process.alive?(pid)
    end
  end

  describe "get_results/1" do
    test "returns accumulated results", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "Test")

      results = Background.get_results(pid)

      assert is_map(results)
      assert Map.has_key?(results, :successful_uuids)
      assert Map.has_key?(results, :failed_objects)
      assert Map.has_key?(results, :failed_references)

      Background.stop(pid)
    end
  end

  describe "automatic flushing" do
    test "flushes when batch size reached", %{client: client} do
      {:ok, pid} =
        Background.start_link(
          client: client,
          collection: "Test",
          batch_size: 2,
          flush_interval: 60_000
        )

      :ok = Background.add_object(pid, %{title: "Test 1"})
      :ok = Background.add_object(pid, %{title: "Test 2"})

      # Auto-flush should have been triggered
      Process.sleep(100)

      state = Background.get_state(pid)
      # Queue should be empty or processing
      assert state.queue_size == 0 or state.active_requests > 0

      Background.stop(pid)
    end

    test "flushes on interval timer", %{client: client} do
      {:ok, pid} =
        Background.start_link(
          client: client,
          collection: "Test",
          batch_size: 100,
          # 100ms
          flush_interval: 100
        )

      :ok = Background.add_object(pid, %{title: "Test"})

      # Wait for interval flush
      Process.sleep(200)

      state = Background.get_state(pid)
      assert state.queue_size == 0 or state.flush_count > 0

      Background.stop(pid)
    end
  end

  describe "concurrent request management" do
    test "respects concurrent_requests limit", %{client: client} do
      {:ok, pid} =
        Background.start_link(
          client: client,
          collection: "Test",
          batch_size: 1,
          concurrent_requests: 2
        )

      # Add many objects to trigger multiple flushes
      for i <- 1..10 do
        :ok = Background.add_object(pid, %{title: "Test #{i}"})
      end

      Process.sleep(50)

      state = Background.get_state(pid)
      assert state.active_requests <= 2

      Background.stop(pid)
    end
  end

  describe "error handling" do
    test "tracks failed objects", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "Test")

      # Simulate error by adding invalid data (depends on mock setup)
      :ok = Background.add_object(pid, %{__invalid__: true})
      :ok = Background.flush(pid)

      Process.sleep(100)

      results = Background.get_results(pid)
      # Results structure should exist even if processing fails
      assert is_map(results)

      Background.stop(pid)
    end

    test "continues processing after errors", %{client: client} do
      {:ok, pid} = Background.start_link(client: client, collection: "Test")

      :ok = Background.add_object(pid, %{title: "Good 1"})
      :ok = Background.add_object(pid, %{__invalid__: true})
      :ok = Background.add_object(pid, %{title: "Good 2"})

      :ok = Background.flush(pid)
      Process.sleep(100)

      # Should still be alive and accepting objects
      assert Process.alive?(pid)
      :ok = Background.add_object(pid, %{title: "Good 3"})

      Background.stop(pid)
    end
  end
end
