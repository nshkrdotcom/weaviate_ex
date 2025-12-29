defmodule WeaviateEx.Client.StateTest do
  use ExUnit.Case, async: true

  import WeaviateEx.TestHelpers

  alias WeaviateEx.Client.State

  describe "new/0" do
    test "creates new state with initializing status" do
      state = State.new()

      assert state.status == :initializing
      assert %DateTime{} = state.created_at
      assert state.last_used_at == nil
      assert state.request_count == 0
      assert state.error_count == 0
      assert state.last_error == nil
    end
  end

  describe "connected/1" do
    test "transitions to connected status" do
      state = State.new() |> State.connected()

      assert state.status == :connected
    end
  end

  describe "disconnected/2" do
    test "transitions to disconnected status with reason" do
      state =
        State.new()
        |> State.connected()
        |> State.disconnected(:connection_lost)

      assert state.status == :disconnected
      assert state.last_error == :connection_lost
    end
  end

  describe "closed/1" do
    test "transitions to closed status" do
      state =
        State.new()
        |> State.connected()
        |> State.closed()

      assert state.status == :closed
    end
  end

  describe "record_request/1" do
    test "increments request count and updates last_used_at" do
      state = State.new() |> State.connected()

      # Wait until time has passed since created_at to ensure different timestamps
      :ok =
        wait_until(
          fn -> DateTime.compare(DateTime.utc_now(), state.created_at) == :gt end,
          timeout: 100,
          interval: 1
        )

      updated = State.record_request(state)

      assert updated.request_count == 1
      assert %DateTime{} = updated.last_used_at
      assert DateTime.compare(updated.last_used_at, state.created_at) == :gt
    end

    test "increments request count multiple times" do
      state =
        State.new()
        |> State.connected()
        |> State.record_request()
        |> State.record_request()
        |> State.record_request()

      assert state.request_count == 3
    end
  end

  describe "record_error/2" do
    test "increments error count and stores last error" do
      error = %RuntimeError{message: "test error"}

      state =
        State.new()
        |> State.connected()
        |> State.record_error(error)

      assert state.error_count == 1
      assert state.last_error == error
    end

    test "increments error count multiple times" do
      error1 = %RuntimeError{message: "error 1"}
      error2 = %RuntimeError{message: "error 2"}

      state =
        State.new()
        |> State.connected()
        |> State.record_error(error1)
        |> State.record_error(error2)

      assert state.error_count == 2
      # Last error should be the most recent
      assert state.last_error == error2
    end
  end

  describe "status transitions" do
    test "full lifecycle" do
      state = State.new()
      assert state.status == :initializing

      state = State.connected(state)
      assert state.status == :connected

      state = State.record_request(state)
      assert state.request_count == 1

      state = State.record_error(state, :timeout)
      assert state.error_count == 1

      state = State.disconnected(state, :network_error)
      assert state.status == :disconnected

      state = State.connected(state)
      assert state.status == :connected

      state = State.closed(state)
      assert state.status == :closed
    end
  end
end
