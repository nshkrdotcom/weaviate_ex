defmodule Weaviate.V1.GenerativeOpenAI.ReasoningEffort do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:REASONING_EFFORT_UNSPECIFIED, 0)
  field(:REASONING_EFFORT_MINIMAL, 1)
  field(:REASONING_EFFORT_LOW, 2)
  field(:REASONING_EFFORT_MEDIUM, 3)
  field(:REASONING_EFFORT_HIGH, 4)
end

defmodule Weaviate.V1.GenerativeOpenAI.Verbosity do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:VERBOSITY_UNSPECIFIED, 0)
  field(:VERBOSITY_LOW, 1)
  field(:VERBOSITY_MEDIUM, 2)
  field(:VERBOSITY_HIGH, 3)
end

defmodule Weaviate.V1.GenerativeSearch.Single do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prompt, 1, type: :string)
  field(:debug, 2, type: :bool)
  field(:queries, 3, repeated: true, type: Weaviate.V1.GenerativeProvider)
end

defmodule Weaviate.V1.GenerativeSearch.Grouped do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:task, 1, type: :string)
  field(:properties, 2, proto3_optional: true, type: Weaviate.V1.TextArray)
  field(:queries, 3, repeated: true, type: Weaviate.V1.GenerativeProvider)
  field(:debug, 4, type: :bool)
end

defmodule Weaviate.V1.GenerativeSearch do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:single_response_prompt, 1,
    type: :string,
    json_name: "singleResponsePrompt",
    deprecated: true
  )

  field(:grouped_response_task, 2,
    type: :string,
    json_name: "groupedResponseTask",
    deprecated: true
  )

  field(:grouped_properties, 3,
    repeated: true,
    type: :string,
    json_name: "groupedProperties",
    deprecated: true
  )

  field(:single, 4, type: Weaviate.V1.GenerativeSearch.Single)
  field(:grouped, 5, type: Weaviate.V1.GenerativeSearch.Grouped)
end

defmodule Weaviate.V1.GenerativeProvider do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:kind, 0)

  field(:return_metadata, 1, type: :bool, json_name: "returnMetadata")
  field(:anthropic, 2, type: Weaviate.V1.GenerativeAnthropic, oneof: 0)
  field(:anyscale, 3, type: Weaviate.V1.GenerativeAnyscale, oneof: 0)
  field(:aws, 4, type: Weaviate.V1.GenerativeAWS, oneof: 0)
  field(:cohere, 5, type: Weaviate.V1.GenerativeCohere, oneof: 0)
  field(:dummy, 6, type: Weaviate.V1.GenerativeDummy, oneof: 0)
  field(:mistral, 7, type: Weaviate.V1.GenerativeMistral, oneof: 0)
  field(:ollama, 8, type: Weaviate.V1.GenerativeOllama, oneof: 0)
  field(:openai, 9, type: Weaviate.V1.GenerativeOpenAI, oneof: 0)
  field(:google, 10, type: Weaviate.V1.GenerativeGoogle, oneof: 0)
  field(:databricks, 11, type: Weaviate.V1.GenerativeDatabricks, oneof: 0)
  field(:friendliai, 12, type: Weaviate.V1.GenerativeFriendliAI, oneof: 0)
  field(:nvidia, 13, type: Weaviate.V1.GenerativeNvidia, oneof: 0)
  field(:xai, 14, type: Weaviate.V1.GenerativeXAI, oneof: 0)
  field(:contextualai, 15, type: Weaviate.V1.GenerativeContextualAI, oneof: 0)
end

defmodule Weaviate.V1.GenerativeAnthropic do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:base_url, 1, proto3_optional: true, type: :string, json_name: "baseUrl")
  field(:max_tokens, 2, proto3_optional: true, type: :int64, json_name: "maxTokens")
  field(:model, 3, proto3_optional: true, type: :string)
  field(:temperature, 4, proto3_optional: true, type: :double)
  field(:top_k, 5, proto3_optional: true, type: :int64, json_name: "topK")
  field(:top_p, 6, proto3_optional: true, type: :double, json_name: "topP")

  field(:stop_sequences, 7,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "stopSequences"
  )

  field(:images, 8, proto3_optional: true, type: Weaviate.V1.TextArray)

  field(:image_properties, 9,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "imageProperties"
  )
end

defmodule Weaviate.V1.GenerativeAnyscale do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:base_url, 1, proto3_optional: true, type: :string, json_name: "baseUrl")
  field(:model, 2, proto3_optional: true, type: :string)
  field(:temperature, 3, proto3_optional: true, type: :double)
end

defmodule Weaviate.V1.GenerativeAWS do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:model, 3, proto3_optional: true, type: :string)
  field(:temperature, 8, proto3_optional: true, type: :double)
  field(:service, 9, proto3_optional: true, type: :string)
  field(:region, 10, proto3_optional: true, type: :string)
  field(:endpoint, 11, proto3_optional: true, type: :string)
  field(:target_model, 12, proto3_optional: true, type: :string, json_name: "targetModel")
  field(:target_variant, 13, proto3_optional: true, type: :string, json_name: "targetVariant")
  field(:images, 14, proto3_optional: true, type: Weaviate.V1.TextArray)

  field(:image_properties, 15,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "imageProperties"
  )

  field(:max_tokens, 16, proto3_optional: true, type: :int64, json_name: "maxTokens")

  field(:stop_sequences, 17,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "stopSequences"
  )
end

defmodule Weaviate.V1.GenerativeCohere do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:base_url, 1, proto3_optional: true, type: :string, json_name: "baseUrl")

  field(:frequency_penalty, 2,
    proto3_optional: true,
    type: :double,
    json_name: "frequencyPenalty"
  )

  field(:max_tokens, 3, proto3_optional: true, type: :int64, json_name: "maxTokens")
  field(:model, 4, proto3_optional: true, type: :string)
  field(:k, 5, proto3_optional: true, type: :int64)
  field(:p, 6, proto3_optional: true, type: :double)
  field(:presence_penalty, 7, proto3_optional: true, type: :double, json_name: "presencePenalty")

  field(:stop_sequences, 8,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "stopSequences"
  )

  field(:temperature, 9, proto3_optional: true, type: :double)
  field(:images, 10, proto3_optional: true, type: Weaviate.V1.TextArray)

  field(:image_properties, 11,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "imageProperties"
  )
end

defmodule Weaviate.V1.GenerativeDummy do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.GenerativeMistral do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:base_url, 1, proto3_optional: true, type: :string, json_name: "baseUrl")
  field(:max_tokens, 2, proto3_optional: true, type: :int64, json_name: "maxTokens")
  field(:model, 3, proto3_optional: true, type: :string)
  field(:temperature, 4, proto3_optional: true, type: :double)
  field(:top_p, 5, proto3_optional: true, type: :double, json_name: "topP")
end

defmodule Weaviate.V1.GenerativeOllama do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:api_endpoint, 1, proto3_optional: true, type: :string, json_name: "apiEndpoint")
  field(:model, 2, proto3_optional: true, type: :string)
  field(:temperature, 3, proto3_optional: true, type: :double)
  field(:images, 4, proto3_optional: true, type: Weaviate.V1.TextArray)

  field(:image_properties, 5,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "imageProperties"
  )
end

defmodule Weaviate.V1.GenerativeOpenAI do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:frequency_penalty, 1,
    proto3_optional: true,
    type: :double,
    json_name: "frequencyPenalty"
  )

  field(:max_tokens, 2, proto3_optional: true, type: :int64, json_name: "maxTokens")
  field(:model, 3, proto3_optional: true, type: :string)
  field(:n, 4, proto3_optional: true, type: :int64)
  field(:presence_penalty, 5, proto3_optional: true, type: :double, json_name: "presencePenalty")
  field(:stop, 6, proto3_optional: true, type: Weaviate.V1.TextArray)
  field(:temperature, 7, proto3_optional: true, type: :double)
  field(:top_p, 8, proto3_optional: true, type: :double, json_name: "topP")
  field(:base_url, 9, proto3_optional: true, type: :string, json_name: "baseUrl")
  field(:api_version, 10, proto3_optional: true, type: :string, json_name: "apiVersion")
  field(:resource_name, 11, proto3_optional: true, type: :string, json_name: "resourceName")
  field(:deployment_id, 12, proto3_optional: true, type: :string, json_name: "deploymentId")
  field(:is_azure, 13, proto3_optional: true, type: :bool, json_name: "isAzure")
  field(:images, 14, proto3_optional: true, type: Weaviate.V1.TextArray)

  field(:image_properties, 15,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "imageProperties"
  )

  field(:reasoning_effort, 16,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeOpenAI.ReasoningEffort,
    json_name: "reasoningEffort",
    enum: true
  )

  field(:verbosity, 17,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeOpenAI.Verbosity,
    enum: true
  )
end

defmodule Weaviate.V1.GenerativeGoogle do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:frequency_penalty, 1,
    proto3_optional: true,
    type: :double,
    json_name: "frequencyPenalty"
  )

  field(:max_tokens, 2, proto3_optional: true, type: :int64, json_name: "maxTokens")
  field(:model, 3, proto3_optional: true, type: :string)
  field(:presence_penalty, 4, proto3_optional: true, type: :double, json_name: "presencePenalty")
  field(:temperature, 5, proto3_optional: true, type: :double)
  field(:top_k, 6, proto3_optional: true, type: :int64, json_name: "topK")
  field(:top_p, 7, proto3_optional: true, type: :double, json_name: "topP")

  field(:stop_sequences, 8,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "stopSequences"
  )

  field(:api_endpoint, 9, proto3_optional: true, type: :string, json_name: "apiEndpoint")
  field(:project_id, 10, proto3_optional: true, type: :string, json_name: "projectId")
  field(:endpoint_id, 11, proto3_optional: true, type: :string, json_name: "endpointId")
  field(:region, 12, proto3_optional: true, type: :string)
  field(:images, 13, proto3_optional: true, type: Weaviate.V1.TextArray)

  field(:image_properties, 14,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "imageProperties"
  )
end

defmodule Weaviate.V1.GenerativeDatabricks do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:endpoint, 1, proto3_optional: true, type: :string)
  field(:model, 2, proto3_optional: true, type: :string)

  field(:frequency_penalty, 3,
    proto3_optional: true,
    type: :double,
    json_name: "frequencyPenalty"
  )

  field(:log_probs, 4, proto3_optional: true, type: :bool, json_name: "logProbs")
  field(:top_log_probs, 5, proto3_optional: true, type: :int64, json_name: "topLogProbs")
  field(:max_tokens, 6, proto3_optional: true, type: :int64, json_name: "maxTokens")
  field(:n, 7, proto3_optional: true, type: :int64)
  field(:presence_penalty, 8, proto3_optional: true, type: :double, json_name: "presencePenalty")
  field(:stop, 9, proto3_optional: true, type: Weaviate.V1.TextArray)
  field(:temperature, 10, proto3_optional: true, type: :double)
  field(:top_p, 11, proto3_optional: true, type: :double, json_name: "topP")
end

defmodule Weaviate.V1.GenerativeFriendliAI do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:base_url, 1, proto3_optional: true, type: :string, json_name: "baseUrl")
  field(:model, 2, proto3_optional: true, type: :string)
  field(:max_tokens, 3, proto3_optional: true, type: :int64, json_name: "maxTokens")
  field(:temperature, 4, proto3_optional: true, type: :double)
  field(:n, 5, proto3_optional: true, type: :int64)
  field(:top_p, 6, proto3_optional: true, type: :double, json_name: "topP")
end

defmodule Weaviate.V1.GenerativeNvidia do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:base_url, 1, proto3_optional: true, type: :string, json_name: "baseUrl")
  field(:model, 2, proto3_optional: true, type: :string)
  field(:temperature, 3, proto3_optional: true, type: :double)
  field(:top_p, 4, proto3_optional: true, type: :double, json_name: "topP")
  field(:max_tokens, 5, proto3_optional: true, type: :int64, json_name: "maxTokens")
end

defmodule Weaviate.V1.GenerativeXAI do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:base_url, 1, proto3_optional: true, type: :string, json_name: "baseUrl")
  field(:model, 2, proto3_optional: true, type: :string)
  field(:temperature, 3, proto3_optional: true, type: :double)
  field(:top_p, 4, proto3_optional: true, type: :double, json_name: "topP")
  field(:max_tokens, 5, proto3_optional: true, type: :int64, json_name: "maxTokens")
  field(:images, 6, proto3_optional: true, type: Weaviate.V1.TextArray)

  field(:image_properties, 7,
    proto3_optional: true,
    type: Weaviate.V1.TextArray,
    json_name: "imageProperties"
  )
end

defmodule Weaviate.V1.GenerativeContextualAI do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:model, 1, proto3_optional: true, type: :string)
  field(:temperature, 2, proto3_optional: true, type: :double)
  field(:top_p, 3, proto3_optional: true, type: :double, json_name: "topP")
  field(:max_new_tokens, 4, proto3_optional: true, type: :int64, json_name: "maxNewTokens")
  field(:system_prompt, 5, proto3_optional: true, type: :string, json_name: "systemPrompt")
  field(:avoid_commentary, 6, proto3_optional: true, type: :bool, json_name: "avoidCommentary")
  field(:knowledge, 7, proto3_optional: true, type: Weaviate.V1.TextArray)
end

defmodule Weaviate.V1.GenerativeAnthropicMetadata.Usage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:input_tokens, 1, type: :int64, json_name: "inputTokens")
  field(:output_tokens, 2, type: :int64, json_name: "outputTokens")
end

defmodule Weaviate.V1.GenerativeAnthropicMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:usage, 1, type: Weaviate.V1.GenerativeAnthropicMetadata.Usage)
end

defmodule Weaviate.V1.GenerativeAnyscaleMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.GenerativeAWSMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.GenerativeCohereMetadata.ApiVersion do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:version, 1, proto3_optional: true, type: :string)
  field(:is_deprecated, 2, proto3_optional: true, type: :bool, json_name: "isDeprecated")
  field(:is_experimental, 3, proto3_optional: true, type: :bool, json_name: "isExperimental")
end

defmodule Weaviate.V1.GenerativeCohereMetadata.BilledUnits do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:input_tokens, 1, proto3_optional: true, type: :double, json_name: "inputTokens")
  field(:output_tokens, 2, proto3_optional: true, type: :double, json_name: "outputTokens")
  field(:search_units, 3, proto3_optional: true, type: :double, json_name: "searchUnits")
  field(:classifications, 4, proto3_optional: true, type: :double)
end

defmodule Weaviate.V1.GenerativeCohereMetadata.Tokens do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:input_tokens, 1, proto3_optional: true, type: :double, json_name: "inputTokens")
  field(:output_tokens, 2, proto3_optional: true, type: :double, json_name: "outputTokens")
end

defmodule Weaviate.V1.GenerativeCohereMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:api_version, 1,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeCohereMetadata.ApiVersion,
    json_name: "apiVersion"
  )

  field(:billed_units, 2,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeCohereMetadata.BilledUnits,
    json_name: "billedUnits"
  )

  field(:tokens, 3, proto3_optional: true, type: Weaviate.V1.GenerativeCohereMetadata.Tokens)
  field(:warnings, 4, proto3_optional: true, type: Weaviate.V1.TextArray)
end

defmodule Weaviate.V1.GenerativeDummyMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.GenerativeMistralMetadata.Usage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prompt_tokens, 1, proto3_optional: true, type: :int64, json_name: "promptTokens")
  field(:completion_tokens, 2, proto3_optional: true, type: :int64, json_name: "completionTokens")
  field(:total_tokens, 3, proto3_optional: true, type: :int64, json_name: "totalTokens")
end

defmodule Weaviate.V1.GenerativeMistralMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:usage, 1, proto3_optional: true, type: Weaviate.V1.GenerativeMistralMetadata.Usage)
end

defmodule Weaviate.V1.GenerativeOllamaMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.GenerativeOpenAIMetadata.Usage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prompt_tokens, 1, proto3_optional: true, type: :int64, json_name: "promptTokens")
  field(:completion_tokens, 2, proto3_optional: true, type: :int64, json_name: "completionTokens")
  field(:total_tokens, 3, proto3_optional: true, type: :int64, json_name: "totalTokens")
end

defmodule Weaviate.V1.GenerativeOpenAIMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:usage, 1, proto3_optional: true, type: Weaviate.V1.GenerativeOpenAIMetadata.Usage)
end

defmodule Weaviate.V1.GenerativeGoogleMetadata.TokenCount do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:total_billable_characters, 1,
    proto3_optional: true,
    type: :int64,
    json_name: "totalBillableCharacters"
  )

  field(:total_tokens, 2, proto3_optional: true, type: :int64, json_name: "totalTokens")
end

defmodule Weaviate.V1.GenerativeGoogleMetadata.TokenMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:input_token_count, 1,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeGoogleMetadata.TokenCount,
    json_name: "inputTokenCount"
  )

  field(:output_token_count, 2,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeGoogleMetadata.TokenCount,
    json_name: "outputTokenCount"
  )
end

defmodule Weaviate.V1.GenerativeGoogleMetadata.Metadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:token_metadata, 1,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeGoogleMetadata.TokenMetadata,
    json_name: "tokenMetadata"
  )
end

defmodule Weaviate.V1.GenerativeGoogleMetadata.UsageMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prompt_token_count, 1,
    proto3_optional: true,
    type: :int64,
    json_name: "promptTokenCount"
  )

  field(:candidates_token_count, 2,
    proto3_optional: true,
    type: :int64,
    json_name: "candidatesTokenCount"
  )

  field(:total_token_count, 3, proto3_optional: true, type: :int64, json_name: "totalTokenCount")
end

defmodule Weaviate.V1.GenerativeGoogleMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:metadata, 1, proto3_optional: true, type: Weaviate.V1.GenerativeGoogleMetadata.Metadata)

  field(:usage_metadata, 2,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeGoogleMetadata.UsageMetadata,
    json_name: "usageMetadata"
  )
end

defmodule Weaviate.V1.GenerativeDatabricksMetadata.Usage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prompt_tokens, 1, proto3_optional: true, type: :int64, json_name: "promptTokens")
  field(:completion_tokens, 2, proto3_optional: true, type: :int64, json_name: "completionTokens")
  field(:total_tokens, 3, proto3_optional: true, type: :int64, json_name: "totalTokens")
end

defmodule Weaviate.V1.GenerativeDatabricksMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:usage, 1, proto3_optional: true, type: Weaviate.V1.GenerativeDatabricksMetadata.Usage)
end

defmodule Weaviate.V1.GenerativeFriendliAIMetadata.Usage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prompt_tokens, 1, proto3_optional: true, type: :int64, json_name: "promptTokens")
  field(:completion_tokens, 2, proto3_optional: true, type: :int64, json_name: "completionTokens")
  field(:total_tokens, 3, proto3_optional: true, type: :int64, json_name: "totalTokens")
end

defmodule Weaviate.V1.GenerativeFriendliAIMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:usage, 1, proto3_optional: true, type: Weaviate.V1.GenerativeFriendliAIMetadata.Usage)
end

defmodule Weaviate.V1.GenerativeNvidiaMetadata.Usage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prompt_tokens, 1, proto3_optional: true, type: :int64, json_name: "promptTokens")
  field(:completion_tokens, 2, proto3_optional: true, type: :int64, json_name: "completionTokens")
  field(:total_tokens, 3, proto3_optional: true, type: :int64, json_name: "totalTokens")
end

defmodule Weaviate.V1.GenerativeNvidiaMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:usage, 1, proto3_optional: true, type: Weaviate.V1.GenerativeNvidiaMetadata.Usage)
end

defmodule Weaviate.V1.GenerativeXAIMetadata.Usage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prompt_tokens, 1, proto3_optional: true, type: :int64, json_name: "promptTokens")
  field(:completion_tokens, 2, proto3_optional: true, type: :int64, json_name: "completionTokens")
  field(:total_tokens, 3, proto3_optional: true, type: :int64, json_name: "totalTokens")
end

defmodule Weaviate.V1.GenerativeXAIMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:usage, 1, proto3_optional: true, type: Weaviate.V1.GenerativeXAIMetadata.Usage)
end

defmodule Weaviate.V1.GenerativeMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:kind, 0)

  field(:anthropic, 1, type: Weaviate.V1.GenerativeAnthropicMetadata, oneof: 0)
  field(:anyscale, 2, type: Weaviate.V1.GenerativeAnyscaleMetadata, oneof: 0)
  field(:aws, 3, type: Weaviate.V1.GenerativeAWSMetadata, oneof: 0)
  field(:cohere, 4, type: Weaviate.V1.GenerativeCohereMetadata, oneof: 0)
  field(:dummy, 5, type: Weaviate.V1.GenerativeDummyMetadata, oneof: 0)
  field(:mistral, 6, type: Weaviate.V1.GenerativeMistralMetadata, oneof: 0)
  field(:ollama, 7, type: Weaviate.V1.GenerativeOllamaMetadata, oneof: 0)
  field(:openai, 8, type: Weaviate.V1.GenerativeOpenAIMetadata, oneof: 0)
  field(:google, 9, type: Weaviate.V1.GenerativeGoogleMetadata, oneof: 0)
  field(:databricks, 10, type: Weaviate.V1.GenerativeDatabricksMetadata, oneof: 0)
  field(:friendliai, 11, type: Weaviate.V1.GenerativeFriendliAIMetadata, oneof: 0)
  field(:nvidia, 12, type: Weaviate.V1.GenerativeNvidiaMetadata, oneof: 0)
  field(:xai, 13, type: Weaviate.V1.GenerativeXAIMetadata, oneof: 0)
end

defmodule Weaviate.V1.GenerativeReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:result, 1, type: :string)
  field(:debug, 2, proto3_optional: true, type: Weaviate.V1.GenerativeDebug)
  field(:metadata, 3, proto3_optional: true, type: Weaviate.V1.GenerativeMetadata)
end

defmodule Weaviate.V1.GenerativeResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: Weaviate.V1.GenerativeReply)
end

defmodule Weaviate.V1.GenerativeDebug do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:full_prompt, 1, proto3_optional: true, type: :string, json_name: "fullPrompt")
end
