defmodule WeaviateEx.Query.GRPCFallbackTest do
  use ExUnit.Case, async: true

  import Mox

  alias WeaviateEx.Protocol.Mock
  alias WeaviateEx.Query
  alias WeaviateEx.Query.Sort

  setup :verify_on_exit!

  defp grpc_client do
    %WeaviateEx.Client{
      config: %WeaviateEx.Client.Config{},
      grpc_channel: :fake_channel,
      protocol_impl: Mock,
      state: nil
    }
  end

  describe "gRPC fallback" do
    test "falls back to GraphQL when sort is set" do
      client = grpc_client()

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.sort(Sort.by_property("title", :asc))

      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        assert body["query"] =~ "sort:"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      assert {:ok, []} = Query.execute(query, client)
    end
  end
end
