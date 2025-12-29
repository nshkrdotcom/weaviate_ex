defmodule WeaviateEx.Batch.DynamicTest do
  # async: false because we use set_mox_global
  use ExUnit.Case, async: false
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.Batch.Dynamic
  alias WeaviateEx.Batch.ErrorTracking.Results
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  # Use global mode for GenServer-based tests
  setup do
    Mox.set_mox_global()
    :ok
  end

  describe "start/1" do
    test "starts the dynamic batcher GenServer", %{client: client} do
      assert {:ok, pid} = Dynamic.start(client: client)
      assert Process.alive?(pid)
      Dynamic.stop(pid)
    end

    test "starts with default options", %{client: client} do
      {:ok, pid} = Dynamic.start(client: client)
      state = Dynamic.get_state(pid)

      assert state.batch_size == 100
      assert state.min_batch_size == 10
      assert state.max_batch_size == 1000
      assert state.concurrent_requests == 2

      Dynamic.stop(pid)
    end

    test "accepts custom options", %{client: client} do
      {:ok, pid} =
        Dynamic.start(
          client: client,
          batch_size: 50,
          min_batch_size: 5,
          max_batch_size: 500,
          concurrent_requests: 4
        )

      state = Dynamic.get_state(pid)

      assert state.batch_size == 50
      assert state.min_batch_size == 5
      assert state.max_batch_size == 500
      assert state.concurrent_requests == 4

      Dynamic.stop(pid)
    end

    test "accepts name option for registration", %{client: client} do
      {:ok, pid} = Dynamic.start(client: client, name: :test_dynamic_batcher)
      assert Process.whereis(:test_dynamic_batcher) == pid
      Dynamic.stop(pid)
    end
  end

  describe "add_object/4" do
    test "adds object to the buffer", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:ok, [%{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS"}]}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      assert :ok = Dynamic.add_object(pid, "Article", %{title: "Test"})

      state = Dynamic.get_state(pid)
      assert length(state.objects_buffer) == 1

      Dynamic.stop(pid)
    end

    test "accepts options like uuid and vector", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:ok, [%{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS"}]}
      end)

      {:ok, pid} = Dynamic.start(client: client)
      uuid = Uniq.UUID.uuid4()
      vector = [0.1, 0.2, 0.3]

      :ok = Dynamic.add_object(pid, "Article", %{title: "Test"}, uuid: uuid, vector: vector)

      state = Dynamic.get_state(pid)
      [object] = state.objects_buffer

      assert object.uuid == uuid
      assert object.vector == vector

      Dynamic.stop(pid)
    end

    test "auto-flushes when batch size is reached", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/batch/objects"
        objects = body["objects"]
        assert length(objects) == 10

        results =
          Enum.map(objects, fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} = Dynamic.start(client: client, batch_size: 10, auto_flush: true)

      # Add 10 objects to trigger auto-flush
      for i <- 1..10 do
        Dynamic.add_object(pid, "Article", %{title: "Test #{i}"})
      end

      # Wait a bit for async flush to complete
      Process.sleep(50)

      state = Dynamic.get_state(pid)
      # Buffer should be empty after flush
      assert state.objects_buffer == []

      Dynamic.stop(pid)
    end
  end

  describe "add_reference/5" do
    test "adds reference to the buffer", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/references"
        {:ok, [%{"status" => "SUCCESS"}]}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      :ok = Dynamic.add_reference(pid, "Article", "uuid-1", "hasAuthor", "uuid-2")

      state = Dynamic.get_state(pid)
      assert length(state.references_buffer) == 1

      Dynamic.stop(pid)
    end

    test "accepts tenant option", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/references"
        {:ok, [%{"status" => "SUCCESS"}]}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      :ok =
        Dynamic.add_reference(pid, "Article", "uuid-1", "hasAuthor", "uuid-2", tenant: "tenantA")

      state = Dynamic.get_state(pid)
      [ref] = state.references_buffer

      assert ref.tenant == "tenantA"

      Dynamic.stop(pid)
    end
  end

  describe "flush/1" do
    test "sends buffered objects to Weaviate", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/batch/objects"
        assert length(body["objects"]) == 3

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      Dynamic.add_object(pid, "Article", %{title: "Test 1"})
      Dynamic.add_object(pid, "Article", %{title: "Test 2"})
      Dynamic.add_object(pid, "Article", %{title: "Test 3"})

      assert {:ok, results} = Dynamic.flush(pid)
      stats = Results.statistics(results)
      assert stats.successful == 3
      assert stats.failed == 0

      state = Dynamic.get_state(pid)
      assert state.objects_buffer == []

      Dynamic.stop(pid)
    end

    test "sends buffered references to Weaviate", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/references"
        {:ok, [%{"status" => "SUCCESS"}, %{"status" => "SUCCESS"}]}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      Dynamic.add_reference(pid, "Article", "uuid-1", "hasAuthor", "author-1")
      Dynamic.add_reference(pid, "Article", "uuid-2", "hasAuthor", "author-2")

      assert {:ok, results} = Dynamic.flush(pid)
      stats = Results.statistics(results)
      assert stats.successful == 2

      Dynamic.stop(pid)
    end

    test "returns ok with empty results when buffer is empty", %{client: client} do
      {:ok, pid} = Dynamic.start(client: client)

      assert {:ok, results} = Dynamic.flush(pid)
      stats = Results.statistics(results)
      assert stats.processed == 0

      Dynamic.stop(pid)
    end

    test "tracks failed objects", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          body["objects"]
          |> Enum.with_index()
          |> Enum.map(fn {obj, idx} ->
            if rem(idx, 2) == 0 do
              %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
            else
              %{
                "id" => obj["id"] || Uniq.UUID.uuid4(),
                "status" => "FAILED",
                "result" => %{"errors" => [%{"message" => "Invalid property"}]}
              }
            end
          end)

        {:ok, results}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      for i <- 1..4 do
        Dynamic.add_object(pid, "Article", %{title: "Test #{i}"})
      end

      {:ok, results} = Dynamic.flush(pid)
      stats = Results.statistics(results)

      assert stats.successful == 2
      assert stats.failed == 2
      assert length(Results.errors(results)) == 2

      Dynamic.stop(pid)
    end
  end

  describe "stop/1" do
    test "flushes remaining objects before stopping", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      Dynamic.add_object(pid, "Article", %{title: "Test"})

      assert {:ok, results} = Dynamic.stop(pid)
      stats = Results.statistics(results)
      assert stats.successful == 1

      refute Process.alive?(pid)
    end

    test "returns empty results if buffer is empty", %{client: client} do
      {:ok, pid} = Dynamic.start(client: client)

      {:ok, results} = Dynamic.stop(pid)
      stats = Results.statistics(results)
      assert stats.processed == 0

      refute Process.alive?(pid)
    end
  end

  describe "dynamic batch size adjustment" do
    test "increases batch size when queue is small", %{client: client} do
      # Simulate fast processing (queue stays small)
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} = Dynamic.start(client: client, batch_size: 10)

      # Simulate queue metrics indicating fast processing
      Dynamic.report_queue_size(pid, 0)

      for i <- 1..10 do
        Dynamic.add_object(pid, "Article", %{title: "Test #{i}"})
      end

      {:ok, _} = Dynamic.flush(pid)

      # Batch size should have increased
      state = Dynamic.get_state(pid)
      assert state.batch_size > 10

      Dynamic.stop(pid)
    end

    test "decreases batch size when queue is large", %{client: client} do
      {:ok, pid} = Dynamic.start(client: client, batch_size: 100)

      # Simulate queue metrics indicating slow processing
      Dynamic.report_queue_size(pid, 500)

      state = Dynamic.get_state(pid)
      # Batch size should have decreased
      assert state.batch_size < 100

      Dynamic.stop(pid)
    end

    test "respects min and max batch size bounds", %{client: client} do
      {:ok, pid} =
        Dynamic.start(client: client, batch_size: 50, min_batch_size: 10, max_batch_size: 100)

      # Try to increase beyond max
      for _ <- 1..10 do
        Dynamic.report_queue_size(pid, 0)
      end

      state = Dynamic.get_state(pid)
      assert state.batch_size <= 100

      # Try to decrease below min
      for _ <- 1..20 do
        Dynamic.report_queue_size(pid, 10_000)
      end

      state = Dynamic.get_state(pid)
      assert state.batch_size >= 10

      Dynamic.stop(pid)
    end
  end

  describe "concurrent requests" do
    test "sends multiple batches concurrently", %{client: client} do
      test_pid = self()

      # Expect multiple concurrent requests
      Mox.expect(Mock, :request, 2, fn _client, :post, _path, body, _opts ->
        send(test_pid, {:batch_sent, length(body["objects"])})

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} = Dynamic.start(client: client, batch_size: 5, concurrent_requests: 2)

      # Add enough objects for 2 batches
      for i <- 1..10 do
        Dynamic.add_object(pid, "Article", %{title: "Test #{i}"})
      end

      {:ok, _} = Dynamic.flush(pid)

      # Should receive 2 batch_sent messages
      assert_receive {:batch_sent, 5}
      assert_receive {:batch_sent, 5}

      Dynamic.stop(pid)
    end
  end

  describe "error handling" do
    test "handles API errors gracefully", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :server_error,
           message: "Internal server error",
           status_code: 500
         }}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      Dynamic.add_object(pid, "Article", %{title: "Test"})

      {:error, error} = Dynamic.flush(pid)
      assert error.type == :server_error

      # Process is still alive but buffer retained the failed object
      # Terminating without further flush expectation
      GenServer.stop(pid, :normal)
    end

    test "process continues after error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :server_error,
           message: "Internal server error",
           status_code: 500
         }}
      end)

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} = Dynamic.start(client: client)

      Dynamic.add_object(pid, "Article", %{title: "Test 1"})
      {:error, _} = Dynamic.flush(pid)

      # Process should still be alive and working
      assert Process.alive?(pid)

      Dynamic.add_object(pid, "Article", %{title: "Test 2"})
      {:ok, results} = Dynamic.flush(pid)
      stats = Results.statistics(results)
      # Results are cumulative within the session - both objects are now flushed
      # (the first one was retained due to error, the second one was added)
      assert stats.successful == 2

      GenServer.stop(pid, :normal)
    end
  end
end
