defmodule WeaviateEx.Integration.GenerativeTest do
  @moduledoc """
  Integration tests for gRPC generative search (RAG).

  These tests require a running Weaviate instance with a generative module configured.
  Run with: WEAVIATE_INTEGRATION=true mix test --include integration

  Note: Many generative tests require actual LLM API keys to be configured.
  Tests are marked with :generative_live if they require real API calls.
  """

  use ExUnit.Case, async: false

  alias Weaviate.V1.{GenerativeSearch, SearchRequest}
  alias WeaviateEx.{Batch, Collections}
  alias WeaviateEx.GRPC.Generative
  alias WeaviateEx.GRPC.Services.Search
  alias WeaviateEx.Query.GenerativeResult

  @moduletag :integration

  @test_collection "GenerativeIntegrationTest#{System.system_time(:millisecond)}"

  setup_all do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Create test collection with text properties
    {:ok, _} =
      Collections.create(@test_collection, %{
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]},
          %{name: "category", dataType: ["text"]}
        ],
        vectorizer: "none"
      })

    # Create test data with vectors
    objects =
      for i <- 1..5 do
        %{
          class: @test_collection,
          properties: %{
            title: "Article #{i}: Machine Learning Basics",
            content:
              "This article covers topic #{i} about machine learning and AI. " <>
                "It includes information about neural networks and deep learning.",
            category: "technology"
          },
          vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
        }
      end

    {:ok, _} = Batch.create_objects(objects)

    on_exit(fn ->
      Collections.delete(@test_collection)
    end)

    :ok
  end

  describe "gRPC Generative message building" do
    test "builds single prompt generative config" do
      config = %{single_prompt: "Summarize this article: {content}"}

      result = Generative.build(config)

      assert %GenerativeSearch{} = result
      assert result.single.prompt == "Summarize this article: {content}"
    end

    test "builds grouped task generative config" do
      config = %{
        grouped_task: "Synthesize the key themes from these articles",
        grouped_properties: ["title", "content"]
      }

      result = Generative.build(config)

      assert %GenerativeSearch{} = result
      assert result.grouped.task == "Synthesize the key themes from these articles"
      assert result.grouped.properties.values == ["title", "content"]
    end

    test "builds provider-specific generative config for OpenAI" do
      config = %{
        single_prompt: "Summarize: {content}",
        provider: :openai,
        model: "gpt-4",
        temperature: 0.7,
        max_tokens: 500
      }

      result = Generative.build_with_provider(config)

      assert %GenerativeSearch{} = result
      assert result.single.prompt == "Summarize: {content}"
      assert length(result.single.queries) == 1

      [provider] = result.single.queries
      assert {:openai, openai_config} = provider.kind
      assert openai_config.model == "gpt-4"
      assert openai_config.temperature == 0.7
      assert openai_config.max_tokens == 500
    end

    test "builds provider-specific generative config for Anthropic" do
      config = %{
        single_prompt: "Explain: {content}",
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 1000
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert {:anthropic, anthropic_config} = provider.kind
      assert anthropic_config.model == "claude-3-5-sonnet-20241022"
      assert anthropic_config.max_tokens == 1000
    end
  end

  describe "gRPC Search request with generative" do
    test "builds near_text request with single prompt generative" do
      request =
        Search.build_near_text_request(@test_collection, "machine learning",
          limit: 5,
          generative: %{
            single_prompt: "Summarize this article in one sentence"
          }
        )

      assert %SearchRequest{} = request
      assert request.collection == @test_collection
      assert request.near_text.query == ["machine learning"]
      assert %GenerativeSearch{} = request.generative
      assert request.generative.single.prompt == "Summarize this article in one sentence"
    end

    test "builds near_vector request with grouped task generative" do
      vector = Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)

      request =
        Search.build_near_vector_request(@test_collection, vector,
          limit: 10,
          generative: %{
            grouped_task: "What are the main themes across these articles?",
            grouped_properties: ["title", "content"]
          }
        )

      assert %SearchRequest{} = request
      assert %GenerativeSearch{} = request.generative
      assert request.generative.grouped.task == "What are the main themes across these articles?"
      assert request.generative.grouped.properties.values == ["title", "content"]
    end

    test "builds hybrid request with provider-specific generative" do
      request =
        Search.build_hybrid_request(@test_collection, "AI trends",
          alpha: 0.5,
          limit: 5,
          generative: %{
            single_prompt: "Extract key points from: {content}",
            provider: :openai,
            model: "gpt-4",
            temperature: 0.5
          }
        )

      assert %SearchRequest{} = request
      assert request.hybrid_search.query == "AI trends"
      assert %GenerativeSearch{} = request.generative
      assert length(request.generative.single.queries) == 1
    end

    test "builds bm25 request with generative" do
      request =
        Search.build_bm25_request(@test_collection, "neural networks",
          properties: ["title", "content"],
          limit: 3,
          generative: %{
            single_prompt: "What does this article teach about neural networks?"
          }
        )

      assert %SearchRequest{} = request
      assert request.bm25_search.query == "neural networks"
      assert %GenerativeSearch{} = request.generative
    end
  end

  describe "GenerativeResult parsing" do
    test "creates GenerativeResult from gRPC response with grouped result" do
      # Simulate a gRPC search reply with generative grouped result
      mock_reply = %{
        results: [
          %{
            properties: %{
              non_ref_props: %{
                fields: %{
                  "title" => %{kind: {:text_value, "Article 1"}}
                }
              }
            },
            metadata: %{
              id: "uuid-1",
              distance: 0.1,
              distance_present: true,
              certainty_present: false,
              score_present: false,
              vector_bytes: <<>>
            },
            generative: nil
          }
        ],
        generative_grouped_results: %Weaviate.V1.GenerativeResult{
          values: [
            %Weaviate.V1.GenerativeReply{
              result: "This is the grouped summary of all articles"
            }
          ]
        }
      }

      result = GenerativeResult.from_grpc_response(mock_reply)

      assert %GenerativeResult{} = result
      assert result.generated == "This is the grouped summary of all articles"
      assert length(result.objects) == 1
      assert GenerativeResult.has_grouped_result?(result)
    end

    test "creates GenerativeResult from gRPC response with single results" do
      # Simulate a gRPC search reply with per-object generative results
      mock_reply = %{
        results: [
          %{
            properties: %{
              non_ref_props: %{
                fields: %{
                  "title" => %{kind: {:text_value, "Article 1"}}
                }
              }
            },
            metadata: %{
              id: "uuid-1",
              distance: 0.1,
              distance_present: true,
              certainty_present: false,
              score_present: false,
              vector_bytes: <<>>
            },
            generative: %Weaviate.V1.GenerativeResult{
              values: [
                %Weaviate.V1.GenerativeReply{result: "Summary of article 1"}
              ]
            }
          },
          %{
            properties: %{
              non_ref_props: %{
                fields: %{
                  "title" => %{kind: {:text_value, "Article 2"}}
                }
              }
            },
            metadata: %{
              id: "uuid-2",
              distance: 0.2,
              distance_present: true,
              certainty_present: false,
              score_present: false,
              vector_bytes: <<>>
            },
            generative: %Weaviate.V1.GenerativeResult{
              values: [
                %Weaviate.V1.GenerativeReply{result: "Summary of article 2"}
              ]
            }
          }
        ],
        generative_grouped_results: nil
      }

      result = GenerativeResult.from_grpc_response(mock_reply)

      assert %GenerativeResult{} = result
      assert result.generated == nil
      assert length(result.generated_per_object) == 2
      assert Enum.member?(result.generated_per_object, "Summary of article 1")
      assert Enum.member?(result.generated_per_object, "Summary of article 2")
      assert GenerativeResult.has_single_results?(result)
    end

    test "creates empty GenerativeResult when no generative data" do
      mock_reply = %{
        results: [
          %{
            properties: nil,
            metadata: %{
              id: "uuid-1",
              distance_present: false,
              certainty_present: false,
              score_present: false,
              vector_bytes: <<>>
            },
            generative: nil
          }
        ],
        generative_grouped_results: nil
      }

      result = GenerativeResult.from_grpc_response(mock_reply)

      assert %GenerativeResult{} = result
      assert result.generated == nil
      assert result.generated_per_object == []
      refute GenerativeResult.has_grouped_result?(result)
      refute GenerativeResult.has_single_results?(result)
    end
  end

  describe "all provider configurations" do
    @providers [
      {:openai, %{model: "gpt-4", temperature: 0.7}},
      {:anthropic, %{model: "claude-3-5-sonnet-20241022", max_tokens: 1000}},
      {:cohere, %{model: "command-r-plus"}},
      {:mistral, %{model: "mistral-large"}},
      {:ollama, %{model: "llama2", api_endpoint: "http://localhost:11434"}},
      {:google, %{model: "gemini-pro", project_id: "test-project"}},
      {:aws, %{model: "anthropic.claude-v2", region: "us-east-1", service: "bedrock"}},
      {:databricks, %{model: "dbrx", endpoint: "https://example.com"}},
      {:friendliai, %{model: "llama-3", n: 1}},
      {:nvidia, %{model: "mixtral-8x7b"}},
      {:xai, %{model: "grok-2"}},
      {:contextualai, %{model: "rag", system_prompt: "Be helpful"}},
      {:anyscale, %{model: "meta-llama/Llama-2-70b"}}
    ]

    for {provider, config} <- @providers do
      test "builds #{provider} provider configuration" do
        full_config =
          Map.merge(
            %{single_prompt: "Test prompt", provider: unquote(provider)},
            unquote(Macro.escape(config))
          )

        result = Generative.build_with_provider(full_config)

        assert %GenerativeSearch{} = result
        assert result.single.prompt == "Test prompt"
        assert length(result.single.queries) == 1

        [provider_query] = result.single.queries
        assert {unquote(provider), _config} = provider_query.kind
      end
    end
  end
end
