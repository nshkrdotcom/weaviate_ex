defmodule WeaviateEx.Generative.ResultTest do
  @moduledoc """
  Tests for typed generative result structures.
  """

  use ExUnit.Case, async: true

  alias WeaviateEx.Generative.Result

  describe "Single result" do
    test "creates single result" do
      result = %Result.Single{
        text: "This is generated text",
        metadata: %{tokens: 100, latency_ms: 150},
        debug: %{full_prompt: "System: You are...\nUser: Summarize..."}
      }

      assert result.text == "This is generated text"
      assert result.metadata[:tokens] == 100
      assert result.debug[:full_prompt] =~ "System:"
    end
  end

  describe "Grouped result" do
    test "creates grouped result" do
      result = %Result.Grouped{
        text: "Combined summary of all objects",
        metadata: %{tokens: 200}
      }

      assert result.text == "Combined summary of all objects"
      assert result.metadata[:tokens] == 200
    end
  end

  describe "GenerativeObject" do
    test "creates object with generative result" do
      obj = %Result.GenerativeObject{
        uuid: "test-uuid",
        properties: %{"title" => "Article Title"},
        collection: "Article",
        generative: %Result.Single{
          text: "Generated summary"
        }
      }

      assert obj.uuid == "test-uuid"
      assert obj.properties["title"] == "Article Title"
      assert obj.generative.text == "Generated summary"
    end
  end

  describe "GenerativeReturn" do
    test "creates return with objects and grouped result" do
      ret = %Result.GenerativeReturn{
        objects: [
          %Result.GenerativeObject{
            uuid: "uuid-1",
            properties: %{"title" => "Article 1"},
            collection: "Article"
          },
          %Result.GenerativeObject{
            uuid: "uuid-2",
            properties: %{"title" => "Article 2"},
            collection: "Article"
          }
        ],
        generative: %Result.Grouped{
          text: "Summary of all articles"
        }
      }

      assert length(ret.objects) == 2
      assert ret.generative.text == "Summary of all articles"
    end
  end

  describe "ResponseParser.parse/1" do
    test "parses single prompt response" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "singleResult" => "Generated text",
                    "error" => nil
                  }
                },
                "title" => "Test Article"
              }
            ]
          }
        }
      }

      result = Result.ResponseParser.parse(response, "Article")

      assert length(result.objects) == 1
      assert hd(result.objects).uuid == "uuid-1"
      assert hd(result.objects).generative.text == "Generated text"
    end

    test "parses grouped task response" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "groupedResult" => "Combined summary",
                    "error" => nil
                  }
                },
                "title" => "Article 1"
              },
              %{
                "_additional" => %{
                  "id" => "uuid-2",
                  "generate" => %{
                    "groupedResult" => "Combined summary",
                    "error" => nil
                  }
                },
                "title" => "Article 2"
              }
            ]
          }
        }
      }

      result = Result.ResponseParser.parse(response, "Article")

      assert length(result.objects) == 2
      assert result.generative.text == "Combined summary"
    end

    test "parses response with metadata" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "singleResult" => "Generated",
                    "metadata" => %{
                      "inputTokens" => 100,
                      "outputTokens" => 50,
                      "latencyMs" => 200
                    }
                  }
                },
                "title" => "Test"
              }
            ]
          }
        }
      }

      result = Result.ResponseParser.parse(response, "Article")

      assert hd(result.objects).generative.metadata["inputTokens"] == 100
      assert hd(result.objects).generative.metadata["outputTokens"] == 50
    end

    test "parses response with debug info" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "singleResult" => "Generated",
                    "debug" => %{
                      "fullPrompt" => "System: Be helpful\nUser: Summarize..."
                    }
                  }
                },
                "title" => "Test"
              }
            ]
          }
        }
      }

      result = Result.ResponseParser.parse(response, "Article")

      assert hd(result.objects).generative.debug[:full_prompt] =~ "System:"
    end

    test "handles error response" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => [
              %{
                "_additional" => %{
                  "id" => "uuid-1",
                  "generate" => %{
                    "singleResult" => nil,
                    "error" => "Rate limit exceeded"
                  }
                },
                "title" => "Test"
              }
            ]
          }
        }
      }

      result = Result.ResponseParser.parse(response, "Article")

      assert hd(result.objects).generative.error == "Rate limit exceeded"
    end

    test "handles empty response" do
      response = %{
        "data" => %{
          "Get" => %{
            "Article" => []
          }
        }
      }

      result = Result.ResponseParser.parse(response, "Article")

      assert result.objects == []
      assert result.generative == nil
    end
  end
end
