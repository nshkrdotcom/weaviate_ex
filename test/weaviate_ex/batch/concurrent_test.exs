defmodule WeaviateEx.Batch.ConcurrentTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.Concurrent

  describe "insert_many/4" do
    test "splits objects into batches based on batch_size" do
      objects = for i <- 1..10, do: %{id: "uuid-#{i}", properties: %{name: "Object #{i}"}}

      # With batch_size of 3, should create 4 batches (3 + 3 + 3 + 1)
      batches = Concurrent.split_into_batches(objects, batch_size: 3)

      assert length(batches) == 4
      assert length(Enum.at(batches, 0)) == 3
      assert length(Enum.at(batches, 1)) == 3
      assert length(Enum.at(batches, 2)) == 3
      assert length(Enum.at(batches, 3)) == 1
    end

    test "default batch_size is 100" do
      objects = for i <- 1..250, do: %{id: "uuid-#{i}"}

      batches = Concurrent.split_into_batches(objects, [])

      assert length(batches) == 3
      assert length(Enum.at(batches, 0)) == 100
      assert length(Enum.at(batches, 1)) == 100
      assert length(Enum.at(batches, 2)) == 50
    end
  end

  describe "options" do
    test "default options" do
      opts = Concurrent.default_options()

      assert opts[:max_concurrency] == 4
      assert opts[:batch_size] == 100
      assert opts[:ordered] == false
      assert opts[:timeout] == 30_000
    end

    test "merges custom options with defaults" do
      custom = [max_concurrency: 8, batch_size: 50]
      opts = Concurrent.merge_options(custom)

      assert opts[:max_concurrency] == 8
      assert opts[:batch_size] == 50
      assert opts[:ordered] == false
      assert opts[:timeout] == 30_000
    end
  end

  describe "aggregate_results/1" do
    test "aggregates successful results" do
      batch_results = [
        {:ok,
         %{
           successful: [%{id: "uuid-1"}, %{id: "uuid-2"}],
           failed: []
         }},
        {:ok,
         %{
           successful: [%{id: "uuid-3"}],
           failed: []
         }}
      ]

      result = Concurrent.aggregate_results(batch_results)

      assert result.successful_count == 3
      assert result.failed_count == 0
      assert length(result.successful) == 3
      assert result.failed == []
    end

    test "aggregates mixed results with failures" do
      batch_results = [
        {:ok,
         %{
           successful: [%{id: "uuid-1"}],
           failed: [%{id: "uuid-2", error: "Validation error"}]
         }},
        {:ok,
         %{
           successful: [%{id: "uuid-3"}],
           failed: []
         }}
      ]

      result = Concurrent.aggregate_results(batch_results)

      assert result.successful_count == 2
      assert result.failed_count == 1
      assert length(result.successful) == 2
      assert length(result.failed) == 1
    end

    test "handles batch-level errors" do
      batch_results = [
        {:ok,
         %{
           successful: [%{id: "uuid-1"}],
           failed: []
         }},
        {:error, %{message: "Connection timeout"}}
      ]

      result = Concurrent.aggregate_results(batch_results)

      assert result.successful_count == 1
      assert result.batch_errors == 1
    end

    test "preserves order when ordered option is true" do
      # Objects with index markers
      batch_results = [
        {:ok,
         %{
           successful: [%{id: "uuid-1", _batch_index: 0}, %{id: "uuid-2", _batch_index: 0}],
           failed: []
         }},
        {:ok,
         %{
           successful: [%{id: "uuid-3", _batch_index: 1}],
           failed: []
         }}
      ]

      result = Concurrent.aggregate_results(batch_results, ordered: true)

      # Results should maintain batch order
      ids = Enum.map(result.successful, & &1.id)
      assert ids == ["uuid-1", "uuid-2", "uuid-3"]
    end
  end

  describe "ConcurrentResult struct" do
    test "creates result with counts" do
      result = %Concurrent.Result{
        successful: [%{id: "uuid-1"}, %{id: "uuid-2"}],
        failed: [%{id: "uuid-3", error: "error"}],
        successful_count: 2,
        failed_count: 1,
        batch_errors: 0,
        total_batches: 1,
        execution_time_ms: 100
      }

      assert result.successful_count == 2
      assert result.failed_count == 1
      assert Concurrent.Result.all_successful?(result) == false
    end

    test "all_successful? returns true when no failures" do
      result = %Concurrent.Result{
        successful: [%{id: "uuid-1"}],
        failed: [],
        successful_count: 1,
        failed_count: 0,
        batch_errors: 0,
        total_batches: 1,
        execution_time_ms: 50
      }

      assert Concurrent.Result.all_successful?(result) == true
    end

    test "has_failures? returns true when there are failures" do
      result = %Concurrent.Result{
        successful: [],
        failed: [%{id: "uuid-1", error: "error"}],
        successful_count: 0,
        failed_count: 1,
        batch_errors: 0,
        total_batches: 1,
        execution_time_ms: 50
      }

      assert Concurrent.Result.has_failures?(result) == true
    end

    test "has_failures? returns true when there are batch errors" do
      result = %Concurrent.Result{
        successful: [],
        failed: [],
        successful_count: 0,
        failed_count: 0,
        batch_errors: 1,
        total_batches: 1,
        execution_time_ms: 50
      }

      assert Concurrent.Result.has_failures?(result) == true
    end
  end

  describe "retry handling" do
    test "identifies retryable errors" do
      # Rate limit error - should retry
      assert Concurrent.retryable_error?({:error, %{status: 429}}) == true

      # Server error - should retry
      assert Concurrent.retryable_error?({:error, %{status: 503}}) == true

      # Client error - should not retry
      assert Concurrent.retryable_error?({:error, %{status: 400}}) == false

      # Success - should not retry
      assert Concurrent.retryable_error?({:ok, %{}}) == false
    end
  end
end
