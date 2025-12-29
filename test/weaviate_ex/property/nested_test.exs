defmodule WeaviateEx.Property.NestedTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Property.Nested

  describe "new/1" do
    test "creates nested property with name and data_type" do
      nested = Nested.new(name: "author", data_type: :text)

      assert nested.name == "author"
      assert nested.data_type == :text
      assert nested.nested_properties == nil
    end

    test "creates nested property with all options" do
      nested =
        Nested.new(
          name: "metadata",
          data_type: :object,
          description: "Metadata object",
          indexable: true,
          tokenization: :word
        )

      assert nested.name == "metadata"
      assert nested.data_type == :object
      assert nested.description == "Metadata object"
      assert nested.indexable == true
      assert nested.tokenization == :word
    end

    test "creates nested property with recursive nested_properties" do
      inner = Nested.new(name: "city", data_type: :text)

      outer =
        Nested.new(
          name: "address",
          data_type: :object,
          nested_properties: [inner]
        )

      assert outer.name == "address"
      assert outer.data_type == :object
      assert length(outer.nested_properties) == 1
      assert hd(outer.nested_properties).name == "city"
    end

    test "raises when name is missing" do
      assert_raise KeyError, fn ->
        Nested.new(data_type: :text)
      end
    end

    test "raises when data_type is missing" do
      assert_raise KeyError, fn ->
        Nested.new(name: "test")
      end
    end
  end

  describe "to_api/1" do
    test "converts simple nested property to API format" do
      nested = Nested.new(name: "title", data_type: :text)
      api = Nested.to_api(nested)

      assert api["name"] == "title"
      assert api["dataType"] == ["text"]
    end

    test "converts nested property with description" do
      nested = Nested.new(name: "title", data_type: :text, description: "The title")
      api = Nested.to_api(nested)

      assert api["name"] == "title"
      assert api["description"] == "The title"
    end

    test "converts nested property with indexable settings" do
      nested =
        Nested.new(
          name: "content",
          data_type: :text,
          indexable: true,
          tokenization: :word
        )

      api = Nested.to_api(nested)

      assert api["indexFilterable"] == true
      assert api["indexSearchable"] == true
      assert api["tokenization"] == "word"
    end

    test "converts nested object with recursive nested_properties" do
      inner_city = Nested.new(name: "city", data_type: :text)
      inner_zip = Nested.new(name: "zip", data_type: :text)

      outer =
        Nested.new(
          name: "address",
          data_type: :object,
          nested_properties: [inner_city, inner_zip]
        )

      api = Nested.to_api(outer)

      assert api["name"] == "address"
      assert api["dataType"] == ["object"]
      assert length(api["nestedProperties"]) == 2

      [city_api, zip_api] = api["nestedProperties"]
      assert city_api["name"] == "city"
      assert zip_api["name"] == "zip"
    end

    test "converts deeply nested properties" do
      inner =
        Nested.new(
          name: "stats",
          data_type: :object,
          nested_properties: [
            Nested.new(name: "views", data_type: :int),
            Nested.new(name: "likes", data_type: :int)
          ]
        )

      outer =
        Nested.new(
          name: "metadata",
          data_type: :object,
          nested_properties: [
            Nested.new(name: "author", data_type: :text),
            inner
          ]
        )

      api = Nested.to_api(outer)

      assert api["name"] == "metadata"
      nested_props = api["nestedProperties"]
      assert length(nested_props) == 2

      stats_prop = Enum.find(nested_props, &(&1["name"] == "stats"))
      assert stats_prop["dataType"] == ["object"]
      assert length(stats_prop["nestedProperties"]) == 2
    end

    test "converts object_array type" do
      nested =
        Nested.new(
          name: "tags",
          data_type: :object_array,
          nested_properties: [
            Nested.new(name: "label", data_type: :text)
          ]
        )

      api = Nested.to_api(nested)

      assert api["dataType"] == ["object[]"]
    end
  end

  describe "from_api/1" do
    test "parses simple nested property from API response" do
      api = %{
        "name" => "title",
        "dataType" => ["text"]
      }

      nested = Nested.from_api(api)

      assert nested.name == "title"
      assert nested.data_type == :text
    end

    test "parses nested property with description" do
      api = %{
        "name" => "title",
        "dataType" => ["text"],
        "description" => "The title"
      }

      nested = Nested.from_api(api)

      assert nested.description == "The title"
    end

    test "parses nested property with indexable settings" do
      api = %{
        "name" => "content",
        "dataType" => ["text"],
        "indexFilterable" => true,
        "indexSearchable" => true,
        "tokenization" => "word"
      }

      nested = Nested.from_api(api)

      assert nested.indexable == true
      assert nested.tokenization == :word
    end

    test "parses nested object with recursive nestedProperties" do
      api = %{
        "name" => "address",
        "dataType" => ["object"],
        "nestedProperties" => [
          %{"name" => "city", "dataType" => ["text"]},
          %{"name" => "zip", "dataType" => ["text"]}
        ]
      }

      nested = Nested.from_api(api)

      assert nested.name == "address"
      assert nested.data_type == :object
      assert length(nested.nested_properties) == 2

      [city, zip] = nested.nested_properties
      assert city.name == "city"
      assert city.data_type == :text
      assert zip.name == "zip"
    end

    test "parses deeply nested properties" do
      api = %{
        "name" => "metadata",
        "dataType" => ["object"],
        "nestedProperties" => [
          %{"name" => "author", "dataType" => ["text"]},
          %{
            "name" => "stats",
            "dataType" => ["object"],
            "nestedProperties" => [
              %{"name" => "views", "dataType" => ["int"]},
              %{"name" => "likes", "dataType" => ["int"]}
            ]
          }
        ]
      }

      nested = Nested.from_api(api)

      assert nested.name == "metadata"
      stats = Enum.find(nested.nested_properties, &(&1.name == "stats"))
      assert stats.data_type == :object
      assert length(stats.nested_properties) == 2
    end

    test "parses object_array type" do
      api = %{
        "name" => "tags",
        "dataType" => ["object[]"],
        "nestedProperties" => [
          %{"name" => "label", "dataType" => ["text"]}
        ]
      }

      nested = Nested.from_api(api)

      assert nested.data_type == :object_array
    end
  end

  describe "valid?/1" do
    test "returns true for valid simple property" do
      nested = Nested.new(name: "title", data_type: :text)
      assert Nested.valid?(nested) == true
    end

    test "returns true for valid object with nested_properties" do
      nested =
        Nested.new(
          name: "address",
          data_type: :object,
          nested_properties: [
            Nested.new(name: "city", data_type: :text)
          ]
        )

      assert Nested.valid?(nested) == true
    end

    test "returns false for object without nested_properties" do
      nested = Nested.new(name: "address", data_type: :object)
      assert Nested.valid?(nested) == false
    end

    test "returns false for non-object with nested_properties" do
      # This should be invalid - only object types should have nested_properties
      nested = %Nested{
        name: "title",
        data_type: :text,
        nested_properties: [Nested.new(name: "sub", data_type: :text)]
      }

      assert Nested.valid?(nested) == false
    end

    test "returns true for empty nested_properties list for non-object type" do
      nested = Nested.new(name: "title", data_type: :text)
      assert Nested.valid?(nested) == true
    end
  end

  describe "object_type?/1" do
    test "returns true for object type" do
      nested = Nested.new(name: "data", data_type: :object)
      assert Nested.object_type?(nested) == true
    end

    test "returns true for object_array type" do
      nested = Nested.new(name: "items", data_type: :object_array)
      assert Nested.object_type?(nested) == true
    end

    test "returns false for non-object types" do
      nested = Nested.new(name: "title", data_type: :text)
      assert Nested.object_type?(nested) == false
    end
  end
end
