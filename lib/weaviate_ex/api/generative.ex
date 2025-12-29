defmodule WeaviateEx.API.Generative do
  @moduledoc """
  Generative Search (RAG) operations for Phase 2.3.

  Provides AI-powered generation capabilities with 15+ provider integrations:
  - OpenAI (GPT-4, GPT-3.5, O1, O3 reasoning models, etc.)
  - Anthropic (Claude 3.5 Sonnet, etc.)
  - Cohere
  - Google PaLM / Vertex AI / Gemini
  - AWS Bedrock / SageMaker
  - Azure OpenAI
  - Anyscale
  - Hugging Face
  - Mistral
  - Ollama (local models)
  - OctoAI
  - Together AI
  - Voyage AI
  - XAI (Grok)
  - ContextualAI
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type collection_name :: String.t()
  @type prompt :: String.t()
  @type opts :: keyword()
  @type provider ::
          :openai
          | :anthropic
          | :cohere
          | :palm
          | :google_vertex
          | :google_gemini
          | :aws_bedrock
          | :aws_sagemaker
          | :azure_openai
          | :anyscale
          | :huggingface
          | :mistral
          | :ollama
          | :octoai
          | :together
          | :voyage
          | :xai
          | :contextualai

  @valid_providers [
    :openai,
    :anthropic,
    :cohere,
    :palm,
    :google_vertex,
    :google_gemini,
    :aws_bedrock,
    :aws_sagemaker,
    :azure_openai,
    :anyscale,
    :huggingface,
    :mistral,
    :ollama,
    :octoai,
    :together,
    :voyage,
    :xai,
    :contextualai
  ]

  ## Single Prompt Generation

  @doc """
  Generate a single result from all retrieved objects.

  The prompt can use property interpolation with {property_name} syntax.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `prompt` - Generation prompt with optional {property} interpolation
    * `opts` - Options:
      - `:provider` - AI provider (required)
      - `:model` - Model name (provider-specific)
      - `:properties` - Properties to retrieve for interpolation
      - `:near_text` - Semantic search query
      - `:where` - Filter conditions
      - `:limit` - Number of objects to retrieve
      - `:temperature` - Sampling temperature (0.0-1.0)
      - `:max_tokens` - Maximum tokens to generate
      - `:top_p` - Nucleus sampling parameter

  ## Examples

      # Basic generation with OpenAI
      {:ok, result} = Generative.single_prompt(client, "Article",
        "Summarize these articles about {title}",
        provider: :openai
      )

      # With Anthropic Claude
      {:ok, result} = Generative.single_prompt(client, "Article",
        "Explain {title} in simple terms",
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022",
        temperature: 0.7
      )

      # With semantic search
      {:ok, result} = Generative.single_prompt(client, "Article",
        "What are the main themes?",
        near_text: "artificial intelligence",
        provider: :openai,
        max_tokens: 500
      )

  ## Returns
    * `{:ok, map()}` - Generated result with "singleResult" and "error" keys
    * `{:error, Error.t()}` - Error if generation fails
  """
  @spec single_prompt(Client.t(), collection_name(), prompt(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def single_prompt(client, collection_name, prompt, opts \\ []) do
    # Validate inputs
    with :ok <- validate_provider(Keyword.get(opts, :provider)),
         :ok <- validate_prompt(prompt) do
      case execute_generate(client, collection_name, prompt, :single, opts) do
        {:ok, results} when is_list(results) ->
          # Extract the first result's generate field
          case List.first(results) do
            %{"_additional" => %{"generate" => generate}} -> {:ok, generate}
            _ -> {:ok, %{"singleResult" => nil, "error" => "No results"}}
          end

        error ->
          error
      end
    end
  end

  ## Grouped Task Generation

  @doc """
  Generate per-object results (grouped task).

  Each retrieved object gets its own generated result with property interpolation.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `prompt` - Generation prompt with optional {property} interpolation
    * `opts` - Options (same as single_prompt/4)

  ## Examples

      {:ok, results} = Generative.grouped_task(client, "Article",
        "Summarize: {title}",
        provider: :openai,
        limit: 10
      )

      # Each result has _additional.generate.groupedResult

  ## Returns
    * `{:ok, [map()]}` - List of objects with generated results
    * `{:error, Error.t()}` - Error if generation fails
  """
  @spec grouped_task(Client.t(), collection_name(), prompt(), opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def grouped_task(client, collection_name, prompt, opts \\ []) do
    # Validate inputs
    with :ok <- validate_provider(Keyword.get(opts, :provider)),
         :ok <- validate_prompt(prompt) do
      case execute_generate(client, collection_name, prompt, :grouped, opts) do
        {:ok, results} when is_list(results) -> {:ok, results}
        {:ok, result} -> {:ok, [result]}
        error -> error
      end
    end
  end

  ## Query Builder Integration

  @doc """
  Add generation clause to existing query map.

  This is a helper for query builder integration.

  ## Examples

      query = %{collection: "Article", fields: ["title"]}
      query = Generative.with_generate(query, "Summarize {title}", provider: :openai)

  ## Returns
    * `query` - Modified query map with generate clause
  """
  @spec with_generate(map(), prompt(), opts()) :: map()
  def with_generate(query, prompt, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)

    Map.put(query, :generate, %{
      type: :single,
      prompt: prompt,
      provider: provider
    })
  end

  ## Validation

  @doc """
  Check if provider is valid.

  ## Examples

      Generative.valid_provider?(:openai)  # => true
      Generative.valid_provider?(:invalid) # => false
  """
  @spec valid_provider?(atom()) :: boolean()
  def valid_provider?(provider), do: provider in @valid_providers

  @doc """
  List all supported providers.
  """
  @spec supported_providers() :: [provider()]
  def supported_providers, do: @valid_providers

  ## Private Implementation

  defp execute_generate(client, collection_name, prompt, type, opts) do
    # Extract properties from prompt for interpolation
    properties = extract_properties_from_prompt(prompt, Keyword.get(opts, :properties, []))

    # Build fields to retrieve
    fields = build_fields(properties, type)

    # Build search clause if present
    search_clause = build_search_clause(opts)

    # Build generate clause
    generate_clause = build_generate_clause(prompt, type, opts)

    # Build full GraphQL query
    query = """
    {
      Get {
        #{collection_name}#{search_clause} {
          #{Enum.join(fields, "\n          ")}
          _additional {
            generate#{generate_clause}
          }
        }
      }
    }
    """

    # Execute query
    case Client.request(client, :post, "/v1/graphql", %{"query" => query}, []) do
      {:ok, %{"data" => %{"Get" => get_results}}} ->
        results = Map.get(get_results, collection_name, [])
        {:ok, results}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = error ->
        error
    end
  end

  defp extract_properties_from_prompt(prompt, explicit_properties) do
    # Extract {property} patterns from prompt
    regex = ~r/\{(\w+)\}/
    extracted = Regex.scan(regex, prompt) |> Enum.map(fn [_, prop] -> prop end)

    # Combine with explicit properties and deduplicate
    (extracted ++ explicit_properties) |> Enum.map(&to_string/1) |> Enum.uniq()
  end

  defp build_fields(properties, _type) do
    if Enum.empty?(properties) do
      []
    else
      properties
    end
  end

  defp build_search_clause(opts) do
    cond do
      near_text = Keyword.get(opts, :near_text) ->
        limit = Keyword.get(opts, :limit, 10)
        "(\n      nearText: { concepts: [\"#{near_text}\"] }\n      limit: #{limit}\n    )"

      where = Keyword.get(opts, :where) ->
        filter_str = build_filter_string(where)
        limit = Keyword.get(opts, :limit, 10)
        "(\n      where: #{filter_str}\n      limit: #{limit}\n    )"

      limit = Keyword.get(opts, :limit) ->
        "(limit: #{limit})"

      true ->
        ""
    end
  end

  defp build_filter_string(%{path: path, operator: operator} = filter) do
    parts = [
      ~s(path: ["#{Enum.join(path, "\", \"")}"]),
      "operator: #{operator}"
    ]

    parts = maybe_add_filter_value(parts, filter, :valueText)
    parts = maybe_add_filter_value(parts, filter, :valueInt)

    "{ #{Enum.join(parts, ", ")} }"
  end

  defp maybe_add_filter_value(parts, filter, key) do
    case Map.get(filter, key) do
      nil -> parts
      value when is_binary(value) -> parts ++ [~s(#{key}: "#{value}")]
      value -> parts ++ ["#{key}: #{value}"]
    end
  end

  defp build_generate_clause(prompt, type, opts) do
    provider = Keyword.get(opts, :provider, :openai)
    result_field = if type == :single, do: "singleResult", else: "groupedResult"

    # Build provider-specific parameters
    params = build_provider_params(provider, opts)

    provider_str = provider_to_string(provider)

    params_str =
      if Enum.empty?(params), do: "", else: ", #{Enum.join(Enum.reverse(params), ", ")}"

    """
    (
            #{result_field}: {
              #{provider_str}: {
                prompt: \"\"\"#{prompt}\"\"\"#{params_str}
              }
            }
          ) {
            #{result_field}
            error
          }
    """
  end

  # Build parameters for different providers
  defp build_provider_params(:openai, opts) do
    params = build_common_params(opts)
    # OpenAI-specific: verbosity and reasoningEffort for O1/O3 models
    params = maybe_add_param(params, opts, :verbosity, "verbosity", &quote_string/1)
    maybe_add_param(params, opts, :reasoning_effort, "reasoningEffort", &quote_string/1)
  end

  defp build_provider_params(:contextualai, opts) do
    params = build_common_params(opts)
    params = maybe_add_param(params, opts, :system_prompt, "systemPrompt", &quote_string/1)
    params = maybe_add_param(params, opts, :avoid_commentary, "avoidCommentary", &to_string/1)
    maybe_add_param(params, opts, :max_new_tokens, "maxNewTokens", &to_string/1)
  end

  defp build_provider_params(:xai, opts) do
    # XAI supports topP in addition to common params
    build_common_params(opts)
  end

  defp build_provider_params(_provider, opts) do
    build_common_params(opts)
  end

  defp build_common_params(opts) do
    params = []
    params = maybe_add_param(params, opts, :model, "model", &quote_string/1)
    params = maybe_add_param(params, opts, :temperature, "temperature", &to_string/1)
    params = maybe_add_param(params, opts, :max_tokens, "maxTokens", &to_string/1)
    maybe_add_param(params, opts, :top_p, "topP", &to_string/1)
  end

  defp maybe_add_param(params, opts, key, graphql_key, formatter) do
    case Keyword.get(opts, key) do
      nil -> params
      value -> ["#{graphql_key}: #{formatter.(value)}" | params]
    end
  end

  defp quote_string(value), do: ~s("#{value}")

  defp provider_to_string(:openai), do: "openai"
  defp provider_to_string(:anthropic), do: "anthropic"
  defp provider_to_string(:cohere), do: "cohere"
  defp provider_to_string(:palm), do: "palm"
  defp provider_to_string(:google_vertex), do: "google"
  defp provider_to_string(:google_gemini), do: "google"
  defp provider_to_string(:aws_bedrock), do: "aws"
  defp provider_to_string(:aws_sagemaker), do: "aws"
  defp provider_to_string(:azure_openai), do: "azureOpenAI"
  defp provider_to_string(:anyscale), do: "anyscale"
  defp provider_to_string(:huggingface), do: "huggingface"
  defp provider_to_string(:mistral), do: "mistral"
  defp provider_to_string(:ollama), do: "ollama"
  defp provider_to_string(:octoai), do: "octoai"
  defp provider_to_string(:together), do: "together"
  defp provider_to_string(:voyage), do: "voyage"
  defp provider_to_string(:xai), do: "xai"
  defp provider_to_string(:contextualai), do: "contextualai"

  defp validate_provider(nil) do
    {:error, %Error{type: :validation_error, message: "Provider is required"}}
  end

  defp validate_provider(provider) do
    if provider in @valid_providers do
      :ok
    else
      {:error,
       %Error{
         type: :validation_error,
         message: "Invalid provider: #{provider}. Must be one of #{inspect(@valid_providers)}"
       }}
    end
  end

  defp validate_prompt("") do
    {:error, %Error{type: :validation_error, message: "Prompt cannot be empty"}}
  end

  defp validate_prompt(nil) do
    {:error, %Error{type: :validation_error, message: "Prompt is required"}}
  end

  defp validate_prompt(_prompt), do: :ok
end
