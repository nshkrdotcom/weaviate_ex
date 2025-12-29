defmodule WeaviateEx.IntegrationsTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Integrations

  describe "openai/1" do
    test "returns OpenAI API key header" do
      headers = Integrations.openai(api_key: "sk-test-key")

      assert headers == [{"X-OpenAI-Api-Key", "sk-test-key"}]
    end

    test "accepts organization option" do
      headers = Integrations.openai(api_key: "sk-test-key", organization: "org-123")

      assert {"X-OpenAI-Api-Key", "sk-test-key"} in headers
      assert {"X-OpenAI-Organization", "org-123"} in headers
    end
  end

  describe "cohere/1" do
    test "returns Cohere API key header" do
      headers = Integrations.cohere(api_key: "cohere-key")

      assert headers == [{"X-Cohere-Api-Key", "cohere-key"}]
    end
  end

  describe "huggingface/1" do
    test "returns HuggingFace API key header" do
      headers = Integrations.huggingface(api_key: "hf-key")

      assert headers == [{"X-HuggingFace-Api-Key", "hf-key"}]
    end
  end

  describe "voyageai/1" do
    test "returns VoyageAI API key header" do
      headers = Integrations.voyageai(api_key: "voyage-key")

      assert headers == [{"X-VoyageAI-Api-Key", "voyage-key"}]
    end
  end

  describe "jinaai/1" do
    test "returns JinaAI API key header" do
      headers = Integrations.jinaai(api_key: "jina-key")

      assert headers == [{"X-JinaAI-Api-Key", "jina-key"}]
    end
  end

  describe "mistral/1" do
    test "returns Mistral API key header" do
      headers = Integrations.mistral(api_key: "mistral-key")

      assert headers == [{"X-Mistral-Api-Key", "mistral-key"}]
    end
  end

  describe "anthropic/1" do
    test "returns Anthropic API key header" do
      headers = Integrations.anthropic(api_key: "anthropic-key")

      assert headers == [{"X-Anthropic-Api-Key", "anthropic-key"}]
    end
  end

  describe "google/1" do
    test "returns Google API key header" do
      headers = Integrations.google(api_key: "google-key")

      assert headers == [{"X-Google-Api-Key", "google-key"}]
    end

    test "accepts vertex option for Vertex AI" do
      headers = Integrations.google(api_key: "google-key", vertex: true)

      assert {"X-Google-Api-Key", "google-key"} in headers
      assert {"X-Google-Vertex", "true"} in headers
    end
  end

  describe "azure_openai/1" do
    test "returns Azure OpenAI API key header" do
      headers = Integrations.azure_openai(api_key: "azure-key")

      assert headers == [{"X-Azure-Api-Key", "azure-key"}]
    end
  end

  describe "aws/1" do
    test "returns AWS headers" do
      headers =
        Integrations.aws(
          access_key: "AKIA...",
          secret_key: "secret",
          session_token: "token"
        )

      assert {"X-AWS-Access-Key", "AKIA..."} in headers
      assert {"X-AWS-Secret-Key", "secret"} in headers
      assert {"X-AWS-Session-Token", "token"} in headers
    end

    test "session token is optional" do
      headers =
        Integrations.aws(
          access_key: "AKIA...",
          secret_key: "secret"
        )

      assert {"X-AWS-Access-Key", "AKIA..."} in headers
      assert {"X-AWS-Secret-Key", "secret"} in headers
      refute Enum.any?(headers, fn {k, _} -> k == "X-AWS-Session-Token" end)
    end
  end

  describe "merge/1" do
    test "merges multiple integration configs" do
      merged =
        Integrations.merge([
          Integrations.openai(api_key: "openai-key"),
          Integrations.cohere(api_key: "cohere-key")
        ])

      assert {"X-OpenAI-Api-Key", "openai-key"} in merged
      assert {"X-Cohere-Api-Key", "cohere-key"} in merged
    end

    test "handles empty list" do
      assert Integrations.merge([]) == []
    end

    test "flattens nested lists" do
      merged =
        Integrations.merge([
          Integrations.openai(api_key: "key1", organization: "org"),
          Integrations.cohere(api_key: "key2")
        ])

      assert length(merged) == 3
    end
  end
end
