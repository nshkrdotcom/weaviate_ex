defmodule WeaviateEx.Protocol.HTTP.RetryTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Protocol.HTTP.Retry

  describe "with_retry/2" do
    test "returns successful result without retry" do
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

    test "does not retry HTTP error responses" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        Agent.update(agent, fn n -> n + 1 end)
        {:ok, %Finch.Response{status: 500, body: "error"}}
      end

      assert {:ok, %Finch.Response{status: 500, body: "error"}} =
               Retry.with_retry(fun, max_retries: 3, base_delay_ms: 10)

      # Only 1 attempt - HTTP errors are not transport errors
      assert Agent.get(agent, & &1) == 1

      Agent.stop(agent)
    end
  end

  describe "calculate_backoff/1" do
    test "calculates exponential backoff" do
      assert Retry.calculate_backoff(0) == 500
      assert Retry.calculate_backoff(1) == 1000
      assert Retry.calculate_backoff(2) == 2000
      assert Retry.calculate_backoff(3) == 4000
      assert Retry.calculate_backoff(4) == 8000
    end

    test "caps backoff at 32 seconds" do
      assert Retry.calculate_backoff(6) == 32_000
      assert Retry.calculate_backoff(10) == 32_000
      assert Retry.calculate_backoff(100) == 32_000
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
end
