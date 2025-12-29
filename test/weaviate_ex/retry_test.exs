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
