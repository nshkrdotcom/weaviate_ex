defmodule WeaviateEx.Auth.TokenManagerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import WeaviateEx.TestHelpers

  alias WeaviateEx.Auth.OIDC.Config
  alias WeaviateEx.Auth.TokenManager

  setup do
    bypass = Bypass.open()

    # Setup discovery endpoint
    Bypass.stub(bypass, "GET", "/.well-known/openid-configuration", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "issuer" => "http://localhost:#{bypass.port}",
          "token_endpoint" => "http://localhost:#{bypass.port}/oauth/token",
          "authorization_endpoint" => "http://localhost:#{bypass.port}/oauth/authorize"
        })
      )
    end)

    {:ok, bypass: bypass}
  end

  describe "start_link/1" do
    test "starts the token manager with OIDC config", %{bypass: bypass} do
      # Setup token endpoint
      Bypass.stub(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => "test-token",
            "token_type" => "Bearer",
            "expires_in" => 3600
          })
        )
      end)

      oidc_config = %Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "test-client",
        client_secret: "test-secret",
        scopes: []
      }

      name = :"token_manager_test_#{:rand.uniform(100_000)}"
      {:ok, pid} = TokenManager.start_link(oidc_config: oidc_config, auth: auth, name: name)

      assert Process.alive?(pid)

      # Cleanup
      GenServer.stop(pid)
    end
  end

  describe "get_token/1" do
    test "returns current valid token", %{bypass: bypass} do
      Bypass.stub(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => "my-access-token",
            "token_type" => "Bearer",
            "expires_in" => 3600
          })
        )
      end)

      oidc_config = %Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "test-client",
        client_secret: "test-secret",
        scopes: []
      }

      name = :"token_manager_test_#{:rand.uniform(100_000)}"
      {:ok, pid} = TokenManager.start_link(oidc_config: oidc_config, auth: auth, name: name)

      # Wait for initial token fetch
      :ok = wait_for_genserver_state(pid, fn state -> state.token != nil end)

      {:ok, token} = TokenManager.get_token(pid)

      assert token.access_token == "my-access-token"
      assert token.token_type == "Bearer"
      assert token.expires_in == 3600

      GenServer.stop(pid)
    end

    test "returns error when no token available", %{bypass: bypass} do
      Bypass.stub(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          401,
          Jason.encode!(%{
            "error" => "invalid_client",
            "error_description" => "Invalid credentials"
          })
        )
      end)

      oidc_config = %Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "bad-client",
        client_secret: "bad-secret",
        scopes: []
      }

      name = :"token_manager_test_#{:rand.uniform(100_000)}"

      log =
        capture_log(fn ->
          {:ok, pid} = TokenManager.start_link(oidc_config: oidc_config, auth: auth, name: name)

          # Wait for the initial token fetch to complete and fail
          # Since token stays nil on failure, we poll until get_token returns an error
          :ok =
            wait_until(fn ->
              TokenManager.get_token(pid) == {:error, :no_token}
            end)

          assert {:error, :no_token} = TokenManager.get_token(pid)

          GenServer.stop(pid)
        end)

      assert log =~ "TokenManager: Failed to fetch token"
      assert log =~ "invalid_client"
    end
  end

  describe "get_access_token/1" do
    test "returns just the access token string", %{bypass: bypass} do
      Bypass.stub(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => "bearer-token-123",
            "token_type" => "Bearer",
            "expires_in" => 3600
          })
        )
      end)

      oidc_config = %Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "test-client",
        client_secret: "test-secret",
        scopes: []
      }

      name = :"token_manager_test_#{:rand.uniform(100_000)}"
      {:ok, pid} = TokenManager.start_link(oidc_config: oidc_config, auth: auth, name: name)

      # Wait for initial token fetch
      :ok = wait_for_genserver_state(pid, fn state -> state.token != nil end)

      {:ok, access_token} = TokenManager.get_access_token(pid)
      assert access_token == "bearer-token-123"

      GenServer.stop(pid)
    end
  end

  describe "automatic token refresh" do
    test "refreshes token when expiring soon", %{bypass: bypass} do
      # Track how many token requests are made
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      Bypass.stub(bypass, "POST", "/oauth/token", fn conn ->
        count = Agent.get_and_update(agent, fn n -> {n + 1, n + 1} end)

        access_token =
          if count == 1, do: "initial-token", else: "refreshed-token"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => access_token,
            "token_type" => "Bearer",
            # Very short expiry to trigger refresh
            "expires_in" => 2,
            "refresh_token" => "refresh-token"
          })
        )
      end)

      oidc_config = %Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "test-client",
        client_secret: "test-secret",
        scopes: []
      }

      name = :"token_manager_test_#{:rand.uniform(100_000)}"

      # Start with short refresh buffer
      {:ok, pid} =
        TokenManager.start_link(
          oidc_config: oidc_config,
          auth: auth,
          name: name,
          refresh_buffer_seconds: 1
        )

      # Wait for initial token
      :ok = wait_for_genserver_state(pid, fn state -> state.token != nil end)

      {:ok, token1} = TokenManager.get_token(pid)
      assert token1.access_token == "initial-token"

      # Trigger refresh manually instead of waiting for timer
      send(pid, :fetch_token)

      :ok =
        wait_for_genserver_state(pid, fn state ->
          state.token && state.token.access_token == "refreshed-token"
        end)

      {:ok, token2} = TokenManager.get_token(pid)
      assert token2.access_token == "refreshed-token"

      GenServer.stop(pid)
      Agent.stop(agent)
    end
  end

  describe "force_refresh/1" do
    test "forces immediate token refresh", %{bypass: bypass} do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      Bypass.stub(bypass, "POST", "/oauth/token", fn conn ->
        count = Agent.get_and_update(agent, fn n -> {n + 1, n + 1} end)
        access_token = "token-#{count}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => access_token,
            "token_type" => "Bearer",
            "expires_in" => 3600
          })
        )
      end)

      oidc_config = %Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "test-client",
        client_secret: "test-secret",
        scopes: []
      }

      name = :"token_manager_test_#{:rand.uniform(100_000)}"
      {:ok, pid} = TokenManager.start_link(oidc_config: oidc_config, auth: auth, name: name)

      # Wait for initial token
      :ok = wait_for_genserver_state(pid, fn state -> state.token != nil end)

      {:ok, token1} = TokenManager.get_token(pid)
      assert token1.access_token == "token-1"

      # Force refresh
      :ok = TokenManager.force_refresh(pid)

      :ok =
        wait_for_genserver_state(pid, fn state ->
          state.token && state.token.access_token == "token-2"
        end)

      {:ok, token2} = TokenManager.get_token(pid)
      assert token2.access_token == "token-2"

      GenServer.stop(pid)
      Agent.stop(agent)
    end
  end

  describe "with issuer URL" do
    test "discovers OIDC config from issuer", %{bypass: bypass} do
      Bypass.stub(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => "discovered-token",
            "token_type" => "Bearer",
            "expires_in" => 3600
          })
        )
      end)

      auth = %{
        type: :oidc_client_credentials,
        client_id: "test-client",
        client_secret: "test-secret",
        scopes: []
      }

      name = :"token_manager_test_#{:rand.uniform(100_000)}"

      {:ok, pid} =
        TokenManager.start_link(
          issuer_url: "http://localhost:#{bypass.port}",
          auth: auth,
          name: name
        )

      :ok = wait_for_genserver_state(pid, fn state -> state.token != nil end)

      {:ok, token} = TokenManager.get_token(pid)
      assert token.access_token == "discovered-token"

      GenServer.stop(pid)
    end
  end
end
