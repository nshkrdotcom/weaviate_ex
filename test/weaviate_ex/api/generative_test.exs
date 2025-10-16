defmodule WeaviateEx.API.GenerativeTest do
  @moduledoc """
  Tests for generative search (RAG) operations (Phase 2.3).

  Following TDD approach - tests written first, then stub, then implementation.
  """

  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Generative
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "single_prompt/4" do
    test "generates single result with OpenAI", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/graphql"
        assert body["query"] =~ "Get"
        assert body["query"] =~ "Article"
        assert body["query"] =~ "generate"
        assert body["query"] =~ "singleResult"
        assert body["query"] =~ "Summarize these articles"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "title" => "AI Article",
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => "This is a generated summary of all articles about AI.",
                       "error" => nil
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, result} =
               Generative.single_prompt(
                 client,
                 "Article",
                 "Summarize these articles about {title}",
                 provider: :openai
               )

      assert result["singleResult"] =~ "generated summary"
      assert result["error"] == nil
    end

    test "generates with Anthropic provider", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "generate"
        assert body["query"] =~ "anthropic"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => "Claude generated this summary."
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, result} =
               Generative.single_prompt(client, "Article", "Summarize these",
                 provider: :anthropic,
                 model: "claude-3-5-sonnet-20241022"
               )

      assert result["singleResult"] =~ "Claude generated"
    end

    test "generates with Cohere provider", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "cohere"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => "Cohere summary."
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, result} =
               Generative.single_prompt(client, "Article", "Summarize", provider: :cohere)

      assert result["singleResult"] == "Cohere summary."
    end

    test "generates with near_text search", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "nearText"
        assert body["query"] =~ "artificial intelligence"
        assert body["query"] =~ "generate"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "title" => "AI Article",
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => "Summary of AI articles."
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, result} =
               Generative.single_prompt(client, "Article", "Summarize",
                 near_text: "artificial intelligence",
                 provider: :openai
               )

      assert result["singleResult"] =~ "AI articles"
    end

    test "handles generation error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => nil,
                       "error" => "API rate limit exceeded"
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, result} =
               Generative.single_prompt(client, "Article", "Summarize", provider: :openai)

      assert result["error"] == "API rate limit exceeded"
    end

    test "supports custom properties for interpolation", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        # Query should request title and content properties
        assert body["query"] =~ "title"
        assert body["query"] =~ "content"
        assert body["query"] =~ "Explain {title} and {content}"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "title" => "AI",
                   "content" => "About AI",
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => "Explanation"
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, result} =
               Generative.single_prompt(
                 client,
                 "Article",
                 "Explain {title} and {content}",
                 properties: ["title", "content"],
                 provider: :openai
               )

      assert result["singleResult"] == "Explanation"
    end
  end

  describe "grouped_task/4" do
    test "generates per-object results with grouped task", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "generate"
        assert body["query"] =~ "groupedResult"
        assert body["query"] =~ "Summarize: {title}"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "title" => "Article 1",
                   "_additional" => %{
                     "generate" => %{
                       "groupedResult" => "Summary of Article 1",
                       "error" => nil
                     }
                   }
                 },
                 %{
                   "title" => "Article 2",
                   "_additional" => %{
                     "generate" => %{
                       "groupedResult" => "Summary of Article 2",
                       "error" => nil
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Generative.grouped_task(client, "Article", "Summarize: {title}", provider: :openai)

      assert length(results) == 2
      assert Enum.at(results, 0)["_additional"]["generate"]["groupedResult"] =~ "Article 1"
      assert Enum.at(results, 1)["_additional"]["generate"]["groupedResult"] =~ "Article 2"
    end

    test "grouped task with filters", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "where"
        assert body["query"] =~ "status"
        assert body["query"] =~ "published"
        assert body["query"] =~ "groupedResult"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "title" => "Published Article",
                   "_additional" => %{
                     "generate" => %{
                       "groupedResult" => "Summary"
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      filter = %{
        path: ["status"],
        operator: "Equal",
        valueText: "published"
      }

      assert {:ok, results} =
               Generative.grouped_task(client, "Article", "Summarize",
                 where: filter,
                 provider: :openai
               )

      assert length(results) == 1
    end
  end

  describe "all AI providers" do
    test "supports all 13+ AI providers", %{client: client} do
      providers = [
        :openai,
        :anthropic,
        :cohere,
        :palm,
        :aws_bedrock,
        :azure_openai,
        :anyscale,
        :huggingface,
        :mistral,
        :ollama,
        :octoai,
        :together,
        :voyage
      ]

      for provider <- providers do
        Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
          assert body["query"] =~ "generate"

          {:ok,
           %{
             "data" => %{
               "Get" => %{
                 "Article" => [
                   %{
                     "_additional" => %{
                       "generate" => %{
                         "singleResult" => "Generated by #{provider}"
                       }
                     }
                   }
                 ]
               }
             }
           }}
        end)

        assert {:ok, result} =
                 Generative.single_prompt(client, "Article", "Test", provider: provider)

        assert result["singleResult"] =~ to_string(provider)
      end
    end
  end

  describe "runtime parameters" do
    test "supports temperature parameter", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "temperature"
        assert body["query"] =~ "0.7"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => "Result"
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, _result} =
               Generative.single_prompt(client, "Article", "Test",
                 provider: :openai,
                 temperature: 0.7
               )
    end

    test "supports max_tokens parameter", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "maxTokens" or body["query"] =~ "max_tokens"
        assert body["query"] =~ "500"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => "Result"
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, _result} =
               Generative.single_prompt(client, "Article", "Test",
                 provider: :openai,
                 max_tokens: 500
               )
    end

    test "supports top_p parameter", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "topP" or body["query"] =~ "top_p"
        assert body["query"] =~ "0.9"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "_additional" => %{
                     "generate" => %{
                       "singleResult" => "Result"
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, _result} =
               Generative.single_prompt(client, "Article", "Test",
                 provider: :openai,
                 top_p: 0.9
               )
    end
  end

  describe "with_generate/3" do
    test "adds generate clause to existing query", %{client: _client} do
      # This function modifies a query map to add generation
      query = %{
        collection: "Article",
        fields: ["title", "content"],
        limit: 5
      }

      modified_query = Generative.with_generate(query, "Summarize {title}", provider: :openai)

      assert modified_query.generate == %{
               type: :single,
               prompt: "Summarize {title}",
               provider: :openai
             }
    end
  end

  describe "error handling" do
    test "handles invalid provider", %{client: client} do
      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               Generative.single_prompt(client, "Article", "Test", provider: :invalid_provider)
    end

    test "handles missing prompt", %{client: client} do
      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               Generative.single_prompt(client, "Article", "", provider: :openai)
    end

    test "handles connection error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :connection_error}}
      end)

      assert {:error, %WeaviateEx.Error{type: :connection_error}} =
               Generative.single_prompt(client, "Article", "Test", provider: :openai)
    end
  end
end
