defmodule WeaviateEx.API.AliasesTest do
  use ExUnit.Case, async: true

  import Mox

  alias WeaviateEx.API.Aliases
  alias WeaviateEx.Client

  # Allow async test processes to use mocks
  setup :verify_on_exit!

  defp build_test_client do
    {:ok, client} =
      Client.new(
        base_url: "http://localhost:8080",
        protocol_impl: WeaviateEx.Protocol.Mock
      )

    client
  end

  describe "create/3" do
    test "creates an alias for a collection" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client, :post, "/v1/aliases", body, _opts ->
        assert body["class"] == "Article"
        assert body["alias"] == "articles"
        {:ok, %{}}
      end)

      assert {:ok, _} = Aliases.create(client, "articles", "Article")
    end

    test "returns error when alias already exists" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client, :post, "/v1/aliases", _body, _opts ->
        {:error, %WeaviateEx.Error{type: :alias_exists, message: "Alias already exists"}}
      end)

      assert {:error, _} = Aliases.create(client, "articles", "Article")
    end
  end

  describe "delete/2" do
    test "deletes an alias" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client,
                                                    :delete,
                                                    "/v1/aliases/articles",
                                                    _body,
                                                    _opts ->
        {:ok, nil}
      end)

      assert {:ok, true} = Aliases.delete(client, "articles")
    end

    test "returns false when alias does not exist" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client,
                                                    :delete,
                                                    "/v1/aliases/nonexistent",
                                                    _body,
                                                    _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Alias not found"}}
      end)

      assert {:ok, false} = Aliases.delete(client, "nonexistent")
    end
  end

  describe "update/3" do
    test "updates an alias to point to a new collection" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client,
                                                    :put,
                                                    "/v1/aliases/articles",
                                                    body,
                                                    _opts ->
        assert body["class"] == "NewArticle"
        {:ok, %{}}
      end)

      assert {:ok, true} = Aliases.update(client, "articles", "NewArticle")
    end

    test "returns false when alias does not exist" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client,
                                                    :put,
                                                    "/v1/aliases/nonexistent",
                                                    _body,
                                                    _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Alias not found"}}
      end)

      assert {:ok, false} = Aliases.update(client, "nonexistent", "NewCollection")
    end
  end

  describe "get/2" do
    test "gets an alias by name" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client,
                                                    :get,
                                                    "/v1/aliases/articles",
                                                    _body,
                                                    _opts ->
        {:ok, %{"alias" => "articles", "class" => "Article"}}
      end)

      assert {:ok, alias_info} = Aliases.get(client, "articles")
      assert alias_info.alias == "articles"
      assert alias_info.collection == "Article"
    end

    test "returns nil when alias does not exist" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client,
                                                    :get,
                                                    "/v1/aliases/nonexistent",
                                                    _body,
                                                    _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:ok, nil} = Aliases.get(client, "nonexistent")
    end
  end

  describe "list/2" do
    test "lists all aliases" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client, :get, "/v1/aliases", _body, _opts ->
        {:ok,
         %{
           "aliases" => [
             %{"alias" => "articles", "class" => "Article"},
             %{"alias" => "posts", "class" => "Post"}
           ]
         }}
      end)

      assert {:ok, aliases} = Aliases.list(client)
      assert length(aliases) == 2
      assert Enum.any?(aliases, &(&1.alias == "articles"))
      assert Enum.any?(aliases, &(&1.alias == "posts"))
    end

    test "lists aliases for a specific collection" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path =~ "class=Article"

        {:ok,
         %{
           "aliases" => [
             %{"alias" => "articles", "class" => "Article"}
           ]
         }}
      end)

      assert {:ok, aliases} = Aliases.list(client, collection: "Article")
      assert length(aliases) == 1
    end

    test "returns empty list when no aliases exist" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client, :get, "/v1/aliases", _body, _opts ->
        {:ok, %{"aliases" => nil}}
      end)

      assert {:ok, aliases} = Aliases.list(client)
      assert aliases == []
    end
  end

  describe "exists?/2" do
    test "returns true when alias exists" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client,
                                                    :get,
                                                    "/v1/aliases/articles",
                                                    _body,
                                                    _opts ->
        {:ok, %{"alias" => "articles", "class" => "Article"}}
      end)

      assert {:ok, true} = Aliases.exists?(client, "articles")
    end

    test "returns false when alias does not exist" do
      client = build_test_client()

      expect(WeaviateEx.Protocol.Mock, :request, fn _client,
                                                    :get,
                                                    "/v1/aliases/nonexistent",
                                                    _body,
                                                    _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:ok, false} = Aliases.exists?(client, "nonexistent")
    end
  end

  describe "Alias struct" do
    test "creates alias struct from map" do
      alias_struct = Aliases.Alias.from_api(%{"alias" => "articles", "class" => "Article"})

      assert alias_struct.alias == "articles"
      assert alias_struct.collection == "Article"
    end
  end

  describe "version requirement" do
    test "returns the minimum version requirement" do
      assert Aliases.minimum_version() == "1.32.0"
    end
  end
end
