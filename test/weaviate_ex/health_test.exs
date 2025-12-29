defmodule WeaviateEx.HealthTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.Health
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "alive?/1 with client" do
    test "returns {:ok, true} when server responds successfully", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/.well-known/live", nil, [] ->
        {:ok, %{}}
      end)

      assert {:ok, true} = Health.alive?(client)
    end

    test "returns {:ok, false} when server returns 5xx error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/.well-known/live", nil, [] ->
        {:error, %{status_code: 503}}
      end)

      assert {:ok, false} = Health.alive?(client)
    end

    test "returns {:ok, false} when server returns 4xx error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/.well-known/live", nil, [] ->
        {:error, %{status_code: 404}}
      end)

      assert {:ok, false} = Health.alive?(client)
    end

    test "returns {:ok, false} when connection fails", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/.well-known/live", nil, [] ->
        {:error, %WeaviateEx.Error{type: :connection_error, message: "Connection refused"}}
      end)

      assert {:ok, false} = Health.alive?(client)
    end
  end

  describe "ready?/1 with client" do
    test "returns {:ok, true} when server is ready", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/.well-known/ready", nil, [] ->
        {:ok, %{}}
      end)

      assert {:ok, true} = Health.ready?(client)
    end

    test "returns {:ok, false} when server is not ready", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/.well-known/ready", nil, [] ->
        {:error, %{status_code: 503}}
      end)

      assert {:ok, false} = Health.ready?(client)
    end

    test "returns {:ok, false} when server returns 4xx error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/.well-known/ready", nil, [] ->
        {:error, %{status_code: 400}}
      end)

      assert {:ok, false} = Health.ready?(client)
    end

    test "returns {:ok, false} when connection fails", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/.well-known/ready", nil, [] ->
        {:error, %WeaviateEx.Error{type: :timeout_error, message: "Timeout"}}
      end)

      assert {:ok, false} = Health.ready?(client)
    end
  end

  describe "integration tests" do
    @tag :integration
    test "alive? returns true for running server" do
      if WeaviateEx.TestHelpers.integration_mode?() do
        assert {:ok, true} = Health.alive?()
      else
        assert true
      end
    end

    @tag :integration
    test "ready? returns true for ready server" do
      if WeaviateEx.TestHelpers.integration_mode?() do
        assert {:ok, true} = Health.ready?()
      else
        assert true
      end
    end
  end
end
