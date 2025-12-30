defmodule WeaviateEx.Protocol.HTTP.RateLimit do
  @moduledoc """
  Tracks rate limit headers from Weaviate responses.

  Parses rate limit information from HTTP response headers and provides
  utilities for implementing client-side rate limiting.

  ## Headers Tracked

  - `X-RateLimit-Limit` - Maximum requests allowed in the window
  - `X-RateLimit-Remaining` - Requests remaining in current window
  - `X-RateLimit-Reset` - Unix timestamp when the rate limit resets

  ## Usage

      # Extract rate limit info from response headers
      rate_limit = RateLimit.from_headers(response.headers)

      # Check if we should wait
      case RateLimit.should_wait?(rate_limit) do
        {:wait, ms} -> Process.sleep(ms)
        :ok -> :proceed
      end
  """

  @type t :: %__MODULE__{
          limit: non_neg_integer() | nil,
          remaining: non_neg_integer() | nil,
          reset_at: DateTime.t() | nil
        }

  defstruct [:limit, :remaining, :reset_at]

  @doc """
  Extracts rate limit information from response headers.

  ## Examples

      headers = [
        {"x-ratelimit-limit", "100"},
        {"x-ratelimit-remaining", "95"},
        {"x-ratelimit-reset", "1735500000"}
      ]
      RateLimit.from_headers(headers)
      # => %RateLimit{limit: 100, remaining: 95, reset_at: ~U[...]}
  """
  @spec from_headers(list({String.t(), String.t()})) :: t()
  def from_headers(headers) when is_list(headers) do
    headers_map = normalize_headers(headers)

    %__MODULE__{
      limit: parse_int(headers_map["x-ratelimit-limit"]),
      remaining: parse_int(headers_map["x-ratelimit-remaining"]),
      reset_at: parse_reset(headers_map["x-ratelimit-reset"])
    }
  end

  defp normalize_headers(headers) do
    Map.new(headers, fn {k, v} -> {String.downcase(to_string(k)), v} end)
  end

  @doc """
  Checks if rate limited and returns wait time in milliseconds.

  ## Examples

      rate_limit = %RateLimit{remaining: 0, reset_at: future_time}
      RateLimit.should_wait?(rate_limit)
      # => {:wait, 5000}

      rate_limit = %RateLimit{remaining: 10, reset_at: future_time}
      RateLimit.should_wait?(rate_limit)
      # => :ok
  """
  @spec should_wait?(t()) :: {:wait, non_neg_integer()} | :ok
  def should_wait?(%__MODULE__{remaining: 0, reset_at: reset_at}) when not is_nil(reset_at) do
    now = DateTime.utc_now()
    diff = DateTime.diff(reset_at, now, :millisecond)

    if diff > 0 do
      {:wait, diff}
    else
      :ok
    end
  end

  def should_wait?(_), do: :ok

  @doc """
  Returns the percentage of rate limit remaining.

  ## Examples

      rate_limit = %RateLimit{limit: 100, remaining: 25}
      RateLimit.remaining_percent(rate_limit)
      # => 25.0
  """
  @spec remaining_percent(t()) :: float() | nil
  def remaining_percent(%__MODULE__{limit: limit, remaining: remaining})
      when is_integer(limit) and is_integer(remaining) and limit > 0 do
    remaining / limit * 100
  end

  def remaining_percent(_), do: nil

  @doc """
  Checks if the rate limit info indicates we're close to being rate limited.

  Returns true if remaining requests are below the threshold percentage.

  ## Examples

      rate_limit = %RateLimit{limit: 100, remaining: 5}
      RateLimit.near_limit?(rate_limit, 10)
      # => true

      rate_limit = %RateLimit{limit: 100, remaining: 50}
      RateLimit.near_limit?(rate_limit, 10)
      # => false
  """
  @spec near_limit?(t(), number()) :: boolean()
  def near_limit?(%__MODULE__{} = rate_limit, threshold_percent \\ 10) do
    case remaining_percent(rate_limit) do
      nil -> false
      percent -> percent < threshold_percent
    end
  end

  @doc """
  Returns seconds until the rate limit resets.

  ## Examples

      rate_limit = %RateLimit{reset_at: future_time}
      RateLimit.seconds_until_reset(rate_limit)
      # => 60
  """
  @spec seconds_until_reset(t()) :: non_neg_integer() | nil
  def seconds_until_reset(%__MODULE__{reset_at: nil}), do: nil

  def seconds_until_reset(%__MODULE__{reset_at: reset_at}) do
    now = DateTime.utc_now()
    diff = DateTime.diff(reset_at, now, :second)
    max(0, diff)
  end

  @doc """
  Checks if the rate limit info is stale (reset time has passed).

  ## Examples

      rate_limit = %RateLimit{reset_at: past_time}
      RateLimit.stale?(rate_limit)
      # => true
  """
  @spec stale?(t()) :: boolean()
  def stale?(%__MODULE__{reset_at: nil}), do: true

  def stale?(%__MODULE__{reset_at: reset_at}) do
    DateTime.compare(reset_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Returns a human-readable summary of the rate limit status.

  ## Examples

      rate_limit = %RateLimit{limit: 100, remaining: 42, reset_at: future_time}
      RateLimit.summary(rate_limit)
      # => "42/100 remaining, resets in 45s"
  """
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{limit: nil}), do: "No rate limit information available"

  def summary(%__MODULE__{limit: limit, remaining: remaining, reset_at: reset_at}) do
    remaining_str = remaining || "?"
    reset_str = format_reset(reset_at)

    "#{remaining_str}/#{limit} remaining#{reset_str}"
  end

  defp format_reset(nil), do: ""

  defp format_reset(reset_at) do
    now = DateTime.utc_now()
    diff = DateTime.diff(reset_at, now, :second)

    if diff > 0 do
      ", resets in #{diff}s"
    else
      ", reset"
    end
  end

  defp parse_int(nil), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_reset(nil), do: nil

  defp parse_reset(str) when is_binary(str) do
    case Integer.parse(str) do
      {timestamp, _} ->
        case DateTime.from_unix(timestamp) do
          {:ok, dt} -> dt
          _ -> nil
        end

      :error ->
        nil
    end
  end
end
