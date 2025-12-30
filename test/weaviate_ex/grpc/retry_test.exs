defmodule WeaviateEx.GRPC.RetryTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.GRPC.Retry

  describe "with_retry/2" do
    test "returns result on first success" do
      result = Retry.with_retry(fn -> {:ok, "success"} end)
      assert result == {:ok, "success"}
    end

    test "returns error result on first call if not retryable" do
      result =
        Retry.with_retry(fn ->
          {:error, %GRPC.RPCError{status: 3, message: "invalid argument"}}
        end)

      assert {:error, %GRPC.RPCError{status: 3}} = result
    end

    test "retries on unavailable error (status 14)" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            count = :counters.get(counter, 1)

            if count < 3 do
              {:error, %GRPC.RPCError{status: 14, message: "unavailable"}}
            else
              {:ok, "success after retry"}
            end
          end,
          max_retries: 5,
          base_delay_ms: 1
        )

      assert result == {:ok, "success after retry"}
      assert :counters.get(counter, 1) == 3
    end

    test "retries on resource_exhausted error (status 8)" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            count = :counters.get(counter, 1)

            if count < 2 do
              {:error, %GRPC.RPCError{status: 8, message: "resource exhausted"}}
            else
              {:ok, "success"}
            end
          end,
          max_retries: 5,
          base_delay_ms: 1
        )

      assert result == {:ok, "success"}
      assert :counters.get(counter, 1) == 2
    end

    test "gives up after max retries and returns exhausted error" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, %GRPC.RPCError{status: 14, message: "unavailable"}}
          end,
          max_retries: 2,
          base_delay_ms: 1
        )

      # Should have been called max_retries + 1 times (initial + retries)
      assert :counters.get(counter, 1) == 3
      assert {:error, %WeaviateEx.Error{type: :retry_exhausted}} = result
    end

    test "does not retry non-retryable errors" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, %GRPC.RPCError{status: 3, message: "invalid argument"}}
          end,
          max_retries: 5,
          base_delay_ms: 1
        )

      # Should only be called once - no retries for non-retryable errors
      assert :counters.get(counter, 1) == 1
      assert {:error, %GRPC.RPCError{status: 3}} = result
    end

    test "passes through non-GRPC errors without retry" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, "some other error"}
          end,
          max_retries: 5,
          base_delay_ms: 1
        )

      assert :counters.get(counter, 1) == 1
      assert result == {:error, "some other error"}
    end

    test "respects max_retries option" do
      counter = :counters.new(1, [:atomics])

      Retry.with_retry(
        fn ->
          :counters.add(counter, 1, 1)
          {:error, %GRPC.RPCError{status: 14, message: "unavailable"}}
        end,
        max_retries: 3,
        base_delay_ms: 1
      )

      # initial call + 3 retries = 4 total calls
      assert :counters.get(counter, 1) == 4
    end
  end

  describe "calculate_backoff/1" do
    test "calculates exponential backoff" do
      assert Retry.calculate_backoff(0) == 1000
      assert Retry.calculate_backoff(1) == 2000
      assert Retry.calculate_backoff(2) == 4000
      assert Retry.calculate_backoff(3) == 8000
    end

    test "caps at max backoff (32 seconds)" do
      # At attempt 5, 2^5 * 1000 = 32000
      assert Retry.calculate_backoff(5) == 32_000
      # Beyond that should still be capped
      assert Retry.calculate_backoff(10) == 32_000
      assert Retry.calculate_backoff(100) == 32_000
    end
  end

  describe "retryable?/1" do
    test "unavailable (14) is retryable" do
      assert Retry.retryable?(%GRPC.RPCError{status: 14, message: "unavailable"})
    end

    test "resource_exhausted (8) is retryable" do
      assert Retry.retryable?(%GRPC.RPCError{status: 8, message: "resource exhausted"})
    end

    test "aborted (10) is retryable" do
      assert Retry.retryable?(%GRPC.RPCError{status: 10, message: "aborted"})
    end

    test "deadline_exceeded (4) is retryable" do
      assert Retry.retryable?(%GRPC.RPCError{status: 4, message: "deadline exceeded"})
    end

    test "invalid_argument (3) is not retryable" do
      refute Retry.retryable?(%GRPC.RPCError{status: 3, message: "invalid"})
    end

    test "not_found (5) is not retryable" do
      refute Retry.retryable?(%GRPC.RPCError{status: 5, message: "not found"})
    end

    test "permission_denied (7) is not retryable" do
      refute Retry.retryable?(%GRPC.RPCError{status: 7, message: "permission denied"})
    end

    test "unauthenticated (16) is not retryable" do
      refute Retry.retryable?(%GRPC.RPCError{status: 16, message: "unauthenticated"})
    end
  end

  describe "retryable_status?/1" do
    test "returns true for retryable status codes" do
      # deadline_exceeded
      assert Retry.retryable_status?(4)
      # resource_exhausted
      assert Retry.retryable_status?(8)
      # aborted
      assert Retry.retryable_status?(10)
      # unavailable
      assert Retry.retryable_status?(14)
    end

    test "returns false for non-retryable status codes" do
      # ok
      refute Retry.retryable_status?(0)
      # cancelled
      refute Retry.retryable_status?(1)
      # unknown
      refute Retry.retryable_status?(2)
      # invalid_argument
      refute Retry.retryable_status?(3)
      # not_found
      refute Retry.retryable_status?(5)
      # permission_denied
      refute Retry.retryable_status?(7)
      # unauthenticated
      refute Retry.retryable_status?(16)
    end
  end
end
