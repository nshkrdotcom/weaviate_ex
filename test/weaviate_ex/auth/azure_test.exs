defmodule WeaviateEx.Auth.AzureTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Auth.Azure

  describe "azure_endpoint?/1" do
    test "detects Azure login endpoint" do
      assert Azure.azure_endpoint?("https://login.microsoftonline.com/tenant/oauth2/v2.0/token")
    end

    test "detects Azure login.microsoft.com" do
      assert Azure.azure_endpoint?("https://login.microsoft.com/tenant/token")
    end

    test "detects Azure sts.windows.net" do
      assert Azure.azure_endpoint?("https://sts.windows.net/tenant/oauth2/token")
    end

    test "returns false for non-Azure endpoints" do
      refute Azure.azure_endpoint?("https://auth.example.com/token")
    end

    test "returns false for nil" do
      refute Azure.azure_endpoint?(nil)
    end
  end

  describe "default_scopes/1" do
    test "returns Azure-style default scope with client_id" do
      scopes = Azure.default_scopes("my-client-id")

      assert scopes == ["my-client-id/.default"]
    end
  end

  describe "apply_azure_defaults/1" do
    test "adds default scope for Azure endpoints" do
      opts = [
        token_endpoint: "https://login.microsoftonline.com/tenant/oauth2/token",
        client_id: "my-client-id"
      ]

      result = Azure.apply_azure_defaults(opts)

      assert result[:scopes] == ["my-client-id/.default"]
    end

    test "preserves existing scopes" do
      opts = [
        token_endpoint: "https://login.microsoftonline.com/tenant/token",
        client_id: "id",
        scopes: ["custom.scope"]
      ]

      result = Azure.apply_azure_defaults(opts)

      assert result[:scopes] == ["custom.scope"]
    end

    test "does not modify non-Azure endpoints" do
      opts = [
        token_endpoint: "https://auth.example.com/token",
        client_id: "id"
      ]

      result = Azure.apply_azure_defaults(opts)

      refute Keyword.has_key?(result, :scopes)
    end

    test "handles missing client_id" do
      opts = [
        token_endpoint: "https://login.microsoftonline.com/tenant/token"
      ]

      result = Azure.apply_azure_defaults(opts)

      # Should not add scopes without client_id
      refute Keyword.has_key?(result, :scopes)
    end
  end

  describe "format_resource/1" do
    test "formats resource URL for Azure v1 endpoints" do
      resource = Azure.format_resource("my-client-id")

      assert resource == "my-client-id"
    end
  end

  describe "detect_version/1" do
    test "detects v2 endpoints" do
      assert Azure.detect_version("https://login.microsoftonline.com/tenant/oauth2/v2.0/token") ==
               :v2
    end

    test "detects v1 endpoints" do
      assert Azure.detect_version("https://login.microsoftonline.com/tenant/oauth2/token") == :v1
    end

    test "returns unknown for non-standard endpoints" do
      assert Azure.detect_version("https://example.com/token") == :unknown
    end
  end
end
