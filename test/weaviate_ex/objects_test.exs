defmodule WeaviateEx.ObjectsTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks
  alias WeaviateEx.API.Data
  alias WeaviateEx.Fixtures
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "insert/3 (create)" do
    test "creates an object with properties", %{client: client} do
      object = Fixtures.object_fixture()

      data = %{
        "properties" => %{
          "title" => "Test Article",
          "content" => "This is test content"
        }
      }

      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects", body, _opts ->
        assert body["class"] == "Article"
        assert body["properties"] == data["properties"]
        {:ok, object}
      end)

      assert {:ok, result} = Data.insert(client, "Article", data)
      assert result["class"] == "Article"
      assert result["id"]
    end

    test "creates object with custom ID and vector", %{client: client} do
      object = Fixtures.object_fixture()

      data = %{
        "id" => "00000000-0000-0000-0000-000000000001",
        "properties" => %{"title" => "Test"},
        "vector" => [0.1, 0.2, 0.3]
      }

      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects", body, _opts ->
        assert body["id"] == "00000000-0000-0000-0000-000000000001"
        assert body["vector"] == [0.1, 0.2, 0.3]
        {:ok, object}
      end)

      assert {:ok, result} = Data.insert(client, "Article", data)
      assert result["id"] == "00000000-0000-0000-0000-000000000001"
    end

    test "returns error on invalid data", %{client: client} do
      data = %{}

      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects", _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :validation_error,
           message: "Invalid property",
           details: %{},
           status_code: 422
         }}
      end)

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               Data.insert(client, "Article", data)
    end
  end

  describe "get_by_id/3 (get)" do
    test "retrieves an object by class and ID", %{client: client} do
      object = Fixtures.object_fixture()

      expect_http_success(
        Mock,
        :get,
        "/v1/objects/Article/00000000-0000-0000-0000-000000000001",
        object
      )

      assert {:ok, result} =
               Data.get_by_id(client, "Article", "00000000-0000-0000-0000-000000000001")

      assert result["id"] == "00000000-0000-0000-0000-000000000001"
    end

    test "returns error when object not found", %{client: client} do
      expect_http_error(
        Mock,
        :get,
        "/v1/objects/Article/00000000-0000-0000-0000-999999999999",
        :not_found
      )

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Data.get_by_id(client, "Article", "00000000-0000-0000-0000-999999999999")
    end
  end

  describe "list (not in Data module, skipping)" do
    # Note: The new Data module doesn't have a list function.
    # List operations are typically handled via GraphQL queries.
    # These tests would need to be migrated to use query_advanced module.
  end

  describe "update/4" do
    test "updates an object (PUT - full replacement)", %{client: client} do
      updated_object = %{
        "id" => "00000000-0000-0000-0000-000000000001",
        "class" => "Article",
        "properties" => %{"title" => "Updated Title", "content" => "Updated content"}
      }

      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/Article/00000000-0000-0000-0000-000000000001"
        assert body["properties"] == %{"title" => "Updated Title", "content" => "Updated content"}
        {:ok, updated_object}
      end)

      assert {:ok, result} =
               Data.update(client, "Article", "00000000-0000-0000-0000-000000000001", %{
                 "properties" => %{"title" => "Updated Title", "content" => "Updated content"}
               })

      assert result["properties"]["title"] == "Updated Title"
    end
  end

  describe "patch/4" do
    test "patches an object (PATCH - partial update)", %{client: client} do
      patched_object = %{
        "id" => "00000000-0000-0000-0000-000000000001",
        "class" => "Article",
        "properties" => %{"title" => "Patched Title", "content" => "Original"}
      }

      # PATCH request returns 204 No Content
      Mox.expect(Mock, :request, fn _client, :patch, path, _body, _opts ->
        assert path == "/v1/objects/Article/00000000-0000-0000-0000-000000000001"
        {:ok, %{}}
      end)

      # Then GET to retrieve updated object
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert path == "/v1/objects/Article/00000000-0000-0000-0000-000000000001"
        {:ok, patched_object}
      end)

      assert {:ok, result} =
               Data.patch(client, "Article", "00000000-0000-0000-0000-000000000001", %{
                 "properties" => %{"title" => "Patched Title"}
               })

      assert result["properties"]["title"] == "Patched Title"
    end
  end

  describe "delete_by_id/3 (delete)" do
    test "deletes an object", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :delete,
                                    "/v1/objects/Article/00000000-0000-0000-0000-000000000001",
                                    nil,
                                    _opts ->
        {:ok, %{}}
      end)

      assert {:ok, _} =
               Data.delete_by_id(client, "Article", "00000000-0000-0000-0000-000000000001")
    end

    test "returns error when object not found", %{client: client} do
      expect_http_error(
        Mock,
        :delete,
        "/v1/objects/Article/00000000-0000-0000-0000-999999999999",
        :not_found
      )

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Data.delete_by_id(client, "Article", "00000000-0000-0000-0000-999999999999")
    end
  end

  describe "exists?/3" do
    test "returns true when object exists (HEAD request)", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :head,
                                    "/v1/objects/Article/00000000-0000-0000-0000-000000000001",
                                    nil,
                                    _opts ->
        {:ok, %{}}
      end)

      assert {:ok, true} =
               Data.exists?(client, "Article", "00000000-0000-0000-0000-000000000001")
    end

    test "returns false when object doesn't exist", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :head,
                                    "/v1/objects/Article/00000000-0000-0000-0000-999999999999",
                                    nil,
                                    _opts ->
        {:error,
         %WeaviateEx.Error{type: :not_found, message: "Not found", details: %{}, status_code: 404}}
      end)

      assert {:ok, false} =
               Data.exists?(client, "Article", "00000000-0000-0000-0000-999999999999")
    end
  end

  describe "validate/3" do
    test "validates an object without creating it", %{client: client} do
      data = %{
        "properties" => %{"title" => "Test"}
      }

      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects/validate", _body, _opts ->
        {:ok, %{"valid" => true}}
      end)

      assert {:ok, result} = Data.validate(client, "Article", data)
      assert result["valid"] == true
    end
  end

  describe "integration tests" do
    @tag :integration
    test "full CRUD workflow with real Weaviate" do
      if WeaviateEx.TestHelpers.integration_mode?() do
        {:ok, client} =
          WeaviateEx.Client.new(
            base_url: WeaviateEx.base_url(),
            api_key: WeaviateEx.api_key()
          )

        # Create object
        {:ok, created} =
          Data.insert(client, "TestArticle", %{
            "properties" => %{"title" => "Integration Test"}
          })

        id = created["id"]

        # Get object
        {:ok, fetched} = Data.get_by_id(client, "TestArticle", id)
        assert fetched["properties"]["title"] == "Integration Test"

        # Update object
        {:ok, updated} =
          Data.update(client, "TestArticle", id, %{
            "properties" => %{"title" => "Updated"}
          })

        assert updated["properties"]["title"] == "Updated"

        # Delete object
        {:ok, _} = Data.delete_by_id(client, "TestArticle", id)
      else
        assert true
      end
    end
  end
end
