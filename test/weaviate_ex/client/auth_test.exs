defmodule WeaviateEx.Client.AuthTest do
  use ExUnit.Case, async: false

  import WeaviateEx.TestHelpers

  alias WeaviateEx.Auth
  alias WeaviateEx.Client

  setup do
    bypass = Bypass.open()

    Bypass.stub(bypass, "GET", "/v1/.well-known/openid-configuration", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "issuer" => "http://localhost:#{bypass.port}/v1",
          "token_endpoint" => "http://localhost:#{bypass.port}/oauth/token",
          "authorization_endpoint" => "http://localhost:#{bypass.port}/oauth/authorize"
        })
      )
    end)

    Bypass.stub(bypass, "POST", "/oauth/token", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "access_token" => "oidc-access-token",
          "token_type" => "Bearer",
          "expires_in" => 3600
        })
      )
    end)

    {:ok, bypass: bypass}
  end

  test "connect/1 attaches token manager and injects OIDC metadata", %{bypass: bypass} do
    auth = Auth.client_credentials("client-id", "client-secret")

    {:ok, client} =
      Client.connect(
        base_url: "http://localhost:#{bypass.port}",
        auth: auth,
        skip_grpc: true,
        skip_init_checks: true
      )

    assert is_pid(client.config.token_manager)

    :ok =
      wait_for_genserver_state(client.config.token_manager, fn state ->
        state.token != nil
      end)

    metadata = Client.grpc_metadata(client)
    assert metadata["authorization"] == "Bearer oidc-access-token"

    :ok = Client.close(client)
  end
end
