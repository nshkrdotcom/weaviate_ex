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

    test "merges raw config overrides before creating", %{client: client} do
      base_config = %{
        "class" => "Article",
        "properties" => [%{"name" => "title", "dataType" => ["text"]}],
        "multiTenancyConfig" => %{"enabled" => false}
      }

      overrides = %{
        "multiTenancyConfig" => %{"enabled" => true},
        "vectorIndexConfig" => %{"ef" => 64}
      }

      expected_payload = %{
        "class" => "Article",
        "properties" => [%{"name" => "title", "dataType" => ["text"]}],
        "multiTenancyConfig" => %{"enabled" => true},
        "vectorIndexConfig" => %{"ef" => 64}
      }

      Mox.expect(Mock, :request, fn _client, :post, "/v1/schema", body, _opts ->
        assert body == expected_payload
        {:ok, body}
      end)

      assert {:ok, _} =
               Collections.create(client, base_config, config_overrides: overrides)
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

    test "merges raw config overrides on update", %{client: client} do
      updates = %{"description" => "Updated description"}

      overrides = %{
        "vectorIndexConfig" => %{"ef" => 120},
        "multiTenancyConfig" => %{"enabled" => true}
      }

      expected_body = %{
        "description" => "Updated description",
        "vectorIndexConfig" => %{"ef" => 120},
        "multiTenancyConfig" => %{"enabled" => true}
      }

      Mox.expect(Mock, :request, fn _client, :put, "/v1/schema/Article", body, _opts ->
        assert body == expected_body
        {:ok, Map.put(body, "class", "Article")}
      end)

      assert {:ok, result} =
               Collections.update(client, "Article", updates, config_overrides: overrides)

      assert result["multiTenancyConfig"]["enabled"]
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

  describe "set_multi_tenancy/3" do
    test "enables multi-tenancy", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/schema/Article/multi-tenancy/enable",
                                    %{"enabled" => true},
                                    _opts ->
        {:ok, %{"enabled" => true}}
      end)

      assert {:ok, %{"enabled" => true}} =
               Collections.set_multi_tenancy(client, "Article", true)
    end

    test "propagates conflict errors when toggling multi-tenancy", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/schema/Article/multi-tenancy/disable",
                                    %{"enabled" => false},
                                    _opts ->
        {:error, %WeaviateEx.Error{type: :conflict, message: "not allowed"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :conflict}} =
               Collections.set_multi_tenancy(client, "Article", false)
    end
  end

  describe "get_shards/3" do
    test "fetches shards scoped to tenant", %{client: client} do
      shards = [
        %{"name" => "tenant-a__shard", "status" => "READY", "tenant" => "tenant-a"}
      ]

      Mox.expect(Mock, :request, fn _client,
                                    :get,
                                    "/v1/schema/Article/shards?tenant=tenant-a",
                                    nil,
                                    _opts ->
        {:ok, shards}
      end)

      assert {:ok, result} = Collections.get_shards(client, "Article", tenant: "tenant-a")
      assert hd(result)["tenant"] == "tenant-a"
    end
  end

  describe "delete_all/1" do
    test "deletes all collections successfully", %{client: client} do
      # First call to list collections
      Mox.expect(Mock, :request, fn _client, :get, "/v1/schema", nil, _opts ->
        {:ok,
         %{
           "classes" => [
             %{"class" => "Article"},
             %{"class" => "Author"}
           ]
         }}
      end)

      # Expect delete calls for each collection
      Mox.expect(Mock, :request, 2, fn _client, :delete, path, nil, _opts ->
        assert path in ["/v1/schema/Article", "/v1/schema/Author"]
        {:ok, %{}}
      end)

      assert {:ok, deleted_count: 2} = Collections.delete_all(client)
    end

    test "handles empty schema", %{client: client} do
      expect_http_success(Mock, :get, "/v1/schema", %{"classes" => []})

      assert {:ok, deleted_count: 0} = Collections.delete_all(client)
    end

    test "reports partial failures", %{client: client} do
      # List collections
      Mox.expect(Mock, :request, fn _client, :get, "/v1/schema", nil, _opts ->
        {:ok,
         %{
           "classes" => [
             %{"class" => "Article"},
             %{"class" => "Author"}
           ]
         }}
      end)

      # First delete succeeds, second fails
      Mox.expect(Mock, :request, fn _client, :delete, "/v1/schema/Article", nil, _opts ->
        {:ok, %{}}
      end)

      Mox.expect(Mock, :request, fn _client, :delete, "/v1/schema/Author", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :server_error, message: "Failed to delete"}}
      end)

      assert {:ok, result} = Collections.delete_all(client)
      assert result[:deleted_count] == 1
      assert result[:failed_count] == 1
      assert length(result[:failures]) == 1
      assert hd(result[:failures])[:collection] == "Author"
    end
  end
end
