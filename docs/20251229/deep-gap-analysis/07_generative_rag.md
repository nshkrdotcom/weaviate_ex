# Deep Gap Analysis: Generative AI and RAG Features

**Date:** 2025-12-29
**Comparison:** Python Canonical Client vs Elixir Port (WeaviateEx)

## Executive Summary

This analysis compares the generative AI (RAG) and vectorization capabilities between the Python canonical Weaviate client and the Elixir WeaviateEx port. The Elixir implementation covers most core features but has significant gaps in advanced generative parameters, multimodal support, and certain vectorizer integrations.

---

## 1. Generate Single Prompt

### Python Implementation

**Location:** `weaviate/collections/classes/generative.py` - `_SinglePrompt` class

```python
class _SinglePrompt(BaseModel):
    prompt: str
    image_properties: Optional[List[str]]
    images: Optional[Iterable[str]]
    metadata: bool = False
    debug: bool = False

    def _to_grpc(self, provider: _GenerativeConfigRuntime) -> generative_pb2.GenerativeSearch.Single:
        return generative_pb2.GenerativeSearch.Single(
            prompt=self.prompt,
            debug=self.debug,
            queries=[provider._to_grpc(...)]
        )
```

**Features:**
- Property placeholder interpolation (`{property_name}`)
- Multimodal image support (external images via base64/path)
- Image properties from object properties
- Metadata return option
- Debug mode (returns full prompt)
- gRPC protocol support

### Elixir Implementation

**Location:** `lib/weaviate_ex/generative/parameters.ex` - `SinglePrompt` module

```elixir
defmodule SinglePrompt do
  defstruct [
    :prompt,
    :images,
    :image_properties,
    :non_blob_properties,
    metadata: false,
    debug: false
  ]
end
```

**Status: IMPLEMENTED (Partial)**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Basic prompt | Yes | Yes | None |
| Property interpolation | Yes | Yes | None |
| External images | Yes | Yes | None |
| Image properties | Yes | Yes | None |
| Non-blob properties | Yes | Yes | None |
| Metadata flag | Yes | Yes | None |
| Debug flag | Yes | Yes | None |
| gRPC protocol | Yes | **No** | **Missing - GraphQL only** |

### Code Example Comparison

**Python:**
```python
from weaviate.classes.generative import GenerativeParameters

# Create single prompt with options
param = GenerativeParameters.single_prompt(
    prompt="Summarize: {content}",
    image_properties=["product_image"],
    images=["/path/to/image.jpg"],  # Supports file paths
    metadata=True,
    debug=True
)

# Use in query
response = collection.generate.near_text(
    query="machine learning",
    single_prompt=param
)
```

**Elixir:**
```elixir
alias WeaviateEx.Generative.Parameters

# Create single prompt
param = Parameters.single_prompt("Summarize: {content}",
  image_properties: ["product_image"],
  images: ["base64_data..."],  # Base64 only, no file path support
  metadata: true,
  debug: true
)

# Use in query - GraphQL only
Generate.new("Article")
|> Generate.near_text("machine learning")
|> Generate.single_prompt("Summarize: {title}")
|> Generate.execute(client)
```

---

## 2. Generate Grouped Task

### Python Implementation

**Location:** `weaviate/collections/classes/generative.py` - `_GroupedTask` class

```python
class _GroupedTask(BaseModel):
    prompt: str
    non_blob_properties: Optional[List[str]]
    image_properties: Optional[List[str]]
    images: Optional[Iterable[str]]
    metadata: bool = False
```

### Elixir Implementation

**Location:** `lib/weaviate_ex/generative/parameters.ex` - `GroupedTask` module

**Status: IMPLEMENTED (Full)**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Task prompt | Yes | Yes | None |
| Non-blob properties | Yes | Yes | None |
| Image properties | Yes | Yes | None |
| External images | Yes | Yes | None |
| Metadata flag | Yes | Yes | None |
| gRPC protocol | Yes | **No** | **Missing** |

---

## 3. Generative Config for Collections

### Python Implementation

**Location:** `weaviate/collections/classes/config.py` - `_Generative` factory class

The Python client provides a `Configure.Generative` factory class for collection-level generative configuration.

### Elixir Implementation

**Location:** `lib/weaviate_ex/api/generative_config.ex`

**Status: IMPLEMENTED (Full)**

Both implementations support:
- OpenAI, Azure OpenAI, Anthropic, Cohere, Google (Vertex/Gemini), AWS, Mistral, Ollama, XAI, NVIDIA, Databricks, FriendliAI, Anyscale, ContextualAI
- Custom provider configuration

---

## 4. Generative Providers Comparison

### Provider Support Matrix

| Provider | Python | Elixir Config | Elixir Runtime | Gap |
|----------|--------|---------------|----------------|-----|
| OpenAI | Yes | Yes | Yes | None |
| Azure OpenAI | Yes | Yes | Yes | None |
| Anthropic | Yes | Yes | Yes | None |
| Cohere | Yes | Yes | Yes | None |
| AWS Bedrock | Yes | Yes | Yes | None |
| AWS SageMaker | Yes | Yes | Yes | None |
| Google Vertex | Yes | Yes | Yes | None |
| Google Gemini | Yes | Yes | Yes | None |
| Mistral | Yes | Yes | Yes | None |
| Ollama | Yes | Yes | Yes | None |
| XAI (Grok) | Yes | Yes | Yes | None |
| NVIDIA | Yes | Yes | Yes | None |
| Databricks | Yes | Yes | Yes | None |
| FriendliAI | Yes | Yes | Yes | None |
| Anyscale | Yes | Yes | Yes | None |
| ContextualAI | Yes | Yes | Yes | None |
| **Dummy** | Yes | **No** | **No** | **Missing (testing)** |

### Python Provider Details

```python
# From weaviate/collections/classes/generative.py

class _GenerativeAnthropic(_GenerativeConfigRuntime):
    base_url: Optional[AnyHttpUrl]
    max_tokens: Optional[int]
    model: Optional[str]
    temperature: Optional[float]
    top_k: Optional[int]
    top_p: Optional[float]
    stop_sequences: Optional[List[str]]
    # Supports multimodal via images/image_properties
```

### Elixir Provider Details

```elixir
# From lib/weaviate_ex/generative/config.ex

defmodule Anthropic do
  defstruct [
    :model,
    :temperature,
    :max_tokens,
    :top_p,
    :top_k,
    :stop_sequences,
    :base_url
  ]
end
```

---

## 5. Generative Model Parameters

### Detailed Parameter Comparison by Provider

#### OpenAI

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | None |
| temperature | Yes | Yes | None |
| max_tokens | Yes | Yes | None |
| top_p | Yes | Yes | None |
| frequency_penalty | Yes | Yes | None |
| presence_penalty | Yes | Yes | None |
| stop | Yes | Yes | None |
| base_url | Yes | Yes | None |
| api_version | Yes | Yes | None |
| deployment_id | Yes | Yes | None |
| resource_name | Yes | Yes | None |
| is_azure | Yes | Yes | None |
| **verbosity** | Yes | Yes | None |
| **reasoning_effort** | Yes | Yes | None |

#### Anthropic

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | None |
| temperature | Yes | Yes | None |
| max_tokens | Yes | Yes | None |
| top_p | Yes | Yes | None |
| top_k | Yes | Yes | None |
| stop_sequences | Yes | Yes | None |
| base_url | Yes | Yes | None |

#### AWS (Bedrock/SageMaker)

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | None |
| region | Yes | Yes | None |
| endpoint | Yes | Yes | None |
| service | Yes | Yes | None |
| target_model | Yes | Yes | None |
| target_variant | Yes | Yes | None |
| temperature | Yes | Yes | None |
| max_tokens | Yes | Yes | None |
| top_k | Yes | Yes | None |
| top_p | Yes | Yes | None |
| stop_sequences | Yes | Yes | None |

#### Google (Vertex/Gemini)

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | None |
| temperature | Yes | Yes | None |
| max_tokens | Yes | Yes | None |
| top_p | Yes | Yes | None |
| top_k | Yes | Yes | None |
| api_endpoint | Yes | Yes | None |
| endpoint_id | Yes | Yes | None |
| project_id | Yes | Yes | None |
| region | Yes | Yes | None |
| frequency_penalty | Yes | Yes | None |
| presence_penalty | Yes | Yes | None |
| stop_sequences | Yes | Yes | None |

#### ContextualAI (Unique Parameters)

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | None |
| temperature | Yes | Yes | None |
| max_new_tokens | Yes | Yes | None |
| top_p | Yes | Yes | None |
| system_prompt | Yes | Yes | None |
| avoid_commentary | Yes | Yes | None |
| knowledge | Yes | Yes | None |

#### Databricks (Extended Parameters)

| Parameter | Python Runtime | Elixir | Gap |
|-----------|----------------|--------|-----|
| endpoint | Yes | Yes | None |
| model | Yes | Yes | None |
| temperature | Yes | Yes | None |
| max_tokens | Yes | Yes | None |
| top_p | Yes | Yes | None |
| **frequency_penalty** | Yes | **No** | **Missing** |
| **log_probs** | Yes | **No** | **Missing** |
| **n** | Yes | **No** | **Missing** |
| **presence_penalty** | Yes | **No** | **Missing** |
| **stop** | Yes | **No** | **Missing** |
| **top_log_probs** | Yes | **No** | **Missing** |

#### FriendliAI (Extended Parameters)

| Parameter | Python Runtime | Elixir | Gap |
|-----------|----------------|--------|-----|
| model | Yes | Yes | None |
| temperature | Yes | Yes | None |
| max_tokens | Yes | Yes | None |
| top_p | Yes | Yes | None |
| base_url | Yes | Yes | None |
| **n** | Yes | **No** | **Missing** |

---

## 6. Generative Result Handling

### Python Implementation

**Location:** Multiple query executor files

Python returns structured results with:
- `generated` - The generated text per object
- `generated_grouped` - The grouped task result
- Metadata including token counts, latency
- Error handling per generation

### Elixir Implementation

**Location:** `lib/weaviate_ex/generative/result.ex`

```elixir
defmodule Single do
  defstruct [:text, :metadata, :debug, :error]
end

defmodule Grouped do
  defstruct [:text, :metadata, :error]
end

defmodule GenerativeObject do
  defstruct [:uuid, :properties, :references, :vector, :collection, :generative]
end

defmodule GenerativeReturn do
  defstruct [:objects, :generative]
end
```

**Status: IMPLEMENTED (Full)**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Single result text | Yes | Yes | None |
| Grouped result text | Yes | Yes | None |
| Metadata | Yes | Yes | None |
| Debug info (full prompt) | Yes | Yes | None |
| Error per object | Yes | Yes | None |
| Response parser | Yes | Yes | None |

---

## 7. Reranking Providers

### Python Implementation

**Location:** `weaviate/collections/classes/config.py` - Rerankers enum and configs

```python
class Rerankers(str, BaseEnum):
    NONE = "none"
    COHERE = "reranker-cohere"
    CONTEXTUALAI = "reranker-contextualai"
    TRANSFORMERS = "reranker-transformers"
    VOYAGEAI = "reranker-voyageai"
    JINAAI = "reranker-jinaai"
    NVIDIA = "reranker-nvidia"
```

### Elixir Implementation

**Location:** `lib/weaviate_ex/api/reranker_config.ex`

**Status: IMPLEMENTED (Partial)**

| Reranker | Python | Elixir | Gap |
|----------|--------|--------|-----|
| None | Yes | Yes | None |
| Cohere | Yes | Yes | None |
| Transformers | Yes | Yes | None |
| VoyageAI | Yes | Yes | None |
| JinaAI | Yes | Yes | None |
| **NVIDIA** | Yes | **No** | **Missing** |
| **ContextualAI** | Yes | **No** | **Missing** |
| Custom | Yes | Yes | None |

### Reranker Config Parameters

#### Cohere

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | Yes | None |
| base_url | Yes | Yes | None |

#### ContextualAI (Python Only)

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | **No** | **Missing** |
| instruction | Yes | **No** | **Missing** |
| top_n | Yes | **No** | **Missing** |

#### NVIDIA (Python Only)

| Parameter | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| model | Yes | **No** | **Missing** |
| base_url | Yes | **No** | **Missing** |

---

## 8. Vectorizer Integrations

### Python Vectorizers

**Location:** `weaviate/collections/classes/config_vectorizers.py`

### Text2Vec Providers

| Vectorizer | Python | Elixir | Gap |
|------------|--------|--------|-----|
| text2vec-aws | Yes | Yes | None |
| text2vec-azure-openai | Yes | Yes | None |
| text2vec-cohere | Yes | **No** | **Missing** |
| text2vec-contextionary | Yes | **No** | **Missing** |
| text2vec-databricks | Yes | **No** | **Missing** |
| text2vec-gpt4all | Yes | **No** | **Missing** |
| text2vec-huggingface | Yes | **No** | **Missing** |
| text2vec-jinaai | Yes | Yes | None |
| text2vec-mistral | Yes | **No** | **Missing** |
| text2vec-model2vec | Yes | **No** | **Missing** |
| text2vec-nvidia | Yes | **No** | **Missing** |
| text2vec-ollama | Yes | Yes | None |
| text2vec-openai | Yes | **No** | **Missing** (only azure) |
| text2vec-palm/google | Yes | Yes | None |
| text2vec-transformers | Yes | Yes | None |
| text2vec-voyageai | Yes | Yes | None |
| text2vec-weaviate | Yes | Yes | None |
| **text2colbert-jinaai** | Yes | **No** | **Missing** |
| **text2vec-morph** | Yes | **No** | **Missing** |

### Multi2Vec Providers

| Vectorizer | Python | Elixir | Gap |
|------------|--------|--------|-----|
| multi2vec-clip | Yes | Yes | None |
| multi2vec-bind | Yes | **No** | **Missing** |
| multi2vec-cohere | Yes | Yes | None |
| multi2vec-google/palm | Yes | Yes | None |
| multi2vec-jinaai | Yes | **No** | **Missing** |
| multi2vec-voyageai | Yes | Yes | None |
| multi2vec-nvidia | Yes | **No** | **Missing** |
| multi2vec-aws | Yes | **No** | **Missing** |
| **multi2multivec-jinaai** | Yes | **No** | **Missing** |

### Img2Vec Providers

| Vectorizer | Python | Elixir | Gap |
|------------|--------|--------|-----|
| img2vec-neural | Yes | Yes | None |

### Ref2Vec Providers

| Vectorizer | Python | Elixir | Gap |
|------------|--------|--------|-----|
| ref2vec-centroid | Yes | Yes | None |

---

## 9. Module Configurations

### Python Multi2Vec Field Configuration

```python
class Multi2VecField(BaseModel):
    name: str
    weight: Optional[float] = Field(default=None, exclude=True)

# Usage in config
class _Multi2VecBindConfig(_Multi2VecBase):
    audioFields: Optional[List[Multi2VecField]]
    depthFields: Optional[List[Multi2VecField]]
    imageFields: Optional[List[Multi2VecField]]
    IMUFields: Optional[List[Multi2VecField]]
    textFields: Optional[List[Multi2VecField]]
    thermalFields: Optional[List[Multi2VecField]]
    videoFields: Optional[List[Multi2VecField]]
```

### Elixir Multi2Vec Field Configuration

```elixir
# From lib/weaviate_ex/api/vectorizers/multi2vec_clip.ex
@type field_config :: %{
  required(:name) => String.t(),
  optional(:weight) => float()
}

defstruct image_fields: nil,
          text_fields: nil,
          inference_url: nil,
          vectorize_collection_name: true
```

**Status: PARTIAL**

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Field names | Yes | Yes | None |
| Field weights | Yes | Yes | None |
| Audio fields (ImageBind) | Yes | **No** | **Missing** |
| Depth fields (ImageBind) | Yes | **No** | **Missing** |
| IMU fields (ImageBind) | Yes | **No** | **Missing** |
| Thermal fields (ImageBind) | Yes | **No** | **Missing** |
| Video fields | Yes | **No** | **Missing** |
| Weight aggregation | Yes | Partial | Limited |

---

## 10. Cross-References in Generative Context

### Python Support

The Python client supports cross-references in generative queries through the property interpolation syntax. Referenced objects' properties can be included in prompts.

### Elixir Support

**Status: PARTIAL**

The Elixir client supports basic property interpolation but lacks:
- Deep reference traversal in prompts
- Reference-aware context building for grouped tasks

---

## Priority Recommendations

### High Priority (Core Functionality Gaps)

1. **Add Missing Vectorizers** - Priority vectorizers:
   - `text2vec-openai` (base OpenAI, not just Azure)
   - `text2vec-cohere`
   - `text2vec-huggingface`
   - `multi2vec-bind` (ImageBind for multimodal)
   - `multi2vec-jinaai`
   - `text2vec-nvidia`

2. **Add Missing Rerankers**:
   - `reranker-nvidia`
   - `reranker-contextualai`

3. **Extended Databricks Parameters**:
   - frequency_penalty, log_probs, n, presence_penalty, stop, top_log_probs

### Medium Priority (Enhanced Features)

4. **gRPC Protocol Support**:
   - Implement gRPC for generative queries (currently GraphQL only)
   - Better performance for large-scale operations

5. **Multimodal Enhancements**:
   - File path support for images (auto base64 encoding)
   - Video field support for multi2vec-google

6. **ColBERT Support**:
   - `text2colbert-jinaai` vectorizer

### Lower Priority (Nice-to-Have)

7. **Dummy Generative Provider**:
   - For testing without API calls

8. **Additional Vectorizers**:
   - `text2vec-contextionary`
   - `text2vec-gpt4all`
   - `text2vec-model2vec`
   - `text2vec-morph`
   - `text2vec-databricks`
   - `text2vec-mistral`

9. **ImageBind Full Support**:
   - Audio, depth, IMU, thermal fields for multi2vec-bind

---

## API Differences Summary

### Generative Query Approach

**Python (Fluent API):**
```python
response = collection.generate.near_text(
    query="machine learning",
    single_prompt="Summarize: {title}",
    grouped_task="Compare all articles",
    limit=5
)
```

**Elixir (Builder Pattern):**
```elixir
Generate.new("Article")
|> Generate.near_text("machine learning")
|> Generate.single_prompt("Summarize: {title}")
|> Generate.grouped_task("Compare all articles")
|> Generate.limit(5)
|> Generate.execute(client)
```

### Config Factory Methods

**Python:**
```python
from weaviate.classes.config import Configure

# Generative config
gen_config = Configure.Generative.openai(model="gpt-4")

# Vectorizer config
vec_config = Configure.Vectorizer.text2vec_openai()

# Reranker config
rerank_config = Configure.Reranker.cohere()
```

**Elixir:**
```elixir
alias WeaviateEx.API.{GenerativeConfig, RerankerConfig}
alias WeaviateEx.API.Vectorizers.Text2VecOpenAI

# Generative config
gen_config = GenerativeConfig.openai(model: "gpt-4")

# Vectorizer config
vec_config = Text2VecOpenAI.new(model: "text-embedding-3-small")

# Reranker config
rerank_config = RerankerConfig.cohere("rerank-english-v3.0")
```

---

## Implementation Roadmap

### Phase 1: Critical Gaps (Immediate)

| Task | Effort | Impact |
|------|--------|--------|
| Add text2vec-openai | Low | High |
| Add text2vec-cohere | Low | High |
| Add reranker-nvidia | Low | Medium |
| Add reranker-contextualai | Low | Medium |

### Phase 2: Core Features (Near-term)

| Task | Effort | Impact |
|------|--------|--------|
| Add text2vec-huggingface | Medium | High |
| Add multi2vec-bind | Medium | Medium |
| Add text2vec-nvidia | Low | Medium |
| Extended Databricks params | Low | Low |

### Phase 3: Advanced Features (Medium-term)

| Task | Effort | Impact |
|------|--------|--------|
| gRPC generative support | High | High |
| File path image support | Medium | Medium |
| Video fields support | Medium | Low |

### Phase 4: Complete Parity (Long-term)

| Task | Effort | Impact |
|------|--------|--------|
| All remaining vectorizers | High | Low |
| Dummy generative provider | Low | Low |
| Full ImageBind support | Medium | Low |

---

## File Reference

### Python Files Analyzed

- `/weaviate-python-client/weaviate/collections/classes/generative.py` - Runtime generative configs
- `/weaviate-python-client/weaviate/collections/generate.py` - Generate collection class
- `/weaviate-python-client/weaviate/collections/classes/config.py` - Collection-level configs
- `/weaviate-python-client/weaviate/collections/classes/config_vectorizers.py` - Vectorizer configs

### Elixir Files Analyzed

- `/lib/weaviate_ex/generative/config.ex` - Provider config structs
- `/lib/weaviate_ex/generative/result.ex` - Result parsing
- `/lib/weaviate_ex/generative/parameters.ex` - Query parameters
- `/lib/weaviate_ex/api/generative.ex` - Generative API
- `/lib/weaviate_ex/api/generative_config.ex` - Collection configs
- `/lib/weaviate_ex/query/generate.ex` - Query builder
- `/lib/weaviate_ex/api/reranker_config.ex` - Reranker configs
- `/lib/weaviate_ex/api/vectorizers/*.ex` - Vectorizer modules
