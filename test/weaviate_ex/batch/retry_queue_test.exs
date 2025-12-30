defmodule WeaviateEx.Batch.RetryQueueTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.RetryQueue

  @moduletag :unit

  # Mock client for testing
  defp mock_client do
    %{
      base_url: "http://localhost:8080",
      grpc_channel: nil
    }
  end

  describe "start_link/1" do
    test "starts with required client option" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "accepts optional configuration" do
      {:ok, pid} =
        RetryQueue.start_link(
          client: mock_client(),
          max_retries: 5,
          base_delay_ms: 500,
          on_permanent_failure: fn _objects -> :ok end
        )

      state = RetryQueue.get_state(pid)
      assert state.max_retries == 5
      assert state.base_delay_ms == 500
      assert is_function(state.on_permanent_failure, 1)
      GenServer.stop(pid)
    end

    test "uses default values when not specified" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())
      state = RetryQueue.get_state(pid)

      assert state.max_retries == 3
      assert state.base_delay_ms == 1000
      assert state.on_permanent_failure == nil
      GenServer.stop(pid)
    end
  end

  describe "enqueue_failed/2" do
    test "adds objects to retry queue" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())

      failed_objects = [
        %{uuid: "uuid-1", properties: %{title: "Test 1"}, collection: "Article"},
        %{uuid: "uuid-2", properties: %{title: "Test 2"}, collection: "Article"}
      ]

      :ok = RetryQueue.enqueue_failed(pid, failed_objects)

      state = RetryQueue.get_state(pid)
      assert state.queue_size == 2
      GenServer.stop(pid)
    end

    test "tracks retry count per UUID" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())

      object = %{uuid: "uuid-1", properties: %{title: "Test"}, collection: "Article"}

      :ok = RetryQueue.enqueue_failed(pid, [object])
      :ok = RetryQueue.enqueue_failed(pid, [object])

      state = RetryQueue.get_state(pid)
      assert state.retry_counts["uuid-1"] == 2
      GenServer.stop(pid)
    end

    test "drops objects after max_retries" do
      test_pid = self()

      {:ok, pid} =
        RetryQueue.start_link(
          client: mock_client(),
          max_retries: 2,
          on_permanent_failure: fn objects ->
            send(test_pid, {:permanent_failure, objects})
          end
        )

      object = %{uuid: "uuid-1", properties: %{title: "Test"}, collection: "Article"}

      # First two retries should be queued
      :ok = RetryQueue.enqueue_failed(pid, [object])
      :ok = RetryQueue.enqueue_failed(pid, [object])

      # Third retry should trigger permanent failure
      :ok = RetryQueue.enqueue_failed(pid, [object])

      # Wait for permanent failure callback
      assert_receive {:permanent_failure, [^object]}, 1000

      state = RetryQueue.get_state(pid)
      # Object should be removed from queue after permanent failure
      refute Map.has_key?(state.retry_counts, "uuid-1")
      GenServer.stop(pid)
    end
  end

  describe "drain/1" do
    test "returns all queued objects" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())

      objects = [
        %{uuid: "uuid-1", properties: %{title: "Test 1"}, collection: "Article"},
        %{uuid: "uuid-2", properties: %{title: "Test 2"}, collection: "Article"}
      ]

      :ok = RetryQueue.enqueue_failed(pid, objects)

      {:ok, drained} = RetryQueue.drain(pid)
      assert length(drained) == 2
      assert Enum.map(drained, & &1.uuid) |> Enum.sort() == ["uuid-1", "uuid-2"]

      # Queue should be empty after drain
      state = RetryQueue.get_state(pid)
      assert state.queue_size == 0
      GenServer.stop(pid)
    end

    test "returns empty list when queue is empty" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())

      {:ok, drained} = RetryQueue.drain(pid)
      assert drained == []
      GenServer.stop(pid)
    end
  end

  describe "size/1" do
    test "returns number of queued objects" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())

      assert RetryQueue.size(pid) == 0

      objects = [
        %{uuid: "uuid-1", properties: %{}, collection: "Article"},
        %{uuid: "uuid-2", properties: %{}, collection: "Article"}
      ]

      :ok = RetryQueue.enqueue_failed(pid, objects)
      assert RetryQueue.size(pid) == 2
      GenServer.stop(pid)
    end
  end

  describe "clear/1" do
    test "removes all objects from queue" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())

      objects = [
        %{uuid: "uuid-1", properties: %{}, collection: "Article"},
        %{uuid: "uuid-2", properties: %{}, collection: "Article"}
      ]

      :ok = RetryQueue.enqueue_failed(pid, objects)
      assert RetryQueue.size(pid) == 2

      :ok = RetryQueue.clear(pid)
      assert RetryQueue.size(pid) == 0
      GenServer.stop(pid)
    end

    test "clears retry counts" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())

      object = %{uuid: "uuid-1", properties: %{}, collection: "Article"}
      :ok = RetryQueue.enqueue_failed(pid, [object])
      :ok = RetryQueue.enqueue_failed(pid, [object])

      state = RetryQueue.get_state(pid)
      assert state.retry_counts["uuid-1"] == 2

      :ok = RetryQueue.clear(pid)

      state = RetryQueue.get_state(pid)
      assert state.retry_counts == %{}
      GenServer.stop(pid)
    end
  end

  describe "get_retry_count/2" do
    test "returns retry count for specific UUID" do
      {:ok, pid} = RetryQueue.start_link(client: mock_client())

      object = %{uuid: "uuid-1", properties: %{}, collection: "Article"}
      :ok = RetryQueue.enqueue_failed(pid, [object])
      :ok = RetryQueue.enqueue_failed(pid, [object])

      assert RetryQueue.get_retry_count(pid, "uuid-1") == 2
      assert RetryQueue.get_retry_count(pid, "uuid-unknown") == 0
      GenServer.stop(pid)
    end
  end

  describe "calculate_backoff/2" do
    test "calculates exponential backoff" do
      assert RetryQueue.calculate_backoff(0, 1000) == 1000
      assert RetryQueue.calculate_backoff(1, 1000) == 2000
      assert RetryQueue.calculate_backoff(2, 1000) == 4000
      assert RetryQueue.calculate_backoff(3, 1000) == 8000
    end

    test "caps backoff at max delay" do
      # Max delay is 60 seconds
      assert RetryQueue.calculate_backoff(10, 1000) == 60_000
    end

    test "applies jitter within range" do
      # Run multiple times to verify jitter is applied
      results =
        for _ <- 1..20 do
          RetryQueue.calculate_backoff_with_jitter(1, 1000)
        end

      # All results should be within ±20% of base (2000ms for attempt 1)
      assert Enum.all?(results, fn r -> r >= 1600 and r <= 2400 end)
      # Should have some variance (not all the same)
      assert length(Enum.uniq(results)) > 1
    end
  end

  describe "retryable_error?/1" do
    test "returns true for retryable gRPC status codes" do
      # UNAVAILABLE
      assert RetryQueue.retryable_error?(%{code: :unavailable})
      # RESOURCE_EXHAUSTED
      assert RetryQueue.retryable_error?(%{code: :resource_exhausted})
      # ABORTED
      assert RetryQueue.retryable_error?(%{code: :aborted})
      # DEADLINE_EXCEEDED
      assert RetryQueue.retryable_error?(%{code: :deadline_exceeded})
    end

    test "returns true for rate limit errors" do
      assert RetryQueue.retryable_error?(%{message: "rate limit exceeded"})
      assert RetryQueue.retryable_error?(%{message: "Rate limit reached"})
      assert RetryQueue.retryable_error?(%{message: "503 error"})
    end

    test "returns false for non-retryable errors" do
      refute RetryQueue.retryable_error?(%{code: :invalid_argument})
      refute RetryQueue.retryable_error?(%{code: :not_found})
      refute RetryQueue.retryable_error?(%{message: "Invalid property"})
    end
  end
end
