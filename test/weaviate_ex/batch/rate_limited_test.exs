defmodule WeaviateEx.Batch.RateLimitedTest do
  # async: false because we use set_mox_global
  use ExUnit.Case, async: false
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.Batch.RateLimited
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
    test "starts the rate-limited batcher GenServer", %{client: client} do
      assert {:ok, pid} = RateLimited.start(client: client)
      assert Process.alive?(pid)
      RateLimited.stop(pid)
    end

    test "starts with default options", %{client: client} do
      {:ok, pid} = RateLimited.start(client: client)
      state = RateLimited.get_state(pid)

      assert state.requests_per_minute == 60
      assert state.batch_size == 100

      RateLimited.stop(pid)
    end

    test "accepts custom rate limit options", %{client: client} do
      {:ok, pid} =
        RateLimited.start(
          client: client,
          requests_per_minute: 30,
          batch_size: 50
        )

      state = RateLimited.get_state(pid)

      assert state.requests_per_minute == 30
      assert state.batch_size == 50

      RateLimited.stop(pid)
    end

    test "accepts name option for registration", %{client: client} do
      {:ok, pid} = RateLimited.start(client: client, name: :test_rate_limited_batcher)
      assert Process.whereis(:test_rate_limited_batcher) == pid
      RateLimited.stop(pid)
    end
  end

  describe "add_object/4" do
    test "adds object to the buffer", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:ok, [%{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS"}]}
      end)

      {:ok, pid} = RateLimited.start(client: client)

      assert :ok = RateLimited.add_object(pid, "Article", %{title: "Test"})

      state = RateLimited.get_state(pid)
      assert length(state.objects_buffer) == 1

      RateLimited.stop(pid)
    end

    test "accepts options like uuid and vector", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:ok, [%{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS"}]}
      end)

      {:ok, pid} = RateLimited.start(client: client)
      uuid = Uniq.UUID.uuid4()
      vector = [0.1, 0.2, 0.3]

      :ok = RateLimited.add_object(pid, "Article", %{title: "Test"}, uuid: uuid, vector: vector)

      state = RateLimited.get_state(pid)
      [object] = state.objects_buffer

      assert object.uuid == uuid
      assert object.vector == vector

      RateLimited.stop(pid)
    end
  end

  describe "add_reference/5" do
    test "adds reference to the buffer", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/references"
        {:ok, [%{"status" => "SUCCESS"}]}
      end)

      {:ok, pid} = RateLimited.start(client: client)

      :ok = RateLimited.add_reference(pid, "Article", "uuid-1", "hasAuthor", "uuid-2")

      state = RateLimited.get_state(pid)
      assert length(state.references_buffer) == 1

      RateLimited.stop(pid)
    end
  end

  describe "flush/1" do
    test "sends buffered objects to Weaviate", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/batch/objects"
        assert length(body["objects"]) == 2

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} = RateLimited.start(client: client)

      RateLimited.add_object(pid, "Article", %{title: "Test 1"})
      RateLimited.add_object(pid, "Article", %{title: "Test 2"})

      assert {:ok, results} = RateLimited.flush(pid)
      stats = Results.statistics(results)
      assert stats.successful == 2

      RateLimited.stop(pid)
    end

    test "sends multiple batches", %{client: client} do
      test_pid = self()

      # Expect 3 requests
      Mox.expect(Mock, :request, 3, fn _client, :post, _path, body, _opts ->
        send(test_pid, {:batch_sent, length(body["objects"])})

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      # High rate limit to avoid waiting
      {:ok, pid} = RateLimited.start(client: client, requests_per_minute: 10000, batch_size: 5)

      # Add enough objects for 3 batches
      for i <- 1..15 do
        RateLimited.add_object(pid, "Article", %{title: "Test #{i}"})
      end

      {:ok, _} = RateLimited.flush(pid)

      # Collect batch sent messages
      assert_receive {:batch_sent, 5}
      assert_receive {:batch_sent, 5}
      assert_receive {:batch_sent, 5}

      RateLimited.stop(pid)
    end
  end

  describe "rate limit tracking" do
    test "get_remaining_requests returns remaining requests", %{client: client} do
      {:ok, pid} = RateLimited.start(client: client, requests_per_minute: 10)

      remaining = RateLimited.get_remaining_requests(pid)
      assert remaining == 10

      RateLimited.stop(pid)
    end

    test "remaining requests decreases after flush", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} = RateLimited.start(client: client, requests_per_minute: 10)

      RateLimited.add_object(pid, "Article", %{title: "Test"})
      {:ok, _} = RateLimited.flush(pid)

      remaining = RateLimited.get_remaining_requests(pid)
      # Should have used 1 request
      assert remaining == 9

      RateLimited.stop(pid)
    end

    test "tracks rate limit capacity", %{client: client} do
      Mox.expect(Mock, :request, 2, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      # High rate limit so requests complete quickly
      {:ok, pid} = RateLimited.start(client: client, requests_per_minute: 10000)

      initial = RateLimited.get_remaining_requests(pid)

      RateLimited.add_object(pid, "Article", %{title: "Test 1"})
      {:ok, _} = RateLimited.flush(pid)

      after_first = RateLimited.get_remaining_requests(pid)

      RateLimited.add_object(pid, "Article", %{title: "Test 2"})
      {:ok, _} = RateLimited.flush(pid)

      after_second = RateLimited.get_remaining_requests(pid)

      # Verify capacity decreases with each request
      assert initial > after_first
      assert after_first > after_second

      RateLimited.stop(pid)
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

      {:ok, pid} = RateLimited.start(client: client)

      RateLimited.add_object(pid, "Article", %{title: "Test"})

      {:ok, results} = RateLimited.stop(pid)
      stats = Results.statistics(results)
      assert stats.successful == 1

      refute Process.alive?(pid)
    end
  end

  describe "error handling" do
    test "handles rate limit errors from server", %{client: client} do
      # First request fails with rate limit
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :rate_limited,
           message: "rate limit exceeded",
           status_code: 429
         }}
      end)

      # Second request succeeds after backoff
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, pid} =
        RateLimited.start(
          client: client,
          retry_on_rate_limit: true,
          retry_sleep: fn _ -> :ok end
        )

      RateLimited.add_object(pid, "Article", %{title: "Test"})

      {:ok, results} = RateLimited.flush(pid)
      stats = Results.statistics(results)
      assert stats.successful == 1

      RateLimited.stop(pid)
    end

    test "respects max retries on rate limit errors", %{client: client} do
      # Always fail with rate limit - max_retries: 5 means 5 total attempts (not 5 retries)
      Mox.expect(Mock, :request, 5, fn _client, :post, _path, _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :rate_limited,
           message: "rate limit exceeded",
           status_code: 429
         }}
      end)

      {:ok, pid} =
        RateLimited.start(
          client: client,
          retry_on_rate_limit: true,
          max_retries: 5,
          retry_sleep: fn _ -> :ok end
        )

      RateLimited.add_object(pid, "Article", %{title: "Test"})

      {:error, error} = RateLimited.flush(pid)
      # After max retries exceeded, returns :max_retries_exceeded atom
      assert error == :max_retries_exceeded

      GenServer.stop(pid, :normal)
    end
  end

  describe "callback support" do
    test "calls on_flush callback after each batch", %{client: client} do
      test_pid = self()

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      on_flush = fn results ->
        stats = Results.statistics(results)
        send(test_pid, {:flushed, stats})
      end

      {:ok, pid} = RateLimited.start(client: client, on_flush: on_flush)

      RateLimited.add_object(pid, "Article", %{title: "Test"})
      {:ok, _} = RateLimited.flush(pid)

      assert_receive {:flushed, %{successful: 1}}

      RateLimited.stop(pid)
    end

    test "calls on_error callback on failures", %{client: client} do
      test_pid = self()

      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :server_error,
           message: "Internal error",
           status_code: 500
         }}
      end)

      on_error = fn error ->
        send(test_pid, {:error_received, error.type})
      end

      {:ok, pid} = RateLimited.start(client: client, on_error: on_error)

      RateLimited.add_object(pid, "Article", %{title: "Test"})
      {:error, _} = RateLimited.flush(pid)

      assert_receive {:error_received, :server_error}

      GenServer.stop(pid, :normal)
    end
  end
end
