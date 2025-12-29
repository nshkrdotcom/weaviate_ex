defmodule WeaviateEx.Objects.DataOpsTest do
  @moduledoc """
  Tests for data operation functions: update/3, replace/3, and exists?/2.

  These tests follow TDD methodology - they were written before the implementation.
  """
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks
  alias WeaviateEx.API.Data
  alias WeaviateEx.Fixtures
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  @test_uuid "00000000-0000-0000-0000-000000000001"
  @test_collection "Article"

  describe "patch/4 (PATCH - partial update)" do
    test "performs partial update with only provided properties", %{client: client} do
      patched_object = %{
        "id" => @test_uuid,
        "class" => @test_collection,
        "properties" => %{
          "title" => "Updated Title",
          "content" => "Original Content"
        }
      }

      # PATCH request returns 204 No Content
      Mox.expect(Mock, :request, fn _client, :patch, path, body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        assert body["properties"] == %{"title" => "Updated Title"}
        # PATCH doesn't include id or class in response, just empty map
        {:ok, %{}}
      end)

      # Then GET to retrieve updated object
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        {:ok, patched_object}
      end)

      assert {:ok, result} =
               Data.patch(client, @test_collection, @test_uuid, %{
                 "properties" => %{"title" => "Updated Title"}
               })

      assert result["properties"]["title"] == "Updated Title"
    end

    test "patch only updates specified fields, not others", %{client: client} do
      # Object has title, content, and score. We only patch title.
      patched_object = %{
        "id" => @test_uuid,
        "class" => @test_collection,
        "properties" => %{
          "title" => "New Title",
          "content" => "Original Content",
          "score" => 42
        }
      }

      Mox.expect(Mock, :request, fn _client, :patch, path, body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        # Only title should be in the patch body
        assert body["properties"] == %{"title" => "New Title"}
        refute Map.has_key?(body["properties"], "content")
        refute Map.has_key?(body["properties"], "score")
        {:ok, %{}}
      end)

      Mox.expect(Mock, :request, fn _client, :get, _path, nil, _opts ->
        {:ok, patched_object}
      end)

      assert {:ok, result} =
               Data.patch(client, @test_collection, @test_uuid, %{
                 "properties" => %{"title" => "New Title"}
               })

      # All properties should be present in returned object
      assert result["properties"]["title"] == "New Title"
      assert result["properties"]["content"] == "Original Content"
      assert result["properties"]["score"] == 42
    end

    test "patch returns error when object doesn't exist", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :patch, _path, _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :not_found,
           message: "Object not found",
           details: %{},
           status_code: 404
         }}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Data.patch(client, @test_collection, "nonexistent-id", %{
                 "properties" => %{"title" => "Test"}
               })
    end

    test "patch with tenant option", %{client: client} do
      patched_object = Fixtures.object_fixture()

      Mox.expect(Mock, :request, fn _client, :patch, path, _body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}?tenant=TenantA"
        {:ok, %{}}
      end)

      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}?tenant=TenantA"
        {:ok, patched_object}
      end)

      assert {:ok, _result} =
               Data.patch(
                 client,
                 @test_collection,
                 @test_uuid,
                 %{"properties" => %{"title" => "Test"}},
                 tenant: "TenantA"
               )
    end

    test "patch strips vector from payload (not allowed in PATCH)", %{client: client} do
      patched_object = Fixtures.object_fixture()

      Mox.expect(Mock, :request, fn _client, :patch, _path, body, _opts ->
        # Vector should NOT be in PATCH body
        refute Map.has_key?(body, "vector")
        refute Map.has_key?(body, :vector)
        {:ok, %{}}
      end)

      Mox.expect(Mock, :request, fn _client, :get, _path, nil, _opts ->
        {:ok, patched_object}
      end)

      # Try to send a vector with patch - it should be stripped
      assert {:ok, _result} =
               Data.patch(client, @test_collection, @test_uuid, %{
                 "properties" => %{"title" => "Test"},
                 "vector" => [0.1, 0.2, 0.3]
               })
    end
  end

  describe "update/4 (PUT - full replacement)" do
    test "replaces entire object with new data", %{client: client} do
      replaced_object = %{
        "id" => @test_uuid,
        "class" => @test_collection,
        "properties" => %{
          "title" => "Replaced Title",
          "content" => "Replaced Content"
        }
      }

      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        assert body["class"] == @test_collection
        assert body["id"] == @test_uuid

        assert body["properties"] == %{
                 "title" => "Replaced Title",
                 "content" => "Replaced Content"
               }

        {:ok, replaced_object}
      end)

      assert {:ok, result} =
               Data.update(client, @test_collection, @test_uuid, %{
                 "properties" => %{"title" => "Replaced Title", "content" => "Replaced Content"}
               })

      assert result["properties"]["title"] == "Replaced Title"
      assert result["properties"]["content"] == "Replaced Content"
    end

    test "Data.replace/4 is a semantic alias for update", %{client: client} do
      replaced_object = %{
        "id" => @test_uuid,
        "class" => @test_collection,
        "properties" => %{"title" => "Via Replace"}
      }

      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        assert body["properties"] == %{"title" => "Via Replace"}
        {:ok, replaced_object}
      end)

      assert {:ok, result} =
               Data.replace(client, @test_collection, @test_uuid, %{
                 "properties" => %{"title" => "Via Replace"}
               })

      assert result["properties"]["title"] == "Via Replace"
    end

    test "replace with vector", %{client: client} do
      vector = [0.1, 0.2, 0.3, 0.4, 0.5]

      replaced_object = %{
        "id" => @test_uuid,
        "class" => @test_collection,
        "properties" => %{"title" => "With Vector"},
        "vector" => vector
      }

      Mox.expect(Mock, :request, fn _client, :put, _path, body, _opts ->
        assert body["vector"] == vector
        {:ok, replaced_object}
      end)

      assert {:ok, result} =
               Data.update(client, @test_collection, @test_uuid, %{
                 "properties" => %{"title" => "With Vector"},
                 "vector" => vector
               })

      assert result["vector"] == vector
    end

    test "replace returns error when object doesn't exist", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, _path, _body, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :not_found,
           message: "Object not found",
           details: %{},
           status_code: 404
         }}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Data.update(client, @test_collection, "nonexistent-id", %{
                 "properties" => %{"title" => "Test"}
               })
    end

    test "replace with tenant option", %{client: client} do
      replaced_object = Fixtures.object_fixture()

      Mox.expect(Mock, :request, fn _client, :put, path, _body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}?tenant=TenantB"
        {:ok, replaced_object}
      end)

      assert {:ok, _result} =
               Data.update(
                 client,
                 @test_collection,
                 @test_uuid,
                 %{"properties" => %{"title" => "Test"}},
                 tenant: "TenantB"
               )
    end

    test "replace with consistency_level option", %{client: client} do
      replaced_object = Fixtures.object_fixture()

      Mox.expect(Mock, :request, fn _client, :put, path, _body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}?consistency_level=ALL"
        {:ok, replaced_object}
      end)

      assert {:ok, _result} =
               Data.update(
                 client,
                 @test_collection,
                 @test_uuid,
                 %{"properties" => %{"title" => "Test"}},
                 consistency_level: "ALL"
               )
    end
  end

  describe "exists?/3 (HEAD - check existence)" do
    test "returns true when object exists", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :head, path, nil, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        {:ok, %{}}
      end)

      assert {:ok, true} = Data.exists?(client, @test_collection, @test_uuid)
    end

    test "returns false when object doesn't exist (404)", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :head, path, nil, _opts ->
        assert path == "/v1/objects/#{@test_collection}/nonexistent-id"

        {:error,
         %WeaviateEx.Error{
           type: :not_found,
           message: "Not found",
           details: %{},
           status_code: 404
         }}
      end)

      assert {:ok, false} = Data.exists?(client, @test_collection, "nonexistent-id")
    end

    test "returns false on other errors", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :head, _path, nil, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :server_error,
           message: "Server error",
           details: %{},
           status_code: 500
         }}
      end)

      # exists? returns false for any error, not just 404
      assert {:ok, false} = Data.exists?(client, @test_collection, @test_uuid)
    end

    test "exists? with tenant option", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :head, path, nil, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}?tenant=TenantC"
        {:ok, %{}}
      end)

      assert {:ok, true} = Data.exists?(client, @test_collection, @test_uuid, tenant: "TenantC")
    end

    test "exists? with consistency_level option", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :head, path, nil, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}?consistency_level=QUORUM"
        {:ok, %{}}
      end)

      assert {:ok, true} =
               Data.exists?(client, @test_collection, @test_uuid, consistency_level: "QUORUM")
    end
  end

  describe "WeaviateEx.Objects module interface" do
    # These tests verify the simplified interface without client parameter
    # The functions use the global configuration

    test "Objects.patch/3 performs partial update" do
      # This tests the WeaviateEx.Objects.patch/4 function
      # which wraps the Data API

      patched_object = Fixtures.object_fixture()

      Mox.expect(Mock, :request, fn _client, :patch, path, body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        assert body["properties"]["title"] == "Patched via Objects"
        {:ok, %{}}
      end)

      Mox.expect(Mock, :request, fn _client, :get, _path, nil, _opts ->
        {:ok, patched_object}
      end)

      # Note: WeaviateEx.Objects uses global config, not passed client
      # This test uses the mock setup from test_helper.exs
      assert {:ok, _result} =
               WeaviateEx.Objects.patch(@test_collection, @test_uuid, %{
                 properties: %{title: "Patched via Objects"}
               })
    end

    test "Objects.update/4 performs full replacement (PUT)" do
      updated_object = Fixtures.object_fixture()

      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        assert body["properties"]["title"] == "Replaced via Objects"
        {:ok, updated_object}
      end)

      assert {:ok, _result} =
               WeaviateEx.Objects.update(@test_collection, @test_uuid, %{
                 properties: %{title: "Replaced via Objects"}
               })
    end

    test "Objects.replace/3 performs full replacement (PUT) - semantic alias" do
      replaced_object = Fixtures.object_fixture()

      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        assert body["properties"]["title"] == "Replaced via Objects.replace"
        {:ok, replaced_object}
      end)

      assert {:ok, _result} =
               WeaviateEx.Objects.replace(@test_collection, @test_uuid, %{
                 properties: %{title: "Replaced via Objects.replace"}
               })
    end

    test "Objects.replace/4 with options" do
      replaced_object = Fixtures.object_fixture()

      Mox.expect(Mock, :request, fn _client, :put, path, _body, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}?tenant=TenantX"
        {:ok, replaced_object}
      end)

      assert {:ok, _result} =
               WeaviateEx.Objects.replace(
                 @test_collection,
                 @test_uuid,
                 %{properties: %{title: "Test"}},
                 tenant: "TenantX"
               )
    end

    test "Objects.exists?/2 checks object existence" do
      Mox.expect(Mock, :request, fn _client, :head, path, nil, _opts ->
        assert path == "/v1/objects/#{@test_collection}/#{@test_uuid}"
        {:ok, %{}}
      end)

      assert {:ok, true} = WeaviateEx.Objects.exists?(@test_collection, @test_uuid)
    end

    test "Objects.exists?/2 returns error for non-existent object" do
      Mox.expect(Mock, :request, fn _client, :head, _path, nil, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :not_found,
           message: "Not found",
           details: %{},
           status_code: 404
         }}
      end)

      # The Objects.exists?/3 returns error, unlike Data.exists? which returns {:ok, false}
      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               WeaviateEx.Objects.exists?(@test_collection, "nonexistent-id")
    end
  end
end
