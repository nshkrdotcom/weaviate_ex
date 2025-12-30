# Generative AI / RAG Gap Analysis

## Overview

This document provides a deep gap analysis comparing the Generative AI (RAG) functionality between the canonical Python Weaviate client and the WeaviateEx Elixir port.

**Analysis Date:** 2025-12-29
**Python Client Version:** weaviate-python-client (latest)
**Elixir Port:** WeaviateEx

---

## Executive Summary

The Elixir implementation provides solid foundational support for generative search (RAG) with 21+ provider integrations and basic single/grouped generation. However, several critical gaps exist, particularly around:

1. **gRPC-based generation** - Python uses gRPC protocol for generation; Elixir uses GraphQL only
2. **Multimodal support** - Python has full image/media support; Elixir has structs but no implementation
3. **Generation metadata** - Python extracts provider-specific metadata; Elixir has basic parsing only
4. **Dynamic RAG providers** - Python supports runtime provider switching; Elixir requires provider at call time
5. **GroupBy with generation** - Python supports generative group-by; Elixir does not implement this

---

## 1. Single Prompt Generation

### Python Implementation

The Python client supports single prompt generation through multiple interfaces:

```python
# Via GenerativeParameters factory
GenerativeParameters.single_prompt(
    prompt="Summarize: {content}",
    image_properties=["product_image"],  # Multimodal
    images=[base64_image],               # External images
    metadata=True,                        # Return metadata
    debug=True                           # Return full prompt
)

# Direct string prompt (legacy)
collection.generate.near_text(
    query="AI",
    single_prompt="Summarize this: {title}"
)

# gRPC protocol message
GenerativeSearch.Single(
    prompt="...",
    debug=True,
    queries=[GenerativeProvider(...)]
)
```

**Key Features:**
- Debug mode returns full prompt sent to LLM
- Metadata returns token usage and provider-specific info
- Supports image_properties for multimodal from object properties
- Supports external images (base64 or file path)
- Non-blob properties filtering

### Elixir Implementation

```elixir
# Via API module
Generative.single_prompt(client, "Article", "Summarize: {title}",
  provider: :openai,
  temperature: 0.7,
  max_tokens: 500
)

# Via Parameters module (typed struct)
Parameters.single_prompt("Summarize: {content}",
  images: [base64_data],
  image_properties: ["product_image"],
  metadata: true,
  debug: true
)

# Via Query builder
Generate.new("Article")
|> Generate.near_text("AI")
|> Generate.single_prompt("Summarize: {title}")
|> Generate.execute(client)
```

### Critical Gaps

| Feature | Python | Elixir | Gap Level |
|---------|--------|--------|-----------|
| Basic single prompt | Yes | Yes | None |
| Property interpolation | Yes | Yes | None |
| Debug mode (full prompt) | Yes | Struct defined, not wired | Medium |
| Metadata return | Yes | Struct defined, not wired | Medium |
| External images | Yes | Struct defined, not implemented | Critical |
| Image properties | Yes | Struct defined, not implemented | Critical |
| gRPC protocol | Yes | No (GraphQL only) | Medium |

### Minor Gaps

- Python supports both string prompts and typed `_SinglePrompt` objects; Elixir requires specific function calls
- Python validates multimodal support per provider; Elixir does not

---

## 2. Grouped Generation

### Python Implementation

```python
# Via GenerativeParameters factory
GenerativeParameters.grouped_task(
    prompt="Compare these articles",
    non_blob_properties=["title", "summary"],  # Properties for context
    image_properties=["cover_image"],           # Multimodal
    images=[external_image],
    metadata=True
)

# gRPC protocol
GenerativeSearch.Grouped(
    task="...",
    properties=TextArray(values=["title", "summary"]),
    queries=[GenerativeProvider(...)],
    debug=True
)
```

**Key Features:**
- `non_blob_properties` controls which properties are included in generation context
- Grouped task operates on all retrieved objects collectively
- Returns single generated result for the entire group
- Supports debug mode for grouped tasks (v1.27+)

### Elixir Implementation

```elixir
# Via API module
Generative.grouped_task(client, "Article", "Summarize: {title}",
  provider: :openai,
  limit: 10
)

# Via Query builder
Generate.new("Article")
|> Generate.bm25("elixir")
|> Generate.grouped_task("Write a summary", properties: ["title", "content"])
|> Generate.execute(client)

# Via Parameters module
Parameters.grouped_task("Compare products",
  image_properties: ["product_image"],
  non_blob_properties: ["name", "price"]
)
```

### Critical Gaps

| Feature | Python | Elixir | Gap Level |
|---------|--------|--------|-----------|
| Basic grouped task | Yes | Yes | None |
| Properties for context | Yes | Yes | None |
| Non-blob properties filtering | Yes | Struct defined, not wired | Medium |
| Image properties | Yes | Struct defined, not implemented | Critical |
| External images | Yes | Struct defined, not implemented | Critical |
| Debug mode for grouped | Yes | No | Medium |

### Minor Gaps

- Python's `GroupedTask` is a typed Pydantic model; Elixir uses a defstruct
- Elixir does not validate property existence before generation

---

## 3. Provider Configurations

### Python Implementation (GenerativeConfig Factory)

Python provides a comprehensive `GenerativeConfig` factory class with 19+ provider configurations:

```python
class GenerativeConfig:
    @staticmethod
    def openai(
        api_version=None,
        base_url=None,
        deployment_id=None,        # Azure
        frequency_penalty=None,
        max_tokens=None,
        model=None,
        presence_penalty=None,
        reasoning_effort=None,     # O1/O3 models
        resource_name=None,        # Azure
        stop=None,
        temperature=None,
        top_p=None,
        verbosity=None             # O1/O3 models
    )

    @staticmethod
    def anthropic(
        base_url=None,
        model=None,
        max_tokens=None,
        stop_sequences=None,
        temperature=None,
        top_k=None,
        top_p=None
    )

    # Plus: cohere, mistral, ollama, google_vertex, google_gemini,
    # aws_bedrock, aws_sagemaker, azure_openai, anyscale, nvidia,
    # databricks, friendliai, xai, contextualai, dummy
```

**Provider Count:** 19+ providers with distinct configurations

### Elixir Implementation (Config Module)

```elixir
defmodule WeaviateEx.Generative.Config do
  # OpenAI (with Azure support)
  defmodule OpenAI do
    defstruct [
      :model, :temperature, :max_tokens, :top_p,
      :frequency_penalty, :presence_penalty, :stop,
      :base_url, :api_version, :deployment_id, :resource_name,
      :verbosity, :reasoning_effort,
      is_azure: false
    ]
  end

  # Anthropic, Cohere, AWS, Google, Mistral, Ollama,
  # XAI, ContextualAI, Nvidia, Databricks, FriendliAI, Anyscale

  # Factory functions
  def openai(opts), def azure_openai(opts), def anthropic(opts),
  def cohere(opts), def aws_bedrock(opts), def aws_sagemaker(opts),
  def google_vertex(opts), def google_gemini(opts), def mistral(opts),
  def ollama(opts), def xai(opts), def contextualai(opts),
  def nvidia(opts), def databricks(opts), def friendliai(opts),
  def anyscale(opts)
end
```

**Provider Count:** 16 providers with typed configurations

### Provider Comparison Table

| Provider | Python | Elixir | Notes |
|----------|--------|--------|-------|
| OpenAI | Full | Full | Both support O1/O3 reasoning params |
| Azure OpenAI | Full | Full | `is_azure` flag |
| Anthropic | Full | Full | All params supported |
| Cohere | Full | Full | Including k, p params |
| AWS Bedrock | Full | Full | Service-specific configs |
| AWS SageMaker | Full | Full | target_model, target_variant |
| Google Vertex | Full | Full | project_id, region, endpoint_id |
| Google Gemini | Full | Full | Via Google struct |
| Google PaLM | Deprecated | Partial | Python deprecated, Elixir uses atom |
| Mistral | Full | Full | |
| Ollama | Full | Full | api_endpoint for Docker |
| XAI (Grok) | Full | Full | |
| ContextualAI | Full | Full | system_prompt, avoid_commentary, knowledge |
| NVIDIA | Full | Full | |
| Databricks | Full | Partial | Missing: frequency_penalty, n, log_probs, top_log_probs |
| FriendliAI | Full | Partial | Missing: n param |
| Anyscale | Full | Full | |
| HuggingFace | Listed | Listed | Not in Python GenerativeConfig, just in API module |
| OctoAI | Listed | Listed | Not in Python GenerativeConfig, just in API module |
| Together AI | Listed | Listed | Not in Python GenerativeConfig, just in API module |
| Voyage AI | Listed | Listed | Not in Python GenerativeConfig, just in API module |
| Dummy | Yes | No | Testing provider |

### Critical Gaps

| Feature | Python | Elixir | Gap Level |
|---------|--------|--------|-----------|
| Dummy provider | Yes | No | Minor |
| Databricks full params | Yes | Partial | Minor |
| FriendliAI n param | Yes | No | Minor |
| Base URL validation | Pydantic AnyHttpUrl | No validation | Minor |

### Minor Gaps

- Python uses Pydantic models with URL validation; Elixir uses plain structs
- Python providers extend `_GenerativeConfigRuntime` base; Elixir uses separate modules
- Python has `_to_grpc()` method on each provider; Elixir has `to_graphql_params/1`

---

## 4. Generation Parameters

### Python Implementation

**Common Parameters (all providers):**
```python
- model: str
- temperature: float
- max_tokens: int
- top_p: float
```

**OpenAI-specific:**
```python
- frequency_penalty: float
- presence_penalty: float
- stop: List[str]
- base_url: AnyHttpUrl
- api_version: str           # Azure
- deployment_id: str         # Azure
- resource_name: str         # Azure
- is_azure: bool
- verbosity: OpenAiVerbosity  # O1/O3: low, medium, high
- reasoning_effort: OpenAiReasoningEffort  # O1/O3: minimal, low, medium, high
```

**Cohere-specific:**
```python
- k: int        # top_k
- p: float      # top_p (different name)
- presence_penalty: float
- stop_sequences: List[str]
```

**Google-specific:**
```python
- api_endpoint: str
- project_id: str
- endpoint_id: str
- region: str
- frequency_penalty: float
- presence_penalty: float
- top_k: int
- stop_sequences: List[str]
```

**AWS-specific:**
```python
- service: str  # "bedrock" or "sagemaker"
- region: str
- endpoint: str
- target_model: str
- target_variant: str
- top_k: int
- stop_sequences: List[str]
```

**ContextualAI-specific:**
```python
- system_prompt: str
- avoid_commentary: bool
- max_new_tokens: int
- knowledge: List[str]  # Override retrieved context
```

**Databricks-specific:**
```python
- endpoint: str (required)
- frequency_penalty: float
- log_probs: bool
- top_log_probs: int
- n: int
- presence_penalty: float
- stop: List[str]
```

### Elixir Implementation

**Common Parameters:**
```elixir
:model, :temperature, :max_tokens, :top_p
```

**OpenAI-specific:**
```elixir
:frequency_penalty, :presence_penalty, :stop, :base_url,
:api_version, :deployment_id, :resource_name, :is_azure,
:verbosity, :reasoning_effort
```

**Cohere-specific:**
```elixir
:k, :p, :presence_penalty, :stop_sequences, :base_url
```

**Google-specific:**
```elixir
:api_endpoint, :project_id, :endpoint_id, :region,
:frequency_penalty, :presence_penalty, :top_k, :stop_sequences
```

**AWS-specific:**
```elixir
:service, :region, :endpoint, :target_model, :target_variant,
:top_k, :stop_sequences
```

**ContextualAI-specific:**
```elixir
:system_prompt, :avoid_commentary, :max_new_tokens, :knowledge
```

**Databricks-specific:**
```elixir
:endpoint  # Missing: frequency_penalty, log_probs, n, etc.
```

### Critical Gaps

| Parameter | Python | Elixir | Gap Level |
|-----------|--------|--------|-----------|
| Databricks log_probs | Yes | No | Minor |
| Databricks top_log_probs | Yes | No | Minor |
| Databricks n | Yes | No | Minor |
| Databricks frequency_penalty | Yes | No | Minor |
| Databricks presence_penalty | Yes | No | Minor |
| FriendliAI n | Yes | No | Minor |

---

## 5. Result Handling

### Python Implementation

Python provides rich typed result structures:

```python
@dataclass
class GenerativeSingle:
    """Per-object generation result."""
    debug: Optional[GenerativeDebug]      # full_prompt
    metadata: Optional[GenerativeMetadata] # Provider-specific usage
    text: Optional[str]

@dataclass
class GenerativeGrouped:
    """Grouped generation result."""
    metadata: Optional[GenerativeMetadata]
    text: Optional[str]

class GenerativeObject(Object[P, R]):
    """Object with generation."""
    generated: Optional[str]  # Deprecated, use generative.text
    generative: Optional[GenerativeSingle]

class GenerativeReturn(Generic[P, R]):
    """Full return type."""
    generated: Optional[str]  # Deprecated
    objects: List[GenerativeObject[P, R]]
    generative: Optional[GenerativeGrouped]

# Provider-specific metadata types
GenerativeMetadata = Union[
    GenerativeAnthropicMetadata,   # {usage: {input_tokens, output_tokens}}
    GenerativeOpenAIMetadata,      # {usage: {prompt_tokens, completion_tokens, total_tokens}}
    GenerativeCohereMetadata,      # {api_version, billed_units, tokens, warnings}
    GenerativeGoogleMetadata,      # {metadata: {token_metadata}, usage_metadata}
    GenerativeMistralMetadata,
    GenerativeNvidiaMetadata,
    GenerativeDatabricksMetadata,
    GenerativeFriendliAIMetadata,
    GenerativeOllamaMetadata,
    GenerativeAWSMetadata,
    GenerativeAnyscaleMetadata,
    GenerativeDummyMetadata,
    GenerativeXAIMetadata,
]
```

**Key Features:**
- Typed metadata extraction per provider
- Token usage tracking (input, output, total)
- Debug info with full prompt
- Deprecation warnings for old `generated` field
- Support for GroupBy results with generation

### Elixir Implementation

```elixir
# Result module (lib/weaviate_ex/generative/result.ex)
defmodule WeaviateEx.Generative.Result do
  defmodule Single do
    defstruct [:text, :metadata, :debug, :error]
    # debug_info :: %{full_prompt: String.t()}
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

  defmodule ResponseParser do
    def parse(response, collection) do
      # Basic parsing - extracts singleResult/groupedResult
      # Does NOT parse provider-specific metadata
    end
  end
end

# Query result (lib/weaviate_ex/query/generative_result.ex)
defmodule WeaviateEx.Query.GenerativeResult do
  defstruct [:objects, :generated, :generated_per_object]
end
```

### Critical Gaps

| Feature | Python | Elixir | Gap Level |
|---------|--------|--------|-----------|
| Basic text extraction | Yes | Yes | None |
| Error field | Yes | Yes | None |
| Debug full_prompt | Yes | Struct exists, no parsing | Medium |
| Provider-specific metadata | 13 types | Generic map only | Critical |
| Token usage tracking | Yes | No | Critical |
| API version tracking (Cohere) | Yes | No | Minor |
| Billed units (Cohere) | Yes | No | Minor |
| GenerativeGroupByReturn | Yes | No | Critical |

### Minor Gaps

- Python uses dataclasses with property decorators; Elixir uses defstruct
- Python has deprecation warnings; Elixir does not have this pattern
- Python supports generic typing for properties/references; Elixir uses maps

---

## 6. Error Handling

### Python Implementation

```python
# Validation errors
class WeaviateInvalidInputError(Exception):
    """Raised when input validation fails."""

# Feature not supported
class WeaviateUnsupportedFeatureError(Exception):
    """Raised when using features not available in server version."""

# In _Generative.to_grpc():
if server_version.is_lower_than(1, 27, 14):
    if self.generative_provider is not None:
        raise WeaviateUnsupportedFeatureError("Dynamic RAG", str(server_version), "1.27.14")

# Provider multimodal validation
def _validate_multi_modal(self, opts):
    if opts.images is not None or opts.image_properties is not None:
        raise WeaviateInvalidInputError(
            f"The {self.generative.value} module does not support images"
        )

# URL validation via Pydantic
base_url: Optional[AnyHttpUrl]  # Validates URL format
```

**Error Types:**
- `WeaviateInvalidInputError` - Input validation failures
- `WeaviateUnsupportedFeatureError` - Version incompatibility
- Provider-specific validation (multimodal support)
- Pydantic validation for URLs and parameters

### Elixir Implementation

```elixir
# Error struct
defmodule WeaviateEx.Error do
  defstruct [:type, :message, :details]
  # Types: :validation_error, :connection_error, :api_error, etc.
end

# Provider validation
defp validate_provider(nil) do
  {:error, %Error{type: :validation_error, message: "Provider is required"}}
end

defp validate_provider(provider) when provider not in @valid_providers do
  {:error, %Error{
    type: :validation_error,
    message: "Invalid provider: #{provider}"
  }}
end

# Prompt validation
defp validate_prompt(""), do: {:error, %Error{...}}
defp validate_prompt(nil), do: {:error, %Error{...}}

# API error extraction
case Client.request(...) do
  {:ok, %{"data" => ...}} -> ...
  {:error, _} = error -> error
end
```

### Critical Gaps

| Feature | Python | Elixir | Gap Level |
|---------|--------|--------|-----------|
| Basic validation | Yes | Yes | None |
| Provider validation | Yes | Yes | None |
| Prompt validation | Yes | Yes | None |
| Version compatibility check | Yes | No | Medium |
| Multimodal support validation | Yes | No | Medium |
| URL format validation | Pydantic | No | Minor |
| Specific exception types | 2+ types | 1 struct with type atom | Minor |

### Minor Gaps

- Python raises exceptions; Elixir returns `{:error, struct}` tuples (idiomatic difference)
- Python has distinct exception classes; Elixir uses `:type` atom in single struct
- Python validates at gRPC serialization time; Elixir validates at call time

---

## 7. Additional Gaps

### gRPC Protocol Support

**Python:**
- Full gRPC support via protobuf messages
- `GenerativeSearch`, `GenerativeProvider`, `GenerativeResult` protos
- Version-aware serialization (pre/post 1.27.14)

**Elixir:**
- GraphQL only (no gRPC for generation)
- Manual GraphQL query building
- No version-aware protocol switching

### Multimodal Generation

**Python:**
```python
# External images
images: Optional[Union[BLOB_INPUT, Iterable[BLOB_INPUT]]]
# From object properties
image_properties: Optional[List[str]]

# Blob parsing
def parse_blob(input):
    if isinstance(input, (str, Path)):
        # File path -> read and base64
    elif isinstance(input, BufferedReader):
        # Buffer -> base64
    else:
        # Already base64
```

**Elixir:**
```elixir
# Structs exist but implementation missing
defstruct [..., :images, :image_properties, ...]

# to_graphql_clause builds the string but...
# No blob parsing implementation
# No file reading implementation
# No base64 encoding for images
```

### GroupBy with Generation

**Python:**
```python
@dataclass
class GenerativeGroup(Group[P, R]):
    """Group with generation."""
    generated: Optional[str]

@dataclass
class GenerativeGroupByReturn(Generic[P, R]):
    objects: List[GroupByObject[P, R]]
    groups: Dict[str, GenerativeGroup[P, R]]
    generated: Optional[str]
```

**Elixir:**
- No `GenerativeGroup` equivalent
- No `GenerativeGroupByReturn` equivalent
- Query builder does not support group_by with generation

### Dynamic Provider Selection

**Python:**
```python
# Can specify provider at query time
collection.generate.near_text(
    query="AI",
    single_prompt="Summarize",
    generative_provider=GenerativeConfig.openai(model="gpt-4")
)

# Version check for dynamic RAG
if server_version.is_lower_than(1, 27, 14):
    raise WeaviateUnsupportedFeatureError("Dynamic RAG", ...)
```

**Elixir:**
- Provider required at call time (no dynamic switching)
- No server version checking for feature availability

---

## 8. API Differences Summary

| Aspect | Python | Elixir |
|--------|--------|--------|
| Primary API | `collection.generate.near_text()` | `Generative.single_prompt()` / `Generate.new()` |
| Query types | bm25, fetch_objects, fetch_objects_by_ids, hybrid, near_image, near_media, near_object, near_text, near_vector | near_text, near_vector, near_object, bm25, hybrid |
| Protocol | gRPC (primary) + GraphQL | GraphQL only |
| Async support | Full async variants | Via Task/async Elixir patterns |
| Type hints | Full Generic types | Typespecs |
| Validation | Pydantic + runtime | Custom validation functions |
| Result types | Dataclasses with properties | Structs |

---

## 9. Recommendations

### High Priority (Critical Gaps)

1. **Implement multimodal support**
   - Add blob/image parsing utilities
   - Wire image_properties and images to GraphQL queries
   - Add file reading and base64 encoding

2. **Add provider-specific metadata parsing**
   - Create typed structs for each provider's metadata
   - Extract token usage from responses
   - Parse debug info (full_prompt)

3. **Implement GenerativeGroupByReturn**
   - Add group-by support to query builder
   - Create GenerativeGroup struct
   - Parse grouped results with generation

### Medium Priority

4. **Add version compatibility checking**
   - Check server version for Dynamic RAG (1.27.14+)
   - Warn or error on unsupported features

5. **Wire debug and metadata options**
   - Pass debug flag through to GraphQL
   - Request and parse metadata when enabled

6. **Add multimodal validation per provider**
   - Validate that provider supports images before querying
   - Provide helpful error messages

### Low Priority

7. **Add Dummy provider** for testing

8. **Complete Databricks and FriendliAI parameters**
   - Add missing params: n, log_probs, frequency_penalty, etc.

9. **Add URL validation** for base_url parameters

10. **Consider gRPC support** for better performance and feature parity

---

## 10. Conclusion

The WeaviateEx Elixir port provides a solid foundation for generative search with:
- 16+ provider configurations
- Single prompt and grouped task generation
- Query builder with multiple search types
- Basic result parsing

However, critical gaps exist in:
- Multimodal (image) support (structs exist but not wired)
- Provider-specific metadata extraction (no token usage tracking)
- GroupBy with generation support
- gRPC protocol (GraphQL only)

The implementation follows idiomatic Elixir patterns (tuples, structs, pattern matching) rather than direct Python translation, which is appropriate. Priority should be given to multimodal support and metadata extraction as these are commonly used RAG features.
