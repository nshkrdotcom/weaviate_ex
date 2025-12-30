defmodule WeaviateEx.GRPC.Services.SearchTest do
  use ExUnit.Case, async: true

  alias Weaviate.V1.{
    BM25,
    GenerativeSearch,
    Hybrid,
    NearObject,
    NearTextSearch,
    NearVector,
    Rerank,
    SearchRequest
  }

  alias WeaviateEx.GRPC.Services.Search
  alias WeaviateEx.Query.GroupBy
  alias WeaviateEx.Query.NearImage
  alias WeaviateEx.Query.NearMedia
  alias WeaviateEx.Query.QueryReference
  alias WeaviateEx.Query.Rerank, as: QueryRerank
  alias WeaviateEx.Query.TargetVectors

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

  describe "request building" do
    test "builds filters and group_by in search requests" do
      filter = %{path: ["status"], operator: "Equal", valueText: "published"}
      group_by = GroupBy.new("category", objects_per_group: 2, number_of_groups: 3)

      request =
        Search.build_near_text_request("Article", "ai",
          filters: filter,
          group_by: group_by
        )

      assert request.filters.operator == :OPERATOR_EQUAL
      assert request.filters.target.target == {:property, "status"}
      assert request.filters.test_value == {:value_text, "published"}
      assert request.group_by.path == ["category"]
      assert request.group_by.objects_per_group == 2
      assert request.group_by.number_of_groups == 3
    end

    test "maps ContainsAny value arrays into gRPC filters" do
      filter = %{path: ["id"], operator: "ContainsAny", valueText: ["id-1", "id-2"]}

      request = Search.build_near_text_request("Article", "ai", filters: filter)

      assert request.filters.operator == :OPERATOR_CONTAINS_ANY

      assert request.filters.test_value ==
               {:value_text_array, %Weaviate.V1.TextArray{values: ["id-1", "id-2"]}}
    end

    test "accepts on alias for filter path" do
      filter = %{on: ["id"], operator: "Equal", valueText: "id-1"}

      request = Search.build_near_text_request("Article", "ai", filters: filter)

      assert request.filters.operator == :OPERATOR_EQUAL
      assert request.filters.target.target == {:property, "id"}
      assert request.filters.test_value == {:value_text, "id-1"}
    end

    test "builds target vectors into near_vector requests" do
      targets = TargetVectors.weighted(%{"title" => 0.7, "content" => 0.3})

      request = Search.build_near_vector_request("Article", [0.1, 0.2], target_vectors: targets)

      assert Enum.sort(request.near_vector.targets.target_vectors) ==
               Enum.sort(["title", "content"])

      assert request.near_vector.targets.combination == :COMBINATION_METHOD_TYPE_MANUAL

      weights =
        Enum.map(request.near_vector.targets.weights_for_targets, fn weight ->
          {weight.target, weight.weight}
        end)

      assert Enum.sort_by(weights, &elem(&1, 0)) == [{"content", 0.3}, {"title", 0.7}]
    end

    test "builds near_image requests with target vectors" do
      near_image = NearImage.new(image: "base64data", target_vectors: ["image_vec"])

      request = Search.build_near_image_request("Images", near_image)

      assert request.near_image.image == "base64data"
      assert request.near_image.targets.target_vectors == ["image_vec"]
    end

    test "builds near_media requests with correct media type" do
      near_media = NearMedia.new(:audio, media: "audiodata")

      request = Search.build_near_media_request("Media", near_media)

      assert request.near_audio.audio == "audiodata"
      assert request.near_video == nil
      assert request.near_imu == nil
    end

    test "builds return references and vector metadata" do
      ref = QueryReference.new("hasAuthor", return_properties: ["name"], include_vector: true)

      request =
        Search.build_near_text_request("Article", "ai",
          return_properties: ["title"],
          return_references: [ref],
          return_metadata: [:vector]
        )

      assert request.properties.non_ref_properties == ["title"]
      assert length(request.properties.ref_properties) == 1

      ref_request = hd(request.properties.ref_properties)
      assert ref_request.reference_property == "hasAuthor"
      assert ref_request.properties.non_ref_properties == ["name"]
      assert ref_request.metadata.vector == true
      assert request.metadata.vector == true
    end
  end

  describe "generative search" do
    test "builds search request with simple generative config" do
      request =
        Search.build_near_text_request("Article", "machine learning",
          generative: %{single_prompt: "Summarize this article"}
        )

      assert %GenerativeSearch{} = request.generative
      assert request.generative.single.prompt == "Summarize this article"
    end

    test "builds search request with grouped generative config" do
      request =
        Search.build_near_text_request("Article", "machine learning",
          generative: %{
            grouped_task: "Synthesize the key themes from these articles",
            grouped_properties: ["title", "content"]
          }
        )

      assert %GenerativeSearch{} = request.generative
      assert request.generative.grouped.task == "Synthesize the key themes from these articles"
      assert request.generative.grouped.properties.values == ["title", "content"]
    end

    test "builds search request with provider-specific generative config" do
      request =
        Search.build_near_text_request("Article", "machine learning",
          generative: %{
            single_prompt: "Summarize: {content}",
            provider: :openai,
            model: "gpt-4",
            temperature: 0.7
          }
        )

      assert %GenerativeSearch{} = request.generative
      assert request.generative.single.prompt == "Summarize: {content}"
      assert length(request.generative.single.queries) == 1

      [provider] = request.generative.single.queries
      assert {:openai, openai_config} = provider.kind
      assert openai_config.model == "gpt-4"
      assert openai_config.temperature == 0.7
    end

    test "builds near_vector request with generative" do
      request =
        Search.build_near_vector_request("Article", [0.1, 0.2],
          generative: %{
            single_prompt: "Summarize this",
            provider: :anthropic,
            model: "claude-3-5-sonnet-20241022"
          }
        )

      assert %GenerativeSearch{} = request.generative
      assert request.generative.single.prompt == "Summarize this"
    end

    test "builds hybrid request with generative" do
      request =
        Search.build_hybrid_request("Article", "AI trends",
          alpha: 0.5,
          generative: %{
            grouped_task: "What are the main AI trends?",
            provider: :openai
          }
        )

      assert %GenerativeSearch{} = request.generative
      assert request.generative.grouped.task == "What are the main AI trends?"
    end

    test "builds bm25 request with generative" do
      request =
        Search.build_bm25_request("Article", "machine learning",
          properties: ["title", "content"],
          generative: %{single_prompt: "Extract keywords"}
        )

      assert %GenerativeSearch{} = request.generative
      assert request.generative.single.prompt == "Extract keywords"
    end

    test "builds request without generative when not provided" do
      request = Search.build_near_text_request("Article", "machine learning")

      assert request.generative == nil
    end

    test "supports generative field in SearchRequest protobuf" do
      generative = %GenerativeSearch{
        single: %GenerativeSearch.Single{
          prompt: "Test prompt",
          debug: false,
          queries: []
        }
      }

      request = %SearchRequest{
        collection: "Test",
        generative: generative
      }

      assert %GenerativeSearch{} = request.generative
      assert request.generative.single.prompt == "Test prompt"
    end
  end

  describe "rerank search" do
    test "supports rerank field in SearchRequest protobuf" do
      rerank = %Rerank{
        property: "content",
        query: "deep learning"
      }

      request = %SearchRequest{
        collection: "Test",
        rerank: rerank
      }

      assert %Rerank{} = request.rerank
      assert request.rerank.property == "content"
      assert request.rerank.query == "deep learning"
    end

    test "builds search request with rerank" do
      rerank = QueryRerank.new("content")

      request =
        Search.build_near_text_request("Article", "machine learning", rerank: rerank)

      assert %Rerank{} = request.rerank
      assert request.rerank.property == "content"
      assert request.rerank.query == nil
    end

    test "builds search request with rerank and custom query" do
      rerank = QueryRerank.new("content", query: "What is machine learning?")

      request =
        Search.build_near_text_request("Article", "AI", rerank: rerank)

      assert %Rerank{} = request.rerank
      assert request.rerank.property == "content"
      assert request.rerank.query == "What is machine learning?"
    end

    test "builds near_vector request with rerank" do
      rerank = QueryRerank.new("description")

      request =
        Search.build_near_vector_request("Product", [0.1, 0.2], rerank: rerank)

      assert %Rerank{} = request.rerank
      assert request.rerank.property == "description"
    end

    test "builds hybrid request with rerank" do
      rerank = QueryRerank.new("content", query: "AI applications")

      request =
        Search.build_hybrid_request("Article", "machine learning",
          alpha: 0.7,
          rerank: rerank
        )

      assert %Rerank{} = request.rerank
      assert request.rerank.property == "content"
      assert request.rerank.query == "AI applications"
    end

    test "builds bm25 request with rerank" do
      rerank = QueryRerank.new("title")

      request =
        Search.build_bm25_request("Article", "AI",
          properties: ["title", "content"],
          rerank: rerank
        )

      assert %Rerank{} = request.rerank
      assert request.rerank.property == "title"
    end

    test "builds near_object request with rerank" do
      rerank = QueryRerank.new("content")

      request =
        Search.build_near_object_request("Article", "uuid-123", rerank: rerank)

      assert %Rerank{} = request.rerank
      assert request.rerank.property == "content"
    end

    test "builds request without rerank when not provided" do
      request = Search.build_near_text_request("Article", "machine learning")

      assert request.rerank == nil
    end

    test "builds request with both rerank and generative" do
      rerank = QueryRerank.new("content")

      request =
        Search.build_near_text_request("Article", "AI",
          rerank: rerank,
          generative: %{single_prompt: "Summarize this"}
        )

      assert %Rerank{} = request.rerank
      assert request.rerank.property == "content"
      assert %GenerativeSearch{} = request.generative
      assert request.generative.single.prompt == "Summarize this"
    end
  end
end
