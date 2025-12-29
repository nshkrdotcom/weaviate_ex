defmodule WeaviateEx.Debug.ObjectCompareTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Debug.ObjectCompare

  describe "compare/2" do
    test "returns match when objects are identical" do
      rest_object = %{
        "id" => "test-uuid",
        "properties" => %{"title" => "Test", "count" => 42}
      }

      grpc_object = %{
        "id" => "test-uuid",
        "properties" => %{"title" => "Test", "count" => 42}
      }

      result = ObjectCompare.compare(rest_object, grpc_object)

      assert result.match == true
      assert result.differences == []
      assert result.rest_object == rest_object
      assert result.grpc_object == grpc_object
    end

    test "detects top-level differences" do
      rest_object = %{"id" => "uuid-1", "class" => "Article"}
      grpc_object = %{"id" => "uuid-2", "class" => "Article"}

      result = ObjectCompare.compare(rest_object, grpc_object)

      assert result.match == false
      assert length(result.differences) == 1

      [diff] = result.differences
      assert diff.path == ["id"]
      assert diff.rest_value == "uuid-1"
      assert diff.grpc_value == "uuid-2"
    end

    test "detects nested differences" do
      rest_object = %{
        "id" => "uuid-1",
        "properties" => %{"title" => "REST Title", "count" => 10}
      }

      grpc_object = %{
        "id" => "uuid-1",
        "properties" => %{"title" => "gRPC Title", "count" => 10}
      }

      result = ObjectCompare.compare(rest_object, grpc_object)

      assert result.match == false
      assert length(result.differences) == 1

      [diff] = result.differences
      assert diff.path == ["properties", "title"]
      assert diff.rest_value == "REST Title"
      assert diff.grpc_value == "gRPC Title"
    end

    test "detects multiple differences" do
      rest_object = %{
        "id" => "uuid-1",
        "properties" => %{"title" => "REST", "count" => 10}
      }

      grpc_object = %{
        "id" => "uuid-2",
        "properties" => %{"title" => "gRPC", "count" => 20}
      }

      result = ObjectCompare.compare(rest_object, grpc_object)

      assert result.match == false
      assert length(result.differences) >= 2
    end

    test "detects missing keys" do
      rest_object = %{"id" => "uuid-1", "extra_field" => "value"}
      grpc_object = %{"id" => "uuid-1"}

      result = ObjectCompare.compare(rest_object, grpc_object)

      assert result.match == false

      missing_diff = Enum.find(result.differences, fn d -> d.path == ["extra_field"] end)
      assert missing_diff != nil
      assert missing_diff.rest_value == "value"
      assert missing_diff.grpc_value == :missing
    end

    test "detects deeply nested differences" do
      rest_object = %{
        "properties" => %{
          "nested" => %{
            "deep" => %{"value" => 1}
          }
        }
      }

      grpc_object = %{
        "properties" => %{
          "nested" => %{
            "deep" => %{"value" => 2}
          }
        }
      }

      result = ObjectCompare.compare(rest_object, grpc_object)

      assert result.match == false
      assert length(result.differences) == 1

      [diff] = result.differences
      assert diff.path == ["properties", "nested", "deep", "value"]
    end

    test "handles list comparison" do
      rest_object = %{"vector" => [0.1, 0.2, 0.3]}
      grpc_object = %{"vector" => [0.1, 0.2, 0.3]}

      result = ObjectCompare.compare(rest_object, grpc_object)

      assert result.match == true
    end

    test "detects list differences" do
      rest_object = %{"vector" => [0.1, 0.2, 0.3]}
      grpc_object = %{"vector" => [0.1, 0.2, 0.4]}

      result = ObjectCompare.compare(rest_object, grpc_object)

      assert result.match == false
    end
  end

  describe "diff/2" do
    test "returns empty list for identical objects" do
      obj = %{"key" => "value"}
      assert ObjectCompare.diff(obj, obj) == []
    end

    test "returns differences between objects" do
      rest = %{"a" => 1}
      grpc = %{"a" => 2}

      diffs = ObjectCompare.diff(rest, grpc)

      assert length(diffs) == 1
      assert hd(diffs).path == ["a"]
    end
  end

  describe "format_diff/1" do
    test "formats differences as readable string" do
      diffs = [
        %{path: ["properties", "title"], rest_value: "REST", grpc_value: "gRPC"},
        %{path: ["id"], rest_value: "uuid-1", grpc_value: "uuid-2"}
      ]

      formatted = ObjectCompare.format_diff(diffs)

      assert is_binary(formatted)
      assert formatted =~ "properties.title"
      assert formatted =~ "REST"
      assert formatted =~ "gRPC"
      assert formatted =~ "id"
    end

    test "returns message for no differences" do
      formatted = ObjectCompare.format_diff([])

      assert formatted =~ "No differences"
    end

    test "handles missing values" do
      diffs = [
        %{path: ["extra"], rest_value: "value", grpc_value: :missing}
      ]

      formatted = ObjectCompare.format_diff(diffs)

      assert formatted =~ "extra"
      assert formatted =~ "(missing)"
    end
  end
end
