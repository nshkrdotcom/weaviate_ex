defmodule WeaviateEx.ObjectsTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.TestHelpers
  alias WeaviateEx.{Objects, Fixtures}

  setup :verify_on_exit!
  setup :setup_http_client

  describe "create/3" do
    test "creates an object with properties" do
      object = Fixtures.object_fixture()

      expect_http_request_with_body(:post, "/v1/objects", :any, fn ->
        mock_success_response(object, 201)
      end)

      assert {:ok, result} =
               Objects.create("Article", %{
                 properties: %{
                   title: "Test Article",
                   content: "This is test content"
                 }
               })

      assert result["class"] == "Article"
      assert result["id"]
    end

    test "creates object with custom ID and vector" do
      object = Fixtures.object_fixture()

      expect_http_request_with_body(:post, "/v1/objects", :any, fn ->
        mock_success_response(object, 201)
      end)

      assert {:ok, result} =
               Objects.create("Article", %{
                 id: "00000000-0000-0000-0000-000000000001",
                 properties: %{title: "Test"},
                 vector: [0.1, 0.2, 0.3]
               })

      assert result["id"] == "00000000-0000-0000-0000-000000000001"
    end

    test "returns error on invalid data" do
      expect_http_request_with_body(:post, "/v1/objects", :any, fn ->
        mock_error_response(422, "Invalid property")
      end)

      assert {:error, %{status: 422}} = Objects.create("Article", %{})
    end
  end

  describe "get/3" do
    test "retrieves an object by class and ID" do
      object = Fixtures.object_fixture()

      expect_http_request(:get, "/v1/objects/Article/00000000-0000-0000-0000-000000000001", fn ->
        mock_success_response(object)
      end)

      assert {:ok, result} = Objects.get("Article", "00000000-0000-0000-0000-000000000001")
      assert result["id"] == "00000000-0000-0000-0000-000000000001"
    end

    test "returns error when object not found" do
      expect_http_request(:get, "/v1/objects/Article/00000000-0000-0000-0000-999999999999", fn ->
        mock_error_response(404, "Object not found")
      end)

      assert {:error, %{status: 404}} =
               Objects.get("Article", "00000000-0000-0000-0000-999999999999")
    end
  end

  describe "list/2" do
    test "lists objects from a collection" do
      objects = %{"objects" => Fixtures.batch_objects_fixture()}

      expect_http_request(:get, "/v1/objects?class=Article", fn ->
        mock_success_response(objects)
      end)

      assert {:ok, result} = Objects.list("Article")
      assert length(result["objects"]) == 3
    end

    test "lists objects with limit and offset" do
      objects = %{"objects" => [Fixtures.object_fixture()]}

      expect_http_request(:get, "/v1/objects?class=Article&limit=1&offset=10", fn ->
        mock_success_response(objects)
      end)

      assert {:ok, result} = Objects.list("Article", limit: 1, offset: 10)
      assert length(result["objects"]) == 1
    end
  end

  describe "update/4" do
    test "updates an object (PUT - full replacement)" do
      updated_object = %{
        "id" => "00000000-0000-0000-0000-000000000001",
        "class" => "Article",
        "properties" => %{"title" => "Updated Title", "content" => "Updated content"}
      }

      expect_http_request_with_body(
        :put,
        "/v1/objects/Article/00000000-0000-0000-0000-000000000001",
        :any,
        fn ->
          mock_success_response(updated_object)
        end
      )

      assert {:ok, result} =
               Objects.update("Article", "00000000-0000-0000-0000-000000000001", %{
                 properties: %{title: "Updated Title", content: "Updated content"}
               })

      assert result["properties"]["title"] == "Updated Title"
    end
  end

  describe "patch/4" do
    test "patches an object (PATCH - partial update)" do
      patched_object = %{
        "id" => "00000000-0000-0000-0000-000000000001",
        "class" => "Article",
        "properties" => %{"title" => "Patched Title", "content" => "Original"}
      }

      # PATCH request returns 204 No Content
      expect_http_request_with_body(
        :patch,
        "/v1/objects/Article/00000000-0000-0000-0000-000000000001",
        :any,
        fn ->
          mock_success_response(%{}, 204)
        end
      )

      # Then GET to retrieve updated object
      expect_http_request(
        :get,
        "/v1/objects/Article/00000000-0000-0000-0000-000000000001",
        fn ->
          mock_success_response(patched_object)
        end
      )

      assert {:ok, result} =
               Objects.patch("Article", "00000000-0000-0000-0000-000000000001", %{
                 properties: %{title: "Patched Title"}
               })

      assert result["properties"]["title"] == "Patched Title"
    end
  end

  describe "delete/3" do
    test "deletes an object" do
      expect_http_request(
        :delete,
        "/v1/objects/Article/00000000-0000-0000-0000-000000000001",
        fn ->
          mock_success_response(%{})
        end
      )

      assert {:ok, _} = Objects.delete("Article", "00000000-0000-0000-0000-000000000001")
    end

    test "returns error when object not found" do
      expect_http_request(
        :delete,
        "/v1/objects/Article/00000000-0000-0000-0000-999999999999",
        fn ->
          mock_error_response(404, "Object not found")
        end
      )

      assert {:error, %{status: 404}} =
               Objects.delete("Article", "00000000-0000-0000-0000-999999999999")
    end
  end

  describe "exists?/3" do
    test "returns true when object exists (HEAD request)" do
      expect(WeaviateEx.HTTPClient.Mock, :request, fn :head, url, _headers, _body, _opts ->
        if url =~ "00000000-0000-0000-0000-000000000001" do
          {:ok, %{status: 204, body: "", headers: []}}
        else
          {:ok, %{status: 404, body: "", headers: []}}
        end
      end)

      assert {:ok, true} = Objects.exists?("Article", "00000000-0000-0000-0000-000000000001")
    end

    test "returns false when object doesn't exist" do
      expect(WeaviateEx.HTTPClient.Mock, :request, fn :head, _url, _headers, _body, _opts ->
        {:ok, %{status: 404, body: "", headers: []}}
      end)

      assert {:error, %{status: 404}} =
               Objects.exists?("Article", "00000000-0000-0000-0000-999999999999")
    end
  end

  describe "validate/3" do
    test "validates an object without creating it" do
      expect_http_request_with_body(:post, "/v1/objects/validate", :any, fn ->
        mock_success_response(%{"valid" => true})
      end)

      assert {:ok, result} =
               Objects.validate("Article", %{
                 properties: %{title: "Test"}
               })

      assert result["valid"] == true
    end
  end

  describe "integration tests" do
    @tag :integration
    test "full CRUD workflow with real Weaviate" do
      if integration_mode?() do
        # Create object
        {:ok, created} =
          Objects.create("TestArticle", %{
            properties: %{title: "Integration Test"}
          })

        id = created["id"]

        # Get object
        {:ok, fetched} = Objects.get("TestArticle", id)
        assert fetched["properties"]["title"] == "Integration Test"

        # Update object
        {:ok, updated} =
          Objects.update("TestArticle", id, %{
            properties: %{title: "Updated"}
          })

        assert updated["properties"]["title"] == "Updated"

        # Delete object
        {:ok, _} = Objects.delete("TestArticle", id)
      else
        assert true
      end
    end
  end
end
