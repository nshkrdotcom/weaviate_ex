# Gap Analysis: Vectorizers and Integrations

**Date:** 2024-12-29
**Scope:** Text2Vec, Multi2Vec, Img2Vec, Ref2Vec, Generative modules, Rerankers
**Reference:** Python client `weaviate-python-client` vs Elixir port `weaviate_ex`

---

## Executive Summary

The Elixir port has **good foundational coverage** for vectorizers, generative modules, and rerankers. However, there are several gaps in:

1. **Missing Text2Vec vectorizers** (OpenAI, Cohere, HuggingFace, Contextionary, GPT4All, Mistral, NVIDIA, Databricks, Model2Vec)
2. **Missing Multi2Vec vectorizers** (Bind, NVIDIA, AWS, JinaAI multimodal)
3. **Missing ColBERT/Multi-vector support** (text2colbert-jinaai, multi2multivec-jinaai)
4. **Configuration parameter gaps** in existing vectorizers
5. **Missing rerankers** (NVIDIA, ContextualAI)

---

## 1. Text2Vec Vectorizers

### Python Client Coverage

| Vectorizer | Python | Elixir | Status |
|------------|--------|--------|--------|
| text2vec-aws | Yes | Yes | Implemented |
| text2vec-azure-openai | Yes | Yes | Implemented |
| text2vec-cohere | Yes | No | **MISSING** |
| text2vec-contextionary | Yes | No | **MISSING** |
| text2vec-databricks | Yes | No | **MISSING** |
| text2vec-gpt4all | Yes | No | **MISSING** |
| text2vec-huggingface | Yes | No | **MISSING** |
| text2vec-jinaai | Yes | Yes | Implemented |
| text2vec-mistral | Yes | No | **MISSING** |
| text2vec-model2vec | Yes | No | **MISSING** |
| text2vec-morph | Yes | No | **MISSING** |
| text2vec-nvidia | Yes | No | **MISSING** |
| text2vec-ollama | Yes | Yes | Implemented |
| text2vec-openai | Yes | No | **MISSING** |
| text2vec-palm/google | Yes | Yes | Implemented |
| text2vec-transformers | Yes | Yes | Implemented |
| text2vec-voyageai | Yes | Yes | Implemented |
| text2vec-weaviate | Yes | Yes | Implemented |
| text2colbert-jinaai | Yes | No | **MISSING** (ColBERT multi-vector) |

### Missing Text2Vec Implementations

#### 1. text2vec-openai (HIGH PRIORITY)

**Python API:**
```python
Configure.Vectorizer.text2vec_openai(
    model="text-embedding-3-small",
    model_version=None,
    type_="text",  # or "code"
    vectorize_collection_name=True,
    base_url=None,
    dimensions=None
)
```

**Required Elixir Implementation:**
- Module: `WeaviateEx.API.Vectorizers.Text2VecOpenAI`
- Options: model, model_version, type, dimensions, base_url, vectorize_collection_name

#### 2. text2vec-cohere (HIGH PRIORITY)

**Python API:**
```python
Configure.Vectorizer.text2vec_cohere(
    model="embed-english-v3.0",
    truncate="END",  # "NONE", "START", "END", "LEFT", "RIGHT"
    vectorize_collection_name=True,
    base_url=None
)
```

**Required Elixir Implementation:**
- Module: `WeaviateEx.API.Vectorizers.Text2VecCohere`
- Options: model, truncate, base_url, vectorize_collection_name, dimensions

#### 3. text2vec-huggingface (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Vectorizer.text2vec_huggingface(
    model=None,
    passage_model=None,
    query_model=None,
    endpoint_url=None,
    wait_for_model=None,
    use_gpu=None,
    use_cache=None,
    vectorize_collection_name=True
)
```

**Required Elixir Implementation:**
- Module: `WeaviateEx.API.Vectorizers.Text2VecHuggingFace`
- Options: model, passage_model, query_model, endpoint_url, wait_for_model, use_gpu, use_cache

#### 4. text2vec-mistral (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Vectorizer.text2vec_mistral(
    base_url=None,
    model=None,
    vectorize_collection_name=True
)
```

#### 5. text2vec-nvidia (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Vectorizer.text2vec_nvidia(
    model=None,
    base_url=None,
    truncate=None,
    vectorize_collection_name=True
)
```

#### 6. text2vec-databricks (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Vectorizer.text2vec_databricks(
    endpoint="...",  # required
    instruction=None,
    vectorize_collection_name=True
)
```

#### 7. text2vec-contextionary (LOW PRIORITY - Legacy)

**Python API:**
```python
Configure.Vectorizer.text2vec_contextionary(
    vectorize_collection_name=True
)
```

#### 8. text2vec-gpt4all (LOW PRIORITY)

**Python API:**
```python
Configure.Vectorizer.text2vec_gpt4all(
    vectorize_collection_name=True
)
```

#### 9. text2vec-model2vec (LOW PRIORITY)

**Python API:**
```python
Configure.Vectorizer.text2vec_model2vec(
    inference_url=None,
    vectorize_collection_name=True
)
```

### Configuration Differences in Existing Implementations

#### text2vec-transformers

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| pooling_strategy | Yes | Yes | OK |
| dimensions | Yes | No | **MISSING** |
| vectorize_collection_name | Yes | Yes | OK |
| inference_url | Yes | Yes | OK |
| passage_inference_url | Yes | Yes | OK |
| query_inference_url | Yes | Yes | OK |

#### text2vec-azure-openai

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| resource_name | Yes | Yes | OK |
| deployment_id | Yes | Yes | OK |
| base_url | Yes | Yes | OK |
| dimensions | Yes | No | **MISSING** |
| model | Yes | No | **MISSING** |
| vectorize_collection_name | Yes | Yes | OK |

#### text2vec-weaviate

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | OK |
| base_url | Yes | Yes | OK |
| dimensions | Yes | No | **MISSING** |
| vectorize_collection_name | Yes | Yes | OK |

---

## 2. Multi2Vec Vectorizers

### Python Client Coverage

| Vectorizer | Python | Elixir | Status |
|------------|--------|--------|--------|
| multi2vec-clip | Yes | Yes | Implemented |
| multi2vec-cohere | Yes | Yes | Implemented |
| multi2vec-google/palm | Yes | Yes | Implemented |
| multi2vec-voyageai | Yes | Yes | Implemented |
| multi2vec-bind | Yes | No | **MISSING** |
| multi2vec-nvidia | Yes | No | **MISSING** |
| multi2vec-aws | Yes | No | **MISSING** |
| multi2vec-jinaai | Yes | No | **MISSING** |
| multi2multivec-jinaai | Yes | No | **MISSING** (ColBERT multi-vector) |

### Missing Multi2Vec Implementations

#### 1. multi2vec-bind (MEDIUM PRIORITY)

Supports multiple modalities: images, text, audio, depth, IMU, thermal, video.

**Python API:**
```python
Configure.Vectorizer.multi2vec_bind(
    audio_fields=None,
    depth_fields=None,
    image_fields=None,
    imu_fields=None,
    text_fields=None,
    thermal_fields=None,
    video_fields=None,
    vectorize_collection_name=True
)
```

**Required Elixir Implementation:**
- Module: `WeaviateEx.API.Vectorizers.Multi2VecBind`
- Options: audio_fields, depth_fields, image_fields, imu_fields, text_fields, thermal_fields, video_fields

#### 2. multi2vec-nvidia (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Vectorizer.multi2vec_nvidia(
    model=None,
    truncation=None,
    base_url=None,
    image_fields=None,
    text_fields=None
)
```

#### 3. multi2vec-aws (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Vectorizer.multi2vec_aws(
    region=None,
    model=None,
    dimensions=None,
    image_fields=None,
    text_fields=None
)
```

#### 4. multi2vec-jinaai (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Vectorizer.multi2vec_jinaai(
    model=None,
    base_url=None,
    dimensions=None,
    image_fields=None,
    text_fields=None
)
```

### Configuration Differences in Existing Implementations

#### multi2vec-google

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| project_id | Yes | Yes | OK |
| location | Yes | Yes | OK |
| model_id | Yes | Yes | OK |
| dimensions | Yes | Yes | OK |
| image_fields | Yes | Yes | OK |
| text_fields | Yes | Yes | OK |
| video_fields | Yes | Yes | OK |
| video_interval_seconds | Yes | No | **MISSING** |
| vectorize_collection_name | Python implicit | Yes | OK |

---

## 3. Img2Vec Vectorizers

### Coverage

| Vectorizer | Python | Elixir | Status |
|------------|--------|--------|--------|
| img2vec-neural | Yes | Yes | Implemented |

**Elixir Implementation Status:** Complete

The Elixir implementation matches the Python client's functionality for img2vec-neural.

---

## 4. Ref2Vec Vectorizers

### Coverage

| Vectorizer | Python | Elixir | Status |
|------------|--------|--------|--------|
| ref2vec-centroid | Yes | Yes | Implemented |

**Elixir Implementation Status:** Complete

The Elixir implementation matches the Python client's functionality.

---

## 5. Generative Modules

### Python Client Coverage

| Module | Python | Elixir | Status |
|--------|--------|--------|--------|
| generative-openai | Yes | Yes | Implemented |
| generative-azure-openai | Yes | Yes | Implemented |
| generative-anthropic | Yes | Yes | Implemented |
| generative-cohere | Yes | Yes | Implemented |
| generative-mistral | Yes | Yes | Implemented |
| generative-google/palm | Yes | Yes | Implemented |
| generative-aws | Yes | Yes | Implemented |
| generative-ollama | Yes | Yes | Implemented |
| generative-databricks | Yes | Yes | Implemented |
| generative-nvidia | Yes | Yes | Implemented |
| generative-friendliai | Yes | Yes | Implemented |
| generative-xai | Yes | Yes | Implemented |
| generative-anyscale | Yes | Yes | Implemented |
| generative-contextualai | Yes | Yes | Implemented |
| generative-dummy | Yes | No | **MISSING** (testing only) |
| generative-custom | Yes | Yes | Implemented |

**Elixir Implementation Status:** Excellent coverage - all production modules implemented.

### Configuration Differences

#### generative-openai

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | OK |
| temperature | Yes | Yes | OK |
| max_tokens | Yes | Yes | OK |
| base_url | Yes | Yes | OK |
| frequency_penalty | Yes | No | **MISSING** |
| presence_penalty | Yes | No | **MISSING** |
| top_p | Yes | No | **MISSING** |
| verbosity | Yes | No | **MISSING** (O1/O3 models) |
| reasoning_effort | Yes | No | **MISSING** (O1/O3 models) |

#### generative-anthropic

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | OK |
| temperature | Yes | Yes | OK |
| max_tokens | Yes | Yes | OK |
| stop_sequences | Yes | No | **MISSING** |
| top_k | Yes | Yes | OK |
| top_p | Yes | Yes | OK |

#### generative-cohere

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | OK |
| temperature | Yes | Yes | OK |
| max_tokens | Yes | Yes | OK |
| k | Yes | Yes | OK |
| p | Yes | Yes | OK |
| base_url | Yes | No | **MISSING** |
| stop_sequences | Yes | No | **MISSING** |

#### generative-google

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | OK |
| temperature | Yes | Yes | OK |
| max_tokens | Yes | Yes | OK |
| project_id | Yes | Yes | OK |
| api_endpoint | Yes | No | **MISSING** |
| region | Yes | No | **MISSING** |
| endpoint_id | Yes | No | **MISSING** |
| top_k | Yes | No | **MISSING** |
| top_p | Yes | No | **MISSING** |

#### generative-aws

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | OK |
| region | Yes | Yes | OK |
| service | Yes | Yes | OK |
| temperature | Yes | Yes | OK |
| max_tokens | Yes | Yes | OK |
| endpoint | Yes | No | **MISSING** |
| target_model | Yes | No | **MISSING** |
| target_variant | Yes | No | **MISSING** |
| top_k | Yes | No | **MISSING** |
| top_p | Yes | No | **MISSING** |
| stop_sequences | Yes | No | **MISSING** |

#### generative-contextualai

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | OK |
| temperature | Yes | No | **MISSING** |
| top_p | Yes | No | **MISSING** |
| max_new_tokens | Yes | No | **MISSING** |
| system_prompt | Yes | No | **MISSING** |
| avoid_commentary | Yes | No | **MISSING** |
| knowledge | Yes | No | **MISSING** |

---

## 6. Reranker Configurations

### Python Client Coverage

| Reranker | Python | Elixir | Status |
|----------|--------|--------|--------|
| reranker-cohere | Yes | Yes | Implemented |
| reranker-transformers | Yes | Yes | Implemented |
| reranker-voyageai | Yes | Yes | Implemented |
| reranker-jinaai | Yes | Yes | Implemented |
| reranker-nvidia | Yes | No | **MISSING** |
| reranker-contextualai | Yes | No | **MISSING** |
| reranker-custom | Yes | Yes | Implemented |
| none | Yes | Yes | Implemented |

### Missing Reranker Implementations

#### 1. reranker-nvidia (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Reranker.nvidia(
    model=None,
    base_url=None
)
```

**Required Elixir Implementation:**
- Add `nvidia/2` function to `WeaviateEx.API.RerankerConfig`

#### 2. reranker-contextualai (MEDIUM PRIORITY)

**Python API:**
```python
Configure.Reranker.contextualai(
    model=None,
    instruction=None,
    top_n=None
)
```

**Required Elixir Implementation:**
- Add `contextualai/1` function to `WeaviateEx.API.RerankerConfig`

---

## 7. Integration Headers (API Key Management)

### Python Client Coverage

The Python client uses `weaviate.classes.init.Auth` and environment variables.

### Elixir Coverage

The Elixir `WeaviateEx.Integrations` module provides header builders:

| Provider | Python | Elixir | Status |
|----------|--------|--------|--------|
| OpenAI | Yes | Yes | Implemented |
| Cohere | Yes | Yes | Implemented |
| HuggingFace | Yes | Yes | Implemented |
| VoyageAI | Yes | Yes | Implemented |
| JinaAI | Yes | Yes | Implemented |
| Mistral | Yes | Yes | Implemented |
| Anthropic | Yes | Yes | Implemented |
| Google | Yes | Yes | Implemented |
| Azure OpenAI | Yes | Yes | Implemented |
| AWS | Yes | Yes | Implemented |
| NVIDIA | Yes | Yes | Implemented |
| Databricks | Yes | Yes | Implemented |

**Elixir Implementation Status:** Complete - all providers covered.

---

## 8. ColBERT/Multi-Vector Support

### Python Client Coverage

The Python client supports ColBERT and multi-vector configurations:

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| text2colbert-jinaai | Yes | No | **MISSING** |
| multi2multivec-jinaai | Yes | No | **MISSING** |
| MultiVectors config class | Yes | No | **MISSING** |

This is a newer feature that enables storing multiple vectors per field (e.g., token-level embeddings).

---

## 9. Priority Implementation Recommendations

### High Priority (Core Functionality)

1. **text2vec-openai** - Most popular vectorizer
2. **text2vec-cohere** - Major provider
3. **reranker-nvidia** - Complete reranker coverage
4. **reranker-contextualai** - Complete reranker coverage

### Medium Priority (Provider Expansion)

5. **text2vec-huggingface** - Open-source models
6. **text2vec-mistral** - Growing provider
7. **text2vec-nvidia** - Enterprise use cases
8. **text2vec-databricks** - Enterprise integration
9. **multi2vec-bind** - Multimodal capabilities
10. **multi2vec-nvidia** - Enterprise multimodal
11. **multi2vec-aws** - AWS ecosystem
12. **multi2vec-jinaai** - JinaAI multimodal

### Low Priority (Niche Use Cases)

13. **text2vec-contextionary** - Legacy module
14. **text2vec-gpt4all** - Local models
15. **text2vec-model2vec** - Specialized
16. **text2vec-morph** - Specialized
17. **ColBERT support** - Advanced use cases

### Configuration Parameter Additions

18. Add missing parameters to generative configs (frequency_penalty, presence_penalty, etc.)
19. Add missing parameters to existing vectorizers (dimensions where missing)
20. Add video_interval_seconds to multi2vec-google

---

## 10. API Design Comparison

### Python API Pattern

```python
# Vectorizer configuration
Configure.Vectorizer.text2vec_openai(
    model="text-embedding-3-small",
    dimensions=512
)

# Named vectors
Configure.NamedVectors.text2vec_openai(
    name="default",
    model="text-embedding-3-small"
)

# Generative configuration
Configure.Generative.openai(
    model="gpt-4",
    temperature=0.7
)

# Reranker configuration
Configure.Reranker.cohere(
    model="rerank-english-v3.0"
)
```

### Elixir API Pattern

```elixir
# Vectorizer configuration
Text2VecOpenAI.new(
  model: "text-embedding-3-small",
  dimensions: 512
)

# Generative configuration
GenerativeConfig.openai(
  model: "gpt-4",
  temperature: 0.7
)

# Reranker configuration
RerankerConfig.cohere("rerank-english-v3.0")
```

### Design Recommendations

1. **Consistency**: The Elixir pattern is good but could benefit from a unified `Configure` module namespace like Python
2. **Named Vectors**: Need to add support for named vector configurations
3. **Type Safety**: Consider adding typed options validation with dialyzer specs

---

## 11. Example Implementation Templates

### Text2VecOpenAI (Missing - High Priority)

```elixir
defmodule WeaviateEx.API.Vectorizers.Text2VecOpenAI do
  @moduledoc """
  Text2Vec-OpenAI vectorizer configuration.
  """

  @type openai_type :: :text | :code
  @type t :: %__MODULE__{
          model: String.t() | nil,
          model_version: String.t() | nil,
          type: openai_type() | nil,
          dimensions: pos_integer() | nil,
          base_url: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct model: nil,
            model_version: nil,
            type: nil,
            dimensions: nil,
            base_url: nil,
            vectorize_collection_name: true

  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-openai"

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      model: Keyword.get(opts, :model),
      model_version: Keyword.get(opts, :model_version),
      type: Keyword.get(opts, :type),
      dimensions: Keyword.get(opts, :dimensions),
      base_url: Keyword.get(opts, :base_url),
      vectorize_collection_name: Keyword.get(opts, :vectorize_collection_name, true)
    }
  end

  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    module_config =
      %{
        "vectorizeClassName" => config.vectorize_collection_name,
        "isAzure" => false
      }
      |> maybe_put("model", config.model)
      |> maybe_put("modelVersion", config.model_version)
      |> maybe_put("type", type_to_string(config.type))
      |> maybe_put("dimensions", config.dimensions)
      |> maybe_put("baseURL", config.base_url)

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  defp type_to_string(nil), do: nil
  defp type_to_string(:text), do: "text"
  defp type_to_string(:code), do: "code"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

### RerankerNVIDIA (Missing - Medium Priority)

```elixir
# Add to WeaviateEx.API.RerankerConfig

@doc """
Create an NVIDIA reranker configuration.

## Options

  - `:model` - NVIDIA model name
  - `:base_url` - Custom API endpoint URL

## Examples

    RerankerConfig.nvidia("nvidia-rerank-qa-mistral-4b", base_url: "https://api.nvidia.com")
"""
@spec nvidia(String.t() | nil, keyword()) :: config()
def nvidia(model \\ nil, opts \\ []) do
  config =
    %{}
    |> maybe_put("model", model)
    |> maybe_put("baseURL", Keyword.get(opts, :base_url))

  %{"reranker-nvidia" => config}
end
```

---

## 12. Summary Statistics

| Category | Python Count | Elixir Count | Coverage |
|----------|--------------|--------------|----------|
| Text2Vec | 18 | 9 | 50% |
| Multi2Vec | 9 | 4 | 44% |
| Img2Vec | 1 | 1 | 100% |
| Ref2Vec | 1 | 1 | 100% |
| Generative | 14 | 13 | 93% |
| Rerankers | 7 | 5 | 71% |
| Integration Headers | 12 | 12 | 100% |

**Overall Vectorizer/Integration Coverage: ~70%**

The Elixir port has solid coverage for generative modules and integration headers, but needs work on text2vec and multi2vec vectorizers to reach full parity with the Python client.
