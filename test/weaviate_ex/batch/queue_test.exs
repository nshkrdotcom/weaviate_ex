defmodule WeaviateEx.Batch.QueueTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.Queue

  describe "new/0" do
    test "creates an empty queue" do
      queue = Queue.new()

      assert Queue.empty?(queue)
      assert Queue.pending_count(queue) == 0
      assert Queue.failed_count(queue) == 0
    end
  end

  describe "enqueue/2" do
    test "adds object to pending queue" do
      queue =
        Queue.new()
        |> Queue.enqueue(%{id: "uuid-1", properties: %{name: "Test"}})

      assert Queue.pending_count(queue) == 1
      refute Queue.empty?(queue)
    end

    test "preserves FIFO order" do
      queue =
        Queue.new()
        |> Queue.enqueue(%{id: "uuid-1"})
        |> Queue.enqueue(%{id: "uuid-2"})
        |> Queue.enqueue(%{id: "uuid-3"})

      {batch, _queue} = Queue.dequeue_batch(queue, 2)

      assert length(batch) == 2
      assert Enum.at(batch, 0).id == "uuid-1"
      assert Enum.at(batch, 1).id == "uuid-2"
    end
  end

  describe "enqueue_many/2" do
    test "adds multiple objects to pending queue" do
      objects = [
        %{id: "uuid-1"},
        %{id: "uuid-2"},
        %{id: "uuid-3"}
      ]

      queue =
        Queue.new()
        |> Queue.enqueue_many(objects)

      assert Queue.pending_count(queue) == 3
    end
  end

  describe "dequeue_batch/2" do
    test "removes objects from pending queue" do
      objects = [%{id: "uuid-1"}, %{id: "uuid-2"}, %{id: "uuid-3"}]

      queue =
        Queue.new()
        |> Queue.enqueue_many(objects)

      {batch, queue} = Queue.dequeue_batch(queue, 2)

      assert length(batch) == 2
      assert Queue.pending_count(queue) == 1
    end

    test "returns all remaining when size exceeds pending" do
      objects = [%{id: "uuid-1"}, %{id: "uuid-2"}]

      queue =
        Queue.new()
        |> Queue.enqueue_many(objects)

      {batch, queue} = Queue.dequeue_batch(queue, 10)

      assert length(batch) == 2
      assert Queue.pending_count(queue) == 0
    end

    test "returns empty list when queue is empty" do
      queue = Queue.new()

      {batch, queue} = Queue.dequeue_batch(queue, 10)

      assert batch == []
      assert Queue.empty?(queue)
    end
  end

  describe "mark_failed/3" do
    test "adds object to failed list with reason" do
      object = %{id: "uuid-1", properties: %{name: "Test"}}
      reason = "Validation error: missing required field"

      queue =
        Queue.new()
        |> Queue.mark_failed(object, reason)

      assert Queue.failed_count(queue) == 1

      [failed] = Queue.get_failed(queue)
      assert failed.object == object
      assert failed.reason == reason
      assert failed.retry_count == 1
    end

    test "increments retry count for same object" do
      object = %{id: "uuid-1"}

      queue =
        Queue.new()
        |> Queue.mark_failed(object, "Error 1")
        |> Queue.mark_failed(object, "Error 2")

      assert Queue.failed_count(queue) == 1

      [failed] = Queue.get_failed(queue)
      assert failed.retry_count == 2
      assert failed.reason == "Error 2"
    end
  end

  describe "requeue_failed/2" do
    test "moves failed objects back to pending queue" do
      object1 = %{id: "uuid-1"}
      object2 = %{id: "uuid-2"}

      queue =
        Queue.new()
        |> Queue.mark_failed(object1, "Temp error")
        |> Queue.mark_failed(object2, "Temp error")

      queue = Queue.requeue_failed(queue, max_retries: 3)

      assert Queue.pending_count(queue) == 2
      assert Queue.failed_count(queue) == 0
    end

    test "does not requeue objects exceeding max retries" do
      object = %{id: "uuid-1"}

      # Fail the same object 3 times
      queue =
        Queue.new()
        |> Queue.mark_failed(object, "Error 1")
        |> Queue.mark_failed(object, "Error 2")
        |> Queue.mark_failed(object, "Error 3")

      queue = Queue.requeue_failed(queue, max_retries: 3)

      # Should stay in failed (3 retries = at max)
      assert Queue.pending_count(queue) == 0
      assert Queue.failed_count(queue) == 1
    end

    test "requeues objects under max retries" do
      object = %{id: "uuid-1"}

      queue =
        Queue.new()
        |> Queue.mark_failed(object, "Error 1")
        |> Queue.mark_failed(object, "Error 2")

      queue = Queue.requeue_failed(queue, max_retries: 3)

      # 2 retries < 3 max, should be requeued
      assert Queue.pending_count(queue) == 1
      assert Queue.failed_count(queue) == 0
    end
  end

  describe "get_failed/1" do
    test "returns all failed objects" do
      queue =
        Queue.new()
        |> Queue.mark_failed(%{id: "uuid-1"}, "Error 1")
        |> Queue.mark_failed(%{id: "uuid-2"}, "Error 2")

      failed = Queue.get_failed(queue)

      assert length(failed) == 2
    end

    test "returns empty list when no failures" do
      queue = Queue.new()

      assert Queue.get_failed(queue) == []
    end
  end

  describe "clear_failed/1" do
    test "removes all failed objects" do
      queue =
        Queue.new()
        |> Queue.mark_failed(%{id: "uuid-1"}, "Error")
        |> Queue.mark_failed(%{id: "uuid-2"}, "Error")

      queue = Queue.clear_failed(queue)

      assert Queue.failed_count(queue) == 0
      assert Queue.get_failed(queue) == []
    end
  end

  describe "stats/1" do
    test "returns queue statistics" do
      objects = [%{id: "uuid-1"}, %{id: "uuid-2"}, %{id: "uuid-3"}]

      queue =
        Queue.new()
        |> Queue.enqueue_many(objects)
        |> Queue.mark_failed(%{id: "uuid-4"}, "Error")

      stats = Queue.stats(queue)

      assert stats.pending == 3
      assert stats.failed == 1
      assert stats.total == 4
    end
  end

  describe "FailedObject struct" do
    test "contains object, reason, and retry_count" do
      failed = %Queue.FailedObject{
        object: %{id: "uuid-1"},
        reason: "Validation error",
        retry_count: 2,
        failed_at: DateTime.utc_now()
      }

      assert failed.object.id == "uuid-1"
      assert failed.reason == "Validation error"
      assert failed.retry_count == 2
    end
  end
end
