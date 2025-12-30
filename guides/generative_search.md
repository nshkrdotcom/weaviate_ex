# Generative Search (RAG) Guide

This guide covers Retrieval-Augmented Generation (RAG) with WeaviateEx. Generative search combines Weaviate's search capabilities with Large Language Models (LLMs) to generate context-aware responses.

## Overview

Weaviate's generative search:
1. Retrieves relevant objects using vector or keyword search
2. Passes the retrieved context to an LLM
3. Returns the generated response along with the source objects

WeaviateEx supports 20+ AI providers through the `WeaviateEx.API.Generative` module.
Generative queries execute via GraphQL even when a gRPC channel is available.

## Supported Providers

| Provider | Identifier | Models |
|----------|------------|--------|
| OpenAI | `:openai` | GPT-4o, GPT-4, GPT-3.5, O1, O3 |
| Anthropic | `:anthropic` | Claude 3.5 Sonnet, Claude 3 |
| Cohere | `:cohere` | Command, Command-R |
| Google | `:google_gemini`, `:google_vertex` | Gemini, PaLM |
| AWS | `:aws_bedrock`, `:aws_sagemaker` | Claude, Titan |
| Azure | `:azure_openai` | Azure-hosted OpenAI models |
| Mistral | `:mistral` | Mistral models |
| Ollama | `:ollama` | Local models |
| NVIDIA | `:nvidia` | NIM models |
| Databricks | `:databricks` | Databricks models |
| And more... | | |

## Configuration

### Enable Generative Module

Configure the generative module when creating a collection:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-openai",
  moduleConfig: %{
    "text2vec-openai" => %{model: "text-embedding-3-small"},
    # Enable generative module
    "generative-openai" => %{
      model: "gpt-4o-mini"
    }
  }
})
```

### API Keys

Provide API keys using the `WeaviateEx.Integrations` module:

```elixir
headers = WeaviateEx.Integrations.openai(api_key: "sk-...")

{:ok, client} = WeaviateEx.Client.new(
  base_url: WeaviateEx.base_url(),
  headers: headers
)
```

Or set via environment variable:
```bash
export OPENAI_API_KEY=sk-...
```

## Single Prompt Generation

Generate a single result combining all retrieved objects:

```elixir
alias WeaviateEx.API.Generative

{:ok, client} = WeaviateEx.Client.new(
  base_url: WeaviateEx.base_url(),
  headers: WeaviateEx.Integrations.openai(api_key: "sk-...")
)

# Basic single prompt
{:ok, result} = Generative.single_prompt(
  client,
  "Article",
  "Summarize the main themes from these articles: {title}",
  provider: :openai
)

IO.puts(result["singleResult"])
```

### With Semantic Search

Combine generative AI with semantic search:

```elixir
{:ok, result} = Generative.single_prompt(
  client,
  "Article",
  "Based on these articles about {title}, explain the key concepts.",
  provider: :openai,
  near_text: "machine learning",
  limit: 5
)

IO.puts(result["singleResult"])
```

### With Model Parameters

Customize the generation:

```elixir
{:ok, result} = Generative.single_prompt(
  client,
  "Article",
  "Write a professional summary of: {content}",
  provider: :openai,
  model: "gpt-4o",
  temperature: 0.3,       # Lower = more focused
  max_tokens: 500,        # Limit response length
  top_p: 0.9,            # Nucleus sampling
  limit: 3
)
```

## Grouped Task Generation

Generate per-object results (each object gets its own generation):

```elixir
{:ok, results} = Generative.grouped_task(
  client,
  "Article",
  "Generate a tweet-length summary for: {title}",
  provider: :openai,
  limit: 10
)

Enum.each(results, fn article ->
  IO.puts("Article: #{article["title"]}")
  IO.puts("Summary: #{article["_additional"]["generate"]["groupedResult"]}")
  IO.puts("---")
end)
```

## Property Interpolation

Use `{property_name}` syntax to include object properties in prompts:

```elixir
# Single property
{:ok, result} = Generative.single_prompt(
  client,
  "Article",
  "Explain {title} in simple terms.",
  provider: :openai
)

# Multiple properties
{:ok, result} = Generative.single_prompt(
  client,
  "Article",
  "The article '{title}' by {author} discusses: {content}. Provide key takeaways.",
  provider: :openai,
  limit: 1
)
```

## Provider-Specific Examples

### OpenAI

```elixir
headers = WeaviateEx.Integrations.openai(api_key: System.get_env("OPENAI_API_KEY"))
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url(), headers: headers)

# Standard GPT model
{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Analyze the following documents: {content}",
  provider: :openai,
  model: "gpt-4o-mini",
  temperature: 0.7
)

# O1/O3 reasoning models (with reasoning effort)
{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Solve this problem step by step: {content}",
  provider: :openai,
  model: "o1-mini",
  reasoning_effort: "medium"  # low, medium, high
)
```

### Anthropic (Claude)

```elixir
headers = WeaviateEx.Integrations.anthropic(api_key: System.get_env("ANTHROPIC_API_KEY"))
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url(), headers: headers)

{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Provide a detailed analysis of: {content}",
  provider: :anthropic,
  model: "claude-3-5-sonnet-20241022",
  temperature: 0.5,
  max_tokens: 1000
)
```

### Cohere

```elixir
headers = WeaviateEx.Integrations.cohere(api_key: System.get_env("COHERE_API_KEY"))
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url(), headers: headers)

{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Summarize: {content}",
  provider: :cohere,
  model: "command-r-plus"
)
```

### Ollama (Local Models)

```elixir
# No API key needed for local Ollama
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url())

{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Explain: {content}",
  provider: :ollama,
  model: "llama3.2"  # or any model you have installed
)
```

### Google Gemini

```elixir
headers = WeaviateEx.Integrations.google(api_key: System.get_env("GOOGLE_API_KEY"))
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url(), headers: headers)

{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Analyze: {content}",
  provider: :google_gemini,
  model: "gemini-1.5-pro"
)
```

### Databricks

```elixir
{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Summarize: {content}",
  provider: :databricks,
  model: "dbrx",
  log_probs: true,
  top_log_probs: 5,
  n: 2,
  frequency_penalty: 0.2,
  presence_penalty: 0.1,
  stop: ["END"]
)
```

### FriendliAI

```elixir
{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Summarize: {content}",
  provider: :friendliai,
  model: "llama-3.1-70b-instruct",
  n: 2
)
```

### AWS Bedrock

```elixir
headers = WeaviateEx.Integrations.aws(
  access_key: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_key: System.get_env("AWS_SECRET_ACCESS_KEY")
)
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url(), headers: headers)

{:ok, result} = Generative.single_prompt(
  client,
  "Document",
  "Summarize: {content}",
  provider: :aws_bedrock,
  model: "anthropic.claude-3-sonnet-20240229-v1:0"
)
```

## Filtering with Generative Search

Combine generation with filters:

```elixir
{:ok, result} = Generative.single_prompt(
  client,
  "Article",
  "What are the common themes in these technology articles? {title}: {content}",
  provider: :openai,
  where: %{
    path: ["category"],
    operator: "Equal",
    valueText: "Technology"
  },
  limit: 5
)
```

## Building Custom Queries

For more complex generative queries, use the Query module with raw GraphQL:

```elixir
query = """
{
  Get {
    Article(
      nearText: { concepts: ["machine learning"] }
      limit: 5
    ) {
      title
      content
      _additional {
        generate(
          singleResult: {
            prompt: "Summarize this article about {title}: {content}"
          }
        ) {
          singleResult
          error
        }
      }
    }
  }
}
"""

{:ok, response} = WeaviateEx.Client.request(client, :post, "/v1/graphql", %{query: query})
```

## Error Handling

```elixir
case Generative.single_prompt(client, "Article", "Summarize {content}", provider: :openai) do
  {:ok, %{"singleResult" => result, "error" => nil}} ->
    IO.puts("Generated: #{result}")

  {:ok, %{"error" => error}} when not is_nil(error) ->
    IO.puts("Generation error: #{error}")

  {:error, %WeaviateEx.Error{type: :validation_error, message: msg}} ->
    IO.puts("Validation error: #{msg}")

  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

## Complete RAG Example

Here's a complete RAG application example:

```elixir
defmodule KnowledgeBase do
  alias WeaviateEx.API.Generative

  @collection "KnowledgeArticle"

  def setup(client) do
    WeaviateEx.Collections.create(@collection, %{
      properties: [
        %{name: "title", dataType: ["text"]},
        %{name: "content", dataType: ["text"]},
        %{name: "category", dataType: ["text"]}
      ],
      vectorizer: "text2vec-openai",
      moduleConfig: %{
        "text2vec-openai" => %{model: "text-embedding-3-small"},
        "generative-openai" => %{model: "gpt-4o-mini"}
      }
    })
  end

  def add_article(title, content, category) do
    WeaviateEx.Objects.create(@collection, %{
      properties: %{
        title: title,
        content: content,
        category: category
      }
    })
  end

  def ask(client, question, opts \\ []) do
    category = Keyword.get(opts, :category)
    limit = Keyword.get(opts, :limit, 5)

    prompt = """
    Based on the following knowledge base articles, answer the question.

    Articles:
    {title}: {content}

    Question: #{question}

    Answer:
    """

    Generative.single_prompt(
      client,
      @collection,
      prompt,
      [
        provider: :openai,
        model: "gpt-4o-mini",
        near_text: question,
        limit: limit,
        temperature: 0.3
      ] ++ build_filter(category)
    )
  end

  def summarize_category(client, category) do
    Generative.single_prompt(
      client,
      @collection,
      "Provide a comprehensive summary of all articles about {title} in this category.",
      provider: :openai,
      where: %{path: ["category"], operator: "Equal", valueText: category},
      limit: 10
    )
  end

  defp build_filter(nil), do: []
  defp build_filter(category) do
    [where: %{path: ["category"], operator: "Equal", valueText: category}]
  end
end

# Usage
headers = WeaviateEx.Integrations.openai(api_key: System.get_env("OPENAI_API_KEY"))
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url(), headers: headers)

# Setup
KnowledgeBase.setup(client)

# Add articles
KnowledgeBase.add_article(
  "Introduction to Elixir",
  "Elixir is a dynamic, functional language designed for building scalable applications...",
  "Programming"
)

KnowledgeBase.add_article(
  "OTP Basics",
  "OTP (Open Telecom Platform) provides a set of libraries and design principles...",
  "Programming"
)

# Ask a question
{:ok, result} = KnowledgeBase.ask(client, "What is Elixir used for?")
IO.puts(result["singleResult"])

# Get category summary
{:ok, summary} = KnowledgeBase.summarize_category(client, "Programming")
IO.puts(summary["singleResult"])
```

## Best Practices

1. **Limit retrieved objects** - More objects = more tokens = higher cost and latency
2. **Use specific prompts** - Clear instructions produce better results
3. **Temperature tuning** - Lower for factual, higher for creative
4. **Error handling** - Always handle potential generation errors
5. **Caching** - Consider caching generated responses for repeated queries

## Next Steps

- [Queries Guide](queries.md) - Learn about search methods
- [Collections Guide](collections.md) - Configure generative modules
- [Vectorizers Guide](vectorizers.md) - Configure text vectorization
