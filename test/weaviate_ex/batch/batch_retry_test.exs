defmodule WeaviateEx.Batch.BatchRetryTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.BatchRetry

  describe "rate_limit_error?/1" do
    test "returns false for nil" do
      refute BatchRetry.rate_limit_error?(nil)
    end

    test "detects rate limit messages" do
      assert BatchRetry.rate_limit_error?("rate limit exceeded")
      assert BatchRetry.rate_limit_error?("Rate limit reached for this model")
      assert BatchRetry.rate_limit_error?("tokens per min limit exceeded")
      assert BatchRetry.rate_limit_error?("Please contact support@cohere.com")
      assert BatchRetry.rate_limit_error?("503 error: service unavailable")
    end

    test "returns false for non-rate-limit errors" do
      refute BatchRetry.rate_limit_error?("Invalid property")
      refute BatchRetry.rate_limit_error?("Object not found")
    end
  end

  describe "calculate_backoff/1" do
    test "calculates exponential backoff" do
      assert BatchRetry.calculate_backoff(0) == 1000
      assert BatchRetry.calculate_backoff(1) == 2000
      assert BatchRetry.calculate_backoff(2) == 4000
      assert BatchRetry.calculate_backoff(3) == 8000
    end

    test "caps backoff at max value" do
      # Should cap at 30 seconds
      assert BatchRetry.calculate_backoff(10) <= 30_000
    end
  end

  describe "should_retry?/2" do
    test "returns true for rate limit errors under max retries" do
      assert BatchRetry.should_retry?("rate limit exceeded", 0)
      assert BatchRetry.should_retry?("rate limit exceeded", 4)
    end

    test "returns false for rate limit errors at max retries" do
      refute BatchRetry.should_retry?("rate limit exceeded", 5)
    end

    test "returns false for non-rate-limit errors" do
      refute BatchRetry.should_retry?("Invalid property", 0)
    end

    test "returns false for nil errors" do
      refute BatchRetry.should_retry?(nil, 0)
    end
  end
end
