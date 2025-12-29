defmodule WeaviateEx.GRPC.Services.BatchTest do
  use ExUnit.Case, async: true

  alias Weaviate.V1.{
    BatchDeleteReply,
    BatchDeleteRequest,
    BatchObject,
    BatchObjectsReply,
    BatchObjectsRequest,
    BatchReference,
    BatchReferencesReply
  }

  alias WeaviateEx.GRPC.Services.Batch

  @moduletag :grpc

  describe "parse_result/1" do
    test "parses BatchObjectsReply with no errors" do
      reply = %BatchObjectsReply{
        errors: [],
        took: 0.5
      }

      result = Batch.parse_result(reply)

      assert result.failed == 0
      assert result.errors == []
      assert result.took_ms == 500.0
    end

    test "parses BatchObjectsReply with errors" do
      reply = %BatchObjectsReply{
        errors: [
          %BatchObjectsReply.BatchError{index: 0, error: "Invalid object"},
          %BatchObjectsReply.BatchError{index: 5, error: "Duplicate UUID"}
        ],
        took: 1.2
      }

      result = Batch.parse_result(reply)

      assert result.failed == 2
      assert length(result.errors) == 2
      assert Enum.at(result.errors, 0) == %{index: 0, error: "Invalid object"}
      assert Enum.at(result.errors, 1) == %{index: 5, error: "Duplicate UUID"}
      assert result.took_ms == 1200.0
    end

    test "parses BatchReferencesReply with no errors" do
      reply = %BatchReferencesReply{
        errors: [],
        took: 0.3
      }

      result = Batch.parse_result(reply)

      assert result.failed == 0
      assert result.errors == []
      assert result.took_ms == 300.0
    end

    test "parses BatchReferencesReply with errors" do
      reply = %BatchReferencesReply{
        errors: [
          %BatchReferencesReply.BatchError{index: 2, error: "Reference not found"}
        ],
        took: 0.8
      }

      result = Batch.parse_result(reply)

      assert result.failed == 1
      assert length(result.errors) == 1
      assert result.took_ms == 800.0
    end
  end

  describe "BatchObjectsRequest protobuf" do
    test "can create with objects list" do
      request = %BatchObjectsRequest{objects: []}
      assert request.objects == []
    end

    test "supports consistency_level field" do
      request = %BatchObjectsRequest{
        objects: [],
        consistency_level: :CONSISTENCY_LEVEL_QUORUM
      }

      assert request.consistency_level == :CONSISTENCY_LEVEL_QUORUM
    end
  end

  describe "BatchObject protobuf" do
    test "can create with collection and uuid" do
      obj = %BatchObject{
        collection: "Article",
        uuid: "test-uuid",
        tenant: ""
      }

      assert obj.collection == "Article"
      assert obj.uuid == "test-uuid"
    end

    test "supports vector_bytes field" do
      vector_bytes = <<0.1::float-little-32, 0.2::float-little-32>>

      obj = %BatchObject{
        collection: "Article",
        vector_bytes: vector_bytes
      }

      assert obj.vector_bytes == vector_bytes
    end

    test "supports tenant field" do
      obj = %BatchObject{
        collection: "Article",
        tenant: "tenant-a"
      }

      assert obj.tenant == "tenant-a"
    end

    test "supports properties field" do
      props = %BatchObject.Properties{
        non_ref_properties: %Google.Protobuf.Struct{
          fields: %{
            "title" => %Google.Protobuf.Value{kind: {:string_value, "Test"}}
          }
        }
      }

      obj = %BatchObject{
        collection: "Article",
        properties: props
      }

      assert %BatchObject.Properties{} = obj.properties
    end
  end

  describe "BatchReference protobuf" do
    test "can create with required fields" do
      ref = %BatchReference{
        from_collection: "Article",
        from_uuid: "uuid-1",
        name: "author",
        to_uuid: "uuid-2"
      }

      assert ref.from_collection == "Article"
      assert ref.from_uuid == "uuid-1"
      assert ref.name == "author"
      assert ref.to_uuid == "uuid-2"
    end

    test "supports to_collection field" do
      ref = %BatchReference{
        from_collection: "Article",
        from_uuid: "uuid-1",
        name: "author",
        to_uuid: "uuid-2",
        to_collection: "Author"
      }

      assert ref.to_collection == "Author"
    end

    test "supports tenant field" do
      ref = %BatchReference{
        from_collection: "Article",
        from_uuid: "uuid-1",
        name: "author",
        to_uuid: "uuid-2",
        tenant: "tenant-a"
      }

      assert ref.tenant == "tenant-a"
    end
  end

  describe "BatchDeleteRequest protobuf" do
    test "can create with collection" do
      request = %BatchDeleteRequest{collection: "Article"}
      assert request.collection == "Article"
    end

    test "supports tenant field" do
      request = %BatchDeleteRequest{
        collection: "Article",
        tenant: "tenant-a"
      }

      assert request.tenant == "tenant-a"
    end

    test "supports verbose field" do
      request = %BatchDeleteRequest{
        collection: "Article",
        verbose: true
      }

      assert request.verbose == true
    end

    test "supports dry_run field" do
      request = %BatchDeleteRequest{
        collection: "Article",
        dry_run: true
      }

      assert request.dry_run == true
    end

    test "supports consistency_level field" do
      request = %BatchDeleteRequest{
        collection: "Article",
        consistency_level: :CONSISTENCY_LEVEL_ALL
      }

      assert request.consistency_level == :CONSISTENCY_LEVEL_ALL
    end
  end

  describe "BatchDeleteReply protobuf" do
    test "has matches field" do
      reply = %BatchDeleteReply{matches: 10}
      assert reply.matches == 10
    end

    test "has successful field" do
      reply = %BatchDeleteReply{successful: 10}
      assert reply.successful == 10
    end

    test "has failed field" do
      reply = %BatchDeleteReply{failed: 0}
      assert reply.failed == 0
    end

    test "has took field" do
      reply = %BatchDeleteReply{took: 1.5}
      assert reply.took == 1.5
    end
  end

  describe "consistency levels" do
    test "ONE level" do
      request = %BatchObjectsRequest{
        objects: [],
        consistency_level: :CONSISTENCY_LEVEL_ONE
      }

      assert request.consistency_level == :CONSISTENCY_LEVEL_ONE
    end

    test "QUORUM level" do
      request = %BatchObjectsRequest{
        objects: [],
        consistency_level: :CONSISTENCY_LEVEL_QUORUM
      }

      assert request.consistency_level == :CONSISTENCY_LEVEL_QUORUM
    end

    test "ALL level" do
      request = %BatchObjectsRequest{
        objects: [],
        consistency_level: :CONSISTENCY_LEVEL_ALL
      }

      assert request.consistency_level == :CONSISTENCY_LEVEL_ALL
    end
  end

  describe "BatchError protobuf" do
    test "has index and error fields" do
      error = %BatchObjectsReply.BatchError{index: 5, error: "Test error"}
      assert error.index == 5
      assert error.error == "Test error"
    end
  end
end
