defmodule WeaviateEx.Client.State do
  @moduledoc """
  Client lifecycle state tracking.

  Tracks the state of a client connection including:
  - Connection status
  - Request and error counts
  - Timestamps for lifecycle events

  ## Example

      state = State.new()
      |> State.connected()
      |> State.record_request()
      |> State.record_request()

      IO.puts("Request count: \#{state.request_count}")
  """

  @type status :: :initializing | :connected | :disconnected | :closed

  @type t :: %__MODULE__{
          status: status(),
          created_at: DateTime.t(),
          last_used_at: DateTime.t() | nil,
          request_count: non_neg_integer(),
          error_count: non_neg_integer(),
          last_error: term() | nil
        }

  defstruct status: :initializing,
            created_at: nil,
            last_used_at: nil,
            request_count: 0,
            error_count: 0,
            last_error: nil

  @doc """
  Create new client state.

  Initializes state with `:initializing` status and current timestamp.

  ## Example

      state = State.new()
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      status: :initializing,
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Transition to connected status.

  ## Example

      state = State.new() |> State.connected()
  """
  @spec connected(t()) :: t()
  def connected(%__MODULE__{} = state) do
    %{state | status: :connected}
  end

  @doc """
  Transition to disconnected status with reason.

  ## Example

      state = State.connected(state) |> State.disconnected(:network_error)
  """
  @spec disconnected(t(), reason :: term()) :: t()
  def disconnected(%__MODULE__{} = state, reason) do
    %{state | status: :disconnected, last_error: reason}
  end

  @doc """
  Transition to closed status.

  ## Example

      state = State.connected(state) |> State.closed()
  """
  @spec closed(t()) :: t()
  def closed(%__MODULE__{} = state) do
    %{state | status: :closed}
  end

  @doc """
  Record a successful request.

  Increments the request count and updates the last_used_at timestamp.

  ## Example

      state = State.record_request(state)
  """
  @spec record_request(t()) :: t()
  def record_request(%__MODULE__{} = state) do
    %{state | request_count: state.request_count + 1, last_used_at: DateTime.utc_now()}
  end

  @doc """
  Record an error.

  Increments the error count and stores the last error.

  ## Example

      state = State.record_error(state, %RuntimeError{message: "connection timeout"})
  """
  @spec record_error(t(), error :: term()) :: t()
  def record_error(%__MODULE__{} = state, error) do
    %{state | error_count: state.error_count + 1, last_error: error}
  end
end
