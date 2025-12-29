defmodule WeaviateEx.Batch.WithBatchTest do
  # async: false because we use set_mox_global for GenServer-based tests
  use ExUnit.Case, async: false
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.Batch
  alias WeaviateEx.Batch.ErrorTracking.Results
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  # Use global mode for GenServer-based tests
  setup do
    Mox.set_mox_global()
    :ok
  end

  describe "with_batch/3 fixed size mode" do
    test "creates batch context and auto-flushes on exit", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/batch/objects"
        assert length(body["objects"]) == 3

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, results} =
        Batch.with_batch(client, [batch_size: 100], fn batch ->
          batch
          |> Batch.add_object("Article", %{title: "Test 1"})
          |> Batch.add_object("Article", %{title: "Test 2"})
          |> Batch.add_object("Article", %{title: "Test 3"})
        end)

      stats = Results.statistics(results)
      assert stats.successful == 3
      assert stats.failed == 0
    end

    test "auto-flushes when batch size is reached", %{client: client} do
      test_pid = self()

      # Expect 2 batch requests (5 objects each)
      Mox.expect(Mock, :request, 2, fn _client, :post, _path, body, _opts ->
        send(test_pid, {:batch_size, length(body["objects"])})

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, results} =
        Batch.with_batch(client, [batch_size: 5], fn batch ->
          Enum.reduce(1..10, batch, fn i, b ->
            Batch.add_object(b, "Article", %{title: "Test #{i}"})
          end)
        end)

      # Verify 2 batches were sent
      assert_receive {:batch_size, 5}
      assert_receive {:batch_size, 5}

      # The final stats are accumulated from all flushes
      stats = Results.statistics(results)
      assert stats.successful == 10
    end

    test "supports references", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/references"
        {:ok, [%{"status" => "SUCCESS"}, %{"status" => "SUCCESS"}]}
      end)

      {:ok, results} =
        Batch.with_batch(client, [], fn batch ->
          batch
          |> Batch.add_reference("Article", "uuid-1", "hasAuthor", "author-1")
          |> Batch.add_reference("Article", "uuid-2", "hasAuthor", "author-2")
        end)

      stats = Results.statistics(results)
      assert stats.successful == 2
    end

    test "handles objects only", %{client: client} do
      # Request for objects
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/batch/objects"

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, results} =
        Batch.with_batch(client, [], fn batch ->
          batch
          |> Batch.add_object("Article", %{title: "Test"})
        end)

      stats = Results.statistics(results)
      assert stats.successful == 1
    end
  end

  describe "with_batch/3 dynamic mode" do
    test "uses dynamic batching when mode: :dynamic", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, results} =
        Batch.with_batch(client, [mode: :dynamic], fn batch ->
          batch
          |> Batch.add_object("Article", %{title: "Test 1"})
          |> Batch.add_object("Article", %{title: "Test 2"})
        end)

      stats = Results.statistics(results)
      assert stats.successful == 2
    end
  end

  describe "with_batch/3 rate_limited mode" do
    test "uses rate-limited batching when mode: :rate_limited", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, results} =
        Batch.with_batch(client, [mode: :rate_limited, requests_per_minute: 60], fn batch ->
          batch
          |> Batch.add_object("Article", %{title: "Test 1"})
          |> Batch.add_object("Article", %{title: "Test 2"})
        end)

      stats = Results.statistics(results)
      assert stats.successful == 2
    end
  end

  describe "with_batch/3 error handling" do
    test "propagates errors from flush", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :server_error,
           message: "Internal error",
           status_code: 500
         }}
      end)

      {:error, error} =
        Batch.with_batch(client, [], fn batch ->
          Batch.add_object(batch, "Article", %{title: "Test"})
        end)

      assert error.type == :server_error
    end

    test "captures partial failures", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:ok,
         [
           %{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS"},
           %{
             "id" => Uniq.UUID.uuid4(),
             "status" => "FAILED",
             "result" => %{"errors" => [%{"message" => "Invalid property"}]}
           }
         ]}
      end)

      {:ok, results} =
        Batch.with_batch(client, [], fn batch ->
          batch
          |> Batch.add_object("Article", %{title: "Good"})
          |> Batch.add_object("Article", %{title: "Bad"})
        end)

      stats = Results.statistics(results)
      assert stats.successful == 1
      assert stats.failed == 1
    end

    test "handles exceptions in callback", %{client: client} do
      assert_raise RuntimeError, "test error", fn ->
        Batch.with_batch(client, [], fn _batch ->
          raise "test error"
        end)
      end
    end
  end

  describe "with_batch/3 flush control" do
    test "explicit flush within callback", %{client: client} do
      test_pid = self()

      Mox.expect(Mock, :request, 2, fn _client, :post, _path, body, _opts ->
        send(test_pid, {:batch_size, length(body["objects"])})

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, results} =
        Batch.with_batch(client, [], fn batch ->
          batch = Batch.add_object(batch, "Article", %{title: "Test 1"})
          {:ok, batch, flush_results} = Batch.flush(batch)

          # Verify first flush was successful
          first_stats = Results.statistics(flush_results)
          assert first_stats.successful == 1

          batch = Batch.add_object(batch, "Article", %{title: "Test 2"})
          batch
        end)

      assert_receive {:batch_size, 1}
      assert_receive {:batch_size, 1}

      # Total accumulated results
      stats = Results.statistics(results)
      assert stats.successful == 2
    end
  end

  describe "with_batch/3 callback options" do
    test "passes on_flush callback", %{client: client} do
      test_pid = self()

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      on_flush = fn batch_results ->
        stats = Results.statistics(batch_results)
        send(test_pid, {:flushed, stats})
      end

      {:ok, _results} =
        Batch.with_batch(client, [on_flush: on_flush], fn batch ->
          Batch.add_object(batch, "Article", %{title: "Test"})
        end)

      assert_receive {:flushed, %{successful: 1}}
    end

    test "passes on_error callback", %{client: client} do
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

      {:error, _} =
        Batch.with_batch(client, [on_error: on_error], fn batch ->
          Batch.add_object(batch, "Article", %{title: "Test"})
        end)

      assert_receive {:error_received, :server_error}
    end
  end

  describe "with_batch/3 consistency options" do
    test "passes consistency_level to requests", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "consistency_level=QUORUM"

        results =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj["id"] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, results}
      end)

      {:ok, _} =
        Batch.with_batch(client, [consistency_level: "QUORUM"], fn batch ->
          Batch.add_object(batch, "Article", %{title: "Test"})
        end)
    end
  end
end
