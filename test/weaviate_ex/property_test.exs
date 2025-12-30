defmodule WeaviateEx.PropertyTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Property

  describe "new/3" do
    test "creates basic property" do
      prop = Property.new("title", :text)

      assert prop["name"] == "title"
      assert prop["dataType"] == ["text"]
    end

    test "accepts description option" do
      prop = Property.new("title", :text, description: "Article title")

      assert prop["description"] == "Article title"
    end

    test "accepts indexing options" do
      prop =
        Property.new("title", :text,
          index_filterable: true,
          index_searchable: true,
          index_inverted: true
        )

      assert prop["indexFilterable"] == true
      assert prop["indexSearchable"] == true
      assert prop["indexInverted"] == true
    end

    test "accepts tokenization option" do
      prop = Property.new("title", :text, tokenization: :word)

      assert prop["tokenization"] == "word"
    end

    test "accepts string tokenization value" do
      prop = Property.new("title", :text, tokenization: "lowercase")

      assert prop["tokenization"] == "lowercase"
    end

    test "accepts skip_vectorization option" do
      prop = Property.new("title", :text, skip_vectorization: true)

      assert prop["moduleConfig"]["skip"] == true
    end

    test "accepts vectorize_property_name option" do
      prop = Property.new("title", :text, vectorize_property_name: false)

      assert prop["moduleConfig"]["vectorizePropertyName"] == false
    end
  end

  describe "convenience constructors" do
    test "text/2 creates text property" do
      prop = Property.text("title")

      assert prop["name"] == "title"
      assert prop["dataType"] == ["text"]
    end

    test "text_array/2 creates text array property" do
      prop = Property.text_array("tags")

      assert prop["dataType"] == ["text[]"]
    end

    test "int/2 creates int property" do
      prop = Property.int("count")

      assert prop["dataType"] == ["int"]
    end

    test "int_array/2 creates int array property" do
      prop = Property.int_array("counts")

      assert prop["dataType"] == ["int[]"]
    end

    test "number/2 creates number property" do
      prop = Property.number("price")

      assert prop["dataType"] == ["number"]
    end

    test "number_array/2 creates number array property" do
      prop = Property.number_array("prices")

      assert prop["dataType"] == ["number[]"]
    end

    test "boolean/2 creates boolean property" do
      prop = Property.boolean("active")

      assert prop["dataType"] == ["boolean"]
    end

    test "boolean_array/2 creates boolean array property" do
      prop = Property.boolean_array("flags")

      assert prop["dataType"] == ["boolean[]"]
    end

    test "date/2 creates date property" do
      prop = Property.date("created_at")

      assert prop["dataType"] == ["date"]
    end

    test "date_array/2 creates date array property" do
      prop = Property.date_array("timestamps")

      assert prop["dataType"] == ["date[]"]
    end

    test "uuid/2 creates uuid property" do
      prop = Property.uuid("external_id")

      assert prop["dataType"] == ["uuid"]
    end

    test "uuid_array/2 creates uuid array property" do
      prop = Property.uuid_array("external_ids")

      assert prop["dataType"] == ["uuid[]"]
    end

    test "blob/2 creates blob property without filterable" do
      prop = Property.blob("image")

      assert prop["dataType"] == ["blob"]
      assert prop["indexFilterable"] == false
    end

    test "geo_coordinates/2 creates geoCoordinates property" do
      prop = Property.geo_coordinates("location")

      assert prop["dataType"] == ["geoCoordinates"]
    end

    test "phone_number/2 creates phoneNumber property" do
      prop = Property.phone_number("contact")

      assert prop["dataType"] == ["phoneNumber"]
    end
  end

  describe "object/3" do
    test "creates nested object property" do
      prop =
        Property.object("author", [
          Property.text("name"),
          Property.text("email")
        ])

      assert prop["name"] == "author"
      assert prop["dataType"] == ["object"]
      assert length(prop["nestedProperties"]) == 2
    end

    test "supports deeply nested objects" do
      prop =
        Property.object("author", [
          Property.text("name"),
          Property.object("address", [
            Property.text("city"),
            Property.text("country")
          ])
        ])

      assert prop["nestedProperties"] |> Enum.at(1) |> Map.get("nestedProperties") |> length() ==
               2
    end
  end

  describe "object_array/3" do
    test "creates nested object array property" do
      prop =
        Property.object_array("authors", [
          Property.text("name"),
          Property.text("email")
        ])

      assert prop["dataType"] == ["object[]"]
      assert length(prop["nestedProperties"]) == 2
    end
  end

  describe "reference/3" do
    test "creates cross-reference property" do
      prop = Property.reference("hasAuthor", "Author")

      assert prop["name"] == "hasAuthor"
      assert prop["dataType"] == ["Author"]
    end

    test "accepts description option" do
      prop = Property.reference("hasAuthor", "Author", description: "Reference to author")

      assert prop["description"] == "Reference to author"
    end

    test "creates multi-target reference with list of collections" do
      prop = Property.reference("hasContent", ["Article", "BlogPost", "Video"])

      assert prop["name"] == "hasContent"
      assert prop["dataType"] == ["Article", "BlogPost", "Video"]
    end

    test "multi-target reference accepts description option" do
      prop =
        Property.reference("hasContent", ["Article", "BlogPost"],
          description: "Can be article or blog post"
        )

      assert prop["dataType"] == ["Article", "BlogPost"]
      assert prop["description"] == "Can be article or blog post"
    end
  end

  describe "multi_reference/3" do
    test "creates multi-target reference property" do
      prop = Property.multi_reference("hasContent", ["Article", "BlogPost"])

      assert prop["name"] == "hasContent"
      assert prop["dataType"] == ["Article", "BlogPost"]
    end

    test "accepts description option" do
      prop =
        Property.multi_reference("hasContent", ["Article", "Video"],
          description: "Content reference"
        )

      assert prop["description"] == "Content reference"
    end
  end

  describe "tokenization values" do
    test "word tokenization" do
      prop = Property.text("title", tokenization: :word)
      assert prop["tokenization"] == "word"
    end

    test "whitespace tokenization" do
      prop = Property.text("title", tokenization: :whitespace)
      assert prop["tokenization"] == "whitespace"
    end

    test "lowercase tokenization" do
      prop = Property.text("title", tokenization: :lowercase)
      assert prop["tokenization"] == "lowercase"
    end

    test "field tokenization" do
      prop = Property.text("title", tokenization: :field)
      assert prop["tokenization"] == "field"
    end

    test "trigram tokenization" do
      prop = Property.text("title", tokenization: :trigram)
      assert prop["tokenization"] == "trigram"
    end

    test "gse tokenization (Chinese)" do
      prop = Property.text("title", tokenization: :gse)
      assert prop["tokenization"] == "gse"
    end

    test "kagome_ja tokenization (Japanese)" do
      prop = Property.text("title", tokenization: :kagome_ja)
      assert prop["tokenization"] == "kagome_ja"
    end

    test "kagome_kr tokenization (Korean)" do
      prop = Property.text("title", tokenization: :kagome_kr)
      assert prop["tokenization"] == "kagome_kr"
    end
  end
end
