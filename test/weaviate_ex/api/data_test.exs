defmodule WeaviateEx.API.DataTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Data
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "insert/3" do
    test "creates an object with auto-generated UUID", %{client: client} do
      properties = %{"title" => "Test Article", "content" => "Content"}

      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects", body, _opts ->
        assert body["class"] == "Article"
        assert body["properties"] == properties
        assert Map.has_key?(body, "id")

        {:ok,
         %{
           "id" => body["id"],
           "class" => "Article",
           "properties" => properties
         }}
      end)

      assert {:ok, object} = Data.insert(client, "Article", %{properties: properties})
      assert object["class"] == "Article"
      assert object["properties"] == properties
    end

    test "creates an object with custom UUID", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      properties = %{"title" => "Test"}

      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects", body, _opts ->
        assert body["id"] == uuid
        {:ok, %{"id" => uuid, "class" => "Article", "properties" => properties}}
      end)

      assert {:ok, object} = Data.insert(client, "Article", %{id: uuid, properties: properties})
      assert object["id"] == uuid
    end

    test "creates an object with vector", %{client: client} do
      vector = [0.1, 0.2, 0.3]

      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects", body, _opts ->
        assert body["vector"] == vector
        {:ok, %{"id" => "uuid", "class" => "Article", "vector" => vector}}
      end)

      assert {:ok, _} = Data.insert(client, "Article", %{properties: %{}, vector: vector})
    end

    test "handles validation errors", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects", _body, _opts ->
        {:error, %WeaviateEx.Error{type: :validation_error, message: "Invalid properties"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               Data.insert(client, "Article", %{properties: %{}})
    end
  end

  describe "get_by_id/3" do
    test "retrieves an object by UUID", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert path == "/v1/objects/Article/#{uuid}"
        {:ok, %{"id" => uuid, "class" => "Article", "properties" => %{"title" => "Test"}}}
      end)

      assert {:ok, object} = Data.get_by_id(client, "Article", uuid)
      assert object["id"] == uuid
    end

    test "handles not found errors", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      Mox.expect(Mock, :request, fn _client, :get, _path, nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Data.get_by_id(client, "Article", uuid)
    end
  end

  describe "update/4" do
    test "updates an object (full replacement)", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      new_properties = %{"title" => "Updated"}

      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/Article/#{uuid}"
        assert body["id"] == uuid
        assert body["class"] == "Article"
        assert body["properties"] == new_properties

        {:ok, %{"id" => uuid, "class" => "Article", "properties" => new_properties}}
      end)

      assert {:ok, updated} = Data.update(client, "Article", uuid, %{properties: new_properties})
      assert updated["properties"] == new_properties
    end
  end

  describe "patch/4" do
    test "patches an object (partial update)", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      partial_properties = %{"title" => "Patched"}

      # PATCH returns 204 No Content
      Mox.expect(Mock, :request, fn _client, :patch, path, body, _opts ->
        assert path == "/v1/objects/Article/#{uuid}"
        assert body["properties"] == partial_properties
        {:ok, %{}}
      end)

      # Then GET to retrieve the updated object
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert path == "/v1/objects/Article/#{uuid}"

        {:ok,
         %{
           "id" => uuid,
           "class" => "Article",
           "properties" => %{"title" => "Patched", "content" => "Original"}
         }}
      end)

      assert {:ok, patched} =
               Data.patch(client, "Article", uuid, %{properties: partial_properties})

      assert patched["properties"]["title"] == "Patched"
      assert patched["properties"]["content"] == "Original"
    end
  end

  describe "delete_by_id/3" do
    test "deletes an object", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      Mox.expect(Mock, :request, fn _client, :delete, path, nil, _opts ->
        assert path == "/v1/objects/Article/#{uuid}"
        {:ok, %{}}
      end)

      assert {:ok, _} = Data.delete_by_id(client, "Article", uuid)
    end

    test "handles not found errors", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      Mox.expect(Mock, :request, fn _client, :delete, _path, nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Data.delete_by_id(client, "Article", uuid)
    end
  end

  describe "exists?/3" do
    test "returns true when object exists", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      Mox.expect(Mock, :request, fn _client, :head, path, nil, _opts ->
        assert path == "/v1/objects/Article/#{uuid}"
        {:ok, %{}}
      end)

      assert {:ok, true} = Data.exists?(client, "Article", uuid)
    end

    test "returns false when object doesn't exist", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      Mox.expect(Mock, :request, fn _client, :head, _path, nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:ok, false} = Data.exists?(client, "Article", uuid)
    end
  end

  describe "validate/3" do
    test "validates object data without creating it", %{client: client} do
      properties = %{"title" => "Test"}

      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects/validate", body, _opts ->
        assert body["class"] == "Article"
        assert body["properties"] == properties
        {:ok, %{"valid" => true}}
      end)

      assert {:ok, result} = Data.validate(client, "Article", %{properties: properties})
      assert result["valid"] == true
    end

    test "returns validation errors", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/objects/validate", _body, _opts ->
        {:error, %WeaviateEx.Error{type: :validation_error, message: "Missing required property"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               Data.validate(client, "Article", %{properties: %{}})
    end
  end

  describe "with tenant support" do
    test "creates object with tenant parameter", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "tenant=TenantA"
        assert body["class"] == "Article"
        {:ok, %{"id" => "uuid", "class" => "Article"}}
      end)

      assert {:ok, _} = Data.insert(client, "Article", %{properties: %{}}, tenant: "TenantA")
    end

    test "gets object with tenant parameter", %{client: client} do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert path =~ "tenant=TenantA"
        {:ok, %{"id" => uuid}}
      end)

      assert {:ok, _} = Data.get_by_id(client, "Article", uuid, tenant: "TenantA")
    end
  end

  describe "with consistency level" do
    test "creates object with consistency level", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "consistency_level=QUORUM"
        {:ok, %{"id" => "uuid"}}
      end)

      assert {:ok, _} =
               Data.insert(client, "Article", %{properties: %{}}, consistency_level: "QUORUM")
    end
  end
end
