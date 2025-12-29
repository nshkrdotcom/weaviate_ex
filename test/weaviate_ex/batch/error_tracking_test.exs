defmodule WeaviateEx.Batch.ErrorTrackingTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.ErrorTracking.{ErrorObject, ErrorReference, Results}

  describe "ErrorObject" do
    test "creates error object with required fields" do
      error = %ErrorObject{
        message: "Invalid property",
        object: %{title: "Test"}
      }

      assert error.message == "Invalid property"
      assert error.object == %{title: "Test"}
      assert error.original_uuid == nil
      assert error.retry_count == nil
    end

    test "creates error object with all fields" do
      error = %ErrorObject{
        message: "Rate limit exceeded",
        object: %{title: "Test"},
        original_uuid: "uuid-123",
        retry_count: 2
      }

      assert error.original_uuid == "uuid-123"
      assert error.retry_count == 2
    end
  end

  describe "ErrorReference" do
    test "creates error reference with required fields" do
      error = %ErrorReference{
        message: "Reference not found",
        reference: %{from: "uuid1", to: "uuid2"}
      }

      assert error.message == "Reference not found"
      assert error.reference == %{from: "uuid1", to: "uuid2"}
    end
  end

  describe "Results" do
    test "creates empty results" do
      results = Results.new()

      assert results.failed_objects == []
      assert results.failed_references == []
      assert results.successful_uuids == %{}
      assert results.elapsed_seconds == 0.0
    end

    test "adds object error" do
      error = %ErrorObject{message: "Error", object: %{}}
      results = Results.new() |> Results.add_error(error)

      assert length(results.failed_objects) == 1
      assert hd(results.failed_objects) == error
    end

    test "adds reference error" do
      error = %ErrorReference{message: "Error", reference: %{}}
      results = Results.new() |> Results.add_error(error)

      assert length(results.failed_references) == 1
      assert hd(results.failed_references) == error
    end

    test "adds successful uuid" do
      results = Results.new() |> Results.add_success(0, "uuid-123")

      assert results.successful_uuids == %{0 => "uuid-123"}
    end

    test "tracks multiple successes" do
      results =
        Results.new()
        |> Results.add_success(0, "uuid-1")
        |> Results.add_success(1, "uuid-2")
        |> Results.add_success(2, "uuid-3")

      assert map_size(results.successful_uuids) == 3
    end

    test "has_errors? returns false for empty results" do
      results = Results.new()

      refute Results.has_errors?(results)
    end

    test "has_errors? returns true with object errors" do
      error = %ErrorObject{message: "Error", object: %{}}
      results = Results.new() |> Results.add_error(error)

      assert Results.has_errors?(results)
    end

    test "has_errors? returns true with reference errors" do
      error = %ErrorReference{message: "Error", reference: %{}}
      results = Results.new() |> Results.add_error(error)

      assert Results.has_errors?(results)
    end

    test "number_errors counts all errors" do
      obj_error = %ErrorObject{message: "Error", object: %{}}
      ref_error = %ErrorReference{message: "Error", reference: %{}}

      results =
        Results.new()
        |> Results.add_error(obj_error)
        |> Results.add_error(ref_error)

      assert Results.number_errors(results) == 2
    end
  end
end
