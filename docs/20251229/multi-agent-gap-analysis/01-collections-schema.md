# Collections/Schema Gap Analysis: Python Client vs Elixir Port

**Date:** 2025-12-29
**Comparison:** Python Weaviate Client v4.x (canonical) vs WeaviateEx (Elixir)
**Focus:** Collection CRUD, properties, vectorizers, index configuration, replication, sharding, and module configurations

---

## Executive Summary

The Elixir WeaviateEx client has achieved **strong functional parity** (~90%) with the Python client for schema and collections management. Core operations, property definitions, and most vectorizer configurations are well-implemented. However, several gaps exist in advanced features.

### Coverage Overview

| Area | Python | Elixir | Coverage |
|------|--------|--------|----------|
| Collection CRUD | Complete | Complete | 100% |
| Property Definitions | 17 types | 17 types | 100% |
| Text2Vec Vectorizers | 19 | 18 | 95% |
| Multi2Vec Vectorizers | 10 | 10 | 100% |
| Other Vectorizers | 3 | 3 | 100% |
| Index Types | 3 (HNSW/Flat/Dynamic) | 3 | 100% |
| Quantizers | 4 (PQ/BQ/SQ/RQ) | 4 | 100% |
| Replication Config | Complete | Complete | 100% |
| Sharding Config | 6 options | 3 options | 50% |
| Multi-Tenancy | 3 options | 1 option | 33% |
| Object TTL | Complete | Not implemented | 0% |

### Critical Gaps

1. **Object TTL Configuration** - Time-based object expiration not implemented
2. **Multi-Tenancy Auto Options** - `autoTenantCreation` and `autoTenantActivation` missing
3. **Index Range Filters** - `indexRangeFilters` property option missing
4. **Multi-Target References** - References to multiple collections not supported
5. **Named Vectors source_properties** - Property selection for named vectors missing

---

## 1. Collection CRUD Operations

### 1.1 Python Implementation

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
    object_ttl_config: Optional[_ObjectTTLConfigCreate] = None,  # NOT IN ELIXIR
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
def delete(self, name: str) -> None
def delete_all(self) -> None
def exists(self, name: str) -> bool
def get(self, name: str) -> Collection
def list_all(self) -> List[str]
```

### 1.2 Elixir Implementation

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

@spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
def get(client, collection_name)

@spec list(Client.t()) :: {:ok, [map()]} | {:error, Error.t()}
def list(client)

@spec exists?(Client.t(), String.t()) :: boolean()
def exists?(client, collection_name)

@spec add_property(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
def add_property(client, collection_name, property)

@spec get_shards(Client.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, Error.t()}
def get_shards(client, collection_name, opts \\ [])
```

### 1.3 CRUD Feature Matrix

| Feature | Python | Elixir | Status | Notes |
|---------|--------|--------|--------|-------|
| Create collection | `collections.create()` | `Collections.create/3` | Implemented | |
| Create from dict | `create_from_dict()` | Direct map to `create/3` | Implemented | |
| Create from config | `create_from_config()` | Via builder pattern | Implemented | |
| Get collection | `collections.get()` | `Collections.get/2` | Implemented | |
| List collections | `collections.list_all()` | `Collections.list/1` | Implemented | |
| Delete collection | `collection.delete()` | `Collections.delete/2` | Implemented | |
| Delete all | `collections.delete_all()` | `Collections.delete_all/1` | Implemented | |
| Exists check | `collections.exists()` | `Collections.exists?/2` | Implemented | |
| Update collection | `collection.config.update()` | `Collections.update/4` | Implemented | |
| Add property | `collection.config.add_property()` | `Collections.add_property/3` | Implemented | |
| Get shards | `collection.config.get_shards()` | `Collections.get_shards/3` | Implemented | |
| **Object TTL config** | `object_ttl_config=` parameter | **Not Implemented** | **Missing** | Critical gap |

---

## 2. Property Definitions and Data Types

### 2.1 Data Type Support

| Data Type | Python Enum | Elixir Atom | API String | Status |
|-----------|-------------|-------------|------------|--------|
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

**Status: Full Parity (17/17 data types)**

### 2.2 Property Options Comparison

#### Python Property Definition
```python
# File: weaviate/collections/classes/config.py

class Property(_ConfigCreateModel):
    name: str
    dataType: DataType
    description: Optional[str] = None
    indexFilterable: Optional[bool] = True
    indexSearchable: Optional[bool] = True
    indexRangeFilters: Optional[bool] = False  # NOT IN ELIXIR
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
  # Missing: indexRangeFilters
  |> maybe_put("tokenization", normalize_tokenization(Keyword.get(opts, :tokenization)))
  |> maybe_add_nested_properties(Keyword.get(opts, :nested_properties))
  |> maybe_add_module_config(opts)
end
```

### 2.3 Property Feature Matrix

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic properties | `Property(name=, dataType=)` | `Property.new/3` | Implemented |
| Convenience constructors | N/A | `Property.text/2`, `Property.int/2`, etc. | **Enhanced** |
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

### 2.4 Tokenization Options

| Tokenization | Python | Elixir | Status |
|--------------|--------|--------|--------|
| Word | `Tokenization.WORD` | `:word` | Implemented |
| Whitespace | `Tokenization.WHITESPACE` | `:whitespace` | Implemented |
| Lowercase | `Tokenization.LOWERCASE` | `:lowercase` | Implemented |
| Field | `Tokenization.FIELD` | `:field` | Implemented |
| GSE | `Tokenization.GSE` | `:gse` | Implemented |
| Trigram | `Tokenization.TRIGRAM` | `:trigram` | Implemented |
| Kagome JA | `Tokenization.KAGOME_JA` | `:kagome_ja` | Implemented |
| Kagome KR | `Tokenization.KAGOME_KR` | `:kagome_kr` | Implemented |
| **GSE CH** | `Tokenization.GSE_CH` | Not implemented | **Missing** |

### 2.5 Gap: Index Range Filters

**Python:**
```python
Property(
    name="price",
    dataType=DataType.NUMBER,
    indexRangeFilters=True  # Enables optimized range filtering
)
```

**Elixir:** Not implemented. Add to `Property.new/3`:
```elixir
def new(name, data_type, opts \\ []) do
  # ... existing code ...
  |> maybe_put("indexRangeFilters", Keyword.get(opts, :index_range_filters))
end
```

### 2.6 Gap: Multi-Target References

**Python:**
```python
# Reference that can point to multiple collections
ReferenceProperty.MultiTarget(
    name="hasRelated",
    target_collections=["Article", "BlogPost", "News"]
)
```

**Elixir:** Not implemented. Current implementation only supports single-target references:
```elixir
# Current implementation
Property.reference("hasAuthor", "Author")  # Single target only

# Needed:
Property.multi_reference("hasRelated", ["Article", "BlogPost", "News"])
```

---

## 3. Vectorizer Configurations

### 3.1 Text2Vec Vectorizers

| Vectorizer | Python Function | Elixir Function | Status |
|------------|-----------------|-----------------|--------|
| text2vec-openai | `text2vec_openai()` | `text2vec_openai/1` | Implemented |
| text2vec-cohere | `text2vec_cohere()` | `text2vec_cohere/1` | Implemented |
| text2vec-huggingface | `text2vec_huggingface()` | `text2vec_huggingface/1` | Implemented |
| text2vec-transformers | `text2vec_transformers()` | `text2vec_transformers/1` | Implemented |
| text2vec-contextionary | `text2vec_contextionary()` | `text2vec_contextionary/1` | Implemented |
| text2vec-gpt4all | `text2vec_gpt4all()` | `text2vec_gpt4all/1` | Implemented |
| text2vec-azure-openai | `text2vec_azure_openai()` | `text2vec_azure_openai/1` | Implemented |
| text2vec-aws | `text2vec_aws()` | `text2vec_aws/1` | Implemented |
| text2vec-google (Vertex) | `text2vec_google()` | `text2vec_google_vertex/1` | Implemented |
| text2vec-google (AI Studio) | `text2vec_google_aistudio()` | `text2vec_google_gemini/1` | Implemented |
| text2vec-ollama | `text2vec_ollama()` | `text2vec_ollama/1` | Implemented |
| text2vec-mistral | `text2vec_mistral()` | `text2vec_mistral/1` | Implemented |
| text2vec-nvidia | `text2vec_nvidia()` | `text2vec_nvidia/1` | Implemented |
| text2vec-jinaai | `text2vec_jinaai()` | `text2vec_jinaai/1` | Implemented |
| text2vec-voyageai | `text2vec_voyageai()` | `text2vec_voyageai/1` | Implemented |
| text2vec-weaviate | `text2vec_weaviate()` | `text2vec_weaviate/1` | Implemented |
| text2vec-databricks | `text2vec_databricks()` | `text2vec_databricks/1` | Implemented |
| text2vec-model2vec | `text2vec_model2vec()` | `text2vec_model2vec/1` | Implemented |
| text2vec-morph | `text2vec_morph()` | `text2vec_morph/1` | Implemented |
| **Custom vectorizer** | `Vectorizer.custom()` | `VectorConfig.custom/2` | Implemented |

### 3.2 Multi2Vec Vectorizers (Multimodal)

| Vectorizer | Python | Elixir | Status |
|------------|--------|--------|--------|
| multi2vec-clip | `multi2vec_clip()` | `multi2vec_clip/1` | Implemented |
| multi2vec-bind | `multi2vec_bind()` | `multi2vec_bind/1` | Implemented |
| multi2vec-google | `multi2vec_google()` | `multi2vec_google/1` | Implemented |
| multi2vec-cohere | `multi2vec_cohere()` | `multi2vec_cohere/1` | Implemented |
| multi2vec-jinaai | `multi2vec_jinaai()` | `multi2vec_jinaai/1` | Implemented |
| multi2vec-voyageai | `multi2vec_voyageai()` | `multi2vec_voyageai/1` | Implemented |
| multi2vec-nvidia | `multi2vec_nvidia()` | `multi2vec_nvidia/1` | Implemented |
| multi2vec-aws | N/A | `multi2vec_aws/1` | **Enhanced** |
| multi2multivec-jinaai | `multi2multivec_jinaai()` | `multi2multivec_jinaai/1` | Implemented |
| text2colbert-jinaai | `text2colbert_jinaai()` | `text2colbert_jinaai/1` | Implemented |

### 3.3 Other Vectorizers

| Vectorizer | Python | Elixir | Status |
|------------|--------|--------|--------|
| img2vec-neural | `img2vec_neural()` | `img2vec_neural/1` | Implemented |
| ref2vec-centroid | `ref2vec_centroid()` | `ref2vec_centroid/1` | Implemented |
| none | `Vectorizer.none()` | `VectorConfig.none/0` | Implemented |

### 3.4 Named Vectors Configuration

#### Python Named Vectors
```python
# File: weaviate/collections/classes/config_named_vectors.py

class _NamedVectorConfigCreate(_ConfigCreateModel):
    name: str
    properties: Optional[List[str]] = Field(default=None, alias="source_properties")  # MISSING IN ELIXIR
    vectorizer: _VectorizerConfigCreate
    vectorIndexType: VectorIndexType
    vectorIndexConfig: Optional[_VectorIndexConfigCreate]

# Usage:
vector_config=[
    Configure.NamedVectors.text2vec_openai(
        name="title_vector",
        source_properties=["title"],  # Property selection
        vector_index_config=Configure.VectorIndex.hnsw()
    ),
    Configure.NamedVectors.text2vec_cohere(
        name="content_vector",
        source_properties=["content"],
        model="embed-english-v3.0"
    )
]
```

#### Elixir Named Vectors
```elixir
# File: lib/weaviate_ex/api/vector_config.ex

def with_named_vectors(config, vectors) do
  vectors_with_string_keys =
    Enum.into(vectors, %{}, fn {name, vector_config} ->
      {name, stringify_keys(vector_config)}
    end)
  Map.put(config, "vectorConfig", vectors_with_string_keys)
end

# Usage - no source_properties option:
VectorConfig.new("Article")
|> VectorConfig.with_named_vectors(%{
  "title_vector" => VectorConfig.text2vec_openai(model: "text-embedding-ada-002"),
  "content_vector" => VectorConfig.text2vec_cohere(model: "embed-english-v3.0")
})
```

### 3.5 Gap: Named Vector Source Properties

**Python:**
```python
Configure.NamedVectors.text2vec_openai(
    name="title_vector",
    source_properties=["title", "subtitle"]  # Only these properties are vectorized
)
```

**Elixir:** Missing. The `source_properties` option should be added to vectorizer configurations for named vectors.

---

## 4. Index Configurations

### 4.1 Vector Index Types

| Index Type | Python | Elixir | Status |
|------------|--------|--------|--------|
| HNSW | `Configure.VectorIndex.hnsw()` | `VectorConfig.hnsw_index/1` | Implemented |
| Flat | `Configure.VectorIndex.flat()` | `VectorConfig.flat_index/1` | Implemented |
| Dynamic | `Configure.VectorIndex.dynamic()` | `VectorConfig.dynamic_index/1` | Implemented |

### 4.2 HNSW Index Configuration

#### Python HNSW
```python
class _VectorIndexConfigHNSW(_VectorIndexConfig):
    cleanup_interval_seconds: int
    distance_metric: VectorDistances
    dynamic_ef_min: int
    dynamic_ef_max: int
    dynamic_ef_factor: int
    ef: int
    ef_construction: int
    filter_strategy: VectorFilterStrategy  # :sweeping or :acorn
    flat_search_cutoff: int
    max_connections: int
    skip: bool
    vector_cache_max_objects: int
    quantizer: Optional[Union[PQConfig, BQConfig, SQConfig, RQConfig]]
    multi_vector: Optional[_MultiVectorConfig]  # ColBERT/Muvera - NOT IN ELIXIR
```

#### Elixir HNSW
```elixir
def hnsw_index(opts \\ []) do
  %{
    "vectorIndexType" => "hnsw",
    "vectorIndexConfig" => %{
      "distance" => distance,
      "ef" => Keyword.get(opts, :ef, -1),
      "efConstruction" => Keyword.get(opts, :ef_construction, 128),
      "maxConnections" => Keyword.get(opts, :max_connections, 32)
    }
    # Plus: dynamicEfMin, dynamicEfMax, dynamicEfFactor,
    #       vectorCacheMaxObjects, flatSearchCutoff,
    #       cleanupIntervalSeconds, filterStrategy, quantizer
  }
end
```

### 4.3 HNSW Feature Matrix

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Distance metric | `distance=` | `distance:` | Implemented |
| EF parameter | `ef=` | `ef:` | Implemented |
| EF construction | `ef_construction=` | `ef_construction:` | Implemented |
| Max connections | `max_connections=` | `max_connections:` | Implemented |
| Dynamic EF min | `dynamic_ef_min=` | `dynamic_ef_min:` | Implemented |
| Dynamic EF max | `dynamic_ef_max=` | `dynamic_ef_max:` | Implemented |
| Dynamic EF factor | `dynamic_ef_factor=` | `dynamic_ef_factor:` | Implemented |
| Vector cache max | `vector_cache_max_objects=` | `vector_cache_max_objects:` | Implemented |
| Flat search cutoff | `flat_search_cutoff=` | `flat_search_cutoff:` | Implemented |
| Cleanup interval | `cleanup_interval_seconds=` | `cleanup_interval_seconds:` | Implemented |
| Filter strategy | `filter_strategy=` | `filter_strategy:` | Implemented |
| Skip indexing | `skip=` | Not implemented | **Missing** |
| **Multi-vector (ColBERT)** | `multi_vector=` | **Not implemented** | **Missing** |

### 4.4 Quantization Methods

| Method | Python | Elixir | Status |
|--------|--------|--------|--------|
| Product Quantization (PQ) | `Configure.VectorIndex.Quantizer.pq()` | `product_quantization/1`, `Quantizer.pq/1` | Implemented |
| Binary Quantization (BQ) | `Configure.VectorIndex.Quantizer.bq()` | `binary_quantization/1`, `Quantizer.bq/1` | Implemented |
| Scalar Quantization (SQ) | `Configure.VectorIndex.Quantizer.sq()` | `scalar_quantization/1`, `Quantizer.sq/1` | Implemented |
| Rotational Quantization (RQ) | `Configure.VectorIndex.Quantizer.rq()` | `rotational_quantization/1`, `Quantizer.rq/1` | Implemented |

### 4.5 PQ Configuration Options

| Option | Python | Elixir | Status |
|--------|--------|--------|--------|
| Enabled | `enabled=` | `enabled:` | Implemented |
| Training limit | `training_limit=` | `training_limit:` | Implemented |
| Segments | `segments=` | `segments:` | Implemented |
| Centroids | `centroids=` | `centroids:` | Implemented |
| Encoder type | `encoder.type=` | `encoder: %{type: ...}` | Implemented |
| Encoder distribution | `encoder.distribution=` | `encoder: %{distribution: ...}` | Implemented |

### 4.6 Gap: Multi-Vector (ColBERT) Configuration

**Python:**
```python
# File: weaviate/collections/classes/config.py

class _MuveraConfig(_ConfigBase):
    enabled: Optional[bool]
    ksim: Optional[int]
    dprojections: Optional[int]
    repetitions: Optional[int]

class _MultiVectorConfig(_ConfigBase):
    encoding: Optional[_MuveraConfig]
    aggregation: str  # "maxsim"

# Usage:
Configure.VectorIndex.hnsw(
    multi_vector=Configure.VectorIndex.MultiVector.muvera(
        ksim=128,
        dprojections=2,
        repetitions=1
    )
)
```

**Elixir:** Not implemented. ColBERT/multi-vector support is missing.

---

## 5. Replication and Sharding Configuration

### 5.1 Replication Configuration

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
    |> maybe_put("deletionStrategy", format_deletion_strategy(Keyword.get(opts, :deletion_strategy)))

  Map.put(config, "replicationConfig", replication_config)
end

defp format_deletion_strategy(:delete_on_conflict), do: "DeleteOnConflict"
defp format_deletion_strategy(:no_automated_resolution), do: "NoAutomatedResolution"
defp format_deletion_strategy(:time_based_resolution), do: "TimeBasedResolution"
```

**Status: Full Parity**

### 5.2 Sharding Configuration

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
  # Missing: desiredVirtualCount, key, strategy, function

  Map.put(config, "shardingConfig", sharding_config)
end
```

### 5.3 Sharding Feature Matrix

| Feature | Python | Elixir | Status | Notes |
|---------|--------|--------|--------|-------|
| Virtual per physical | `virtualPerPhysical=` | `virtual_per_physical:` | Implemented | |
| Desired count | `desiredCount=` | `desired_count:` | Implemented | |
| Actual count | Read-only | `actual_count:` | Implemented | |
| **Desired virtual count** | `desiredVirtualCount=` | Not implemented | **Missing** | Low priority |
| **Key** | `key=` (default "_id") | Not implemented | **Missing** | Low priority |
| **Strategy** | `strategy=` (default "hash") | Not implemented | **Missing** | Low priority |
| **Function** | `function=` (default "murmur3") | Not implemented | **Missing** | Low priority |

---

## 6. Multi-Tenancy Configuration

### 6.1 Python Implementation
```python
class _MultiTenancyConfigCreate(_ConfigCreateModel):
    enabled: bool
    autoTenantCreation: Optional[bool]
    autoTenantActivation: Optional[bool]
```

### 6.2 Elixir Implementation
```elixir
# Current implementation
def with_multi_tenancy(config, opts \\ []) do
  mt_config = %{
    "enabled" => Keyword.get(opts, :enabled, false)
  }
  # Missing: autoTenantCreation, autoTenantActivation

  Map.put(config, "multiTenancyConfig", mt_config)
end

# Separate struct exists but not integrated:
# lib/weaviate_ex/schema/multi_tenancy_config.ex
defmodule WeaviateEx.Schema.MultiTenancyConfig do
  defstruct enabled: false, auto_tenant_creation: false, auto_tenant_activation: false
end
```

### 6.3 Multi-Tenancy Feature Matrix

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Enabled | `enabled=` | `enabled:` | Implemented |
| **Auto-tenant creation** | `autoTenantCreation=` | Not exposed in builder | **Missing** |
| **Auto-tenant activation** | `autoTenantActivation=` | Not exposed in builder | **Missing** |

### 6.4 Gap: Auto-Tenant Configuration

**Python:**
```python
collections.create(
    name="TenantCollection",
    multi_tenancy_config=Configure.multi_tenancy(
        enabled=True,
        auto_tenant_creation=True,  # Auto-create tenants on insert
        auto_tenant_activation=True  # Auto-activate inactive tenants
    )
)
```

**Elixir:** `MultiTenancyConfig` struct exists but options are not exposed in `VectorConfig.with_multi_tenancy/2`.

**Fix:**
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

## 7. Object TTL Configuration

### 7.1 Python Implementation
```python
# File: weaviate/collections/classes/config_object_ttl.py

class _ObjectTTLConfigCreate(_ConfigCreateModel):
    enabled: bool = True
    filterExpiredObjects: Optional[bool]
    deleteOn: Optional[str]  # "_lastUpdateTimeUnix", "_creationTimeUnix", or property name
    defaultTtl: Optional[int]

class _ObjectTTL:
    @staticmethod
    def delete_by_update_time(time_to_live: int | timedelta, filter_expired_objects: Optional[bool] = None)

    @staticmethod
    def delete_by_creation_time(time_to_live: int | timedelta, filter_expired_objects: Optional[bool] = None)

    @staticmethod
    def delete_by_date_property(property_name: str, ttl_offset: Optional[int | timedelta] = None, ...)
```

### 7.2 Elixir Implementation

**Not Implemented.** This is a critical gap.

### 7.3 Recommended Implementation

```elixir
defmodule WeaviateEx.API.ObjectTTL do
  @moduledoc """
  Object Time-To-Live (TTL) configuration for automatic object expiration.
  """

  @doc """
  Delete objects based on their last update time.

  ## Options
    - `:time_to_live` - TTL in seconds (required)
    - `:filter_expired` - Exclude expired objects from search (optional)
  """
  def delete_by_update_time(opts) do
    %{
      "enabled" => true,
      "deleteOn" => "_lastUpdateTimeUnix",
      "defaultTtl" => Keyword.fetch!(opts, :time_to_live)
    }
    |> maybe_put("filterExpiredObjects", Keyword.get(opts, :filter_expired))
  end

  @doc """
  Delete objects based on their creation time.
  """
  def delete_by_creation_time(opts) do
    %{
      "enabled" => true,
      "deleteOn" => "_creationTimeUnix",
      "defaultTtl" => Keyword.fetch!(opts, :time_to_live)
    }
    |> maybe_put("filterExpiredObjects", Keyword.get(opts, :filter_expired))
  end

  @doc """
  Delete objects based on a custom date property.
  """
  def delete_by_date_property(property_name, opts \\ []) do
    %{
      "enabled" => true,
      "deleteOn" => property_name,
      "defaultTtl" => Keyword.get(opts, :ttl_offset, 0)
    }
    |> maybe_put("filterExpiredObjects", Keyword.get(opts, :filter_expired))
  end

  @doc """
  Disable object TTL.
  """
  def disabled do
    %{"enabled" => false}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

---

## 8. Module Configuration (Generative, Reranker)

### 8.1 Generative Module Configuration

| Provider | Python | Elixir | Status |
|----------|--------|--------|--------|
| generative-openai | `Generative.openai()` | Via module config | Implemented |
| generative-azure-openai | `Generative.azure_openai()` | Via module config | Implemented |
| generative-anthropic | `Generative.anthropic()` | Via module config | Implemented |
| generative-cohere | `Generative.cohere()` | Via module config | Implemented |
| generative-aws | `Generative.aws()` | Via module config | Implemented |
| generative-google | `Generative.palm()` | Via module config | Implemented |
| generative-mistral | `Generative.mistral()` | Via module config | Implemented |
| generative-ollama | `Generative.ollama()` | Via module config | Implemented |
| generative-nvidia | `Generative.nvidia()` | Via module config | Implemented |
| generative-databricks | `Generative.databricks()` | Via module config | Implemented |
| generative-friendliai | `Generative.friendliai()` | Via module config | Implemented |
| generative-anyscale | `Generative.anyscale()` | Via module config | Implemented |
| generative-contextualai | `Generative.contextualai()` | Via module config | Implemented |
| generative-xai | `Generative.xai()` | Via module config | Implemented |

### 8.2 Reranker Module Configuration

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

## 9. Inverted Index Configuration

### 9.1 Feature Matrix

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

## 10. Collection Config Update Capabilities

### 10.1 Python Update Operations
```python
# File: weaviate/collections/config/executor.py

def update(
    self,
    *,
    description: Optional[str] = None,
    inverted_index_config: Optional[_InvertedIndexConfigUpdate] = None,
    multi_tenancy_config: Optional[_MultiTenancyConfigUpdate] = None,
    object_ttl_config: Optional[_ObjectTTLConfigUpdate] = None,
    replication_config: Optional[_ReplicationConfigUpdate] = None,
    vector_index_config: Optional[_VectorIndexConfigUpdate] = None,
    vectorizer_config: Optional[Union[_VectorIndexConfigUpdate, List[_NamedVectorConfigUpdate]]] = None,
    vector_config: Optional[Union[_VectorConfigUpdate, List[_VectorConfigUpdate]]] = None,
)
```

### 10.2 Elixir Update Operations
```elixir
@spec update(Client.t(), String.t(), map(), opts()) :: {:ok, map()} | {:error, Error.t()}
def update(client, collection_name, updates, opts \\ [])
# Updates are passed as raw map, no typed update structs
```

### 10.3 Update Feature Matrix

| Updatable Config | Python | Elixir | Status |
|------------------|--------|--------|--------|
| Description | `description=` | Map key | Implemented |
| Inverted index config | Typed update struct | Raw map | Implemented |
| Multi-tenancy config | Typed update struct | Raw map | Implemented |
| Object TTL config | Typed update struct | **Not implemented** | **Missing** |
| Replication config | Typed update struct | Raw map | Implemented |
| Vector index config | Typed update struct | Raw map | Implemented |
| Named vector config | Typed update struct | Raw map | Implemented |

---

## 11. Summary of All Gaps

### 11.1 Critical Gaps (P0)

| Gap | Python Location | Description | Effort |
|-----|-----------------|-------------|--------|
| Object TTL Configuration | `config_object_ttl.py` | Time-based object expiration | Medium |
| Auto-tenant options | `_MultiTenancyConfigCreate` | `autoTenantCreation`, `autoTenantActivation` | Low |
| Index range filters | `Property.indexRangeFilters` | Range filter optimization | Low |
| Multi-target references | `ReferenceProperty.MultiTarget` | References to multiple collections | Medium |

### 11.2 High Priority Gaps (P1)

| Gap | Python Location | Description | Effort |
|-----|-----------------|-------------|--------|
| Multi-vector (ColBERT) | `_MultiVectorConfigCreate` | Muvera encoding for ColBERT | High |
| Named vector source_properties | `_NamedVectorConfigCreate` | Property selection for vectorization | Medium |
| GSE_CH tokenization | `Tokenization.GSE_CH` | Chinese GSE tokenizer | Low |
| HNSW skip option | `_VectorIndexConfigHNSW.skip` | Skip vector indexing | Low |

### 11.3 Low Priority Gaps (P2)

| Gap | Python Location | Description | Effort |
|-----|-----------------|-------------|--------|
| Advanced sharding options | `_ShardingConfigCreate` | key, strategy, function | Low |
| Desired virtual count | `_ShardingConfigCreate` | Virtual shard count | Low |
| Deprecation warnings | Throughout Python client | User migration guidance | Low |
| Typed update structs | `*ConfigUpdate` classes | Type-safe updates | High |

---

## 12. Recommendations

### 12.1 Immediate Actions (Sprint 1)

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

### 12.2 Short-term Actions (Sprint 2-3)

1. **Create Object TTL module** (see Section 7.3)

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

3. **Add source_properties to named vectors**:
   ```elixir
   def with_named_vector(config, name, vectorizer_config, opts \\ []) do
     vector = vectorizer_config
     |> maybe_put("properties", Keyword.get(opts, :source_properties))
     # ... rest of implementation
   end
   ```

### 12.3 Long-term Actions (Future Releases)

1. **Multi-vector (ColBERT) support** - Requires understanding of Muvera encoding
2. **Typed configuration structs** - Consider using Elixir structs with validation
3. **Deprecation framework** - Add compile-time warnings for deprecated options

---

## 13. API Differences Summary

### 13.1 Naming Conventions

| Concept | Python | Elixir |
|---------|--------|--------|
| Collection CRUD | `collections.create()`, `collection.delete()` | `Collections.create/3`, `Collections.delete/2` |
| Property builder | `Property()` | `Property.new/3`, `Property.text/2`, etc. |
| Vectorizer config | `Configure.Vectorizer.text2vec_*()` | `VectorConfig.text2vec_*/1` |
| Index config | `Configure.VectorIndex.hnsw()` | `VectorConfig.hnsw_index/1` |
| Named vectors | `Configure.NamedVectors.*()` | `VectorConfig.with_named_vectors/2` |
| Quantizer | `Configure.VectorIndex.Quantizer.pq()` | `VectorConfig.product_quantization/1`, `Quantizer.pq/1` |

### 13.2 Structural Differences

| Aspect | Python | Elixir |
|--------|--------|--------|
| Configuration style | Pydantic models with validation | Plain maps with optional validation |
| Builder pattern | Method chaining on objects | Pipe operator with functions |
| Error handling | Exceptions | `{:ok, result}` / `{:error, reason}` tuples |
| Type safety | Runtime validation via Pydantic | Optional typespecs |

---

## 14. File References

### Python Client Files
- `weaviate/collections/collections/executor.py` - Collection CRUD operations
- `weaviate/collections/classes/config.py` - Main configuration classes
- `weaviate/collections/classes/config_vectorizers.py` - Vectorizer configurations
- `weaviate/collections/classes/config_vector_index.py` - Vector index configurations
- `weaviate/collections/classes/config_named_vectors.py` - Named vector configurations
- `weaviate/collections/classes/config_object_ttl.py` - Object TTL configuration
- `weaviate/collections/config/executor.py` - Collection config operations

### Elixir Implementation Files
- `lib/weaviate_ex/api/collections.ex` - Collection CRUD operations
- `lib/weaviate_ex/api/vector_config.ex` - Vectorizer and index configuration
- `lib/weaviate_ex/api/inverted_index_config.ex` - Inverted index configuration
- `lib/weaviate_ex/api/quantizer.ex` - Quantization configuration
- `lib/weaviate_ex/property.ex` - Property definitions
- `lib/weaviate_ex/types/data_type.ex` - Data type mappings
- `lib/weaviate_ex/schema/multi_tenancy_config.ex` - Multi-tenancy configuration

---

*Document generated: 2025-12-29*
*Analysis based on Python client v4.x and WeaviateEx current master branch*
