defmodule WeaviateEx.Query.GenerateTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.Generate
  alias WeaviateEx.Query.GenerativeResult

  describe "GenerativeResult struct" do
    test "creates empty result" do
      result = %GenerativeResult{
        objects: [],
        generated: nil,
        generated_per_object: []
      }

      assert result.objects == []
      assert result.generated == nil
      assert result.generated_per_object == []
    end

    test "creates result with generated text" do
      result = %GenerativeResult{
        objects: [%{uuid: "uuid-1", properties: %{title: "Test"}}],
        generated: "Summary of results",
        generated_per_object: ["Summary 1"]
      }

      assert result.generated == "Summary of results"
      assert length(result.objects) == 1
      assert length(result.generated_per_object) == 1
    end
  end

  describe "new/1" do
    test "creates a generate query builder" do
      builder = Generate.new("Article")

      assert builder.collection == "Article"
      assert builder.search_type == nil
      assert builder.single_prompt == nil
      assert builder.grouped_task == nil
    end
  end

  describe "near_text/3" do
    test "creates near_text generate query" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("machine learning")

      assert builder.search_type == :near_text
      assert builder.search_query == "machine learning"
    end

    test "near_text with certainty" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("AI", certainty: 0.8)

      assert builder.search_opts[:certainty] == 0.8
    end

    test "near_text with distance" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("AI", distance: 0.3)

      assert builder.search_opts[:distance] == 0.3
    end
  end

  describe "near_vector/3" do
    test "creates near_vector generate query" do
      vector = [0.1, 0.2, 0.3]

      builder =
        Generate.new("Article")
        |> Generate.near_vector(vector)

      assert builder.search_type == :near_vector
      assert builder.search_query == vector
    end

    test "near_vector with certainty" do
      vector = [0.1, 0.2, 0.3]

      builder =
        Generate.new("Article")
        |> Generate.near_vector(vector, certainty: 0.9)

      assert builder.search_opts[:certainty] == 0.9
    end
  end

  describe "near_object/3" do
    test "creates near_object generate query" do
      builder =
        Generate.new("Article")
        |> Generate.near_object("uuid-123")

      assert builder.search_type == :near_object
      assert builder.search_query == "uuid-123"
    end
  end

  describe "bm25/3" do
    test "creates bm25 generate query" do
      builder =
        Generate.new("Article")
        |> Generate.bm25("elixir programming")

      assert builder.search_type == :bm25
      assert builder.search_query == "elixir programming"
    end

    test "bm25 with properties" do
      builder =
        Generate.new("Article")
        |> Generate.bm25("elixir", properties: ["title", "content"])

      assert builder.search_opts[:properties] == ["title", "content"]
    end
  end

  describe "hybrid/3" do
    test "creates hybrid generate query" do
      builder =
        Generate.new("Article")
        |> Generate.hybrid("machine learning")

      assert builder.search_type == :hybrid
      assert builder.search_query == "machine learning"
    end

    test "hybrid with alpha" do
      builder =
        Generate.new("Article")
        |> Generate.hybrid("AI", alpha: 0.7)

      assert builder.search_opts[:alpha] == 0.7
    end

    test "hybrid with fusion type" do
      builder =
        Generate.new("Article")
        |> Generate.hybrid("AI", fusion_type: :relative_score)

      assert builder.search_opts[:fusion_type] == :relative_score
    end
  end

  describe "single_prompt/2" do
    test "sets single prompt" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.single_prompt("Summarize: {title}")

      assert builder.single_prompt == "Summarize: {title}"
    end

    test "single prompt with template variables" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.single_prompt("Write about {title} and {content}")

      assert builder.single_prompt =~ "{title}"
      assert builder.single_prompt =~ "{content}"
    end
  end

  describe "grouped_task/3" do
    test "sets grouped task" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.grouped_task("Summarize all articles")

      assert builder.grouped_task == "Summarize all articles"
    end

    test "grouped task with properties" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.grouped_task("Summarize", properties: ["title", "content"])

      assert builder.grouped_task == "Summarize"
      assert builder.grouped_properties == ["title", "content"]
    end
  end

  describe "limit/2" do
    test "sets result limit" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.limit(5)

      assert builder.limit == 5
    end
  end

  describe "offset/2" do
    test "sets result offset" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.offset(10)

      assert builder.offset == 10
    end
  end

  describe "return_properties/2" do
    test "sets properties to return" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.return_properties(["title", "content", "author"])

      assert builder.return_properties == ["title", "content", "author"]
    end
  end

  describe "where/2" do
    test "sets filter condition" do
      filter = %{
        path: ["status"],
        operator: "Equal",
        valueText: "published"
      }

      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.where(filter)

      assert builder.where == filter
    end
  end

  describe "tenant/2" do
    test "sets tenant" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.tenant("tenant-a")

      assert builder.tenant == "tenant-a"
    end
  end

  describe "to_graphql/1" do
    test "generates GraphQL for near_text with single_prompt" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("machine learning")
        |> Generate.single_prompt("Summarize: {title}")
        |> Generate.return_properties(["title", "content"])
        |> Generate.limit(5)

      graphql = Generate.to_graphql(builder)

      assert graphql =~ "Get"
      assert graphql =~ "Article"
      assert graphql =~ "nearText"
      assert graphql =~ "machine learning"
      assert graphql =~ "generate"
      assert graphql =~ "singleResult"
      assert graphql =~ "Summarize: {title}"
    end

    test "generates GraphQL for bm25 with grouped_task" do
      builder =
        Generate.new("Article")
        |> Generate.bm25("elixir")
        |> Generate.grouped_task("Write a summary", properties: ["title"])
        |> Generate.return_properties(["title"])
        |> Generate.limit(10)

      graphql = Generate.to_graphql(builder)

      assert graphql =~ "bm25"
      assert graphql =~ "elixir"
      assert graphql =~ "groupedResult"
      assert graphql =~ "Write a summary"
    end

    test "generates GraphQL with both single and grouped prompts" do
      builder =
        Generate.new("Article")
        |> Generate.hybrid("AI", alpha: 0.5)
        |> Generate.single_prompt("Explain: {title}")
        |> Generate.grouped_task("Overall summary")
        |> Generate.return_properties(["title"])

      graphql = Generate.to_graphql(builder)

      assert graphql =~ "hybrid"
      assert graphql =~ "singleResult"
      assert graphql =~ "groupedResult"
    end

    test "generates GraphQL with filter" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.single_prompt("Summarize: {title}")
        |> Generate.where(%{path: ["status"], operator: "Equal", valueText: "active"})

      graphql = Generate.to_graphql(builder)

      assert graphql =~ "where"
      assert graphql =~ "status"
    end

    test "generates GraphQL for near_vector" do
      builder =
        Generate.new("Article")
        |> Generate.near_vector([0.1, 0.2, 0.3])
        |> Generate.single_prompt("Describe: {content}")

      graphql = Generate.to_graphql(builder)

      assert graphql =~ "nearVector"
      assert graphql =~ "0.1"
      assert graphql =~ "0.2"
      assert graphql =~ "0.3"
    end
  end

  describe "parse_response/2" do
    test "parses response with single results" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "singleResult" => "Generated text 1"
                  }
                },
                "title" => "Title 1"
              },
              %{
                "_additional" => %{
                  "id" => "uuid-2",
                  "generate" => %{
                    "singleResult" => "Generated text 2"
                  }
                },
                "title" => "Title 2"
              }
            ]
          }
        }
      }

      result = Generate.parse_response(response, "Article")

      assert length(result.objects) == 2
      assert Enum.at(result.generated_per_object, 0) == "Generated text 1"
      assert Enum.at(result.generated_per_object, 1) == "Generated text 2"
    end

    test "parses response with grouped result" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "groupedResult" => "Summary of all articles"
                  }
                },
                "title" => "Title 1"
              }
            ]
          }
        }
      }

      result = Generate.parse_response(response, "Article")

      assert result.generated == "Summary of all articles"
    end

    test "parses response with both single and grouped results" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "singleResult" => "Single 1",
                    "groupedResult" => "Grouped summary"
                  }
                },
                "title" => "Title 1"
              }
            ]
          }
        }
      }

      result = Generate.parse_response(response, "Article")

      assert result.generated == "Grouped summary"
      assert Enum.at(result.generated_per_object, 0) == "Single 1"
    end

    test "parses empty response" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => []
          }
        }
      }

      result = Generate.parse_response(response, "Article")

      assert result.objects == []
      assert result.generated == nil
      assert result.generated_per_object == []
    end

    test "parses response with error" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "error" => "Rate limit exceeded"
                  }
                },
                "title" => "Title 1"
              }
            ]
          }
        }
      }

      result = Generate.parse_response(response, "Article")

      assert length(result.objects) == 1
      # Error is included in the object's metadata
    end
  end

  describe "valid?/1" do
    test "returns true for valid builder with search and prompt" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")
        |> Generate.single_prompt("Summarize")

      assert Generate.valid?(builder) == true
    end

    test "returns false without search type" do
      builder =
        Generate.new("Article")
        |> Generate.single_prompt("Summarize")

      assert Generate.valid?(builder) == false
    end

    test "returns false without prompt" do
      builder =
        Generate.new("Article")
        |> Generate.near_text("test")

      assert Generate.valid?(builder) == false
    end

    test "returns true with grouped_task only" do
      builder =
        Generate.new("Article")
        |> Generate.bm25("test")
        |> Generate.grouped_task("Summarize all")

      assert Generate.valid?(builder) == true
    end
  end
end
