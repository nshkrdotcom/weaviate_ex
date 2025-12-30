# Collections and Schema API Gap Analysis

## Weaviate Python Client vs WeaviateEx Elixir Port

**Analysis Date:** December 29, 2025 (Updated)
**Python Client Path:** `weaviate-python-client/weaviate/collections/`
**Elixir Port Path:** `lib/weaviate_ex/`
**Python Client Version:** Latest (weaviate-client)
**Elixir Port Version:** v0.7.2

---

## Executive Summary

The WeaviateEx Elixir port provides **substantial coverage** of the Weaviate Python client's Collections and Schema API, with approximately **85-90%** feature parity for core functionality. The Elixir implementation demonstrates idiomatic Elixir patterns with good type specifications and documentation.

### Coverage Statistics

| Area | Python Features | Elixir Features | Coverage |
|------|-----------------|-----------------|----------|
| Collection CRUD | 6 | 6 | 100% |
| Data Types | 17 | 17 | 100% |
| Property Definitions | 8 | 8 | 100% |
| Named Vectors | 12+ vectorizers | 12+ vectorizers | ~95% |
| Multi-tenancy | 7 states | 6 states | ~85% |
| Quantizers | 4 types | 4 types | 100% |
| Index Types | 3 types | 3 types | 100% |
| Generative Configs | 15+ providers | 15+ providers | ~90% |
| Reranker Configs | 7 providers | 6 providers | ~85% |

### Key Strengths of Elixir Port
- Comprehensive vectorizer support (25+ vectorizers matching Python)
- Strong inverted index configuration
- Full multi-tenancy support with gRPC optimization
- Named vectors support with update builders
- Property builder with nested object support
- All quantization methods (PQ, BQ, SQ, RQ)
- Elixir-specific convenience functions (delete_all with details, tenant filtering)

### Primary Gaps
1. **Object TTL configuration** - Not implemented
2. **Some advanced property options** - `index_range_filters`, per-vectorizer property configs
3. **Custom reranker/generative providers** - Limited support
4. **Auto-tenant management** - Missing autoTenantCreation/autoTenantActivation

---

## Feature-by-Feature Comparison

### 1. Collection CRUD Operations

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Create collection | `collections.create()` | `Collections.create/3` | Complete |
| Get collection | `collections.get()` | `Collections.get/2` | Complete |
| List collections | `collections.list_all()` | `Collections.list/1` | Complete |
| Delete collection | `collections.delete()` | `Collections.delete/2` | Complete |
| Exists check | `collections.exists()` | `Collections.exists?/2` | Complete |
| Delete all | `collections.delete_all()` | `Collections.delete_all/1` | Complete |
| Update collection | `collection.config.update()` | `Collections.update/4` | Partial |
| Add property | `collection.config.add_property()` | `Collections.add_property/3` | Complete |

**Gaps in Update Operations:**
- Python supports granular config updates (inverted index, replication, vectorizer configs)
- Elixir currently passes updates as raw maps without structured validation

**Elixir-Specific Additions:**
- `delete_all/1` returns detailed results with `deleted_count`, `failed_count`, and `failures` list
- `add_property/3` - Dedicated function for adding properties to existing collections
- `get_shards/3` - Dedicated function for shard inspection with tenant filtering
- `set_multi_tenancy/4` - Dedicated function for toggling multi-tenancy

### 2. Property Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Basic properties | `Property()` | `Property.new/3` | Complete |
| Text/text[] | `DataType.TEXT/TEXT_ARRAY` | `:text/:text_array` | Complete |
| Int/int[] | `DataType.INT/INT_ARRAY` | `:int/:int_array` | Complete |
| Number/number[] | `DataType.NUMBER/NUMBER_ARRAY` | `:number/:number_array` | Complete |
| Boolean/boolean[] | `DataType.BOOL/BOOL_ARRAY` | `:boolean/:boolean_array` | Complete |
| Date/date[] | `DataType.DATE/DATE_ARRAY` | `:date/:date_array` | Complete |
| UUID/uuid[] | `DataType.UUID/UUID_ARRAY` | `:uuid/:uuid_array` | Complete |
| GeoCoordinates | `DataType.GEO_COORDINATES` | `:geo_coordinates` | Complete |
| Blob | `DataType.BLOB` | `:blob` | Complete |
| PhoneNumber | `DataType.PHONE_NUMBER` | `:phone_number` | Complete |
| Object/object[] | `DataType.OBJECT/OBJECT_ARRAY` | `:object/:object_array` | Complete |
| Nested properties | `NestedProperty()` | `Property.Nested` | Complete |
| Tokenization | `Tokenization` enum | `:word, :whitespace, etc.` | Complete |
| `indexFilterable` | Yes | Yes | Complete |
| `indexSearchable` | Yes | Yes | Complete |
| `indexRangeFilters` | Yes | No | **Missing** |
| Per-property vectorizer config | `PropertyVectorizerConfig` | Partial | Partial |
| Multi-vectorizer property config | `vectorizer_configs` dict | No | **Missing** |

**Python Property Definition:**
```python
Property(
    name="title",
    data_type=DataType.TEXT,
    index_filterable=True,
    index_searchable=True,
    index_range_filters=True,  # Missing in Elixir
    tokenization=Tokenization.WORD,
    vectorizer_config=PropertyVectorizerConfig(
        skip=False,
        vectorize_property_name=True
    ),
    vectorizer_configs={  # Missing in Elixir
        "title_vector": PropertyVectorizerConfig(skip=False),
        "content_vector": PropertyVectorizerConfig(skip=True)
    }
)
```

**Elixir Property Definition:**
```elixir
Property.text("title",
  index_filterable: true,
  index_searchable: true,
  tokenization: :word,
  skip_vectorization: false,
  vectorize_property_name: true
)
```

### 3. Reference Properties

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Single reference | `ReferenceProperty()` | `Property.reference/3` | Complete |
| Multi-target reference | target_collections list | Single target | Partial |
| Reference description | Yes | Yes | Complete |

**Gap:** Python supports multiple target collections per reference:
```python
ReferenceProperty(
    name="relatedTo",
    target_collections=["Article", "Author", "Topic"]
)
```

Elixir only supports single target:
```elixir
Property.reference("hasAuthor", "Author")
```

### 4. Nested Properties Support

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Nested objects | `NestedProperty` | `Property.Nested` | Complete |
| Recursive nesting | Yes | Yes | Complete |
| `indexFilterable` on nested | Yes | As `indexable` | Complete |
| `indexSearchable` on nested | Yes | As `indexable` | Complete |
| Tokenization on nested | Yes | Yes | Complete |
| API conversion | `to_dict()` | `to_api/1` | Complete |
| API parsing | From response | `from_api/1` | Complete |
| Validation | Implicit | `valid?/1` | Complete |

**Implementation Comparison:**

Python:
```python
NestedProperty(
    name="author",
    data_type=DataType.OBJECT,
    nested_properties=[
        NestedProperty(name="name", data_type=DataType.TEXT),
        NestedProperty(name="email", data_type=DataType.TEXT)
    ]
)
```

Elixir:
```elixir
Property.object("author", [
  Property.text("name"),
  Property.text("email")
])
```

### 5. Vectorizer Configuration

| Vectorizer | Python Client | Elixir Port | Status |
|------------|---------------|-------------|--------|
| text2vec-openai | Yes | Yes | Complete |
| text2vec-cohere | Yes | Yes | Complete |
| text2vec-huggingface | Yes | Yes | Complete |
| text2vec-transformers | Yes | Yes | Complete |
| text2vec-contextionary | Yes | Yes | Complete |
| text2vec-gpt4all | Yes | Yes | Complete |
| text2vec-palm/google | Yes | Yes | Complete |
| text2vec-aws | Yes | Yes | Complete |
| text2vec-azure-openai | Yes | Yes | Complete |
| text2vec-jinaai | Yes | Yes | Complete |
| text2vec-voyageai | Yes | Yes | Complete |
| text2vec-nvidia | Yes | Yes | Complete |
| text2vec-ollama | Yes | Yes | Complete |
| text2vec-mistral | Yes | Yes | Complete |
| text2vec-databricks | Yes | Yes | Complete |
| text2vec-weaviate | Yes | Yes | Complete |
| text2vec-morph | Yes | Yes | Complete |
| text2vec-model2vec | Yes | Yes | Complete |
| text2colbert-jinaai | Yes | Yes | Complete |
| multi2vec-clip | Yes | Yes | Complete |
| multi2vec-bind | Yes | Yes | Complete |
| multi2vec-palm/google | Yes | Yes | Complete |
| multi2vec-cohere | Yes | Yes | Complete |
| multi2vec-jinaai | Yes | Yes | Complete |
| multi2vec-voyageai | Yes | Yes | Complete |
| multi2vec-nvidia | Yes | Yes | Complete |
| multi2vec-aws | Yes | Yes | Complete |
| multi2multivec-jinaai | Yes | Yes | Complete |
| img2vec-neural | Yes | Yes | Complete |
| ref2vec-centroid | Yes | Yes | Complete |
| none (custom vectors) | Yes | Yes | Complete |

### 6. Vector Index Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| HNSW index | Yes | Yes | Complete |
| Flat index | Yes | Yes | Complete |
| Dynamic index | Yes | Yes | Complete |
| Distance metrics | cosine, dot, l2, hamming, manhattan | All 5 | Complete |
| ef parameter | Yes | Yes | Complete |
| efConstruction | Yes | Yes | Complete |
| maxConnections | Yes | Yes | Complete |
| dynamicEfMin/Max/Factor | Yes | Yes | Complete |
| flatSearchCutoff | Yes | Yes | Complete |
| vectorCacheMaxObjects | Yes | Yes | Complete |
| cleanupIntervalSeconds | Yes | Yes | Complete |
| filterStrategy | sweeping, acorn | Yes | Complete |
| skip | Yes | No | **Missing** |

### 7. Quantization Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Product Quantization (PQ) | Yes | Yes | Complete |
| Binary Quantization (BQ) | Yes | Yes | Complete |
| Scalar Quantization (SQ) | Yes | Yes | Complete |
| Rotational Quantization (RQ) | Yes | Yes | Complete |
| PQ encoder config | type, distribution | Partial | Partial |
| PQ segments/centroids | Yes | Yes | Complete |
| PQ training limit | Yes | Yes | Complete |
| BQ cache | Yes | Implicit | Complete |
| BQ rescore limit | Yes | Implicit | Complete |
| SQ cache | Yes | Yes | Complete |
| SQ rescore/training limit | Yes | Yes | Complete |
| RQ bits | Yes | Yes | Complete |
| RQ cache | Yes | Yes | Complete |

### 8. Named Vectors (Multi-Vector Support)

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Named vector definition | `_NamedVectorConfigCreate` | `NamedVectors` module | Complete |
| Multiple vectorizers | Yes | Yes | Complete |
| Per-vector index config | Yes | Yes | Complete |
| Per-vector quantization | Yes | Yes | Complete |
| Source properties | Yes | Yes | Complete |
| Self-provided vectors | Yes | Yes | Complete |
| Vector config update | `_NamedVectorConfigUpdate` | Yes | Complete |

**Elixir Named Vector Update Builders:**
```elixir
# Update HNSW ef parameter for a named vector
NamedVectors.update_config("title_vector",
  vector_index: [ef: 200, dynamic_ef_max: 500]
)

# Update quantizer for a named vector
NamedVectors.update_config("content_vector",
  quantizer: [type: :pq, segments: 128]
)

# Build batch update configs
NamedVectors.build_update_config([
  NamedVectors.update_config("title_vector", vector_index: [ef: 200]),
  NamedVectors.update_config("content_vector", vector_index: [ef: 150])
])
```

**Python Named Vectors:**
```python
Configure.NamedVectors.text2vec_openai(
    name="title_vector",
    source_properties=["title"],
    vector_index_config=Configure.VectorIndex.hnsw(
        quantizer=Configure.VectorIndex.Quantizer.pq()
    )
)
```

**Elixir Named Vectors:**
```elixir
NamedVectors.text2vec_openai(
  name: "title_vector",
  source_properties: ["title"],
  hnsw_opts: %{"quantizer" => "pq"}
)
```

### 9. Inverted Index Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| BM25 b/k1 parameters | Yes | Yes | Complete |
| Stopwords preset | en, none | Yes | Complete |
| Stopwords additions | Yes | Yes | Complete |
| Stopwords removals | Yes | Yes | Complete |
| cleanupIntervalSeconds | Yes | Yes | Complete |
| indexTimestamps | Yes | Yes | Complete |
| indexPropertyLength | Yes | Yes | Complete |
| indexNullState | Yes | Yes | Complete |
| Config validation | Yes | Yes | Complete |
| Config merge | No | Yes | Elixir Extra |

### 10. Replication Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Replication factor | Yes | Yes | Complete |
| asyncEnabled | Yes | Yes | Complete |
| deletionStrategy | DeleteOnConflict, NoAutomatedResolution, TimeBasedResolution | Yes | Complete |
| Replication operations | Copy, Move types | Yes | Complete |
| Operation status tracking | Yes | Yes | Complete |
| Config update | Yes | Partial | Partial |

### 11. Sharding Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| virtualPerPhysical | Yes | Yes | Complete |
| desiredCount | Yes | Yes | Complete |
| actualCount | Yes | Yes | Complete |
| desiredVirtualCount | Yes | No | **Missing** |
| actualVirtualCount | Read-only | No | **Missing** |
| key | Yes (_id) | No | **Missing** |
| strategy | Yes (hash) | No | **Missing** |
| function | Yes (murmur3) | No | **Missing** |
| Get shards | Yes | Yes | Complete |

### 12. Multi-Tenancy Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Enable/disable | Yes | Yes | Complete |
| autoTenantCreation | Yes | No | **Missing** |
| autoTenantActivation | Yes | No | **Missing** |
| Tenant CRUD | Yes | Yes | Complete |
| Tenant status (HOT/COLD/FROZEN) | Yes | Yes | Complete |
| Tenant offloading | Yes | Yes | Complete |
| gRPC tenant operations | Yes | Yes | Complete |
| Batch tenant operations | Yes | Yes | Complete |
| List active/inactive | No | Yes | **Elixir Extra** |
| Tenant count | No | Yes | **Elixir Extra** |
| Activate/deactivate helpers | Implicit | Yes | **Elixir Extra** |
| Freeze/offload helpers | Implicit | Yes | **Elixir Extra** |

**Elixir Tenant Convenience Functions:**
```elixir
# List tenants by status
{:ok, active_tenants} = Tenants.list_active(client, "Article")
{:ok, inactive_tenants} = Tenants.list_inactive(client, "Article")

# Count tenants
{:ok, 5} = Tenants.count(client, "Article")

# Status change helpers
Tenants.activate(client, "Article", "TenantA")
Tenants.deactivate(client, "Article", "TenantA")
Tenants.freeze(client, "Article", "TenantA")
Tenants.offload(client, "Article", "TenantA")

# Batch update with automatic chunking (100 per batch)
Tenants.batch_update(client, "Article", [
  %{name: "tenant1", activity_status: :hot},
  %{name: "tenant2", activity_status: :cold}
])
```

### 13. Generative (RAG) Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| OpenAI | Yes | Yes | Complete |
| Azure OpenAI | Yes | Yes | Complete |
| Anthropic | Yes | Yes | Complete |
| Cohere | Yes | Yes | Complete |
| Mistral | Yes | Yes | Complete |
| Google/PaLM | Yes | Yes | Complete |
| AWS Bedrock/SageMaker | Yes | Yes | Complete |
| Ollama | Yes | Yes | Complete |
| Databricks | Yes | Yes | Complete |
| NVIDIA | Yes | Yes | Complete |
| FriendliAI | Yes | Yes | Complete |
| XAI (Grok) | Yes | Yes | Complete |
| Anyscale | Yes | Yes | Complete |
| ContextualAI | Yes | Yes | Complete |
| Custom config | Yes | No | **Missing** |
| O1/O3 reasoning params | verbosity, reasoningEffort | No | **Missing** |

### 14. Reranker Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| reranker-cohere | Yes | Yes | Complete |
| reranker-transformers | Yes | Yes | Complete |
| reranker-voyageai | Yes | Yes | Complete |
| reranker-jinaai | Yes | Yes | Complete |
| reranker-nvidia | Yes | Yes | Complete |
| reranker-contextualai | Yes | Yes | Complete |
| Custom reranker | Yes | No | **Missing** |

### 15. Object TTL Configuration

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| TTL enabled | Yes | No | **Missing** |
| time_to_live | Yes | No | **Missing** |
| filter_expired_objects | Yes | No | **Missing** |
| delete_on (updateTime/creationTime) | Yes | No | **Missing** |
| TTL config create | `_ObjectTTLConfigCreate` | No | **Missing** |
| TTL config update | `_ObjectTTLConfigUpdate` | No | **Missing** |

---

## Missing Features Summary

### Critical Gaps (High Priority)
1. **Object TTL Configuration** - Complete feature missing
2. **Multi-target references** - Only single target supported
3. **Named vector config updates** - Cannot update existing named vector configs
4. **autoTenantCreation/autoTenantActivation** - Multi-tenancy auto-management

### Moderate Gaps (Medium Priority)
1. **index_range_filters** property option
2. **Per-vectorizer property configs** for multi-vector scenarios
3. **Custom generative/reranker configs** for unlisted providers
4. **Sharding advanced options** (key, strategy, function)
5. **OpenAI reasoning params** (verbosity, reasoningEffort)

### Minor Gaps (Low Priority)
1. **vector index skip option**
2. **desiredVirtualCount** sharding config
3. **PQ encoder distribution** config

---

## Implementation Differences

### 1. Type System Approach

**Python:** Uses Pydantic models with strong typing, validation, and serialization
```python
@dataclass
class _Property(_PropertyBase):
    data_type: DataType
    index_filterable: bool
    index_range_filters: bool
    # ... with validators and serializers
```

**Elixir:** Uses plain maps with runtime conversion functions
```elixir
def new(name, data_type, opts \\ []) do
  %{
    "name" => name,
    "dataType" => [normalize_data_type(data_type)]
  }
  |> maybe_put("indexFilterable", Keyword.get(opts, :index_filterable))
  # ...
end
```

**Recommendation:** Consider adding Elixir structs with `@enforce_keys` for critical configurations to catch errors earlier.

### 2. Configuration Building Pattern

**Python:** Factory methods on Configure class with nested builders
```python
collection = client.collections.create(
    name="Article",
    vectorizer_config=Configure.Vectorizer.text2vec_openai(model="ada"),
    properties=[
        Property(name="title", data_type=DataType.TEXT)
    ]
)
```

**Elixir:** Pipeline-friendly builders with keyword options
```elixir
config = VectorConfig.new("Article")
|> VectorConfig.with_vectorizer(:text2vec_openai, model: "ada")
|> VectorConfig.with_properties([
  Property.text("title")
])

Collections.create(client, config)
```

Both approaches are idiomatic for their respective languages.

### 3. Error Handling

**Python:** Raises `WeaviateInvalidInputError` with validation messages
**Elixir:** Returns `{:ok, result}` or `{:error, Error.t()}` tuples

The Elixir approach is more idiomatic but validation could be more comprehensive.

---

## Recommendations for Closing Gaps

### Phase 1: Critical Features (1-2 weeks)
1. **Implement Object TTL Configuration**
   - Create `WeaviateEx.API.ObjectTTLConfig` module
   - Add `time_to_live`, `filter_expired_objects`, `delete_on` options
   - Integrate with collection creation/update

2. **Add Multi-Target References**
   - Update `Property.reference/3` to accept list of targets
   - `Property.reference("relatedTo", ["Article", "Author"])`

3. **Implement Auto-Tenant Configuration**
   - Add `auto_tenant_creation` and `auto_tenant_activation` to multi-tenancy config

### Phase 2: Enhanced Property Options (1 week)
1. **Add `index_range_filters` Option**
   - Update Property module to support range filter indexing

2. **Implement Per-Vectorizer Property Configs**
   - Add `vectorizer_configs` map support for named vector scenarios

### Phase 3: Advanced Configurations (1 week)
1. **Named Vector Config Updates**
   - Implement update operations for existing named vector configurations

2. **Custom Provider Configs**
   - Add `GenerativeConfig.custom/2` and `VectorConfig.custom/2` for unlisted providers

3. **Complete Sharding Options**
   - Add key, strategy, function options to sharding config

### Phase 4: Polish and Validation (1 week)
1. **Add Struct-Based Configs**
   - Convert critical configurations to Elixir structs with `@enforce_keys`
   - Add compile-time validation where possible

2. **OpenAI Reasoning Parameters**
   - Add verbosity and reasoningEffort for O1/O3 model support

---

## Conclusion

The WeaviateEx Elixir port provides excellent coverage of Weaviate's Collections and Schema API. The implementation is idiomatic Elixir with good documentation and type specifications. The primary gaps are in advanced configuration options and some newer features (Object TTL, auto-tenant management).

The recommended 4-phase improvement plan would bring the Elixir port to near-complete feature parity with the Python client while maintaining Elixir idioms and patterns.

---

## Appendix: File Reference

### Python Client Files Analyzed
- `/weaviate-python-client/weaviate/collections/classes/config.py` - Main configuration classes
- `/weaviate-python-client/weaviate/collections/classes/config_vectorizers.py` - Vectorizer definitions
- `/weaviate-python-client/weaviate/collections/classes/tenants.py` - Tenant management
- `/weaviate-python-client/weaviate/collections/collections/executor.py` - Collection operations

### Elixir Port Files Analyzed
- `/lib/weaviate_ex/api/collections.ex` - Collection CRUD operations (263 lines)
- `/lib/weaviate_ex/property.ex` - Property builder (236 lines)
- `/lib/weaviate_ex/property/nested.ex` - Nested properties (265 lines)
- `/lib/weaviate_ex/api/tenants.ex` - Tenant management (399 lines)
- `/lib/weaviate_ex/api/vector_config.ex` - Vector configuration (1543 lines)
- `/lib/weaviate_ex/api/named_vectors.ex` - Named vectors (469 lines)
- `/lib/weaviate_ex/api/inverted_index_config.ex` - Inverted index (355 lines)
- `/lib/weaviate_ex/api/generative_config.ex` - Generative RAG (516 lines)
- `/lib/weaviate_ex/types/data_type.ex` - Data type definitions (160 lines)
- `/lib/weaviate_ex/cluster/replication.ex` - Replication types (212 lines)
