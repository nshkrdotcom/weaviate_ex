defmodule WeaviateEx.Objects.PayloadTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Objects.Payload

  describe "prepare_for_insert/3" do
    test "includes properties in result" do
      data = %{properties: %{"title" => "Hello", "content" => "World"}}
      result = Payload.prepare_for_insert(data, "Article", [])
      assert result["properties"] == %{"title" => "Hello", "content" => "World"}
      assert result["class"] == "Article"
    end

    test "auto-generates UUID when not provided" do
      data = %{properties: %{"title" => "Hello"}}
      result = Payload.prepare_for_insert(data, "Article", [])
      assert is_binary(result["id"])
      assert String.length(result["id"]) == 36
    end

    test "uses provided UUID" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      data = %{id: uuid, properties: %{"title" => "Hello"}}
      result = Payload.prepare_for_insert(data, "Article", [])
      assert result["id"] == uuid
    end

    test "single vector still works" do
      data = %{properties: %{"title" => "Hello"}, vector: [0.1, 0.2, 0.3]}
      result = Payload.prepare_for_insert(data, "Article", [])
      assert result["vector"] == [0.1, 0.2, 0.3]
      refute Map.has_key?(result, "vectors")
    end
  end

  describe "prepare_for_insert/3 with named vectors" do
    test "includes vectors map when provided" do
      data = %{
        properties: %{"title" => "Hello"},
        vectors: %{"title_vector" => [0.1, 0.2, 0.3]}
      }

      result = Payload.prepare_for_insert(data, "Article", [])
      assert result["vectors"] == %{"title_vector" => [0.1, 0.2, 0.3]}
      refute Map.has_key?(result, "vector")
    end

    test "includes multiple named vectors" do
      data = %{
        properties: %{"title" => "Hello"},
        vectors: %{
          "title_vector" => [0.1, 0.2, 0.3],
          "content_vector" => [0.4, 0.5, 0.6]
        }
      }

      result = Payload.prepare_for_insert(data, "Article", [])
      assert result["vectors"]["title_vector"] == [0.1, 0.2, 0.3]
      assert result["vectors"]["content_vector"] == [0.4, 0.5, 0.6]
    end

    test "raises when both vector and vectors provided" do
      data = %{
        properties: %{},
        vector: [0.1, 0.2],
        vectors: %{"v" => [0.3, 0.4]}
      }

      assert_raise ArgumentError, ~r/cannot specify both 'vector' and 'vectors'/, fn ->
        Payload.prepare_for_insert(data, "Article", [])
      end
    end

    test "handles empty vectors map" do
      data = %{properties: %{"title" => "Hello"}, vectors: %{}}
      result = Payload.prepare_for_insert(data, "Article", [])
      refute Map.has_key?(result, "vector")
      refute Map.has_key?(result, "vectors")
    end
  end

  describe "prepare_for_update/4 with named vectors" do
    test "includes vectors map when provided" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      data = %{
        properties: %{"title" => "Updated"},
        vectors: %{"title_vector" => [0.1, 0.2, 0.3]}
      }

      result = Payload.prepare_for_update(data, "Article", uuid, [])
      assert result["id"] == uuid
      assert result["class"] == "Article"
      assert result["vectors"] == %{"title_vector" => [0.1, 0.2, 0.3]}
    end

    test "raises when both vector and vectors provided" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      data = %{
        properties: %{},
        vector: [0.1],
        vectors: %{"v" => [0.2]}
      }

      assert_raise ArgumentError, ~r/cannot specify both 'vector' and 'vectors'/, fn ->
        Payload.prepare_for_update(data, "Article", uuid, [])
      end
    end
  end

  describe "normalize_keys/1" do
    test "converts atom keys to strings" do
      data = %{properties: %{title: "Hello"}}
      result = Payload.normalize_keys(data)
      assert result["properties"]["title"] == "Hello"
    end

    test "handles nested maps" do
      data = %{properties: %{author: %{name: "John"}}}
      result = Payload.normalize_keys(data)
      assert result["properties"]["author"]["name"] == "John"
    end
  end

  describe "ensure_class/2" do
    test "sets class on payload" do
      data = %{"properties" => %{}}
      result = Payload.ensure_class(data, "Article")
      assert result["class"] == "Article"
    end

    test "replaces existing class" do
      data = %{"class" => "OldClass", "properties" => %{}}
      result = Payload.ensure_class(data, "NewClass")
      assert result["class"] == "NewClass"
      refute Map.has_key?(result, "OldClass")
    end
  end

  describe "prepare_for_insert/3 with references" do
    test "includes single reference" do
      data = %{
        properties: %{"title" => "Article"},
        references: %{"hasAuthor" => "author-uuid-123"}
      }

      result = Payload.prepare_for_insert(data, "Article", [])

      assert result["properties"]["hasAuthor"] == [
               %{"beacon" => "weaviate://localhost/author-uuid-123"}
             ]
    end

    test "includes multiple references for same property" do
      data = %{
        properties: %{"title" => "Article"},
        references: %{"hasAuthors" => ["uuid-1", "uuid-2"]}
      }

      result = Payload.prepare_for_insert(data, "Article", [])

      assert result["properties"]["hasAuthors"] == [
               %{"beacon" => "weaviate://localhost/uuid-1"},
               %{"beacon" => "weaviate://localhost/uuid-2"}
             ]
    end

    test "includes multi-target reference with target_collection" do
      data = %{
        properties: %{"title" => "Article"},
        references: %{
          "relatedTo" => %{target_collection: "Category", uuids: "cat-uuid"}
        }
      }

      result = Payload.prepare_for_insert(data, "Article", [])

      assert result["properties"]["relatedTo"] == [
               %{"beacon" => "weaviate://localhost/Category/cat-uuid"}
             ]
    end

    test "includes multi-target reference with multiple uuids" do
      data = %{
        properties: %{"title" => "Article"},
        references: %{
          "relatedTo" => %{target_collection: "Category", uuids: ["cat-1", "cat-2"]}
        }
      }

      result = Payload.prepare_for_insert(data, "Article", [])

      assert result["properties"]["relatedTo"] == [
               %{"beacon" => "weaviate://localhost/Category/cat-1"},
               %{"beacon" => "weaviate://localhost/Category/cat-2"}
             ]
    end

    test "merges references with existing properties" do
      data = %{
        properties: %{"title" => "My Article", "content" => "Some content"},
        references: %{"hasAuthor" => "author-uuid"}
      }

      result = Payload.prepare_for_insert(data, "Article", [])
      assert result["properties"]["title"] == "My Article"
      assert result["properties"]["content"] == "Some content"

      assert result["properties"]["hasAuthor"] == [
               %{"beacon" => "weaviate://localhost/author-uuid"}
             ]
    end

    test "handles multiple reference properties" do
      data = %{
        properties: %{"title" => "Article"},
        references: %{
          "hasAuthor" => "author-uuid",
          "hasCategory" => ["cat-1", "cat-2"]
        }
      }

      result = Payload.prepare_for_insert(data, "Article", [])

      assert result["properties"]["hasAuthor"] == [
               %{"beacon" => "weaviate://localhost/author-uuid"}
             ]

      assert result["properties"]["hasCategory"] == [
               %{"beacon" => "weaviate://localhost/cat-1"},
               %{"beacon" => "weaviate://localhost/cat-2"}
             ]
    end

    test "handles empty references map" do
      data = %{
        properties: %{"title" => "Article"},
        references: %{}
      }

      result = Payload.prepare_for_insert(data, "Article", [])
      assert result["properties"]["title"] == "Article"
      refute Map.has_key?(result["properties"], "references")
    end

    test "works without references key" do
      data = %{properties: %{"title" => "Article"}}

      result = Payload.prepare_for_insert(data, "Article", [])
      assert result["properties"]["title"] == "Article"
    end
  end

  describe "property value serialization" do
    alias WeaviateEx.Types.GeoCoordinate
    alias WeaviateEx.Types.PhoneNumber

    test "serializes DateTime to RFC3339 format" do
      dt = ~U[2024-12-29 15:30:00.123456Z]
      data = %{properties: %{"created_at" => dt}}

      result = Payload.prepare_for_insert(data, "Article", [])

      assert result["properties"]["created_at"] == "2024-12-29T15:30:00.123456Z"
    end

    test "serializes NaiveDateTime to RFC3339 format" do
      dt = ~N[2024-12-29 15:30:00.123456]
      data = %{properties: %{"created_at" => dt}}

      result = Payload.prepare_for_insert(data, "Article", [])

      # NaiveDateTime doesn't have timezone, so no Z suffix
      assert result["properties"]["created_at"] == "2024-12-29T15:30:00.123456"
    end

    test "serializes GeoCoordinate struct to map" do
      {:ok, geo} = GeoCoordinate.new(52.3676, 4.9041)
      data = %{properties: %{"location" => geo}}

      result = Payload.prepare_for_insert(data, "Place", [])

      assert result["properties"]["location"] == %{"latitude" => 52.3676, "longitude" => 4.9041}
    end

    test "serializes PhoneNumber struct to map" do
      phone = PhoneNumber.new("+1 650-253-0000")
      data = %{properties: %{"phone" => phone}}

      result = Payload.prepare_for_insert(data, "Contact", [])

      assert result["properties"]["phone"] == %{"input" => "+1 650-253-0000"}
    end

    test "serializes PhoneNumber with default country" do
      phone = PhoneNumber.new("650-253-0000", default_country: "US")
      data = %{properties: %{"phone" => phone}}

      result = Payload.prepare_for_insert(data, "Contact", [])

      assert result["properties"]["phone"] == %{
               "input" => "650-253-0000",
               "defaultCountry" => "US"
             }
    end

    test "serializes nested objects with special types" do
      {:ok, geo} = GeoCoordinate.new(40.7128, -74.0060)

      data = %{
        properties: %{
          "address" => %{
            "city" => "New York",
            "location" => geo
          }
        }
      }

      result = Payload.prepare_for_insert(data, "Place", [])

      assert result["properties"]["address"]["city"] == "New York"

      assert result["properties"]["address"]["location"] == %{
               "latitude" => 40.7128,
               "longitude" => -74.0060
             }
    end

    test "serializes arrays with special types" do
      dt1 = ~U[2024-01-01 00:00:00Z]
      dt2 = ~U[2024-12-31 23:59:59Z]

      data = %{
        properties: %{
          "dates" => [dt1, dt2]
        }
      }

      result = Payload.prepare_for_insert(data, "Event", [])

      assert result["properties"]["dates"] == [
               "2024-01-01T00:00:00Z",
               "2024-12-31T23:59:59Z"
             ]
    end

    test "passes through primitives unchanged" do
      data = %{
        properties: %{
          "title" => "Hello",
          "count" => 42,
          "score" => 3.14,
          "active" => true,
          "tags" => ["a", "b", "c"]
        }
      }

      result = Payload.prepare_for_insert(data, "Article", [])

      assert result["properties"]["title"] == "Hello"
      assert result["properties"]["count"] == 42
      assert result["properties"]["score"] == 3.14
      assert result["properties"]["active"] == true
      assert result["properties"]["tags"] == ["a", "b", "c"]
    end

    test "handles nil values" do
      data = %{properties: %{"optional" => nil}}

      result = Payload.prepare_for_insert(data, "Article", [])

      assert result["properties"]["optional"] == nil
    end
  end
end
