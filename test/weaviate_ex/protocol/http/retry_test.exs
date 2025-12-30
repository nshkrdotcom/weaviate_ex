defmodule WeaviateEx.Protocol.HTTP.RetryTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Protocol.HTTP.Retry

  describe "with_retry/2" do
    test "succeeds on first try without retry" do
      fun = fn -> {:ok, %{data: "success"}} end

      assert {:ok, %{data: "success"}} = Retry.with_retry(fun)
    end

    test "returns error result when not retryable" do
      fun = fn -> {:error, :not_found} end

      assert {:error, :not_found} = Retry.with_retry(fun)
    end

    test "retries on connection refused error" do
      # Track retry attempts with an Agent
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 2 do
          {:error, %Mint.TransportError{reason: :econnrefused}}
        else
          {:ok, :recovered}
        end
      end

      assert {:ok, :recovered} = Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end

    test "retries on connection reset error" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 1 do
          {:error, %Mint.TransportError{reason: :econnreset}}
        else
          {:ok, :recovered}
        end
      end

      assert {:ok, :recovered} = Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end

    test "retries on timeout error" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 1 do
          {:error, %Mint.TransportError{reason: :timeout}}
        else
          {:ok, :recovered}
        end
      end

      assert {:ok, :recovered} = Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end

    test "exhausts retries and returns error" do
      fun = fn -> {:error, %Mint.TransportError{reason: :econnrefused}} end

      result = Retry.with_retry(fun, max_retries: 2, base_delay_ms: 10)

      assert {:error, error} = result
      assert error.type == :retry_exhausted
      assert error.details.attempts == 3
    end

    test "respects max_retries option" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        Agent.update(agent, fn n -> n + 1 end)
        {:error, %Mint.TransportError{reason: :econnrefused}}
      end

      Retry.with_retry(fun, max_retries: 2, base_delay_ms: 10)

      # Initial attempt + 2 retries = 3 attempts
      assert Agent.get(agent, & &1) == 3

      Agent.stop(agent)
    end

    test "does not retry non-transport errors" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        Agent.update(agent, fn n -> n + 1 end)
        {:error, :some_other_error}
      end

      assert {:error, :some_other_error} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      # Only 1 attempt - no retries
      assert Agent.get(agent, & &1) == 1

      Agent.stop(agent)
    end

    test "passes through {:ok, response} from Finch" do
      fun = fn -> {:ok, %Finch.Response{status: 200, body: "ok"}} end

      assert {:ok, %Finch.Response{status: 200, body: "ok"}} = Retry.with_retry(fun)
    end

    test "retries on 503 Service Unavailable and succeeds on second attempt" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 1 do
          {:ok, %Finch.Response{status: 503, body: "Service Unavailable"}}
        else
          {:ok, %Finch.Response{status: 200, body: "ok"}}
        end
      end

      assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      # 2 attempts - initial + 1 retry
      assert Agent.get(agent, & &1) == 2

      Agent.stop(agent)
    end

    test "retries on 429 rate limit" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 1 do
          {:ok, %Finch.Response{status: 429, body: "Too Many Requests"}}
        else
          {:ok, %Finch.Response{status: 200, body: "ok"}}
        end
      end

      assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end

    test "retries on 500 Internal Server Error" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 1 do
          {:ok, %Finch.Response{status: 500, body: "Internal Server Error"}}
        else
          {:ok, %Finch.Response{status: 200, body: "ok"}}
        end
      end

      assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end

    test "retries on 502 Bad Gateway" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 1 do
          {:ok, %Finch.Response{status: 502, body: "Bad Gateway"}}
        else
          {:ok, %Finch.Response{status: 200, body: "ok"}}
        end
      end

      assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end

    test "retries on 504 Gateway Timeout" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 1 do
          {:ok, %Finch.Response{status: 504, body: "Gateway Timeout"}}
        else
          {:ok, %Finch.Response{status: 200, body: "ok"}}
        end
      end

      assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end

    test "retries on 408 Request Timeout" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 1 do
          {:ok, %Finch.Response{status: 408, body: "Request Timeout"}}
        else
          {:ok, %Finch.Response{status: 200, body: "ok"}}
        end
      end

      assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end

    test "does not retry on 400 (client error)" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        Agent.update(agent, fn n -> n + 1 end)
        {:ok, %Finch.Response{status: 400, body: "Bad Request"}}
      end

      assert {:ok, %Finch.Response{status: 400, body: "Bad Request"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      # Only 1 attempt - no retries for 400
      assert Agent.get(agent, & &1) == 1

      Agent.stop(agent)
    end

    test "does not retry on 401 (auth error)" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        Agent.update(agent, fn n -> n + 1 end)
        {:ok, %Finch.Response{status: 401, body: "Unauthorized"}}
      end

      assert {:ok, %Finch.Response{status: 401, body: "Unauthorized"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      # Only 1 attempt - no retries for 401
      assert Agent.get(agent, & &1) == 1

      Agent.stop(agent)
    end

    test "does not retry on 404 (not found)" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        Agent.update(agent, fn n -> n + 1 end)
        {:ok, %Finch.Response{status: 404, body: "Not Found"}}
      end

      assert {:ok, %Finch.Response{status: 404, body: "Not Found"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      # Only 1 attempt - no retries for 404
      assert Agent.get(agent, & &1) == 1

      Agent.stop(agent)
    end

    test "respects max_retries limit for HTTP status errors" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        Agent.update(agent, fn n -> n + 1 end)
        {:ok, %Finch.Response{status: 503, body: "Service Unavailable"}}
      end

      result = Retry.with_retry(fun, max_retries: 2, base_delay_ms: 10)

      assert {:error, error} = result
      assert error.type == :retry_exhausted
      assert error.details.attempts == 3

      # Initial attempt + 2 retries = 3 attempts
      assert Agent.get(agent, & &1) == 3

      Agent.stop(agent)
    end

    test "retries with exponential backoff" do
      # This test verifies that retries happen (timing is tested elsewhere)
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        attempt = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if attempt < 2 do
          {:error, %Mint.TransportError{reason: :econnrefused}}
        else
          {:ok, :recovered}
        end
      end

      # With base_delay_ms: 10, attempt 0 should delay ~10ms, attempt 1 ~20ms
      assert {:ok, :recovered} = Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      Agent.stop(agent)
    end
  end

  describe "calculate_backoff/1" do
    test "calculates exponential backoff base values" do
      # Base values with jitter (±10%), default base_delay_ms = 100
      # Attempt 0: ~100ms
      assert Retry.calculate_backoff(0) >= 90 and Retry.calculate_backoff(0) <= 110
      # Attempt 1: ~200ms
      assert Retry.calculate_backoff(1) >= 180 and Retry.calculate_backoff(1) <= 220
      # Attempt 2: ~400ms
      assert Retry.calculate_backoff(2) >= 360 and Retry.calculate_backoff(2) <= 440
      # Attempt 3: ~800ms
      assert Retry.calculate_backoff(3) >= 720 and Retry.calculate_backoff(3) <= 880
    end

    test "caps backoff at max_delay" do
      # With default max_delay of 5000ms, delay should be capped
      delay = Retry.calculate_backoff(10)
      # 5000 + 10% jitter max = 5500
      assert delay <= 5500
    end

    test "adds jitter to backoff delay" do
      # Run multiple times to verify we get different values (jitter)
      delays = for _ <- 1..10, do: Retry.calculate_backoff(1)
      unique_delays = Enum.uniq(delays)

      # With jitter, we should have multiple unique values
      # (statistically very unlikely to get same value 10 times)
      assert length(unique_delays) > 1
    end
  end

  describe "retryable_transport_error?/1" do
    test "returns true for connection refused" do
      assert Retry.retryable_transport_error?(%Mint.TransportError{reason: :econnrefused})
    end

    test "returns true for connection reset" do
      assert Retry.retryable_transport_error?(%Mint.TransportError{reason: :econnreset})
    end

    test "returns true for timeout" do
      assert Retry.retryable_transport_error?(%Mint.TransportError{reason: :timeout})
    end

    test "returns true for closed" do
      assert Retry.retryable_transport_error?(%Mint.TransportError{reason: :closed})
    end

    test "returns true for nxdomain" do
      assert Retry.retryable_transport_error?(%Mint.TransportError{reason: :nxdomain})
    end

    test "returns false for other errors" do
      refute Retry.retryable_transport_error?(%Mint.TransportError{reason: :invalid_cert})
      refute Retry.retryable_transport_error?(:some_error)
      refute Retry.retryable_transport_error?(nil)
    end

    test "returns true for tuple-based transport errors" do
      assert Retry.retryable_transport_error?(
               {:error, %Mint.TransportError{reason: :econnrefused}}
             )
    end
  end

  describe "retryable_status_code?/1" do
    test "returns true for 408 Request Timeout" do
      assert Retry.retryable_status_code?(408)
    end

    test "returns true for 429 Too Many Requests" do
      assert Retry.retryable_status_code?(429)
    end

    test "returns true for 500 Internal Server Error" do
      assert Retry.retryable_status_code?(500)
    end

    test "returns true for 502 Bad Gateway" do
      assert Retry.retryable_status_code?(502)
    end

    test "returns true for 503 Service Unavailable" do
      assert Retry.retryable_status_code?(503)
    end

    test "returns true for 504 Gateway Timeout" do
      assert Retry.retryable_status_code?(504)
    end

    test "returns false for 200 OK" do
      refute Retry.retryable_status_code?(200)
    end

    test "returns false for 400 Bad Request" do
      refute Retry.retryable_status_code?(400)
    end

    test "returns false for 401 Unauthorized" do
      refute Retry.retryable_status_code?(401)
    end

    test "returns false for 403 Forbidden" do
      refute Retry.retryable_status_code?(403)
    end

    test "returns false for 404 Not Found" do
      refute Retry.retryable_status_code?(404)
    end

    test "returns false for 422 Unprocessable Entity" do
      refute Retry.retryable_status_code?(422)
    end
  end

  describe "retryable_status_codes/0" do
    test "returns list of retryable status codes" do
      codes = Retry.retryable_status_codes()
      assert is_list(codes)
      assert 408 in codes
      assert 429 in codes
      assert 500 in codes
      assert 502 in codes
      assert 503 in codes
      assert 504 in codes
    end
  end

  describe "default_retry_opts/0" do
    test "returns default options" do
      defaults = Retry.default_retry_opts()
      assert is_list(defaults)
      assert Keyword.has_key?(defaults, :max_retries)
      assert Keyword.has_key?(defaults, :base_delay_ms)
      assert Keyword.has_key?(defaults, :max_delay_ms)
    end
  end
end
