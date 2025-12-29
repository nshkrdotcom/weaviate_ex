# Python Client Changes Analysis (Oct 19, 2025 - Dec 28, 2025)

This document analyzes all changes to the weaviate-python-client since our last Elixir port sync, and provides implementation guidance for bringing `weaviate_ex` up to feature parity.

## Summary of Changes

Between commits `361fd0c4` and `aeaf1f53` (HEAD), the Python client has had **+1,384/-384 lines changed** across **41 files**. The major feature additions include:

1. **Object TTL (Time-To-Live) Configuration** - New feature for automatic object expiration
2. **ContextualAI Module Support** - New generative AI provider
3. **AWS Service-Specific Methods** - Separate bedrock/sagemaker factories
4. **Google Service-Specific Methods** - text2vec_google_vertex, text2vec_google_gemini
5. **Cohere Reranker baseURL** - Added baseURL parameter
6. **Boolean Filter Fix** - Improved filter handling
7. **VoyageAI voyage-3-large Model** - New model support
8. **Cohere Dimensions Parameter** - Added dimensions to text2vec_cohere
9. **XAI topP Parameter** - Added to generative config
10. **OpenAI Verbosity/ReasoningEffort** - New parameters for reasoning models
11. **GSE_CH Tokenizer** - New tokenization option

---

## 1. Object TTL (Time-To-Live) Configuration

### Python Implementation

New file: `weaviate/collections/classes/config_object_ttl.py`

```python
class _ObjectTTLConfigCreate(_ConfigCreateModel):
    enabled: bool = True
    filterExpiredObjects: Optional[bool]
    deleteOn: Optional[str]
    defaultTtl: Optional[int]

class _ObjectTTLConfigUpdate(_ConfigUpdateModel):
    enabled: bool
    filterExpiredObjects: Optional[bool] = None
    deleteOn: Optional[str] = None
    defaultTtl: Optional[int] = None
```

**Factory Methods:**
- `_ObjectTTL.delete_by_update_time(time_to_live, filter_expired_objects)`
- `_ObjectTTL.delete_by_creation_time(time_to_live, filter_expired_objects)`
- `_ObjectTTL.delete_by_date_property(property_name, ttl_offset, filter_expired_objects)`
- `_ObjectTTLUpdate.disable()`
- `_ObjectTTLUpdate.delete_by_update_time(...)`
- `_ObjectTTLUpdate.delete_by_creation_time(...)`
- `_ObjectTTLUpdate.delete_by_date_property(...)`

### Elixir Implementation Required

Create new module: `lib/weaviate_ex/config/object_ttl.ex`

```elixir
defmodule WeaviateEx.Config.ObjectTTL do
  @moduledoc """
  Object Time-To-Live (TTL) configuration for automatic object expiration.
  """

  defstruct [
    :enabled,
    :filter_expired_objects,
    :delete_on,
    :default_ttl
  ]

  @type t :: %__MODULE__{
    enabled: boolean(),
    filter_expired_objects: boolean() | nil,
    delete_on: String.t() | nil,
    default_ttl: integer() | nil
  }

  @doc """
  Create TTL config that deletes objects based on their last update time.

  ## Parameters
  - `time_to_live` - TTL in seconds (integer) or duration
  - `filter_expired_objects` - If true, exclude expired but not yet deleted objects from search
  """
  @spec delete_by_update_time(integer() | Duration.t(), boolean() | nil) :: t()
  def delete_by_update_time(time_to_live, filter_expired_objects \\ nil) do
    ttl = normalize_duration(time_to_live)
    %__MODULE__{
      enabled: true,
      delete_on: "_lastUpdateTimeUnix",
      filter_expired_objects: filter_expired_objects,
      default_ttl: ttl
    }
  end

  @doc """
  Create TTL config that deletes objects based on their creation time.
  """
  @spec delete_by_creation_time(integer() | Duration.t(), boolean() | nil) :: t()
  def delete_by_creation_time(time_to_live, filter_expired_objects \\ nil) do
    ttl = normalize_duration(time_to_live)
    %__MODULE__{
      enabled: true,
      delete_on: "_creationTimeUnix",
      filter_expired_objects: filter_expired_objects,
      default_ttl: ttl
    }
  end

  @doc """
  Create TTL config that deletes objects based on a custom date property.
  """
  @spec delete_by_date_property(String.t(), integer() | nil, boolean() | nil) :: t()
  def delete_by_date_property(property_name, ttl_offset \\ nil, filter_expired_objects \\ nil) do
    offset = if is_nil(ttl_offset), do: 0, else: normalize_duration(ttl_offset)
    %__MODULE__{
      enabled: true,
      delete_on: property_name,
      filter_expired_objects: filter_expired_objects,
      default_ttl: offset
    }
  end

  @doc """
  Create a config to disable TTL.
  """
  @spec disable() :: t()
  def disable do
    %__MODULE__{enabled: false}
  end

  @doc """
  Convert to map for API payload.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = config) do
    %{
      "enabled" => config.enabled,
      "filterExpiredObjects" => config.filter_expired_objects,
      "deleteOn" => config.delete_on,
      "defaultTtl" => config.default_ttl
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp normalize_duration(value) when is_integer(value), do: value
  defp normalize_duration(%Duration{} = d), do: Duration.to_seconds(d)
end
```

---

## 2. ContextualAI Generative Module

### Python Implementation

New provider in `generative.py`:

```python
class _GenerativeContextualAI(_GenerativeConfigRuntime):
    generative: Union[GenerativeSearches, _EnumLikeStr] = Field(
        default=GenerativeSearches.CONTEXTUALAI, frozen=True, exclude=True
    )
    model: Optional[str]
    temperature: Optional[float]
    top_p: Optional[float]
    max_new_tokens: Optional[int]
    system_prompt: Optional[str]
    avoid_commentary: Optional[bool]
    knowledge: Optional[List[str]]
```

### Elixir Implementation Required

Add to `lib/weaviate_ex/api/generative.ex`:

```elixir
@doc """
Configure ContextualAI generative module.

## Options
- `:model` - The model to use
- `:temperature` - Sampling temperature
- `:top_p` - Top-p sampling
- `:max_new_tokens` - Maximum tokens to generate
- `:system_prompt` - System prompt to prepend
- `:avoid_commentary` - Whether to avoid model commentary
- `:knowledge` - Optional knowledge array to override defaults
"""
@spec contextualai(keyword()) :: map()
def contextualai(opts \\ []) do
  %{
    "model" => Keyword.get(opts, :model),
    "temperature" => Keyword.get(opts, :temperature),
    "topP" => Keyword.get(opts, :top_p),
    "maxNewTokens" => Keyword.get(opts, :max_new_tokens),
    "systemPrompt" => Keyword.get(opts, :system_prompt),
    "avoidCommentary" => Keyword.get(opts, :avoid_commentary),
    "knowledge" => Keyword.get(opts, :knowledge)
  }
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  |> Map.new()
end
```

Add to `GenerativeSearches` enum:
```elixir
:contextualai => "generative-contextualai"
```

---

## 3. AWS Service-Specific Methods

### Python Implementation

Deprecated the generic `text2vec_aws` and added:
- `text2vec_aws_bedrock(model, region, ...)`
- `text2vec_aws_sagemaker(endpoint, region, target_model, target_variant, ...)`
- `multi2vec_aws_bedrock(...)`

For generative:
- `aws_bedrock(...)`
- `aws_sagemaker(...)`

### Elixir Implementation Required

Add to `lib/weaviate_ex/api/vector_config.ex`:

```elixir
@doc """
Configure text2vec-aws with AWS Bedrock service.
"""
@spec text2vec_aws_bedrock(keyword()) :: map()
def text2vec_aws_bedrock(opts) do
  model = Keyword.fetch!(opts, :model)
  region = Keyword.fetch!(opts, :region)

  %{
    "text2vec-aws" => %{
      "model" => model,
      "region" => region,
      "service" => "bedrock",
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
  }
end

@doc """
Configure text2vec-aws with AWS SageMaker service.
"""
@spec text2vec_aws_sagemaker(keyword()) :: map()
def text2vec_aws_sagemaker(opts) do
  endpoint = Keyword.fetch!(opts, :endpoint)
  region = Keyword.fetch!(opts, :region)

  %{
    "text2vec-aws" => %{
      "endpoint" => endpoint,
      "region" => region,
      "service" => "sagemaker",
      "targetModel" => Keyword.get(opts, :target_model),
      "targetVariant" => Keyword.get(opts, :target_variant),
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end
```

---

## 4. Google Service-Specific Methods

### Python Implementation

Deprecated `text2vec_google` and added:
- `text2vec_google_vertex(project_id, api_endpoint, model, ...)`
- `text2vec_google_gemini(model, ...)`

For generative:
- `google_vertex(...)`
- `google_gemini(...)`

### Elixir Implementation Required

```elixir
@doc """
Configure text2vec-google with Google Vertex AI.
"""
@spec text2vec_google_vertex(keyword()) :: map()
def text2vec_google_vertex(opts) do
  project_id = Keyword.fetch!(opts, :project_id)

  %{
    "text2vec-palm" => %{
      "projectId" => project_id,
      "apiEndpoint" => Keyword.get(opts, :api_endpoint),
      "modelId" => Keyword.get(opts, :model),
      "dimensions" => Keyword.get(opts, :dimensions),
      "titleProperty" => Keyword.get(opts, :title_property),
      "taskType" => Keyword.get(opts, :task_type),
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end

@doc """
Configure text2vec-google with Google AI Studio (Gemini).
"""
@spec text2vec_google_gemini(keyword()) :: map()
def text2vec_google_gemini(opts \\ []) do
  %{
    "text2vec-palm" => %{
      "apiEndpoint" => "generativelanguage.googleapis.com",
      "modelId" => Keyword.get(opts, :model),
      "dimensions" => Keyword.get(opts, :dimensions),
      "titleProperty" => Keyword.get(opts, :title_property),
      "taskType" => Keyword.get(opts, :task_type),
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end
```

---

## 5. Cohere Reranker baseURL

### Python Implementation

Added `base_url` parameter to Cohere reranker configuration.

### Elixir Implementation Required

If we have a reranker module, add:

```elixir
def cohere_reranker(opts \\ []) do
  %{
    "reranker-cohere" => %{
      "model" => Keyword.get(opts, :model),
      "baseURL" => Keyword.get(opts, :base_url)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end
```

---

## 6. Boolean Filter Fix

### Python Implementation

Fixed boolean filter handling in `filters.py`. The key issue was that `bool` is a subclass of `int` in Python, requiring explicit bool checks before int checks.

### Elixir Impact

Elixir doesn't have this issue since `true`/`false` are distinct from integers. However, verify our filter implementation handles booleans correctly:

```elixir
# In filter conversion, ensure booleans are serialized as JSON booleans
defp serialize_value(value) when is_boolean(value), do: value
defp serialize_value(value) when is_integer(value), do: value
# ...etc
```

---

## 7. New VoyageAI Models

### Python Implementation

Added new models to `VoyageModel`:
- `voyage-3.5`
- `voyage-3.5-lite`
- `voyage-3-large`
- `voyage-context-3`

### Elixir Implementation Required

Update `lib/weaviate_ex/api/vector_config.ex` VoyageModel type:

```elixir
@type voyage_model ::
  :"voyage-3.5" |
  :"voyage-3.5-lite" |
  :"voyage-3-large" |
  :"voyage-3" |
  :"voyage-3-lite" |
  :"voyage-context-3" |
  :"voyage-large-2" |
  :"voyage-code-2" |
  :"voyage-2" |
  :"voyage-law-2" |
  :"voyage-large-2-instruct" |
  :"voyage-finance-2" |
  :"voyage-multilingual-2" |
  String.t()
```

---

## 8. Cohere Dimensions Parameter

### Python Implementation

Added `dimensions` parameter to `text2vec-cohere`:

```python
class _Text2VecCohereConfig(_VectorizerConfigCreate):
    # ...
    dimensions: Optional[int]
```

### Elixir Implementation Required

Update `text2vec_cohere/1`:

```elixir
def text2vec_cohere(opts \\ []) do
  %{
    "text2vec-cohere" => %{
      "model" => Keyword.get(opts, :model),
      "dimensions" => Keyword.get(opts, :dimensions),  # NEW
      "truncate" => Keyword.get(opts, :truncate),
      "baseURL" => Keyword.get(opts, :base_url),
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end
```

---

## 9. XAI topP Parameter

### Python Implementation

Added `top_p` to `_GenerativeXAI`:

```python
class _GenerativeXAI(_GenerativeConfigRuntime):
    top_p: Optional[float]
```

### Elixir Implementation Required

Update XAI generative config:

```elixir
def xai(opts \\ []) do
  %{
    "baseURL" => Keyword.get(opts, :base_url),
    "maxTokens" => Keyword.get(opts, :max_tokens),
    "model" => Keyword.get(opts, :model),
    "temperature" => Keyword.get(opts, :temperature),
    "topP" => Keyword.get(opts, :top_p)  # NEW
  }
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  |> Map.new()
end
```

---

## 10. OpenAI Verbosity/ReasoningEffort

### Python Implementation

Added for O1/O3 reasoning models:

```python
class _GenerativeOpenAI(_GenerativeConfigRuntime):
    verbosity: Optional[Union[OpenAiVerbosity, str]]  # "low", "medium", "high"
    reasoning_effort: Optional[Union[OpenAiReasoningEffort, str]]  # "minimal", "low", "medium", "high"
```

### Elixir Implementation Required

```elixir
@type openai_verbosity :: :low | :medium | :high | String.t()
@type openai_reasoning_effort :: :minimal | :low | :medium | :high | String.t()

def openai(opts \\ []) do
  %{
    "apiVersion" => Keyword.get(opts, :api_version),
    "baseURL" => Keyword.get(opts, :base_url),
    "deploymentId" => Keyword.get(opts, :deployment_id),
    "frequencyPenalty" => Keyword.get(opts, :frequency_penalty),
    "maxTokens" => Keyword.get(opts, :max_tokens),
    "model" => Keyword.get(opts, :model),
    "presencePenalty" => Keyword.get(opts, :presence_penalty),
    "resourceName" => Keyword.get(opts, :resource_name),
    "stop" => Keyword.get(opts, :stop),
    "temperature" => Keyword.get(opts, :temperature),
    "topP" => Keyword.get(opts, :top_p),
    "verbosity" => Keyword.get(opts, :verbosity),           # NEW
    "reasoningEffort" => Keyword.get(opts, :reasoning_effort)  # NEW
  }
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  |> Map.new()
end
```

---

## 11. GSE_CH Tokenizer

### Python Implementation

Added `Tokenization.GSE_CH` for Chinese text tokenization:

```python
class Tokenization(str, Enum):
    # ...
    GSE_CH = "gse_ch"
```

### Elixir Implementation Required

Update tokenization enum:

```elixir
@type tokenization ::
  :word |
  :lowercase |
  :whitespace |
  :field |
  :trigram |
  :gse |
  :gse_ch |  # NEW - Chinese tokenization
  :kagome_ja |
  :kagome_kr
```

---

## 12. New Vectorizers Added

### text2vec-morph

```elixir
def text2vec_morph(opts \\ []) do
  %{
    "text2vec-morph" => %{
      "model" => Keyword.get(opts, :model),
      "baseURL" => Keyword.get(opts, :base_url),
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end
```

### text2vec-model2vec

```elixir
def text2vec_model2vec(opts \\ []) do
  %{
    "text2vec-model2vec" => %{
      "inferenceUrl" => Keyword.get(opts, :inference_url),
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end
```

### text2colbert-jinaai (Multi-vector)

```elixir
def text2colbert_jinaai(opts \\ []) do
  %{
    "text2colbert-jinaai" => %{
      "model" => Keyword.get(opts, :model),
      "dimensions" => Keyword.get(opts, :dimensions),
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end
```

### multi2multivec-jinaai

```elixir
def multi2multivec_jinaai(opts \\ []) do
  %{
    "multi2multivec-jinaai" => %{
      "model" => Keyword.get(opts, :model),
      "baseURL" => Keyword.get(opts, :base_url) |> maybe_to_string(),
      "imageFields" => Keyword.get(opts, :image_fields),
      "textFields" => Keyword.get(opts, :text_fields)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  }
end
```

---

## Implementation Priority

### High Priority (Core Features)
1. Object TTL Configuration - Major new feature
2. ContextualAI Generative Module - New provider
3. AWS Service-Specific Methods - Better UX
4. Google Service-Specific Methods - Better UX

### Medium Priority (Enhancements)
5. Cohere dimensions parameter
6. XAI topP parameter
7. OpenAI verbosity/reasoning_effort
8. VoyageAI new models
9. GSE_CH tokenizer

### Low Priority (Minor)
10. Cohere reranker baseURL
11. New vectorizers (morph, model2vec, colbert)

---

## Files to Create/Modify

### New Files
- `lib/weaviate_ex/config/object_ttl.ex` - Object TTL configuration
- `test/weaviate_ex/config/object_ttl_test.exs` - Tests

### Modified Files
- `lib/weaviate_ex/api/generative.ex` - Add ContextualAI, update OpenAI/XAI
- `lib/weaviate_ex/api/vector_config.ex` - Add AWS/Google service-specific methods
- `lib/weaviate_ex/collections.ex` - Support for object_ttl in schema
- `lib/weaviate_ex/config/property.ex` - Add GSE_CH tokenization

### Test Files to Update
- `test/weaviate_ex/api/generative_test.exs`
- `test/weaviate_ex/api/vector_config_test.exs`
- `test/weaviate_ex/collections_test.exs`

---

## API Changes Summary

### Collection Creation
```elixir
# Before
WeaviateEx.Collections.create(client, %{
  class: "MyClass",
  properties: [...]
})

# After (with TTL)
WeaviateEx.Collections.create(client, %{
  class: "MyClass",
  properties: [...],
  object_ttl: WeaviateEx.Config.ObjectTTL.delete_by_update_time(86400)  # 24 hours
})
```

### Collection Update (TTL)
```elixir
# Update TTL configuration
WeaviateEx.Collections.update_config(client, "MyClass", %{
  object_ttl: WeaviateEx.Config.ObjectTTL.delete_by_creation_time(3600)
})

# Disable TTL
WeaviateEx.Collections.update_config(client, "MyClass", %{
  object_ttl: WeaviateEx.Config.ObjectTTL.disable()
})
```

### Generative Search with ContextualAI
```elixir
WeaviateEx.API.Generative.contextualai(
  model: "grounding-large",
  temperature: 0.7,
  system_prompt: "You are a helpful assistant.",
  avoid_commentary: true
)
```

---

## Testing Strategy

1. **Unit Tests** - Test each new configuration function in isolation
2. **Integration Tests** - Test against live Weaviate 1.35+ for TTL features
3. **Backwards Compatibility** - Ensure existing code continues to work

### Weaviate Version Requirements
- Object TTL requires Weaviate 1.35+
- ContextualAI module requires appropriate Weaviate modules enabled
- GSE_CH tokenizer requires Weaviate 1.34+

---

## Docker Compose Updates

Update `docker-compose.yml` to use Weaviate 1.35:

```yaml
services:
  weaviate:
    image: semitechnologies/weaviate:1.35.0
    # ... rest of config
```

This ensures integration tests can test all new features.
