defmodule WeaviateEx.Auth.OIDCTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Auth.OIDC

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "discover/1" do
    test "discovers OIDC configuration from well-known endpoint", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/.well-known/openid-configuration", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "issuer" => "http://localhost:#{bypass.port}",
            "token_endpoint" => "http://localhost:#{bypass.port}/oauth/token",
            "authorization_endpoint" => "http://localhost:#{bypass.port}/oauth/authorize",
            "userinfo_endpoint" => "http://localhost:#{bypass.port}/oauth/userinfo",
            "jwks_uri" => "http://localhost:#{bypass.port}/.well-known/jwks.json"
          })
        )
      end)

      {:ok, config} = OIDC.discover("http://localhost:#{bypass.port}")

      assert config.issuer == "http://localhost:#{bypass.port}"
      assert config.token_endpoint == "http://localhost:#{bypass.port}/oauth/token"
      assert config.authorization_endpoint == "http://localhost:#{bypass.port}/oauth/authorize"
    end

    test "returns error for invalid issuer", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/.well-known/openid-configuration", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert {:error, _reason} = OIDC.discover("http://localhost:#{bypass.port}")
    end

    test "returns error for malformed response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/.well-known/openid-configuration", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, "invalid json")
      end)

      assert {:error, _reason} = OIDC.discover("http://localhost:#{bypass.port}")
    end
  end

  describe "get_token/3 with client_credentials" do
    test "exchanges client credentials for token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        assert params["grant_type"] == "client_credentials"
        assert params["client_id"] == "my-client"
        assert params["client_secret"] == "my-secret"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => "test-access-token",
            "token_type" => "Bearer",
            "expires_in" => 3600,
            "refresh_token" => "test-refresh-token"
          })
        )
      end)

      oidc_config = %OIDC.Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "my-client",
        client_secret: "my-secret",
        scopes: []
      }

      {:ok, token_response} = OIDC.get_token(oidc_config, auth)

      assert token_response.access_token == "test-access-token"
      assert token_response.token_type == "Bearer"
      assert token_response.expires_in == 3600
      assert token_response.refresh_token == "test-refresh-token"
    end

    test "includes scopes in request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        assert params["scope"] == "openid profile email"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => "token",
            "token_type" => "Bearer",
            "expires_in" => 3600
          })
        )
      end)

      oidc_config = %OIDC.Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "my-client",
        client_secret: "my-secret",
        scopes: ["openid", "profile", "email"]
      }

      {:ok, _token_response} = OIDC.get_token(oidc_config, auth)
    end

    test "returns error for token request failure", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          401,
          Jason.encode!(%{
            "error" => "invalid_client",
            "error_description" => "Client authentication failed"
          })
        )
      end)

      oidc_config = %OIDC.Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_client_credentials,
        client_id: "invalid-client",
        client_secret: "invalid-secret",
        scopes: []
      }

      assert {:error, %{error: "invalid_client"}} = OIDC.get_token(oidc_config, auth)
    end
  end

  describe "get_token/3 with password grant" do
    test "exchanges password credentials for token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        assert params["grant_type"] == "password"
        assert params["username"] == "user@example.com"
        assert params["password"] == "secret123"
        assert params["client_id"] == "my-client"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => "password-access-token",
            "token_type" => "Bearer",
            "expires_in" => 7200
          })
        )
      end)

      oidc_config = %OIDC.Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      auth = %{
        type: :oidc_password,
        username: "user@example.com",
        password: "secret123",
        client_id: "my-client",
        client_secret: nil,
        scopes: []
      }

      {:ok, token_response} = OIDC.get_token(oidc_config, auth)

      assert token_response.access_token == "password-access-token"
      assert token_response.expires_in == 7200
    end
  end

  describe "refresh_token/2" do
    test "refreshes access token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        assert params["grant_type"] == "refresh_token"
        assert params["refresh_token"] == "old-refresh-token"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "access_token" => "new-access-token",
            "token_type" => "Bearer",
            "expires_in" => 3600,
            "refresh_token" => "new-refresh-token"
          })
        )
      end)

      oidc_config = %OIDC.Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      {:ok, token_response} = OIDC.refresh_token(oidc_config, "old-refresh-token")

      assert token_response.access_token == "new-access-token"
      assert token_response.refresh_token == "new-refresh-token"
    end

    test "returns error for invalid refresh token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          400,
          Jason.encode!(%{
            "error" => "invalid_grant",
            "error_description" => "Refresh token expired"
          })
        )
      end)

      oidc_config = %OIDC.Config{
        issuer: "http://localhost:#{bypass.port}",
        token_endpoint: "http://localhost:#{bypass.port}/oauth/token"
      }

      assert {:error, %{error: "invalid_grant"}} =
               OIDC.refresh_token(oidc_config, "expired-token")
    end
  end

  describe "OIDC.Config struct" do
    test "has required fields" do
      config = %OIDC.Config{}
      assert Map.has_key?(config, :issuer)
      assert Map.has_key?(config, :token_endpoint)
      assert Map.has_key?(config, :authorization_endpoint)
      assert Map.has_key?(config, :userinfo_endpoint)
      assert Map.has_key?(config, :jwks_uri)
    end
  end

  describe "OIDC.TokenResponse struct" do
    test "has required fields" do
      response = %OIDC.TokenResponse{}
      assert Map.has_key?(response, :access_token)
      assert Map.has_key?(response, :token_type)
      assert Map.has_key?(response, :expires_in)
      assert Map.has_key?(response, :refresh_token)
      assert Map.has_key?(response, :id_token)
      assert Map.has_key?(response, :scope)
    end

    test "expires_at/1 calculates expiration timestamp" do
      # Create a token response
      response = %OIDC.TokenResponse{
        access_token: "test",
        token_type: "Bearer",
        expires_in: 3600,
        issued_at: ~U[2025-01-01 00:00:00Z]
      }

      assert OIDC.TokenResponse.expires_at(response) == ~U[2025-01-01 01:00:00Z]
    end

    test "expired?/1 checks if token is expired" do
      # Expired token
      expired = %OIDC.TokenResponse{
        access_token: "test",
        expires_in: 3600,
        issued_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      }

      assert OIDC.TokenResponse.expired?(expired) == true

      # Valid token
      valid = %OIDC.TokenResponse{
        access_token: "test",
        expires_in: 3600,
        issued_at: DateTime.utc_now()
      }

      assert OIDC.TokenResponse.expired?(valid) == false
    end

    test "expiring_soon?/2 checks if token expires within buffer" do
      # Token expiring in 30 seconds
      soon = %OIDC.TokenResponse{
        access_token: "test",
        expires_in: 3600,
        issued_at: DateTime.add(DateTime.utc_now(), -3570, :second)
      }

      # Default buffer is 60 seconds
      assert OIDC.TokenResponse.expiring_soon?(soon) == true

      # Fresh token
      fresh = %OIDC.TokenResponse{
        access_token: "test",
        expires_in: 3600,
        issued_at: DateTime.utc_now()
      }

      assert OIDC.TokenResponse.expiring_soon?(fresh) == false
    end
  end
end
