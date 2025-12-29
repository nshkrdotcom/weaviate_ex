defmodule WeaviateEx.GRPC.Services.BatchStreamTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.GRPC.Services.BatchStream

  describe "start_message/1" do
    test "creates start message with default consistency level" do
      message = BatchStream.start_message()

      assert %Weaviate.V1.BatchStreamRequest{} = message
      assert message.message == {:start, %Weaviate.V1.BatchStreamRequest.Start{}}
    end

    test "creates start message with specified consistency level" do
      message = BatchStream.start_message(consistency_level: :all)

      assert %Weaviate.V1.BatchStreamRequest{} = message
      {:start, start} = message.message
      assert start.consistency_level == :CONSISTENCY_LEVEL_ALL
    end

    test "creates start message with quorum consistency" do
      message = BatchStream.start_message(consistency_level: :quorum)

      {:start, start} = message.message
      assert start.consistency_level == :CONSISTENCY_LEVEL_QUORUM
    end

    test "creates start message with one consistency" do
      message = BatchStream.start_message(consistency_level: :one)

      {:start, start} = message.message
      assert start.consistency_level == :CONSISTENCY_LEVEL_ONE
    end
  end

  describe "stop_message/0" do
    test "creates stop message" do
      message = BatchStream.stop_message()

      assert %Weaviate.V1.BatchStreamRequest{} = message
      assert message.message == {:stop, %Weaviate.V1.BatchStreamRequest.Stop{}}
    end
  end

  describe "data_message/2" do
    test "creates data message with objects only" do
      objects = [
        %{uuid: "uuid-1", collection: "Test", properties: %{"name" => "test1"}},
        %{uuid: "uuid-2", collection: "Test", properties: %{"name" => "test2"}}
      ]

      message = BatchStream.data_message(objects, [])

      assert %Weaviate.V1.BatchStreamRequest{} = message
      {:data, data} = message.message
      assert data.objects != nil
      assert length(data.objects.values) == 2
      assert data.references == nil
    end

    test "creates data message with references only" do
      refs = [
        %{
          from_collection: "Article",
          from_uuid: "uuid-1",
          name: "author",
          to_uuid: "uuid-author-1"
        }
      ]

      message = BatchStream.data_message([], refs)

      {:data, data} = message.message
      assert data.objects == nil
      assert data.references != nil
      assert length(data.references.values) == 1
    end

    test "creates data message with both objects and references" do
      objects = [%{uuid: "uuid-1", collection: "Test", properties: %{}}]
      refs = [%{from_collection: "Test", from_uuid: "uuid-1", name: "ref", to_uuid: "uuid-2"}]

      message = BatchStream.data_message(objects, refs)

      {:data, data} = message.message
      assert data.objects != nil
      assert data.references != nil
    end

    test "creates empty data message when both lists are empty" do
      message = BatchStream.data_message([], [])

      {:data, data} = message.message
      assert data.objects == nil
      assert data.references == nil
    end
  end

  describe "build_batch_object/1" do
    test "builds batch object with basic properties" do
      obj = %{
        uuid: "test-uuid",
        collection: "TestCollection",
        properties: %{"title" => "Test Title", "count" => 42}
      }

      batch_obj = BatchStream.build_batch_object(obj)

      assert %Weaviate.V1.BatchObject{} = batch_obj
      assert batch_obj.uuid == "test-uuid"
      assert batch_obj.collection == "TestCollection"
    end

    test "builds batch object with tenant" do
      obj = %{
        uuid: "test-uuid",
        collection: "TestCollection",
        properties: %{},
        tenant: "tenant-a"
      }

      batch_obj = BatchStream.build_batch_object(obj)

      assert batch_obj.tenant == "tenant-a"
    end

    test "builds batch object with vector" do
      obj = %{
        uuid: "test-uuid",
        collection: "TestCollection",
        properties: %{},
        vector: [0.1, 0.2, 0.3]
      }

      batch_obj = BatchStream.build_batch_object(obj)

      # Vectors are encoded as bytes
      assert batch_obj.vector_bytes != nil
    end

    test "builds batch object with named vectors" do
      obj = %{
        uuid: "test-uuid",
        collection: "TestCollection",
        properties: %{},
        vectors: %{"title_vector" => [0.1, 0.2], "content_vector" => [0.3, 0.4]}
      }

      batch_obj = BatchStream.build_batch_object(obj)

      assert length(batch_obj.vectors) == 2
    end
  end

  describe "build_batch_reference/1" do
    test "builds basic batch reference" do
      ref = %{
        from_collection: "Article",
        from_uuid: "article-uuid",
        name: "author",
        to_uuid: "author-uuid"
      }

      batch_ref = BatchStream.build_batch_reference(ref)

      assert %Weaviate.V1.BatchReference{} = batch_ref
      assert batch_ref.from_collection == "Article"
      assert batch_ref.from_uuid == "article-uuid"
      assert batch_ref.name == "author"
      assert batch_ref.to_uuid == "author-uuid"
    end

    test "builds batch reference with target collection" do
      ref = %{
        from_collection: "Article",
        from_uuid: "article-uuid",
        name: "author",
        to_collection: "Author",
        to_uuid: "author-uuid"
      }

      batch_ref = BatchStream.build_batch_reference(ref)

      assert batch_ref.to_collection == "Author"
    end

    test "builds batch reference with tenant" do
      ref = %{
        from_collection: "Article",
        from_uuid: "article-uuid",
        name: "author",
        to_uuid: "author-uuid",
        tenant: "tenant-a"
      }

      batch_ref = BatchStream.build_batch_reference(ref)

      assert batch_ref.tenant == "tenant-a"
    end
  end

  describe "parse_reply/1" do
    test "parses started reply" do
      reply = %Weaviate.V1.BatchStreamReply{
        message: {:started, %Weaviate.V1.BatchStreamReply.Started{}}
      }

      assert {:started, %{}} = BatchStream.parse_reply(reply)
    end

    test "parses shutdown reply" do
      reply = %Weaviate.V1.BatchStreamReply{
        message: {:shutdown, %Weaviate.V1.BatchStreamReply.Shutdown{}}
      }

      assert {:shutdown, %{}} = BatchStream.parse_reply(reply)
    end

    test "parses shutting_down reply" do
      reply = %Weaviate.V1.BatchStreamReply{
        message: {:shutting_down, %Weaviate.V1.BatchStreamReply.ShuttingDown{}}
      }

      assert {:shutting_down, %{}} = BatchStream.parse_reply(reply)
    end

    test "parses backoff reply with batch_size" do
      reply = %Weaviate.V1.BatchStreamReply{
        message: {:backoff, %Weaviate.V1.BatchStreamReply.Backoff{batch_size: 50}}
      }

      assert {:backoff, %{batch_size: 50}} = BatchStream.parse_reply(reply)
    end

    test "parses acks reply" do
      reply = %Weaviate.V1.BatchStreamReply{
        message:
          {:acks,
           %Weaviate.V1.BatchStreamReply.Acks{
             uuids: ["uuid-1", "uuid-2"],
             beacons: ["beacon-1"]
           }}
      }

      assert {:acks, %{uuids: ["uuid-1", "uuid-2"], beacons: ["beacon-1"]}} =
               BatchStream.parse_reply(reply)
    end

    test "parses results reply with successes" do
      reply = %Weaviate.V1.BatchStreamReply{
        message:
          {:results,
           %Weaviate.V1.BatchStreamReply.Results{
             successes: [
               %Weaviate.V1.BatchStreamReply.Results.Success{detail: {:uuid, "uuid-1"}},
               %Weaviate.V1.BatchStreamReply.Results.Success{detail: {:beacon, "beacon-1"}}
             ],
             errors: []
           }}
      }

      {:results, result} = BatchStream.parse_reply(reply)
      assert length(result.successes) == 2
      assert result.errors == []
    end

    test "parses results reply with errors" do
      reply = %Weaviate.V1.BatchStreamReply{
        message:
          {:results,
           %Weaviate.V1.BatchStreamReply.Results{
             successes: [],
             errors: [
               %Weaviate.V1.BatchStreamReply.Results.Error{
                 error: "Object validation failed",
                 detail: {:uuid, "uuid-1"}
               }
             ]
           }}
      }

      {:results, result} = BatchStream.parse_reply(reply)
      assert length(result.errors) == 1
      assert hd(result.errors).error == "Object validation failed"
      assert hd(result.errors).uuid == "uuid-1"
    end
  end

  describe "consistency_level_to_proto/1" do
    test "converts :all to proto enum" do
      assert BatchStream.consistency_level_to_proto(:all) == :CONSISTENCY_LEVEL_ALL
    end

    test "converts :quorum to proto enum" do
      assert BatchStream.consistency_level_to_proto(:quorum) == :CONSISTENCY_LEVEL_QUORUM
    end

    test "converts :one to proto enum" do
      assert BatchStream.consistency_level_to_proto(:one) == :CONSISTENCY_LEVEL_ONE
    end

    test "returns nil for nil input" do
      assert BatchStream.consistency_level_to_proto(nil) == nil
    end
  end
end
