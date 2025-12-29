defmodule WeaviateEx.AuthTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Auth

  describe "api_key/1" do
    test "returns auth map with API key" do
      auth = Auth.api_key("my-api-key")

      assert auth == %{
               type: :api_key,
               api_key: "my-api-key"
             }
    end
  end

  describe "bearer_token/2" do
    test "returns auth map with bearer token" do
      auth = Auth.bearer_token("my-token")

      assert auth == %{
               type: :bearer_token,
               access_token: "my-token",
               expires_in: nil,
               refresh_token: nil
             }
    end

    test "accepts expires_in option" do
      auth = Auth.bearer_token("my-token", expires_in: 3600)

      assert auth.expires_in == 3600
    end

    test "accepts refresh_token option" do
      auth = Auth.bearer_token("my-token", refresh_token: "refresh-token")

      assert auth.refresh_token == "refresh-token"
    end
  end

  describe "client_credentials/2" do
    test "returns auth map for OIDC client credentials" do
      auth = Auth.client_credentials("client-id", "client-secret")

      assert auth == %{
               type: :oidc_client_credentials,
               client_id: "client-id",
               client_secret: "client-secret",
               scopes: []
             }
    end

    test "accepts scopes option" do
      auth = Auth.client_credentials("client-id", "client-secret", scopes: ["openid", "profile"])

      assert auth.scopes == ["openid", "profile"]
    end
  end

  describe "client_password/3" do
    test "returns auth map for OIDC password flow" do
      auth = Auth.client_password("username", "password")

      assert auth == %{
               type: :oidc_password,
               username: "username",
               password: "password",
               client_id: nil,
               client_secret: nil,
               scopes: []
             }
    end

    test "accepts client credentials options" do
      auth =
        Auth.client_password("username", "password",
          client_id: "my-client",
          client_secret: "my-secret"
        )

      assert auth.client_id == "my-client"
      assert auth.client_secret == "my-secret"
    end

    test "accepts scopes option" do
      auth = Auth.client_password("username", "password", scopes: ["openid"])

      assert auth.scopes == ["openid"]
    end
  end

  describe "to_headers/1" do
    test "generates API key header" do
      auth = Auth.api_key("my-api-key")
      headers = Auth.to_headers(auth)

      assert headers == [{"Authorization", "Bearer my-api-key"}]
    end

    test "generates bearer token header" do
      auth = Auth.bearer_token("my-token")
      headers = Auth.to_headers(auth)

      assert headers == [{"Authorization", "Bearer my-token"}]
    end

    test "returns empty list for OIDC types (needs token manager)" do
      auth = Auth.client_credentials("client-id", "client-secret")
      headers = Auth.to_headers(auth)

      assert headers == []
    end
  end
end
