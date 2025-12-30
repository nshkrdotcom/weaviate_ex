# Deep Gap Analysis: Schema and Collections Management

**Date:** 2025-12-29
**Comparison:** Python Weaviate Client v4.x (canonical) vs WeaviateEx (Elixir)
**Focus:** Schema creation, collection configuration, property definitions, vectorizer/module configuration

---

## Executive Summary

The Elixir WeaviateEx client has achieved **strong functional parity** (~85-90%) with the Python client for schema and collections management. Core CRUD operations, property definitions, vectorizer configurations, and index settings are well-implemented through a fluent builder pattern.

### Key Strengths (Elixir)
- Comprehensive Property builder with all 17 data types
- 25+ vectorizer configurations with proper module configs
- All 4 quantization methods (PQ, BQ, SQ, RQ) with typed structs
- Full HNSW/FLAT/DYNAMIC index support
- Complete BM25 and stopwords configuration
- Fluent builder pattern via `VectorConfig` module

### Critical Gaps Identified
1. **Typed Configuration Validation** - Python uses Pydantic models; Elixir uses plain maps
2. **Multi-Vector (ColBERT) Support** - Python has Muvera encoding; Elixir lacks this
3. **Object TTL Configuration** - Not implemented in Elixir
4. **Multi-Target References** - `ReferenceProperty.MultiTarget` not implemented
5. **Auto-Tenant Configuration** - `auto_tenant_creation`/`auto_tenant_activation` not exposed
6. **Index Range Filters** - `index_range_filters` property option missing
7. **Custom Vectorizer** - Python's `Vectorizer.custom()` not implemented

### Implementation Priority
1. **P0 (Critical):** Object TTL, auto-tenant configuration, multi-target references
2. **P1 (High):** Multi-vector/ColBERT support, index range filters, typed validation
3. **P2 (Medium):** Custom vectorizer, Skip quantization option, deprecation warnings

---

## 1. Schema Creation, Update, and Deletion

### 1.1 Collection CRUD Operations

#### Python Implementation
```python
# File: weaviate/collections/collections/executor.py

def create(
    self,
    name: str,
    *,
    description: Optional[str] = None,
    generative_config: Optional[_GenerativeProvider] = None,
    inverted_index_config: Optional[_InvertedIndexConfigCreate] = None,
    multi_tenancy_config: Optional[_MultiTenancyConfigCreate] = None,
    object_ttl_config: Optional[_ObjectTTLConfigCreate] = None,
    properties: Optional[Sequence[Property]] = None,
    references: Optional[List[_ReferencePropertyBase]] = None,
    replication_config: Optional[_ReplicationConfigCreate] = None,
    reranker_config: Optional[_RerankerProvider] = None,
    sharding_config: Optional[_ShardingConfigCreate] = None,
    vector_index_config: Optional[_VectorIndexConfigCreate] = None,
    vectorizer_config: Optional[_VectorizerConfigCreate] = None,
    vector_config: Optional[List[_NamedVectorConfigCreate]] = None,
) -> Collection

def create_from_dict(self, config: dict) -> Collection
def create_from_config(self, config: CollectionConfig) -> Collection
```

#### Elixir Implementation
```elixir
# File: lib/weaviate_ex/api/collections.ex

@spec create(Client.t(), map(), opts()) :: {:ok, map()} | {:error, Error.t()}
def create(client, config, opts \\ [])

@spec update(Client.t(), String.t(), map(), opts()) :: {:ok, map()} | {:error, Error.t()}
def update(client, collection_name, updates, opts \\ [])

@spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
def delete(client, collection_name)

@spec delete_all(Client.t()) :: {:ok, keyword()} | {:error, Error.t()}
def delete_all(client)
```

### 1.2 Feature Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Create collection | `collections.create()` | `Collections.create/3` | Implemented |
| Create from dict | `create_from_dict()` | Direct map to `create/3` | Implemented |
| Create from config | `create_from_config()` | Via builder pattern | Implemented |
| Get collection | `collections.get()` | `Collections.get/2` | Implemented |
| List collections | `collections.list_all()` | `Collections.list/1` | Implemented |
| Delete collection | `collection.delete()` | `Collections.delete/2` | Implemented |
| Delete all | `collections.delete_all()` | `Collections.delete_all/1` | Implemented |
| Exists check | `collections.exists()` | `Collections.exists?/2` | Implemented |
| Update collection | `collection.config.update()` | `Collections.update/4` | Implemented |
| Add property | `collection.config.add_property()` | `Collections.add_property/3` | Implemented |
| Get shards | `collection.config.get_shards()` | `Collections.get_shards/3` | Implemented |
| Set multi-tenancy | N/A (at create time) | `Collections.set_multi_tenancy/4` | Implemented |
| Object TTL config | `object_ttl_config=` parameter | **Not Implemented** | **Missing** |

### 1.3 Identified Gaps

#### Gap 1: Object TTL Configuration
**Python Location:** `weaviate/collections/classes/config_object_ttl.py`
```python
class _ObjectTTLConfigCreate(_ConfigCreateModel):
    enabled: bool = True
    timeToLive: Optional[str]  # Duration string like "24h", "7d"
    filterExpiredObjects: bool = True
    deleteOn: Literal["updateTime", "creationTime"] = "creationTime"
```

**Elixir Status:** Not implemented. No equivalent module or option.

**Recommendation:** Create `WeaviateEx.API.ObjectTTL` module with builder functions.

---

## 2. Collection/Class Configuration Options

### 2.1 Python Configuration Classes
```python
# File: weaviate/collections/classes/config.py

class _CollectionConfig:
    name: str
    description: Optional[str]
    generative_config: Optional[GenerativeConfig]
    inverted_index_config: InvertedIndexConfig
    multi_tenancy_config: MultiTenancyConfig
    object_ttl_config: Optional[ObjectTTLConfig]
    properties: List[PropertyConfig]
    references: List[ReferencePropertyConfig]
    replication_config: ReplicationConfig
    reranker_config: Optional[RerankerConfig]
    sharding_config: Optional[ShardingConfig]
    vector_index_config: Union[VectorIndexConfigHNSW, VectorIndexConfigFlat, VectorIndexConfigDynamic, None]
    vector_index_type: Optional[VectorIndexType]
    vectorizer_config: Optional[VectorizerConfig]
    vectorizer: Optional[Union[Vectorizers, str]]
    vector_config: Optional[Dict[str, _NamedVectorConfig]]
```

### 2.2 Elixir Builder Pattern
```elixir
# File: lib/weaviate_ex/api/vector_config.ex

VectorConfig.new("Article")
|> VectorConfig.with_vectorizer(:text2vec_openai, model: "...")
|> VectorConfig.with_hnsw_index(ef: 100, max_connections: 64)
|> VectorConfig.with_properties([...])
|> VectorConfig.with_replication_config(factor: 3)
|> VectorConfig.with_sharding_config(desired_count: 3)
|> VectorConfig.with_multi_tenancy(enabled: true)
```

### 2.3 Configuration Feature Matrix

| Configuration Area | Python | Elixir | Status |
|-------------------|--------|--------|--------|
| Collection name | `name=` | `VectorConfig.new/1` | Implemented |
| Description | `description=` | Map key `"description"` | Implemented |
| Properties | `properties=` | `with_properties/2` | Implemented |
| References | `references=` | `Property.reference/3` | Implemented |
| Vectorizer config | `vectorizer_config=` | `with_vectorizer/3` | Implemented |
| Vector index config | `vector_index_config=` | `with_hnsw_index/2`, etc. | Implemented |
| Inverted index config | `inverted_index_config=` | Via `InvertedIndexConfig.build/1` | Implemented |
| Replication config | `replication_config=` | `with_replication_config/2` | Implemented |
| Sharding config | `sharding_config=` | `with_sharding_config/2` | Implemented |
| Multi-tenancy config | `multi_tenancy_config=` | `with_multi_tenancy/2` | Partial |
| Object TTL config | `object_ttl_config=` | **Not implemented** | **Missing** |
| Generative config | `generative_config=` | Via module config | Implemented |
| Reranker config | `reranker_config=` | `with_reranker/3` | Implemented |
| Named vectors | `vector_config=` | `with_named_vectors/2` | Implemented |

### 2.4 Multi-Tenancy Configuration Gap

#### Python
```python
class _MultiTenancyConfigCreate(_ConfigCreateModel):
    enabled: bool
    autoTenantCreation: Optional[bool]
    autoTenantActivation: Optional[bool]
```

#### Elixir
```elixir
def with_multi_tenancy(config, opts \\ []) do
  mt_config = %{
    "enabled" => Keyword.get(opts, :enabled, false)
  }
  Map.put(config, "multiTenancyConfig", mt_config)
end
```

**Gap:** Elixir is missing `autoTenantCreation` and `autoTenantActivation` options.

**Recommendation:** Update `with_multi_tenancy/2` to accept these options:
```elixir
def with_multi_tenancy(config, opts \\ []) do
  mt_config = %{
    "enabled" => Keyword.get(opts, :enabled, false)
  }
  |> maybe_put("autoTenantCreation", Keyword.get(opts, :auto_tenant_creation))
  |> maybe_put("autoTenantActivation", Keyword.get(opts, :auto_tenant_activation))

  Map.put(config, "multiTenancyConfig", mt_config)
end
```

---

## 3. Property Definitions and Data Types

### 3.1 Supported Data Types

| Data Type | Python Enum | Elixir Atom | Weaviate String | Status |
|-----------|-------------|-------------|-----------------|--------|
| Text | `DataType.TEXT` | `:text` | `"text"` | Implemented |
| Text Array | `DataType.TEXT_ARRAY` | `:text_array` | `"text[]"` | Implemented |
| Integer | `DataType.INT` | `:int` | `"int"` | Implemented |
| Integer Array | `DataType.INT_ARRAY` | `:int_array` | `"int[]"` | Implemented |
| Number | `DataType.NUMBER` | `:number` | `"number"` | Implemented |
| Number Array | `DataType.NUMBER_ARRAY` | `:number_array` | `"number[]"` | Implemented |
| Boolean | `DataType.BOOL` | `:boolean` | `"boolean"` | Implemented |
| Boolean Array | `DataType.BOOL_ARRAY` | `:boolean_array` | `"boolean[]"` | Implemented |
| Date | `DataType.DATE` | `:date` | `"date"` | Implemented |
| Date Array | `DataType.DATE_ARRAY` | `:date_array` | `"date[]"` | Implemented |
| UUID | `DataType.UUID` | `:uuid` | `"uuid"` | Implemented |
| UUID Array | `DataType.UUID_ARRAY` | `:uuid_array` | `"uuid[]"` | Implemented |
| Geo Coordinates | `DataType.GEO_COORDINATES` | `:geo_coordinates` | `"geoCoordinates"` | Implemented |
| Blob | `DataType.BLOB` | `:blob` | `"blob"` | Implemented |
| Phone Number | `DataType.PHONE_NUMBER` | `:phone_number` | `"phoneNumber"` | Implemented |
| Object | `DataType.OBJECT` | `:object` | `"object"` | Implemented |
| Object Array | `DataType.OBJECT_ARRAY` | `:object_array` | `"object[]"` | Implemented |

**Status: Full Parity** - All 17 data types implemented.

### 3.2 Property Options Comparison

#### Python Property Definition
```python
# File: weaviate/collections/classes/config.py

class Property(_ConfigCreateModel):
    name: str
    dataType: DataType
    description: Optional[str] = None
    indexFilterable: Optional[bool] = True
    indexSearchable: Optional[bool] = True
    indexRangeFilters: Optional[bool] = False
    nestedProperties: Optional[Union["Property", List["Property"]]] = None
    skip_vectorization: bool = False
    tokenization: Optional[Tokenization] = None
    vectorize_property_name: bool = True
```

#### Elixir Property Definition
```elixir
# File: lib/weaviate_ex/property.ex

def new(name, data_type, opts \\ []) do
  %{
    "name" => name,
    "dataType" => [normalize_data_type(data_type)]
  }
  |> maybe_put("description", Keyword.get(opts, :description))
  |> maybe_put("indexFilterable", Keyword.get(opts, :index_filterable))
  |> maybe_put("indexSearchable", Keyword.get(opts, :index_searchable))
  |> maybe_put("indexInverted", Keyword.get(opts, :index_inverted))
  |> maybe_put("tokenization", normalize_tokenization(Keyword.get(opts, :tokenization)))
  |> maybe_add_nested_properties(Keyword.get(opts, :nested_properties))
  |> maybe_add_module_config(opts)
end
```

### 3.3 Property Feature Matrix

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic properties | `Property(name=, dataType=)` | `Property.new/3` | Implemented |
| Convenience constructors | N/A | `Property.text/2`, `Property.int/2`, etc. | Enhanced |
| Description | `description=` | `description:` | Implemented |
| Index filterable | `indexFilterable=` | `index_filterable:` | Implemented |
| Index searchable | `indexSearchable=` | `index_searchable:` | Implemented |
| **Index range filters** | `indexRangeFilters=` | **Not implemented** | **Missing** |
| Tokenization | `tokenization=` | `tokenization:` | Implemented |
| Skip vectorization | `skip_vectorization=` | `skip_vectorization:` | Implemented |
| Vectorize property name | `vectorize_property_name=` | `vectorize_property_name:` | Implemented |
| Nested properties | `nestedProperties=` | `nested_properties:` | Implemented |
| Cross-references | `ReferenceProperty` | `Property.reference/3` | Implemented |
| **Multi-target refs** | `ReferenceProperty.MultiTarget` | **Not implemented** | **Missing** |

### 3.4 Tokenization Options

| Tokenization | Python Enum | Elixir Atom | Status |
|--------------|-------------|-------------|--------|
| Word | `Tokenization.WORD` | `:word` | Implemented |
| Whitespace | `Tokenization.WHITESPACE` | `:whitespace` | Implemented |
| Lowercase | `Tokenization.LOWERCASE` | `:lowercase` | Implemented |
| Field | `Tokenization.FIELD` | `:field` | Implemented |
| GSE | `Tokenization.GSE` | `:gse` | Implemented |
| Trigram | `Tokenization.TRIGRAM` | `:trigram` | Implemented |
| Kagome JA | `Tokenization.KAGOME_JA` | `:kagome_ja` | Implemented |
| Kagome KR | `Tokenization.KAGOME_KR` | `:kagome_kr` | Implemented |
| GSE CH | `Tokenization.GSE_CH` | Not implemented | **Missing** |

---

## 4. Vectorizer Configuration

### 4.1 Text2Vec Vectorizers

| Vectorizer | Python Function | Elixir Function | Status |
|------------|-----------------|-----------------|--------|
| text2vec-openai | `Vectorizer.text2vec_openai()` | `VectorConfig.text2vec_openai/1` | Implemented |
| text2vec-cohere | `Vectorizer.text2vec_cohere()` | `VectorConfig.text2vec_cohere/1` | Implemented |
| text2vec-huggingface | `Vectorizer.text2vec_huggingface()` | `VectorConfig.text2vec_huggingface/1` | Implemented |
| text2vec-transformers | `Vectorizer.text2vec_transformers()` | `VectorConfig.text2vec_transformers/1` | Implemented |
| text2vec-contextionary | `Vectorizer.text2vec_contextionary()` | `VectorConfig.text2vec_contextionary/1` | Implemented |
| text2vec-gpt4all | `Vectorizer.text2vec_gpt4all()` | `VectorConfig.text2vec_gpt4all/1` | Implemented |
| text2vec-azure-openai | `Vectorizer.text2vec_azure_openai()` | `VectorConfig.text2vec_azure_openai/1` | Implemented |
| text2vec-aws | `Vectorizer.text2vec_aws()` | `VectorConfig.text2vec_aws/1` | Implemented |
| text2vec-google | `Vectorizer.text2vec_google()` | `VectorConfig.text2vec_google_vertex/1` | Implemented |
| text2vec-google-aistudio | `Vectorizer.text2vec_google_aistudio()` | `VectorConfig.text2vec_google_gemini/1` | Implemented |
| text2vec-ollama | `Vectorizer.text2vec_ollama()` | `VectorConfig.text2vec_ollama/1` | Implemented |
| text2vec-mistral | `Vectorizer.text2vec_mistral()` | `VectorConfig.text2vec_mistral/1` | Implemented |
| text2vec-nvidia | `Vectorizer.text2vec_nvidia()` | `VectorConfig.text2vec_nvidia/1` | Implemented |
| text2vec-jinaai | `Vectorizer.text2vec_jinaai()` | `VectorConfig.text2vec_jinaai/1` | Implemented |
| text2vec-voyageai | `Vectorizer.text2vec_voyageai()` | `VectorConfig.text2vec_voyageai/1` | Implemented |
| text2vec-weaviate | `Vectorizer.text2vec_weaviate()` | `VectorConfig.text2vec_weaviate/1` | Implemented |
| text2vec-databricks | `Vectorizer.text2vec_databricks()` | `VectorConfig.text2vec_databricks/1` | Implemented |
| text2vec-model2vec | `Vectorizer.text2vec_model2vec()` | `VectorConfig.text2vec_model2vec/1` | Implemented |
| text2vec-morph | `Vectorizer.text2vec_morph()` | `VectorConfig.text2vec_morph/1` | Implemented |
| **Custom vectorizer** | `Vectorizer.custom()` | **Not implemented** | **Missing** |

### 4.2 Multi2Vec Vectorizers (Multimodal)

| Vectorizer | Python Function | Elixir Function | Status |
|------------|-----------------|-----------------|--------|
| multi2vec-clip | `Vectorizer.multi2vec_clip()` | `VectorConfig.multi2vec_clip/1` | Implemented |
| multi2vec-bind | `Vectorizer.multi2vec_bind()` | `VectorConfig.multi2vec_bind/1` | Implemented |
| multi2vec-google | `Vectorizer.multi2vec_google()` | `VectorConfig.multi2vec_google/1` | Implemented |
| multi2vec-cohere | `Vectorizer.multi2vec_cohere()` | `VectorConfig.multi2vec_cohere/1` | Implemented |
| multi2vec-jinaai | `Vectorizer.multi2vec_jinaai()` | `VectorConfig.multi2vec_jinaai/1` | Implemented |
| multi2vec-voyageai | `Vectorizer.multi2vec_voyageai()` | `VectorConfig.multi2vec_voyageai/1` | Implemented |
| multi2vec-nvidia | `Vectorizer.multi2vec_nvidia()` | `VectorConfig.multi2vec_nvidia/1` | Implemented |
| multi2vec-aws | N/A | `VectorConfig.multi2vec_aws/1` | Enhanced |
| multi2multivec-jinaai | `Vectorizer.multi2multivec_jinaai()` | `VectorConfig.multi2multivec_jinaai/1` | Implemented |
| text2colbert-jinaai | `Vectorizer.text2colbert_jinaai()` | `VectorConfig.text2colbert_jinaai/1` | Implemented |

### 4.3 Other Vectorizers

| Vectorizer | Python | Elixir | Status |
|------------|--------|--------|--------|
| img2vec-neural | `Vectorizer.img2vec_neural()` | `VectorConfig.img2vec_neural/1` | Implemented |
| ref2vec-centroid | `Vectorizer.ref2vec_centroid()` | `VectorConfig.ref2vec_centroid/1` | Implemented |
| none | `Vectorizer.none()` | `VectorConfig.none/0` | Implemented |

### 4.4 Gap: Custom Vectorizer

**Python:**
```python
Vectorizer.custom(
    module_name="my-custom-vectorizer",
    module_config={"key": "value"}
)
```

**Elixir:** Not implemented. Users must construct the map manually.

**Recommendation:** Add `VectorConfig.custom/2` function.

---

## 5. Module Configuration (text2vec, img2vec, generative, reranker)

### 5.1 Generative Module Configuration

#### Python Generative Providers
```python
# File: weaviate/collections/classes/config.py

class GenerativeSearches(str, Enum):
    AWS = "generative-aws"
    ANTHROPIC = "generative-anthropic"
    ANYSCALE = "generative-anyscale"
    COHERE = "generative-cohere"
    CONTEXTUALAI = "generative-contextualai"
    DATABRICKS = "generative-databricks"
    FRIENDLIAI = "generative-friendliai"
    MISTRAL = "generative-mistral"
    NVIDIA = "generative-nvidia"
    OLLAMA = "generative-ollama"
    OPENAI = "generative-openai"
    PALM = "generative-palm"
    XAI = "generative-xai"
```

#### Elixir Generative Configurations
```elixir
# File: lib/weaviate_ex/generative/config.ex

defmodule WeaviateEx.Generative.Config do
  def openai(opts \\ [])
  def azure_openai(opts \\ [])
  def anthropic(opts \\ [])
  def cohere(opts \\ [])
  def aws_bedrock(opts \\ [])
  def aws_sagemaker(opts \\ [])
  def google_vertex(opts \\ [])
  def google_gemini(opts \\ [])
  def mistral(opts \\ [])
  def ollama(opts \\ [])
  def xai(opts \\ [])
  def contextualai(opts \\ [])
  def nvidia(opts \\ [])
  def databricks(opts \\ [])
  def friendliai(opts \\ [])
  def anyscale(opts \\ [])
end
```

**Status: Full Parity** - All 13+ generative providers implemented.

### 5.2 Reranker Module Configuration

| Reranker | Python | Elixir | Status |
|----------|--------|--------|--------|
| reranker-cohere | `Reranker.cohere()` | `VectorConfig.reranker_cohere/1` | Implemented |
| reranker-transformers | `Reranker.transformers()` | `VectorConfig.reranker_transformers/1` | Implemented |
| reranker-voyageai | `Reranker.voyageai()` | `VectorConfig.reranker_voyageai/1` | Implemented |
| reranker-jinaai | `Reranker.jinaai()` | `VectorConfig.reranker_jinaai/1` | Implemented |
| reranker-nvidia | `Reranker.nvidia()` | `VectorConfig.reranker_nvidia/1` | Implemented |
| reranker-contextualai | `Reranker.contextualai()` | `VectorConfig.reranker_contextualai/1` | Implemented |

**Status: Full Parity**

---

## 6. Replication and Sharding Settings

### 6.1 Replication Configuration

#### Python
```python
class _ReplicationConfigCreate(_ConfigCreateModel):
    factor: Optional[int]
    asyncEnabled: Optional[bool]
    deletionStrategy: Optional[ReplicationDeletionStrategy]

class ReplicationDeletionStrategy(str, Enum):
    DELETE_ON_CONFLICT = "DeleteOnConflict"
    NO_AUTOMATED_RESOLUTION = "NoAutomatedResolution"
    TIME_BASED_RESOLUTION = "TimeBasedResolution"
```

#### Elixir
```elixir
def with_replication_config(config, opts \\ []) do
  replication_config =
    %{
      "factor" => Keyword.get(opts, :factor, 1)
    }
    |> maybe_put("asyncEnabled", Keyword.get(opts, :async_enabled))
    |> maybe_put(
      "deletionStrategy",
      format_deletion_strategy(Keyword.get(opts, :deletion_strategy))
    )

  Map.put(config, "replicationConfig", replication_config)
end

defp format_deletion_strategy(:delete_on_conflict), do: "DeleteOnConflict"
defp format_deletion_strategy(:no_automated_resolution), do: "NoAutomatedResolution"
defp format_deletion_strategy(:time_based_resolution), do: "TimeBasedResolution"
```

**Status: Full Parity**

### 6.2 Sharding Configuration

#### Python
```python
class _ShardingConfigCreate(_ConfigCreateModel):
    virtualPerPhysical: Optional[int]
    desiredCount: Optional[int]
    desiredVirtualCount: Optional[int]
    key: str = "_id"
    strategy: str = "hash"
    function: str = "murmur3"
```

#### Elixir
```elixir
def with_sharding_config(config, opts \\ []) do
  sharding_config = %{}
  |> maybe_put("virtualPerPhysical", Keyword.get(opts, :virtual_per_physical))
  |> maybe_put("desiredCount", Keyword.get(opts, :desired_count))
  |> maybe_put("actualCount", Keyword.get(opts, :actual_count))

  Map.put(config, "shardingConfig", sharding_config)
end
```

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Replication factor | `factor=` | `factor:` | Implemented |
| Async replication | `asyncEnabled=` | `async_enabled:` | Implemented |
| Deletion strategy | `deletionStrategy=` | `deletion_strategy:` | Implemented |
| Virtual per physical | `virtualPerPhysical=` | `virtual_per_physical:` | Implemented |
| Desired count | `desiredCount=` | `desired_count:` | Implemented |
| Actual count | Read-only in Python | `actual_count:` | Implemented |
| Desired virtual count | `desiredVirtualCount=` | Not implemented | **Missing** |
| Key | `key=` (default "_id") | Not implemented | **Missing** |
| Strategy | `strategy=` (default "hash") | Not implemented | **Missing** |
| Function | `function=` (default "murmur3") | Not implemented | **Missing** |

### 6.3 Sharding Configuration Gaps

The Elixir implementation is missing advanced sharding options that rarely need customization:
- `desiredVirtualCount` - Virtual shard count
- `key` - Sharding key (default is `_id`)
- `strategy` - Sharding strategy (default is `hash`)
- `function` - Hash function (default is `murmur3`)

**Recommendation:** Low priority - these are advanced options with sensible defaults.

---

## 7. Inverted Index Configuration

### 7.1 Configuration Comparison

#### Python
```python
class _InvertedIndexConfigCreate(_ConfigCreateModel):
    bm25: Optional[_BM25ConfigCreate]
    cleanupIntervalSeconds: Optional[int]
    indexTimestamps: Optional[bool]
    indexPropertyLength: Optional[bool]
    indexNullState: Optional[bool]
    stopwords: _StopwordsCreate

class _BM25ConfigCreate(_ConfigCreateModel):
    b: float
    k1: float

class _StopwordsCreate(_ConfigCreateModel):
    preset: Optional[StopwordsPreset]
    additions: Optional[List[str]]
    removals: Optional[List[str]]
```

#### Elixir
```elixir
# File: lib/weaviate_ex/api/inverted_index_config.ex

defmodule WeaviateEx.API.InvertedIndexConfig do
  def bm25(opts \\ [])           # b, k1 parameters
  def stopwords(opts \\ [])      # preset, additions, removals
  def index_timestamps(enabled)
  def index_property_length(enabled)
  def index_null_state(enabled)
  def cleanup_interval_seconds(seconds)
  def build(opts \\ [])          # Complete config builder
  def merge(base, override)
  def validate(config)
end
```

### 7.2 Feature Matrix

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| BM25 b parameter | `bm25_b=` | `bm25: [b: ...]` | Implemented |
| BM25 k1 parameter | `bm25_k1=` | `bm25: [k1: ...]` | Implemented |
| Cleanup interval | `cleanupIntervalSeconds=` | `cleanup_interval_seconds:` | Implemented |
| Index timestamps | `indexTimestamps=` | `index_timestamps:` | Implemented |
| Index property length | `indexPropertyLength=` | `index_property_length:` | Implemented |
| Index null state | `indexNullState=` | `index_null_state:` | Implemented |
| Stopwords preset | `stopwords.preset=` | `stopwords: [preset: ...]` | Implemented |
| Stopwords additions | `stopwords.additions=` | `stopwords: [additions: ...]` | Implemented |
| Stopwords removals | `stopwords.removals=` | `stopwords: [removals: ...]` | Implemented |
| Config validation | Pydantic validation | `validate/1` function | Implemented |

**Status: Full Parity**

---

## 8. Summary of All Gaps

### 8.1 Critical Gaps (P0)

| Gap | Python Location | Description | Effort |
|-----|-----------------|-------------|--------|
| Object TTL Configuration | `config_object_ttl.py` | Time-based object expiration | Medium |
| Auto-tenant options | `_MultiTenancyConfigCreate` | `autoTenantCreation`, `autoTenantActivation` | Low |
| Multi-target references | `ReferenceProperty.MultiTarget` | References to multiple collections | Medium |

### 8.2 High Priority Gaps (P1)

| Gap | Python Location | Description | Effort |
|-----|-----------------|-------------|--------|
| Multi-vector (ColBERT) | `_MultiVectorConfigCreate` | Muvera encoding for ColBERT | High |
| Index range filters | `Property.indexRangeFilters` | Range filter optimization | Low |
| Typed validation | Pydantic models | Configuration validation | High |
| GSE_CH tokenization | `Tokenization.GSE_CH` | Chinese GSE tokenizer | Low |

### 8.3 Medium Priority Gaps (P2)

| Gap | Python Location | Description | Effort |
|-----|-----------------|-------------|--------|
| Custom vectorizer | `Vectorizer.custom()` | User-defined vectorizers | Low |
| Skip quantization | `Quantizer.none()` | Explicit no-compression | Low |
| Advanced sharding | `_ShardingConfigCreate` | key, strategy, function | Low |
| Deprecation warnings | Throughout Python client | User migration guidance | Low |

---

## 9. Recommendations

### 9.1 Immediate Actions (Sprint 1)

1. **Add auto-tenant configuration options** to `with_multi_tenancy/2`:
   ```elixir
   def with_multi_tenancy(config, opts \\ []) do
     mt_config = %{"enabled" => Keyword.get(opts, :enabled, false)}
     |> maybe_put("autoTenantCreation", Keyword.get(opts, :auto_tenant_creation))
     |> maybe_put("autoTenantActivation", Keyword.get(opts, :auto_tenant_activation))
     Map.put(config, "multiTenancyConfig", mt_config)
   end
   ```

2. **Add index range filters** to Property:
   ```elixir
   def new(name, data_type, opts \\ []) do
     # ... existing code ...
     |> maybe_put("indexRangeFilters", Keyword.get(opts, :index_range_filters))
   end
   ```

3. **Add GSE_CH tokenization**:
   ```elixir
   defp normalize_tokenization(:gse_ch), do: "gse_ch"
   ```

### 9.2 Short-term Actions (Sprint 2-3)

1. **Create Object TTL module**:
   ```elixir
   defmodule WeaviateEx.API.ObjectTTL do
     def new(opts \\ []) do
       %{
         "enabled" => Keyword.get(opts, :enabled, true),
         "timeToLive" => Keyword.get(opts, :time_to_live),
         "filterExpiredObjects" => Keyword.get(opts, :filter_expired, true),
         "deleteOn" => Keyword.get(opts, :delete_on, "creationTime")
       }
     end
   end
   ```

2. **Add multi-target reference support**:
   ```elixir
   def multi_reference(name, target_collections, opts \\ []) when is_list(target_collections) do
     %{
       "name" => name,
       "dataType" => target_collections
     }
     |> maybe_put("description", Keyword.get(opts, :description))
   end
   ```

3. **Add custom vectorizer support**:
   ```elixir
   def custom(module_name, module_config \\ %{}) do
     %{
       "vectorizer" => module_name,
       "moduleConfig" => %{module_name => module_config}
     }
   end
   ```

### 9.3 Long-term Actions (Future Releases)

1. **Multi-vector (ColBERT) support** - Requires understanding of Muvera encoding and multi-vector indices
2. **Typed configuration structs** - Consider using Elixir structs with Ecto-like changesets for validation
3. **Deprecation framework** - Add compile-time warnings for deprecated options

---

## 10. Appendix: File References

### Python Client Files
- `weaviate/collections/classes/config.py` - Main configuration classes
- `weaviate/collections/classes/config_vectorizers.py` - Vectorizer configurations
- `weaviate/collections/classes/config_vector_index.py` - Vector index configurations
- `weaviate/collections/classes/config_object_ttl.py` - Object TTL configuration
- `weaviate/collections/collections/executor.py` - Collection operations

### Elixir Implementation Files
- `lib/weaviate_ex/api/collections.ex` - Collection CRUD operations
- `lib/weaviate_ex/api/vector_config.ex` - Vectorizer and index configuration
- `lib/weaviate_ex/api/inverted_index_config.ex` - Inverted index configuration
- `lib/weaviate_ex/api/quantizer.ex` - Quantization configuration
- `lib/weaviate_ex/property.ex` - Property definitions
- `lib/weaviate_ex/types/data_type.ex` - Data type mappings
- `lib/weaviate_ex/generative/config.ex` - Generative configurations
- `lib/weaviate_ex/cluster/replication.ex` - Replication operations
- `lib/weaviate_ex/cluster/shard.ex` - Shard information

---

*Document generated: 2025-12-29*
*Analysis based on Python client v4.x and WeaviateEx current master branch*
