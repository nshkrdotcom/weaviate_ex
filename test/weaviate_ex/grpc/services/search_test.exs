defmodule WeaviateEx.GRPC.Services.SearchTest do
  use ExUnit.Case, async: true

  alias Weaviate.V1.{BM25, Hybrid, NearObject, NearTextSearch, NearVector, SearchRequest}

  @moduletag :grpc

  describe "SearchRequest protobuf" do
    test "can create with collection name" do
      request = %SearchRequest{collection: "Test"}
      assert request.collection == "Test"
    end

    test "supports near_vector field" do
      request = %SearchRequest{
        collection: "Test",
        near_vector: %NearVector{vector_bytes: <<>>}
      }

      assert %NearVector{} = request.near_vector
    end

    test "supports near_text field" do
      request = %SearchRequest{
        collection: "Test",
        near_text: %NearTextSearch{query: ["test"]}
      }

      assert %NearTextSearch{} = request.near_text
    end

    test "supports near_object field" do
      request = %SearchRequest{
        collection: "Test",
        near_object: %NearObject{id: "uuid-here"}
      }

      assert %NearObject{} = request.near_object
    end

    test "supports bm25_search field" do
      request = %SearchRequest{
        collection: "Test",
        bm25_search: %BM25{query: "test"}
      }

      assert %BM25{} = request.bm25_search
    end

    test "supports hybrid_search field" do
      request = %SearchRequest{
        collection: "Test",
        hybrid_search: %Hybrid{query: "test", alpha: 0.5}
      }

      assert %Hybrid{} = request.hybrid_search
    end

    test "supports limit field" do
      request = %SearchRequest{collection: "Test", limit: 10}
      assert request.limit == 10
    end

    test "supports offset field" do
      request = %SearchRequest{collection: "Test", offset: 5}
      assert request.offset == 5
    end

    test "supports tenant field" do
      request = %SearchRequest{collection: "Test", tenant: "tenant-a"}
      assert request.tenant == "tenant-a"
    end

    test "supports autocut field" do
      request = %SearchRequest{collection: "Test", autocut: 3}
      assert request.autocut == 3
    end
  end

  describe "NearVector protobuf" do
    test "can create with vector_bytes" do
      vector_bytes = <<0.1::float-little-32, 0.2::float-little-32>>
      near_vector = %NearVector{vector_bytes: vector_bytes}
      assert near_vector.vector_bytes == vector_bytes
    end

    test "supports certainty field" do
      near_vector = %NearVector{certainty: 0.7}
      assert near_vector.certainty == 0.7
    end

    test "supports distance field" do
      near_vector = %NearVector{distance: 0.3}
      assert near_vector.distance == 0.3
    end

    test "converts float list to bytes" do
      vector = [0.1, 0.2, 0.3]
      bytes = vector |> Enum.map(&<<&1::float-little-32>>) |> IO.iodata_to_binary()
      near_vector = %NearVector{vector_bytes: bytes}
      # 3 floats * 4 bytes
      assert byte_size(near_vector.vector_bytes) == 12
    end
  end

  describe "NearTextSearch protobuf" do
    test "accepts list of query strings" do
      near_text = %NearTextSearch{query: ["machine", "learning"]}
      assert near_text.query == ["machine", "learning"]
    end

    test "supports certainty field" do
      near_text = %NearTextSearch{query: ["test"], certainty: 0.8}
      assert near_text.certainty == 0.8
    end

    test "supports distance field" do
      near_text = %NearTextSearch{query: ["test"], distance: 0.2}
      assert near_text.distance == 0.2
    end
  end

  describe "NearObject protobuf" do
    test "accepts object id" do
      near_object = %NearObject{id: "object-uuid-123"}
      assert near_object.id == "object-uuid-123"
    end

    test "supports certainty field" do
      near_object = %NearObject{id: "uuid", certainty: 0.9}
      assert near_object.certainty == 0.9
    end
  end

  describe "BM25 protobuf" do
    test "accepts query string" do
      bm25 = %BM25{query: "test query"}
      assert bm25.query == "test query"
    end

    test "accepts properties list" do
      bm25 = %BM25{query: "test", properties: ["title", "content"]}
      assert bm25.properties == ["title", "content"]
    end
  end

  describe "Hybrid protobuf" do
    test "accepts query and alpha" do
      hybrid = %Hybrid{query: "test", alpha: 0.7}
      assert hybrid.query == "test"
      assert hybrid.alpha == 0.7
    end

    test "accepts properties list" do
      hybrid = %Hybrid{query: "test", properties: ["title"]}
      assert hybrid.properties == ["title"]
    end

    test "default alpha is 0.0" do
      hybrid = %Hybrid{query: "test"}
      assert hybrid.alpha == 0.0
    end
  end
end
