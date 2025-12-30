defmodule WeaviateEx.Client.InitChecksTest do
  use ExUnit.Case, async: true

  import Mox

  alias WeaviateEx.Client
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!

  test "skips init checks when skip_init_checks is true" do
    {:ok, client} =
      Client.connect(
        base_url: "http://localhost:8080",
        protocol_impl: Mock,
        skip_grpc: true,
        skip_init_checks: true
      )

    assert %Client{} = client
  end

  test "returns error when server version is below minimum" do
    Mox.expect(Mock, :request, fn _client, :get, "/v1/meta", nil, _opts ->
      {:ok, %{"version" => "1.0.0"}}
    end)

    assert {:error, %WeaviateEx.Error{type: :version_error}} =
             Client.connect(
               base_url: "http://localhost:8080",
               protocol_impl: Mock,
               skip_grpc: true
             )
  end

  test "passes init checks with supported server version" do
    Mox.expect(Mock, :request, fn _client, :get, "/v1/meta", nil, _opts ->
      {:ok, %{"version" => "1.28.0"}}
    end)

    assert {:ok, %Client{}} =
             Client.connect(
               base_url: "http://localhost:8080",
               protocol_impl: Mock,
               skip_grpc: true
             )
  end
end
