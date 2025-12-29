# Start ExUnit with async test support
ExUnit.start()

# Note: Support files are automatically compiled via elixirc_paths in mix.exs
# No need to require them here as it causes module redefinition warnings

# Configure Mox
Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)

# Set global mode for async tests
Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)

# Disable strict health checks during tests
Application.put_env(:weaviate_ex, :strict, false)

# Exclude integration tests by default
ExUnit.configure(exclude: [:integration, :property, :performance])

defmodule WeaviateEx.TestHelpers do
  @moduledoc """
  Shared test helpers and utilities.

  Uses supertester patterns for robust, async-safe testing without Process.sleep.
  """

  @doc """
  Checks if we should run tests against a live Weaviate instance.

  Set WEAVIATE_INTEGRATION=true to enable integration tests.
  """
  def integration_mode? do
    System.get_env("WEAVIATE_INTEGRATION") == "true"
  end

  @doc """
  Sets up the appropriate Protocol implementation based on test mode.

  - In mock mode: Uses WeaviateEx.Protocol.Mock
  - In integration mode: Uses WeaviateEx.Protocol.HTTP.Client (real HTTP)
  """
  def setup_protocol(_context) do
    if integration_mode?() do
      Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
      :ok
    else
      Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)
      :ok
    end
  end

  @doc """
  Wait until a condition is met, polling at regular intervals.

  This is a robust replacement for Process.sleep that ensures deterministic
  test behavior. Uses supertester-style polling pattern.

  ## Options
    - `:timeout` - Maximum time to wait in milliseconds (default: 5000)
    - `:interval` - Polling interval in milliseconds (default: 10)

  ## Examples

      # Wait for GenServer state to have a token
      wait_until(fn ->
        case :sys.get_state(pid) do
          %{token: nil} -> false
          %{token: _} -> true
        end
      end)

      # Wait with custom timeout
      wait_until(fn -> Process.alive?(pid) end, timeout: 1000)
  """
  @spec wait_until((-> boolean()), keyword()) :: :ok | {:error, :timeout}
  def wait_until(condition, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    interval = Keyword.get(opts, :interval, 10)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_until(condition, deadline, interval)
  end

  defp do_wait_until(condition, deadline, interval) do
    if condition.() do
      :ok
    else
      now = System.monotonic_time(:millisecond)

      if now >= deadline do
        {:error, :timeout}
      else
        Process.sleep(interval)
        do_wait_until(condition, deadline, interval)
      end
    end
  end

  @doc """
  Wait for a GenServer's state to match a condition.

  Uses :sys.get_state to inspect the GenServer state without interrupting
  normal message processing.

  ## Examples

      # Wait for token to be set
      wait_for_genserver_state(pid, fn state -> state.token != nil end)

      # Wait for specific token value
      wait_for_genserver_state(pid, fn state ->
        state.token && state.token.access_token == "expected-token"
      end)
  """
  @spec wait_for_genserver_state(pid(), (map() -> boolean()), keyword()) ::
          :ok | {:error, :timeout}
  def wait_for_genserver_state(server, condition, opts \\ []) do
    wait_until(
      fn ->
        try do
          state = :sys.get_state(server)
          condition.(state)
        rescue
          _ -> false
        catch
          :exit, _ -> false
        end
      end,
      opts
    )
  end

  @doc """
  Advance time in a controlled way for timer-based tests.

  Instead of waiting real time for timers to fire, this helper can be used
  to trigger timer-based operations by sending messages directly.

  ## Examples

      # Trigger a refresh cycle in TokenManager
      send(pid, :fetch_token)
      wait_for_genserver_state(pid, fn state -> state.token != nil end)
  """
  @spec trigger_and_wait(pid(), term(), (map() -> boolean()), keyword()) ::
          :ok | {:error, :timeout}
  def trigger_and_wait(server, message, condition, opts \\ []) do
    send(server, message)
    wait_for_genserver_state(server, condition, opts)
  end
end
