defmodule WeaviateEx.API.CollectionsTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Collections
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "list/1" do
    test "returns list of collection names", %{client: client} do
      # Arrange
      expect_http_success(Mock, :get, "/v1/schema", %{
        "classes" => [
          %{"class" => "Article"},
          %{"class" => "Author"}
        ]
      })

      # Act
      assert {:ok, collections} = Collections.list(client)

      # Assert
      assert length(collections) == 2
      assert "Article" in collections
      assert "Author" in collections
    end

    test "handles empty schema", %{client: client} do
      expect_http_success(Mock, :get, "/v1/schema", %{"classes" => []})

      assert {:ok, []} = Collections.list(client)
    end

    test "handles connection error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema", :connection_error)

      assert {:error, %WeaviateEx.Error{type: :connection_error}} =
               Collections.list(client)
    end

    test "handles authentication error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema", :authentication_failed)

      assert {:error, %WeaviateEx.Error{type: :authentication_failed}} =
               Collections.list(client)
    end
  end

  describe "get/2" do
    test "returns collection configuration", %{client: client} do
      expect_http_success(Mock, :get, "/v1/schema/Article", %{
        "class" => "Article",
        "vectorizer" => "text2vec-openai",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]}
        ]
      })

      assert {:ok, config} = Collections.get(client, "Article")
      assert config["class"] == "Article"
      assert config["vectorizer"] == "text2vec-openai"
    end

    test "handles not found error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema/NonExistent", :not_found)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Collections.get(client, "NonExistent")
    end
  end

  describe "create/2" do
    test "creates a new collection", %{client: client} do
      config = %{
        "class" => "Article",
        "vectorizer" => "text2vec-openai",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]}
        ]
      }

      Mox.expect(Mock, :request, fn _client, :post, "/v1/schema", ^config, _opts ->
        {:ok, config}
      end)

      assert {:ok, created} = Collections.create(client, config)
      assert created["class"] == "Article"
    end

    test "handles validation error", %{client: client} do
      config = %{"class" => "Invalid"}

      Mox.expect(Mock, :request, fn _client, :post, "/v1/schema", ^config, _opts ->
        {:error, %WeaviateEx.Error{type: :validation_error, message: "Invalid config"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               Collections.create(client, config)
    end
  end

  describe "delete/2" do
    test "deletes a collection", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, "/v1/schema/Article", nil, _opts ->
        {:ok, %{}}
      end)

      assert {:ok, _} = Collections.delete(client, "Article")
    end

    test "handles not found error", %{client: client} do
      expect_http_error(Mock, :delete, "/v1/schema/NonExistent", :not_found)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Collections.delete(client, "NonExistent")
    end
  end

  describe "update/3" do
    test "updates a collection", %{client: client} do
      updates = %{"vectorIndexConfig" => %{"ef" => 200}}

      Mox.expect(Mock, :request, fn _client, :put, "/v1/schema/Article", ^updates, _opts ->
        {:ok, %{"class" => "Article", "vectorIndexConfig" => %{"ef" => 200}}}
      end)

      assert {:ok, updated} = Collections.update(client, "Article", updates)
      assert updated["vectorIndexConfig"]["ef"] == 200
    end
  end

  describe "add_property/3" do
    test "adds a property to a collection", %{client: client} do
      property = %{"name" => "author", "dataType" => ["text"]}

      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/schema/Article/properties",
                                    ^property,
                                    _opts ->
        {:ok, property}
      end)

      assert {:ok, added} = Collections.add_property(client, "Article", property)
      assert added["name"] == "author"
    end
  end

  describe "exists?/2" do
    test "returns true when collection exists", %{client: client} do
      expect_http_success(Mock, :get, "/v1/schema/Article", %{"class" => "Article"})

      assert {:ok, true} = Collections.exists?(client, "Article")
    end

    test "returns false when collection does not exist", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema/NonExistent", :not_found)

      assert {:ok, false} = Collections.exists?(client, "NonExistent")
    end
  end
end
