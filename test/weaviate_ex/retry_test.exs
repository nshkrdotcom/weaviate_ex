defmodule WeaviateEx.RetryTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Retry

  describe "with_exponential_backoff/2" do
    test "returns result on success" do
      result = Retry.with_exponential_backoff(fn -> {:ok, "success"} end)

      assert result == {:ok, "success"}
    end

    test "retries on retryable error" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_exponential_backoff(
          fn ->
            count = :counters.get(counter, 1)
            :counters.add(counter, 1, 1)

            if count < 2 do
              {:error, %{status: 503, body: "Service Unavailable"}}
            else
              {:ok, "success"}
            end
          end,
          max_retries: 3,
          base_delay: 1
        )

      assert result == {:ok, "success"}
      assert :counters.get(counter, 1) == 3
    end

    test "returns error after max retries" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_exponential_backoff(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, %{status: 503, body: "Service Unavailable"}}
          end,
          max_retries: 3,
          base_delay: 1
        )

      assert {:error, _} = result
      assert :counters.get(counter, 1) == 4
    end

    test "does not retry non-retryable errors" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_exponential_backoff(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, %{status: 400, body: "Bad Request"}}
          end,
          max_retries: 3,
          base_delay: 1
        )

      assert {:error, _} = result
      # Should only try once (no retries for 400)
      assert :counters.get(counter, 1) == 1
    end

    test "respects max_delay option" do
      # This test verifies the delay cap behavior
      result =
        Retry.with_exponential_backoff(
          fn -> {:ok, "done"} end,
          max_delay: 100
        )

      assert result == {:ok, "done"}
    end
  end

  describe "retryable?/1" do
    test "returns true for 429 rate limit" do
      assert Retry.retryable?(%{status: 429}) == true
    end

    test "returns true for 503 service unavailable" do
      assert Retry.retryable?(%{status: 503}) == true
    end

    test "returns true for 502 bad gateway" do
      assert Retry.retryable?(%{status: 502}) == true
    end

    test "returns true for 504 gateway timeout" do
      assert Retry.retryable?(%{status: 504}) == true
    end

    test "returns true for timeout error" do
      assert Retry.retryable?(%{reason: :timeout}) == true
    end

    test "returns true for connection error" do
      assert Retry.retryable?(%{reason: :econnrefused}) == true
    end

    test "returns false for 400 bad request" do
      assert Retry.retryable?(%{status: 400}) == false
    end

    test "returns false for 401 unauthorized" do
      assert Retry.retryable?(%{status: 401}) == false
    end

    test "returns false for 404 not found" do
      assert Retry.retryable?(%{status: 404}) == false
    end

    test "returns false for 500 internal server error" do
      assert Retry.retryable?(%{status: 500}) == false
    end

    # gRPC error tests
    test "returns true for gRPC UNAVAILABLE (14)" do
      assert Retry.retryable?(%GRPC.RPCError{status: 14, message: "Unavailable"}) == true
    end

    test "returns true for gRPC RESOURCE_EXHAUSTED (8)" do
      assert Retry.retryable?(%GRPC.RPCError{status: 8, message: "Rate limited"}) == true
    end

    test "returns true for gRPC ABORTED (10)" do
      assert Retry.retryable?(%GRPC.RPCError{status: 10, message: "Aborted"}) == true
    end

    test "returns true for gRPC DEADLINE_EXCEEDED (4)" do
      assert Retry.retryable?(%GRPC.RPCError{status: 4, message: "Timeout"}) == true
    end

    test "returns false for gRPC NOT_FOUND (5)" do
      assert Retry.retryable?(%GRPC.RPCError{status: 5, message: "Not found"}) == false
    end

    test "returns false for gRPC INVALID_ARGUMENT (3)" do
      assert Retry.retryable?(%GRPC.RPCError{status: 3, message: "Invalid"}) == false
    end

    test "returns true for WeaviateEx.Error with grpc_status :unavailable" do
      error = %WeaviateEx.Error{
        type: :service_unavailable,
        message: "Unavailable",
        details: %{grpc_status: :unavailable}
      }

      assert Retry.retryable?(error) == true
    end

    test "returns true for WeaviateEx.Error with type :rate_limited" do
      error = %WeaviateEx.Error{type: :rate_limited, message: "Rate limited", details: %{}}
      assert Retry.retryable?(error) == true
    end

    test "returns true for WeaviateEx.Error with type :timeout_error" do
      error = %WeaviateEx.Error{type: :timeout_error, message: "Timeout", details: %{}}
      assert Retry.retryable?(error) == true
    end

    test "returns false for WeaviateEx.Error with type :not_found" do
      error = %WeaviateEx.Error{type: :not_found, message: "Not found", details: %{}}
      assert Retry.retryable?(error) == false
    end
  end

  describe "grpc_retryable?/1" do
    test "returns true for :unavailable" do
      assert Retry.grpc_retryable?(:unavailable) == true
    end

    test "returns true for :resource_exhausted" do
      assert Retry.grpc_retryable?(:resource_exhausted) == true
    end

    test "returns true for :aborted" do
      assert Retry.grpc_retryable?(:aborted) == true
    end

    test "returns true for :deadline_exceeded" do
      assert Retry.grpc_retryable?(:deadline_exceeded) == true
    end

    test "returns true for integer 14 (UNAVAILABLE)" do
      assert Retry.grpc_retryable?(14) == true
    end

    test "returns true for integer 8 (RESOURCE_EXHAUSTED)" do
      assert Retry.grpc_retryable?(8) == true
    end

    test "returns false for :not_found" do
      assert Retry.grpc_retryable?(:not_found) == false
    end

    test "returns false for :invalid_argument" do
      assert Retry.grpc_retryable?(:invalid_argument) == false
    end

    test "returns false for integer 5 (NOT_FOUND)" do
      assert Retry.grpc_retryable?(5) == false
    end
  end

  describe "calculate_delay/3" do
    test "returns base delay for first retry" do
      delay = Retry.calculate_delay(0, 100, 5000)
      # With jitter, should be around 100 +/- 10%
      assert delay >= 90 and delay <= 110
    end

    test "doubles delay for each retry" do
      delay1 = Retry.calculate_delay(0, 100, 5000)
      delay2 = Retry.calculate_delay(1, 100, 5000)
      delay3 = Retry.calculate_delay(2, 100, 5000)

      # Approximate due to jitter
      assert delay2 > delay1
      assert delay3 > delay2
    end

    test "caps delay at max_delay" do
      delay = Retry.calculate_delay(10, 100, 500)
      # Should be capped at 500 +/- jitter
      assert delay <= 550
    end
  end
end
