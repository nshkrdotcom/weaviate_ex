# Collections/Schema API Gap Analysis

**Date:** 2025-12-29
**Python Client Version:** v4.x (latest)
**Elixir Port Version:** v0.7.2

---

## Executive Summary

The WeaviateEx Elixir port has achieved **substantial feature parity** with the Python Weaviate client's Collections/Schema API, estimated at approximately **85-90%** coverage for core functionality. The Elixir implementation provides comprehensive support for collection CRUD operations, property definitions, vectorizers, multi-tenancy, and configuration options.

### Key Strengths
- Full CRUD operations for collections
- Extensive vectorizer support (25+ vectorizers)
- Named vectors with multi-vector collection support
- Complete quantizer implementations (PQ, BQ, SQ, RQ)
- Multi-tenancy with tenant lifecycle management
- Comprehensive generative and reranker configurations

### Critical Gaps
1. **Collection Update API**: Limited update capabilities compared to Python's `Reconfigure` pattern
2. **Typed Configuration Classes**: Python uses Pydantic models with strong typing; Elixir uses maps
3. **Advanced Tenant Operations**: Missing `offload`, `activate`, `deactivate` convenience methods
4. **Multi-Vector Encoding**: Missing `muvera` encoding for ColBERT/multi-vector indices
5. **Object TTL**: Not implemented in Elixir

---

## Feature Comparison Table

| Feature | Python Client | Elixir Port | Status | Priority |
|---------|--------------|-------------|--------|----------|
| **Collection CRUD** | | | | |
| Create collection | `collections.create()` | `Collections.create/3` | Full | - |
| Get collection | `collections.get()` | `Collections.get/2` | Full | - |
| List collections | `collections.list_all()` | `Collections.list/1` | Full | - |
| Delete collection | `collections.delete()` | `Collections.delete/2` | Full | - |
| Update collection | `collection.config.update()` | `Collections.update/4` | Partial | High |
| Delete all | `collections.delete_all()` | `Collections.delete_all/1` | Full | - |
| Check exists | `collections.exists()` | `Collections.exists?/2` | Full | - |
| **Property Management** | | | | |
| Add property | `collection.config.add_property()` | `Collections.add_property/3` | Full | - |
| Property types | All 14 types | All 14 types | Full | - |
| Nested properties | Supported | Supported | Full | - |
| Cross-references | Supported | Supported | Full | - |
| Multi-target refs | Supported | Supported | Full | - |
| Property indexing | `index_filterable`, etc. | All options | Full | - |
| Tokenization | All modes | All modes | Full | - |
| **Vectorizer Config** | | | | |
| text2vec-openai | Full | Full | Full | - |
| text2vec-cohere | Full | Full | Full | - |
| text2vec-huggingface | Full | Full | Full | - |
| text2vec-transformers | Full | Full | Full | - |
| text2vec-azure-openai | Full | Full | Full | - |
| text2vec-aws | Full | Full | Full | - |
| text2vec-google/palm | Full | Full | Full | - |
| text2vec-ollama | Full | Full | Full | - |
| text2vec-mistral | Full | Full | Full | - |
| text2vec-nvidia | Full | Full | Full | - |
| text2vec-jinaai | Full | Full | Full | - |
| text2vec-voyageai | Full | Full | Full | - |
| text2vec-weaviate | Full | Full | Full | - |
| text2vec-databricks | Full | Full | Full | - |
| text2vec-gpt4all | Full | Full | Full | - |
| text2vec-contextionary | Full | Full | Full | - |
| text2vec-model2vec | Full | Full | Full | - |
| text2colbert-jinaai | Full | Partial | Medium | Medium |
| multi2vec-clip | Full | Full | Full | - |
| multi2vec-bind | Full | Full | Full | - |
| multi2vec-google | Full | Full | Full | - |
| multi2vec-cohere | Full | Full | Full | - |
| multi2vec-jinaai | Full | Full | Full | - |
| multi2vec-voyageai | Full | Full | Full | - |
| multi2vec-nvidia | Full | Full | Full | - |
| multi2vec-aws | Full | Full | Full | - |
| img2vec-neural | Full | Full | Full | - |
| ref2vec-centroid | Full | Full | Full | - |
| Custom vectorizer | `_VectorizerCustomConfig` | `VectorConfig.custom/2` | Full | - |
| **Named Vectors** | | | | |
| Named vector creation | `Configure.NamedVectors.*` | `NamedVectors.*` | Full | - |
| Named vector update | `Reconfigure.NamedVectors.update()` | `NamedVectors.update_config/2` | Partial | Medium |
| Source properties | Supported | Supported | Full | - |
| Per-vector index config | Full | Full | Full | - |
| **Vector Index** | | | | |
| HNSW index | Full config | Full config | Full | - |
| FLAT index | Full config | Full config | Full | - |
| DYNAMIC index | Full config | Full config | Full | - |
| Skip indexing | `VectorIndex.none()` | Not explicit | Minor | Low |
| Filter strategy | SWEEPING/ACORN | Both supported | Full | - |
| **Quantization** | | | | |
| PQ (Product) | Full | Full | Full | - |
| BQ (Binary) | Full | Full | Full | - |
| SQ (Scalar) | Full | Full | Full | - |
| RQ (Rotational) | Full | Full | Full | - |
| PQ Encoder config | type, distribution | Supported | Full | - |
| **Multi-Tenancy** | | | | |
| Enable/disable | Full | Full | Full | - |
| Auto tenant creation | Full | Missing | High | High |
| Auto tenant activation | Full | Missing | High | High |
| Create tenants | Full | Full | Full | - |
| Delete tenants | Full | Full | Full | - |
| Get tenants | Full | Full | Full | - |
| Get tenant by name | Full | Missing | Medium | Medium |
| Update tenants | Full | Full | Full | - |
| Tenant exists | Full | Missing | Low | Low |
| Activate tenants | `tenants.activate()` | Missing | Medium | Medium |
| Deactivate tenants | `tenants.deactivate()` | Missing | Medium | Medium |
| Offload tenants | `tenants.offload()` | Missing | Medium | Medium |
| Tenant activity status | HOT/COLD/OFFLOADED/etc | HOT/COLD only | Partial | Medium |
| **Replication** | | | | |
| Replication factor | Full | Full | Full | - |
| Async replication | Full | Full | Full | - |
| Deletion strategy | Full | Full | Full | - |
| **Sharding** | | | | |
| Virtual per physical | Full | Full | Full | - |
| Desired/actual count | Full | Full | Full | - |
| Get shards | Full | Full | Full | - |
| Shard status | Full | Full | Full | - |
| **Inverted Index** | | | | |
| BM25 config | Full | Full | Full | - |
| Stopwords | Full | Full | Full | - |
| Index timestamps | Full | Full | Full | - |
| Index null state | Full | Full | Full | - |
| Index property length | Full | Full | Full | - |
| Cleanup interval | Full | Full | Full | - |
| **Generative Config** | | | | |
| OpenAI | Full | Full | Full | - |
| Anthropic | Full | Full | Full | - |
| Cohere | Full | Full | Full | - |
| Mistral | Full | Full | Full | - |
| Google/PaLM | Full | Full | Full | - |
| AWS | Full | Full | Full | - |
| Ollama | Full | Full | Full | - |
| Databricks | Full | Full | Full | - |
| NVIDIA | Full | Full | Full | - |
| FriendliAI | Full | Full | Full | - |
| XAI | Full | Full | Full | - |
| Anyscale | Full | Full | Full | - |
| ContextualAI | Full | Full | Full | - |
| Custom generative | Full | Full | Full | - |
| **Reranker Config** | | | | |
| Cohere | Full | Full | Full | - |
| Transformers | Full | Full | Full | - |
| VoyageAI | Full | Full | Full | - |
| JinaAI | Full | Full | Full | - |
| NVIDIA | Full | Full | Full | - |
| ContextualAI | Full | Full | Full | - |
| Custom reranker | Full | Full | Full | - |
| **Object TTL** | | | | |
| Configure TTL | `ObjectTTL.create()` | Missing | Medium | Medium |
| Update TTL | `ObjectTTL.update()` | Missing | Medium | Medium |
| **Multi-Vector Index** | | | | |
| Multi-vector config | `MultiVector.*` | `MultiVector.*` | Partial | Low |
| Muvera encoding | Full | Missing | Low | Low |
| Aggregation (maxSim) | Full | Missing | Low | Low |

---

## Detailed Gap Analysis

### 1. Collection Creation, Update, Delete Operations

#### Create Operations

**Python:**
```python
from weaviate.classes.config import Configure, Property, DataType

client.collections.create(
    name="Article",
    properties=[
        Property(name="title", data_type=DataType.TEXT),
        Property(name="content", data_type=DataType.TEXT),
    ],
    vectorizer_config=Configure.Vectorizer.text2vec_openai(
        model="text-embedding-3-small"
    ),
    generative_config=Configure.Generative.openai(model="gpt-4"),
    replication_config=Configure.Replication(factor=3),
    sharding_config=Configure.Sharding(desired_count=2),
    inverted_index_config=Configure.inverted_index(
        bm25_b=0.75,
        bm25_k1=1.2,
        index_timestamps=True
    ),
    multi_tenancy_config=Configure.multi_tenancy(
        enabled=True,
        auto_tenant_creation=True,
        auto_tenant_activation=True
    )
)
```

**Elixir:**
```elixir
alias WeaviateEx.{Property, API.VectorConfig, API.GenerativeConfig}
alias WeaviateEx.API.InvertedIndexConfig

config = %{
  "class" => "Article",
  "properties" => [
    Property.text("title"),
    Property.text("content")
  ],
  "vectorizer" => "text2vec-openai",
  "moduleConfig" => %{
    "text2vec-openai" => %{"model" => "text-embedding-3-small"},
    "generative-openai" => %{"model" => "gpt-4"}
  },
  "replicationConfig" => %{"factor" => 3},
  "shardingConfig" => %{"desiredCount" => 2},
  "invertedIndexConfig" => InvertedIndexConfig.build(
    bm25: [b: 0.75, k1: 1.2],
    index_timestamps: true
  ),
  "multiTenancyConfig" => %{"enabled" => true}
  # NOTE: auto_tenant_creation and auto_tenant_activation not supported
}

WeaviateEx.API.Collections.create(client, config)
```

**Gap:** The Elixir implementation lacks:
- `auto_tenant_creation` option in multi-tenancy config
- `auto_tenant_activation` option in multi-tenancy config
- Strongly-typed configuration builder pattern (Python uses `Configure.*` classes)

#### Update Operations

**Python:**
```python
from weaviate.classes.config import Reconfigure

collection.config.update(
    inverted_index_config=Reconfigure.inverted_index(
        bm25_b=0.8,
        stopwords_additions=["custom", "words"]
    ),
    replication_config=Reconfigure.replication(factor=5),
    vector_index_config=Reconfigure.VectorIndex.hnsw(
        ef=200,
        quantizer=Reconfigure.VectorIndex.Quantizer.pq(enabled=True)
    )
)
```

**Elixir:**
```elixir
# Basic update supported
updates = %{
  "invertedIndexConfig" => %{
    "bm25" => %{"b" => 0.8},
    "stopwords" => %{"additions" => ["custom", "words"]}
  },
  "replicationConfig" => %{"factor" => 5}
}

WeaviateEx.API.Collections.update(client, "Article", updates)
```

**Gap:** The Elixir implementation lacks:
- `Reconfigure` pattern with type-safe update builders
- Named vector update helpers in `Collections.update`
- Vector index quantizer update helpers

---

### 2. Property Definitions and Data Types

#### Supported Data Types

| Data Type | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| TEXT | `DataType.TEXT` | `:text` | Full support |
| TEXT_ARRAY | `DataType.TEXT_ARRAY` | `:text_array` | Full support |
| INT | `DataType.INT` | `:int` | Full support |
| INT_ARRAY | `DataType.INT_ARRAY` | `:int_array` | Full support |
| NUMBER | `DataType.NUMBER` | `:number` | Full support |
| NUMBER_ARRAY | `DataType.NUMBER_ARRAY` | `:number_array` | Full support |
| BOOLEAN | `DataType.BOOLEAN` | `:boolean` | Full support |
| BOOLEAN_ARRAY | `DataType.BOOLEAN_ARRAY` | `:boolean_array` | Full support |
| DATE | `DataType.DATE` | `:date` | Full support |
| DATE_ARRAY | `DataType.DATE_ARRAY` | `:date_array` | Full support |
| UUID | `DataType.UUID` | `:uuid` | Full support |
| UUID_ARRAY | `DataType.UUID_ARRAY` | `:uuid_array` | Full support |
| BLOB | `DataType.BLOB` | `:blob` | Full support |
| GEO_COORDINATES | `DataType.GEO_COORDINATES` | `:geo_coordinates` | Full support |
| PHONE_NUMBER | `DataType.PHONE_NUMBER` | `:phone_number` | Full support |
| OBJECT | `DataType.OBJECT` | `:object` | Full support |
| OBJECT_ARRAY | `DataType.OBJECT_ARRAY` | `:object_array` | Full support |

**Python:**
```python
from weaviate.classes.config import Property, DataType

properties = [
    Property(
        name="title",
        data_type=DataType.TEXT,
        description="Article title",
        index_filterable=True,
        index_searchable=True,
        tokenization=Tokenization.WORD,
        skip_vectorization=True
    ),
    Property(
        name="metadata",
        data_type=DataType.OBJECT,
        nested_properties=[
            Property(name="author", data_type=DataType.TEXT),
            Property(name="tags", data_type=DataType.TEXT_ARRAY)
        ]
    )
]
```

**Elixir:**
```elixir
alias WeaviateEx.Property

properties = [
  Property.text("title",
    description: "Article title",
    index_filterable: true,
    index_searchable: true,
    tokenization: :word,
    skip_vectorization: true
  ),
  Property.object("metadata", [
    Property.text("author"),
    Property.text_array("tags")
  ])
]
```

**Status:** Full parity achieved.

---

### 3. Vectorizer Configurations

#### Text2Vec Vectorizers

The Elixir port supports all 17 text2vec vectorizers with equivalent configuration options:

| Vectorizer | Python Class | Elixir Function | Parity |
|------------|--------------|-----------------|--------|
| text2vec-openai | `_Text2VecOpenAIConfig` | `VectorConfig.text2vec_openai/1` | Full |
| text2vec-cohere | `_Text2VecCohereConfig` | `VectorConfig.text2vec_cohere/1` | Full |
| text2vec-huggingface | `_Text2VecHuggingFaceConfig` | `VectorConfig.text2vec_huggingface/1` | Full |
| text2vec-azure-openai | `_Text2VecAzureOpenAIConfig` | `VectorConfig.text2vec_azure_openai/1` | Full |
| text2vec-aws | `_Text2VecAWSConfig` | `VectorConfig.text2vec_aws_bedrock/1` | Full |
| text2vec-google | `_Text2VecGoogleConfig` | `VectorConfig.text2vec_google_vertex/1` | Full |
| text2vec-ollama | `_Text2VecOllamaConfig` | `VectorConfig.text2vec_ollama/1` | Full |
| text2vec-mistral | `_Text2VecMistralConfig` | `VectorConfig.text2vec_mistral/1` | Full |
| text2vec-nvidia | `_Text2VecNvidiaConfig` | `VectorConfig.text2vec_nvidia/1` | Full |
| text2vec-jinaai | `_Text2VecJinaConfig` | `VectorConfig.text2vec_jinaai/1` | Full |
| text2vec-voyageai | `_Text2VecVoyageConfig` | `VectorConfig.text2vec_voyageai/1` | Full |
| text2vec-weaviate | `_Text2VecWeaviateConfig` | `VectorConfig.text2vec_weaviate/1` | Full |
| text2vec-databricks | `_Text2VecDatabricksConfig` | `VectorConfig.text2vec_databricks/1` | Full |
| text2vec-gpt4all | `_Text2VecGPT4AllConfig` | `VectorConfig.text2vec_gpt4all/1` | Full |
| text2vec-contextionary | `_Text2VecContextionaryConfig` | `VectorConfig.text2vec_contextionary/1` | Full |
| text2vec-transformers | `_Text2VecTransformersConfig` | `VectorConfig.text2vec_transformers/1` | Full |
| text2vec-model2vec | `_Text2VecModel2VecConfig` | `VectorConfig.text2vec_model2vec/1` | Full |

**Python Example:**
```python
from weaviate.classes.config import Configure

vectorizer = Configure.Vectorizer.text2vec_openai(
    model="text-embedding-3-large",
    dimensions=1024,
    base_url="https://custom.openai.api/",
    vectorize_collection_name=False
)
```

**Elixir Example:**
```elixir
vectorizer = VectorConfig.text2vec_openai(
  model: "text-embedding-3-large",
  dimensions: 1024,
  base_url: "https://custom.openai.api/",
  vectorize_collection_name: false
)
```

#### Multi2Vec Vectorizers

| Vectorizer | Python | Elixir | Parity |
|------------|--------|--------|--------|
| multi2vec-clip | Full | Full | Full |
| multi2vec-bind | Full | Full | Full |
| multi2vec-google | Full | Full | Full |
| multi2vec-cohere | Full | Full | Full |
| multi2vec-jinaai | Full | Full | Full |
| multi2vec-voyageai | Full | Full | Full |
| multi2vec-nvidia | Full | Full | Full |
| multi2vec-aws | Full | Full | Full |

#### ColBERT Vectorizer (Gap)

**Python:**
```python
Configure.Vectorizer.text2colbert_jinaai(
    model="jina-colbert-v2",
    dimensions=1024
)
```

**Elixir:**
```elixir
# Available but with limited multi-vector encoding support
VectorConfig.text2colbert_jinaai(
  model: "jina-colbert-v2",
  dimensions: 1024
)
# Missing: muvera encoding configuration
```

---

### 4. Multi-Tenancy Support

#### Tenant Operations Comparison

| Operation | Python Method | Elixir Method | Status |
|-----------|---------------|---------------|--------|
| Create tenants | `tenants.create()` | `Tenants.create/3` | Full |
| Remove tenants | `tenants.remove()` | `Tenants.delete/3` | Full |
| Get all tenants | `tenants.get()` | `Tenants.list/2` | Full |
| Get by names | `tenants.get_by_names()` | Missing | Gap |
| Get by name | `tenants.get_by_name()` | Missing | Gap |
| Update tenants | `tenants.update()` | `Tenants.update/3` | Full |
| Check exists | `tenants.exists()` | Missing | Gap |
| Activate | `tenants.activate()` | Missing | Gap |
| Deactivate | `tenants.deactivate()` | Missing | Gap |
| Offload | `tenants.offload()` | Missing | Gap |

**Python:**
```python
from weaviate.classes.tenants import Tenant, TenantActivityStatus

# Create with status
collection.tenants.create([
    Tenant(name="tenant_a"),
    Tenant(name="tenant_b", activity_status=TenantActivityStatus.INACTIVE)
])

# Activate/deactivate/offload
collection.tenants.activate("tenant_b")
collection.tenants.deactivate("tenant_a")
collection.tenants.offload("tenant_b")

# Check existence
exists = collection.tenants.exists("tenant_a")

# Get specific tenant
tenant = collection.tenants.get_by_name("tenant_a")
```

**Elixir:**
```elixir
alias WeaviateEx.API.Tenants
alias WeaviateEx.Types.Tenant

# Create tenants
Tenants.create(client, "Article", [
  %Tenant{name: "tenant_a", activity_status: :hot},
  %Tenant{name: "tenant_b", activity_status: :cold}
])

# Update tenant status (workaround for activate/deactivate)
Tenants.update(client, "Article", [
  %Tenant{name: "tenant_b", activity_status: :hot}
])

# Missing: exists?, get_by_name, activate, deactivate, offload
```

#### Tenant Activity Status Mapping

| Python Status | Elixir Status | Notes |
|--------------|---------------|-------|
| `ACTIVE` / `HOT` | `:hot` | Full support |
| `INACTIVE` / `COLD` | `:cold` | Full support |
| `OFFLOADED` | `:offloaded` | Missing |
| `OFFLOADING` | `:offloading` | Missing |
| `ONLOADING` | `:onloading` | Missing |

---

### 5. Collection Config (Replication, Sharding, Inverted Index)

#### Replication Configuration

**Python:**
```python
from weaviate.classes.config import Configure, ReplicationDeletionStrategy

Configure.Replication(
    factor=3,
    async_enabled=True,
    deletion_strategy=ReplicationDeletionStrategy.DELETE_ON_CONFLICT
)
```

**Elixir:**
```elixir
VectorConfig.with_replication_config(config,
  factor: 3,
  async_enabled: true,
  deletion_strategy: :delete_on_conflict
)
```

**Status:** Full parity achieved.

#### Sharding Configuration

**Python:**
```python
Configure.Sharding(
    virtual_per_physical=128,
    desired_count=4
)
```

**Elixir:**
```elixir
VectorConfig.with_sharding_config(config,
  virtual_per_physical: 128,
  desired_count: 4
)
```

**Status:** Full parity achieved.

#### Inverted Index Configuration

**Python:**
```python
Configure.inverted_index(
    bm25_b=0.75,
    bm25_k1=1.2,
    cleanup_interval_seconds=60,
    index_timestamps=True,
    index_null_state=True,
    index_property_length=True,
    stopwords_preset=StopwordsPreset.EN,
    stopwords_additions=["custom"],
    stopwords_removals=["the"]
)
```

**Elixir:**
```elixir
InvertedIndexConfig.build(
  bm25: [b: 0.75, k1: 1.2],
  stopwords: [preset: :en, additions: ["custom"], removals: ["the"]],
  cleanup_interval_seconds: 60,
  index_timestamps: true,
  index_null_state: true,
  index_property_length: true
)
```

**Status:** Full parity achieved.

---

### 6. Missing Methods/Functionality

#### High Priority Gaps

1. **Auto Tenant Creation/Activation**
   ```python
   # Python
   Configure.multi_tenancy(
       enabled=True,
       auto_tenant_creation=True,
       auto_tenant_activation=True
   )
   ```
   - Impact: Users must manually create tenants before inserting data
   - Workaround: Pre-create tenants or handle errors

2. **Typed Configuration Update (Reconfigure)**
   ```python
   # Python pattern
   Reconfigure.inverted_index(bm25_b=0.8)
   Reconfigure.VectorIndex.hnsw(ef=200)
   Reconfigure.NamedVectors.update("vector_name", ...)
   ```
   - Impact: Updates require manual JSON construction
   - Recommendation: Add `Reconfigure` module with builder functions

3. **Object TTL Configuration**
   ```python
   # Python
   Configure.ObjectTTL.create(
       collection_ttl=timedelta(days=30)
   )
   ```
   - Impact: Cannot configure automatic object expiration
   - Workaround: Manual cleanup with delete operations

#### Medium Priority Gaps

1. **Tenant Convenience Methods**
   - `tenants.activate()`
   - `tenants.deactivate()`
   - `tenants.offload()`
   - `tenants.exists()`
   - `tenants.get_by_name()`

2. **Multi-Vector Encoding (Muvera)**
   ```python
   # Python
   VectorIndex.MultiVector.Encoding.muvera(
       ksim=64,
       dprojections=128,
       repetitions=4
   )
   ```

3. **Named Vector Index Skip**
   ```python
   # Python
   Configure.NamedVectors.none(
       name="custom_vector",
       vector_index_config=VectorIndex.none()  # Skip indexing
   )
   ```

#### Low Priority Gaps

1. **Vector Index Aggregation Types**
   - `MultiVectorAggregation.MAX_SIM`

2. **Deprecated Method Warnings**
   - Python has `@deprecated` decorators for old methods
   - Elixir could benefit from similar deprecation notices

---

## Priority Recommendations

### Immediate (P0)

1. **Add Auto-Tenant Configuration**
   ```elixir
   # Proposed API
   VectorConfig.with_multi_tenancy(config,
     enabled: true,
     auto_tenant_creation: true,
     auto_tenant_activation: true
   )
   ```

2. **Add Reconfigure Module**
   ```elixir
   # Proposed API
   defmodule WeaviateEx.Reconfigure do
     def inverted_index(opts \\ [])
     def replication(opts \\ [])
     def vector_index_hnsw(opts \\ [])
     def named_vectors_update(name, opts \\ [])
   end
   ```

### Short-term (P1)

1. **Add Tenant Convenience Methods**
   ```elixir
   Tenants.activate(client, collection, tenant_name_or_list)
   Tenants.deactivate(client, collection, tenant_name_or_list)
   Tenants.offload(client, collection, tenant_name_or_list)
   Tenants.exists?(client, collection, tenant_name)
   Tenants.get_by_name(client, collection, tenant_name)
   ```

2. **Add Object TTL Module**
   ```elixir
   defmodule WeaviateEx.Config.ObjectTTL do
     def create(collection_ttl: duration)
     def update(collection_ttl: duration)
   end
   ```

### Medium-term (P2)

1. **Add Multi-Vector Encoding Support**
   ```elixir
   defmodule WeaviateEx.API.MultiVector.Encoding do
     def muvera(opts \\ [])
   end
   ```

2. **Add Missing Tenant Activity Statuses**
   - `:offloaded`
   - `:offloading`
   - `:onloading`

3. **Improve Type Safety**
   - Consider using `TypedStruct` or similar for configuration builders
   - Add compile-time validation for configuration options

---

## Code Examples: Common Patterns

### Creating a Full-Featured Collection

**Python:**
```python
from weaviate.classes.config import (
    Configure, Property, DataType,
    Tokenization, StopwordsPreset
)

client.collections.create(
    name="Article",
    properties=[
        Property(
            name="title",
            data_type=DataType.TEXT,
            tokenization=Tokenization.WORD,
            index_searchable=True
        ),
        Property(
            name="content",
            data_type=DataType.TEXT,
            tokenization=Tokenization.WORD
        ),
        Property(
            name="metadata",
            data_type=DataType.OBJECT,
            nested_properties=[
                Property(name="author", data_type=DataType.TEXT),
                Property(name="publishedAt", data_type=DataType.DATE)
            ]
        )
    ],
    vectorizer_config=[
        Configure.NamedVectors.text2vec_openai(
            name="title_vector",
            source_properties=["title"],
            model="text-embedding-3-small"
        ),
        Configure.NamedVectors.text2vec_openai(
            name="content_vector",
            source_properties=["content"],
            model="text-embedding-3-large",
            dimensions=1024
        )
    ],
    generative_config=Configure.Generative.openai(model="gpt-4"),
    reranker_config=Configure.Reranker.cohere(model="rerank-english-v3.0"),
    replication_config=Configure.Replication(factor=3),
    inverted_index_config=Configure.inverted_index(
        bm25_b=0.75,
        stopwords_preset=StopwordsPreset.EN,
        index_timestamps=True
    ),
    multi_tenancy_config=Configure.multi_tenancy(enabled=True)
)
```

**Elixir:**
```elixir
alias WeaviateEx.{Property, API.Collections, API.VectorConfig}
alias WeaviateEx.API.{NamedVectors, InvertedIndexConfig, GenerativeConfig, RerankerConfig}

named_vectors = NamedVectors.build_vectorizer_config([
  NamedVectors.text2vec_openai(
    name: "title_vector",
    source_properties: ["title"],
    model: "text-embedding-3-small"
  ),
  NamedVectors.text2vec_openai(
    name: "content_vector",
    source_properties: ["content"],
    model: "text-embedding-3-large",
    dimensions: 1024
  )
])

config = %{
  "class" => "Article",
  "properties" => [
    Property.text("title", tokenization: :word, index_searchable: true),
    Property.text("content", tokenization: :word),
    Property.object("metadata", [
      Property.text("author"),
      Property.date("publishedAt")
    ])
  ],
  "vectorConfig" => named_vectors,
  "moduleConfig" => %{
    "generative-openai" => %{"model" => "gpt-4"},
    "reranker-cohere" => %{"model" => "rerank-english-v3.0"}
  },
  "replicationConfig" => %{"factor" => 3},
  "invertedIndexConfig" => InvertedIndexConfig.build(
    bm25: [b: 0.75],
    stopwords: [preset: :en],
    index_timestamps: true
  ),
  "multiTenancyConfig" => %{"enabled" => true}
}

Collections.create(client, config)
```

---

## Conclusion

The WeaviateEx Elixir port provides excellent coverage of the Python Weaviate client's Collections/Schema API. The main areas requiring attention are:

1. **Auto-tenant configuration** - Critical for production multi-tenant deployments
2. **Reconfigure pattern** - Improves developer experience for collection updates
3. **Tenant lifecycle methods** - Convenience methods for common operations
4. **Object TTL** - Required for data lifecycle management

The existing implementation is production-ready for most use cases, with these gaps primarily affecting advanced multi-tenant and lifecycle management scenarios.
