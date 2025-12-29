defmodule WeaviateEx.Config.ProxyTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Config.Proxy

  describe "new/1" do
    test "creates proxy config with explicit options" do
      proxy =
        Proxy.new(
          http: "http://proxy.example.com:8080",
          https: "https://proxy.example.com:8443",
          grpc: "grpc://proxy.example.com:50051"
        )

      assert proxy.http == "http://proxy.example.com:8080"
      assert proxy.https == "https://proxy.example.com:8443"
      assert proxy.grpc == "grpc://proxy.example.com:50051"
    end

    test "creates empty proxy config when no options provided" do
      proxy = Proxy.new()

      assert proxy.http == nil
      assert proxy.https == nil
      assert proxy.grpc == nil
    end

    test "allows partial proxy configuration" do
      proxy = Proxy.new(http: "http://proxy.example.com:8080")

      assert proxy.http == "http://proxy.example.com:8080"
      assert proxy.https == nil
      assert proxy.grpc == nil
    end
  end

  describe "from_env/0" do
    setup do
      # Save original env vars
      original_http = System.get_env("HTTP_PROXY")
      original_https = System.get_env("HTTPS_PROXY")
      original_grpc = System.get_env("GRPC_PROXY")
      original_http_lower = System.get_env("http_proxy")
      original_https_lower = System.get_env("https_proxy")
      original_grpc_lower = System.get_env("grpc_proxy")

      on_exit(fn ->
        # Restore original env vars
        restore_env("HTTP_PROXY", original_http)
        restore_env("HTTPS_PROXY", original_https)
        restore_env("GRPC_PROXY", original_grpc)
        restore_env("http_proxy", original_http_lower)
        restore_env("https_proxy", original_https_lower)
        restore_env("grpc_proxy", original_grpc_lower)
      end)

      # Clear env vars for test
      System.delete_env("HTTP_PROXY")
      System.delete_env("HTTPS_PROXY")
      System.delete_env("GRPC_PROXY")
      System.delete_env("http_proxy")
      System.delete_env("https_proxy")
      System.delete_env("grpc_proxy")

      :ok
    end

    test "reads uppercase HTTP_PROXY environment variable" do
      System.put_env("HTTP_PROXY", "http://proxy.example.com:8080")

      proxy = Proxy.from_env()

      assert proxy.http == "http://proxy.example.com:8080"
    end

    test "reads lowercase http_proxy environment variable" do
      System.put_env("http_proxy", "http://proxy.example.com:8080")

      proxy = Proxy.from_env()

      assert proxy.http == "http://proxy.example.com:8080"
    end

    test "uppercase takes precedence over lowercase for HTTP" do
      System.put_env("HTTP_PROXY", "http://upper.example.com:8080")
      System.put_env("http_proxy", "http://lower.example.com:8080")

      proxy = Proxy.from_env()

      assert proxy.http == "http://upper.example.com:8080"
    end

    test "reads HTTPS_PROXY environment variable (case-insensitive)" do
      System.put_env("HTTPS_PROXY", "https://proxy.example.com:8443")

      proxy = Proxy.from_env()

      assert proxy.https == "https://proxy.example.com:8443"
    end

    test "reads https_proxy lowercase environment variable" do
      System.put_env("https_proxy", "https://proxy.example.com:8443")

      proxy = Proxy.from_env()

      assert proxy.https == "https://proxy.example.com:8443"
    end

    test "reads GRPC_PROXY environment variable (case-insensitive)" do
      System.put_env("GRPC_PROXY", "grpc://proxy.example.com:50051")

      proxy = Proxy.from_env()

      assert proxy.grpc == "grpc://proxy.example.com:50051"
    end

    test "reads grpc_proxy lowercase environment variable" do
      System.put_env("grpc_proxy", "grpc://proxy.example.com:50051")

      proxy = Proxy.from_env()

      assert proxy.grpc == "grpc://proxy.example.com:50051"
    end

    test "returns nil for unset environment variables" do
      proxy = Proxy.from_env()

      assert proxy.http == nil
      assert proxy.https == nil
      assert proxy.grpc == nil
    end

    test "reads all proxy types from environment" do
      System.put_env("HTTP_PROXY", "http://http-proxy.example.com:8080")
      System.put_env("HTTPS_PROXY", "https://https-proxy.example.com:8443")
      System.put_env("GRPC_PROXY", "grpc://grpc-proxy.example.com:50051")

      proxy = Proxy.from_env()

      assert proxy.http == "http://http-proxy.example.com:8080"
      assert proxy.https == "https://https-proxy.example.com:8443"
      assert proxy.grpc == "grpc://grpc-proxy.example.com:50051"
    end
  end

  describe "configured?/1" do
    test "returns false when no proxies are configured" do
      proxy = Proxy.new()

      assert Proxy.configured?(proxy) == false
    end

    test "returns true when http proxy is configured" do
      proxy = Proxy.new(http: "http://proxy.example.com:8080")

      assert Proxy.configured?(proxy) == true
    end

    test "returns true when https proxy is configured" do
      proxy = Proxy.new(https: "https://proxy.example.com:8443")

      assert Proxy.configured?(proxy) == true
    end

    test "returns true when grpc proxy is configured" do
      proxy = Proxy.new(grpc: "grpc://proxy.example.com:50051")

      assert Proxy.configured?(proxy) == true
    end
  end

  describe "http_proxy_for/2" do
    test "returns http proxy for http:// URLs" do
      proxy =
        Proxy.new(
          http: "http://http-proxy.example.com:8080",
          https: "https://https-proxy.example.com:8443"
        )

      assert Proxy.http_proxy_for(proxy, "http://example.com/api") ==
               "http://http-proxy.example.com:8080"
    end

    test "returns https proxy for https:// URLs" do
      proxy =
        Proxy.new(
          http: "http://http-proxy.example.com:8080",
          https: "https://https-proxy.example.com:8443"
        )

      assert Proxy.http_proxy_for(proxy, "https://example.com/api") ==
               "https://https-proxy.example.com:8443"
    end

    test "returns nil when no matching proxy configured" do
      proxy = Proxy.new()

      assert Proxy.http_proxy_for(proxy, "http://example.com/api") == nil
    end

    test "falls back to http proxy for https when https not configured" do
      proxy = Proxy.new(http: "http://http-proxy.example.com:8080")

      # When HTTPS proxy is not set but HTTP is, use HTTP for HTTPS traffic
      assert Proxy.http_proxy_for(proxy, "https://example.com/api") ==
               "http://http-proxy.example.com:8080"
    end
  end

  describe "to_finch_opts/1" do
    test "returns empty list when no proxy configured" do
      proxy = Proxy.new()

      assert Proxy.to_finch_opts(proxy) == []
    end

    test "returns proxy option for HTTP" do
      proxy = Proxy.new(http: "http://proxy.example.com:8080")

      opts = Proxy.to_finch_opts(proxy)
      assert opts[:proxy] == {:http, "proxy.example.com", 8080, []}
    end

    test "returns proxy option for HTTPS" do
      proxy = Proxy.new(https: "https://proxy.example.com:8443")

      opts = Proxy.to_finch_opts(proxy)
      assert opts[:proxy] == {:https, "proxy.example.com", 8443, []}
    end

    test "prefers HTTPS proxy over HTTP" do
      proxy =
        Proxy.new(
          http: "http://http-proxy.example.com:8080",
          https: "https://https-proxy.example.com:8443"
        )

      opts = Proxy.to_finch_opts(proxy)
      assert opts[:proxy] == {:https, "https-proxy.example.com", 8443, []}
    end
  end

  describe "to_grpc_opts/1" do
    test "returns empty list when no grpc proxy configured" do
      proxy = Proxy.new()

      assert Proxy.to_grpc_opts(proxy) == []
    end

    test "returns http_proxy option for gRPC" do
      proxy = Proxy.new(grpc: "http://grpc-proxy.example.com:8080")

      opts = Proxy.to_grpc_opts(proxy)
      assert opts[:http_proxy] == "http://grpc-proxy.example.com:8080"
    end
  end

  # Helper to restore environment variables
  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
