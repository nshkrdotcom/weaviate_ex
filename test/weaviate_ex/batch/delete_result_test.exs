defmodule WeaviateEx.Batch.DeleteResultTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.DeleteResult
  alias WeaviateEx.Batch.DeleteResult.DeletedObject

  describe "from_api/1" do
    test "parses complete delete response" do
      response = %{
        "match" => %{"matches" => 10, "limit" => 10_000},
        "output" => "verbose",
        "dryRun" => false,
        "results" => %{
          "successful" => 8,
          "failed" => 2,
          "objects" => [
            %{"id" => "uuid-1", "status" => "SUCCESS"},
            %{"id" => "uuid-2", "status" => "SUCCESS"},
            %{"id" => "uuid-3", "status" => "FAILED", "errors" => [%{"message" => "Not found"}]}
          ]
        }
      }

      {:ok, result} = DeleteResult.from_api(response)

      assert result.matches == 10
      assert result.limit == 10_000
      assert result.successful == 8
      assert result.failed == 2
      assert result.dry_run == false
      assert length(result.objects) == 3
    end

    test "parses dry run response" do
      response = %{
        "match" => %{"matches" => 5, "limit" => 100},
        "dryRun" => true,
        "results" => %{
          "successful" => 0,
          "failed" => 0,
          "objects" => [
            %{"id" => "uuid-1", "status" => "DRYRUN"}
          ]
        }
      }

      {:ok, result} = DeleteResult.from_api(response)

      assert result.dry_run == true
      assert result.matches == 5
      assert hd(result.objects).status == :dry_run
    end

    test "handles minimal response" do
      response = %{
        "match" => %{},
        "results" => %{}
      }

      {:ok, result} = DeleteResult.from_api(response)

      assert result.matches == 0
      assert result.limit == 0
      assert result.successful == 0
      assert result.failed == 0
      assert result.objects == []
    end

    test "returns error for nil response" do
      assert {:error, :empty_response} = DeleteResult.from_api(nil)
    end

    test "returns error for invalid response" do
      assert {:error, :invalid_response} = DeleteResult.from_api("invalid")
    end
  end

  describe "all_successful?/1" do
    test "returns true when all matched objects were deleted" do
      result = %DeleteResult{
        matches: 10,
        successful: 10,
        failed: 0
      }

      assert DeleteResult.all_successful?(result) == true
    end

    test "returns false when some failed" do
      result = %DeleteResult{
        matches: 10,
        successful: 8,
        failed: 2
      }

      assert DeleteResult.all_successful?(result) == false
    end

    test "returns false when successful doesn't match matches" do
      result = %DeleteResult{
        matches: 10,
        successful: 5,
        failed: 0
      }

      assert DeleteResult.all_successful?(result) == false
    end
  end

  describe "has_failures?/1" do
    test "returns true when failures exist" do
      result = %DeleteResult{failed: 1}
      assert DeleteResult.has_failures?(result) == true
    end

    test "returns false when no failures" do
      result = %DeleteResult{failed: 0}
      assert DeleteResult.has_failures?(result) == false
    end
  end

  describe "failed_objects/1" do
    test "filters to only failed objects" do
      result = %DeleteResult{
        objects: [
          %DeletedObject{uuid: "1", status: :success},
          %DeletedObject{uuid: "2", status: :failed},
          %DeletedObject{uuid: "3", status: :success},
          %DeletedObject{uuid: "4", status: :failed}
        ]
      }

      failed = DeleteResult.failed_objects(result)

      assert length(failed) == 2
      assert Enum.all?(failed, &(&1.status == :failed))
    end
  end

  describe "successful_objects/1" do
    test "filters to only successful objects" do
      result = %DeleteResult{
        objects: [
          %DeletedObject{uuid: "1", status: :success},
          %DeletedObject{uuid: "2", status: :failed},
          %DeletedObject{uuid: "3", status: :success}
        ]
      }

      successful = DeleteResult.successful_objects(result)

      assert length(successful) == 2
      assert Enum.all?(successful, &(&1.status == :success))
    end
  end

  describe "summary/1" do
    test "returns SUCCESS for all successful" do
      result = %DeleteResult{matches: 10, successful: 10, failed: 0}
      assert DeleteResult.summary(result) =~ "SUCCESS"
      assert DeleteResult.summary(result) =~ "10/10 deleted"
    end

    test "returns PARTIAL for partial failures" do
      result = %DeleteResult{matches: 10, successful: 8, failed: 2}
      assert DeleteResult.summary(result) =~ "PARTIAL"
      assert DeleteResult.summary(result) =~ "8/10 deleted"
      assert DeleteResult.summary(result) =~ "2 failed"
    end

    test "returns DRY RUN for dry run mode" do
      result = %DeleteResult{matches: 10, successful: 0, failed: 0, dry_run: true}
      assert DeleteResult.summary(result) =~ "DRY RUN"
    end
  end

  describe "DeletedObject.from_api/1" do
    test "parses successful object" do
      obj = DeletedObject.from_api(%{"id" => "uuid-123", "status" => "SUCCESS"})

      assert obj.uuid == "uuid-123"
      assert obj.status == :success
      assert obj.errors == nil
    end

    test "parses failed object with errors" do
      obj =
        DeletedObject.from_api(%{
          "id" => "uuid-456",
          "status" => "FAILED",
          "errors" => [%{"message" => "Object not found"}]
        })

      assert obj.uuid == "uuid-456"
      assert obj.status == :failed
      assert obj.errors == [%{"message" => "Object not found"}]
    end

    test "parses dry run object" do
      obj = DeletedObject.from_api(%{"id" => "uuid-789", "status" => "DRYRUN"})

      assert obj.status == :dry_run
    end
  end

  describe "DeletedObject.success?/1" do
    test "returns true for success status" do
      obj = %DeletedObject{status: :success}
      assert DeletedObject.success?(obj) == true
    end

    test "returns false for failed status" do
      obj = %DeletedObject{status: :failed}
      assert DeletedObject.success?(obj) == false
    end
  end

  describe "DeletedObject.failed?/1" do
    test "returns true for failed status" do
      obj = %DeletedObject{status: :failed}
      assert DeletedObject.failed?(obj) == true
    end

    test "returns false for success status" do
      obj = %DeletedObject{status: :success}
      assert DeletedObject.failed?(obj) == false
    end
  end

  describe "DeletedObject.dry_run?/1" do
    test "returns true for dry_run status" do
      obj = %DeletedObject{status: :dry_run}
      assert DeletedObject.dry_run?(obj) == true
    end

    test "returns false for other statuses" do
      obj = %DeletedObject{status: :success}
      assert DeletedObject.dry_run?(obj) == false
    end
  end
end
