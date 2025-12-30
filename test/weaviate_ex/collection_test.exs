defmodule WeaviateEx.CollectionTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.Collection
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "new/3" do
    test "stores tenant and consistency defaults", %{client: client} do
      collection =
        Collection.new(client, "Article", tenant: "tenant-a", consistency_level: "QUORUM")

      assert collection.client == client
      assert collection.name == "Article"
      assert collection.tenant == "tenant-a"
      assert collection.consistency_level == "QUORUM"
    end
  end

  describe "with_tenant/2 and with_consistency/2" do
    test "updates defaults", %{client: client} do
      collection = Collection.new(client, "Article")

      updated =
        collection
        |> Collection.with_tenant("tenant-b")
        |> Collection.with_consistency("ALL")

      assert updated.tenant == "tenant-b"
      assert updated.consistency_level == "ALL"
    end
  end

  describe "insert/3" do
    test "applies default tenant and consistency", %{client: client} do
      collection =
        Collection.new(client, "Article", tenant: "tenant-a", consistency_level: "QUORUM")

      data = %{properties: %{"title" => "Hello"}}

      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert String.starts_with?(path, "/v1/objects?")
        assert path =~ "tenant=tenant-a"
        assert path =~ "consistency_level=QUORUM"
        assert body["class"] == "Article"
        {:ok, %{"id" => "uuid-1"}}
      end)

      assert {:ok, _} = Collection.insert(collection, data)
    end

    test "allows opts to override defaults", %{client: client} do
      collection =
        Collection.new(client, "Article", tenant: "tenant-a", consistency_level: "QUORUM")

      data = %{properties: %{"title" => "Hello"}}

      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert String.starts_with?(path, "/v1/objects?")
        assert path =~ "tenant=tenant-b"
        assert path =~ "consistency_level=ALL"
        {:ok, %{"id" => "uuid-2"}}
      end)

      assert {:ok, _} =
               Collection.insert(collection, data,
                 tenant: "tenant-b",
                 consistency_level: "ALL"
               )
    end
  end
end
