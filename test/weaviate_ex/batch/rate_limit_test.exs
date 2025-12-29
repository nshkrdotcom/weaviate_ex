defmodule WeaviateEx.Batch.RateLimitTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.RateLimit

  describe "detect/1 with status code" do
    test "detects 429 status as rate limited" do
      response = %{status: 429, body: %{}}

      assert {:rate_limited, retry_after} = RateLimit.detect(response)
      assert retry_after > 0
    end

    test "returns :ok for successful response" do
      response = %{status: 200, body: %{}}

      assert :ok = RateLimit.detect(response)
    end

    test "returns :ok for 4xx errors (except 429)" do
      assert :ok = RateLimit.detect(%{status: 400, body: %{}})
      assert :ok = RateLimit.detect(%{status: 401, body: %{}})
      assert :ok = RateLimit.detect(%{status: 403, body: %{}})
      assert :ok = RateLimit.detect(%{status: 404, body: %{}})
    end

    test "returns :ok for 5xx errors (not rate limit)" do
      assert :ok = RateLimit.detect(%{status: 500, body: %{}})
      assert :ok = RateLimit.detect(%{status: 502, body: %{}})
      assert :ok = RateLimit.detect(%{status: 503, body: %{}})
    end
  end

  describe "detect/1 with headers" do
    test "uses Retry-After header when present" do
      response = %{
        status: 429,
        headers: %{"retry-after" => "30"},
        body: %{}
      }

      assert {:rate_limited, 30_000} = RateLimit.detect(response)
    end

    test "handles Retry-After as date" do
      # This is a future date format that some APIs use
      response = %{
        status: 429,
        headers: %{"retry-after" => "120"},
        body: %{}
      }

      assert {:rate_limited, 120_000} = RateLimit.detect(response)
    end
  end

  describe "detect/1 with OpenAI error format" do
    test "detects OpenAI rate_limit error type" do
      response = %{
        status: 429,
        body: %{
          "error" => %{
            "type" => "rate_limit",
            "message" => "Rate limit exceeded"
          }
        }
      }

      assert {:rate_limited, _retry_after} = RateLimit.detect(response)
    end

    test "detects OpenAI insufficient_quota error" do
      response = %{
        status: 429,
        body: %{
          "error" => %{
            "type" => "insufficient_quota",
            "message" => "You exceeded your quota"
          }
        }
      }

      assert {:rate_limited, _retry_after} = RateLimit.detect(response)
    end
  end

  describe "detect/1 with Cohere error format" do
    test "detects Cohere rate limit from headers" do
      response = %{
        status: 429,
        headers: %{
          "x-ratelimit-remaining" => "0",
          "x-ratelimit-reset" => "1640000000"
        },
        body: %{}
      }

      assert {:rate_limited, _retry_after} = RateLimit.detect(response)
    end
  end

  describe "detect/1 with Weaviate batch error" do
    test "detects rate limit in batch result errors" do
      response = %{
        status: 200,
        body: [
          %{
            "result" => %{
              "status" => "FAILED",
              "errors" => %{
                "error" => [
                  %{"message" => "rate limit exceeded for vectorizer module"}
                ]
              }
            }
          }
        ]
      }

      assert {:rate_limited, _retry_after} = RateLimit.detect(response)
    end

    test "does not detect rate limit for other errors" do
      response = %{
        status: 200,
        body: [
          %{
            "result" => %{
              "status" => "FAILED",
              "errors" => %{
                "error" => [
                  %{"message" => "validation error: missing required field"}
                ]
              }
            }
          }
        ]
      }

      assert :ok = RateLimit.detect(response)
    end
  end

  describe "calculate_backoff/1" do
    test "returns exponential backoff" do
      assert RateLimit.calculate_backoff(0) == 1000
      assert RateLimit.calculate_backoff(1) == 2000
      assert RateLimit.calculate_backoff(2) == 4000
      assert RateLimit.calculate_backoff(3) == 8000
    end

    test "caps at max backoff" do
      # After many retries, should cap at max (60 seconds)
      assert RateLimit.calculate_backoff(10) <= 60_000
    end
  end

  describe "rate_limited?/1" do
    test "returns true for 429 status" do
      assert RateLimit.rate_limited?(%{status: 429}) == true
    end

    test "returns false for other status codes" do
      assert RateLimit.rate_limited?(%{status: 200}) == false
      assert RateLimit.rate_limited?(%{status: 400}) == false
      assert RateLimit.rate_limited?(%{status: 500}) == false
    end

    test "returns true for error tuples with 429" do
      assert RateLimit.rate_limited?({:error, %{status: 429}}) == true
    end

    test "returns false for error tuples without 429" do
      assert RateLimit.rate_limited?({:error, %{status: 500}}) == false
    end
  end

  describe "extract_retry_after/1" do
    test "extracts from numeric Retry-After header" do
      headers = %{"retry-after" => "60"}
      assert RateLimit.extract_retry_after(headers) == 60_000
    end

    test "returns default when header not present" do
      assert RateLimit.extract_retry_after(%{}) == 1000
    end

    test "handles case-insensitive header" do
      assert RateLimit.extract_retry_after(%{"Retry-After" => "30"}) == 30_000
    end
  end
end
