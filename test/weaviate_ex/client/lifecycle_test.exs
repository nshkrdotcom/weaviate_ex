defmodule WeaviateEx.Client.LifecycleTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Client
  alias WeaviateEx.Error.ClosedClientError

  describe "close/1" do
    test "closes a client" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")

      :ok = Client.close(client)

      assert Client.closed?(client) == true
    end

    test "closing already closed client is idempotent" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")

      :ok = Client.close(client)
      :ok = Client.close(client)

      assert Client.closed?(client) == true
    end
  end

  describe "closed?/1" do
    test "returns false for new client" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")

      assert Client.closed?(client) == false
    end

    test "returns true for closed client" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      Client.close(client)

      assert Client.closed?(client) == true
    end
  end

  describe "status/1" do
    test "returns connected for new client" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")

      status = Client.status(client)

      assert status in [:connected, :initializing]
    end

    test "returns closed for closed client" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      Client.close(client)

      assert Client.status(client) == :closed
    end
  end

  describe "stats/1" do
    test "returns client statistics" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")

      stats = Client.stats(client)

      assert %Client.State{} = stats
      assert stats.request_count >= 0
      assert stats.error_count >= 0
    end
  end

  describe "with_client/2" do
    test "creates client, executes function, and closes" do
      result =
        Client.with_client([base_url: "http://localhost:8080"], fn client ->
          assert %Client{} = client
          :success
        end)

      assert result == :success
    end

    test "returns function result" do
      result =
        Client.with_client([base_url: "http://localhost:8080"], fn _client ->
          {:ok, "computed value"}
        end)

      assert result == {:ok, "computed value"}
    end

    test "closes client even on error" do
      assert_raise RuntimeError, "test error", fn ->
        Client.with_client([base_url: "http://localhost:8080"], fn _client ->
          raise "test error"
        end)
      end

      # Client should have been closed (we can't verify directly since we don't have access)
    end

    test "passes client options to new client" do
      result =
        Client.with_client([base_url: "http://custom:9999"], fn client ->
          assert client.config.base_url == "http://custom:9999"
          :custom_url_verified
        end)

      assert result == :custom_url_verified
    end
  end
end

defmodule WeaviateEx.Error.ClosedClientErrorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Error.ClosedClientError

  describe "exception/1" do
    test "creates error with message" do
      closed_at = DateTime.utc_now()
      error = ClosedClientError.exception(closed_at: closed_at)

      assert %ClosedClientError{} = error
      assert error.closed_at == closed_at
      assert error.message =~ "Client was closed"
    end

    test "message includes closed_at timestamp" do
      closed_at = DateTime.utc_now()
      error = ClosedClientError.exception(closed_at: closed_at)

      assert error.message =~ DateTime.to_string(closed_at)
    end
  end

  describe "raising ClosedClientError" do
    test "can be raised" do
      assert_raise ClosedClientError, fn ->
        raise ClosedClientError, closed_at: DateTime.utc_now()
      end
    end
  end
end
