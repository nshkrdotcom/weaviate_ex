# Collections & Schema API Gap Analysis

## Executive Summary

This analysis compares the Collections/Schema API between the Python client (`weaviate-python-client/weaviate/collections/`) and the Elixir port (`lib/weaviate_ex/`).

**Overall Feature Parity: ~85%**

## Feature Comparison Matrix

| Feature | Python | Elixir | Parity |
|---------|--------|--------|--------|
| Collection CRUD | Full | Basic | 70% |
| Data Types | 17 types | 17 types | 100% |
| Vectorizers | 25+ | 25+ | 100% |
| Vector Index Types | 3 (HNSW, FLAT, DYNAMIC) | 3 | 100% |
| Quantization Methods | 4 (PQ, BQ, SQ, RQ) | 4 | 100% |
| Replication Config | Yes | Yes | 90% |
| Sharding Config | Yes | Yes | 90% |
| Multi-Tenancy | Basic | Advanced | 110%* |
| Inverted Index Config | Full | Missing | 20% |
| Generative Search | 12+ providers | Missing | 0% |
| Rerankers | 6 types | 6 types | 100% |

*Elixir has more features than Python for multi-tenancy (activity status)

---

## 1. Collection Creation, Update, Delete Operations

### Python (Full-Featured)
- `collections.create_from_dict(config: dict)` - Create from raw dictionary
- `collections.create_from_config(config: CollectionConfig)` - Create from typed config object
- Advanced validation through Pydantic models
- Automatic schema generation and type checking
- Full AsyncAPI support

### Elixir (Basic but Functional)
- `Collections.create(name, config, opts)` - Straightforward HTTP-based creation
- `Collections.update(name, config, opts)` - Update existing collection
- `Collections.delete(name, opts)` - Delete collection
- `Collections.delete_all(opts)` - Batch delete with result tracking
- Raw map-based configuration (no type safety)
- Optional HTTP/gRPC protocol support

### Gaps
- Elixir lacks typed configuration builders (no type validation)
- Elixir lacks create_from_config equivalent with pre-validated objects
- No Pydantic-like validation in Elixir version

---

## 2. Property Definitions and Data Types

### Python Support
```python
DataType enum with 17 types:
- TEXT, TEXT_ARRAY
- INT, INT_ARRAY
- BOOL, BOOL_ARRAY
- NUMBER, NUMBER_ARRAY
- DATE, DATE_ARRAY
- UUID, UUID_ARRAY
- GEO_COORDINATES, BLOB, PHONE_NUMBER
- OBJECT, OBJECT_ARRAY
```

### Elixir Support
```elixir
WeaviateEx.Property module with convenience functions:
- text/2, text_array/2
- int/2, int_array/2
- boolean/2, boolean_array/2
- number/2, number_array/2
- date/2, date_array/2
- uuid/2, uuid_array/2
- blob/2, geo_coordinates/2, phone_number/2
- object/3, object_array/3 (nested support)
- reference/3 (cross-references)
```

### Parity
- Both support all 17 data types
- Elixir's builder pattern is more ergonomic than Python's enum-based approach
- Both support nested objects, arrays, and cross-references

---

## 3. Vector Configurations

### Python (25+ Vectorizers)
- text2vec-openai, text2vec-cohere, text2vec-huggingface
- text2vec-transformers, text2vec-contextionary, text2vec-gpt4all
- text2vec-google (vertex/gemini), text2vec-aws (bedrock/sagemaker)
- text2vec-jinaai, text2vec-voyageai, text2vec-mistral, text2vec-nvidia
- text2vec-ollama, text2vec-weaviate, text2vec-azure-openai
- text2colbert-jinaai (multi-vector)
- multi2vec-clip, multi2vec-bind, multi2vec-google, multi2vec-cohere
- multi2vec-jinaai, multi2vec-voyageai, multi2vec-nvidia, multi2vec-aws
- img2vec-neural, ref2vec-centroid

### Elixir (25+ Vectorizers)
- Same coverage via `WeaviateEx.API.VectorConfig` module
- Named vectors via `WeaviateEx.API.NamedVectors`
- Multi-vector support via `WeaviateEx.API.MultiVector`
- Full builder pattern support

### Parity: 100%

---

## 4. Inverted Index Configuration

### Python (Comprehensive)
```python
_InvertedIndexConfigCreate with:
- BM25 configuration (b, k1 parameters)
- Stopwords (preset: EN/NONE, additions, removals)
- cleanupIntervalSeconds
- indexTimestamps
- indexPropertyLength
- indexNullState
```

### Elixir (Basic)
- Only basic support via `invertedIndexConfig` parameter
- No builder helpers for detailed configuration

### Gap: MAJOR
- Elixir lacks dedicated inverted index configuration builders
- Requires manual map construction for advanced settings
- BM25 parameters not exposed in Elixir API

**Recommendation:** Create `WeaviateEx.API.InvertedIndexConfig` module

---

## 5. Replication and Sharding Settings

### Python
```python
_ReplicationConfigCreate:
- factor, asyncEnabled, deletionStrategy

_ShardingConfigCreate:
- virtualPerPhysical, desiredCount, key, strategy, function
```

### Elixir
- `with_replication_config(config, opts)` helper
- `with_sharding_config(config, opts)` helper
- Supports all major parameters

### Parity: 90%

---

## 6. Multi-Tenancy Support

### Python (Basic)
- `_MultiTenancyConfigCreate` with enabled, autoTenantCreation, autoTenantActivation

### Elixir (Advanced)
- Full tenant CRUD operations
- Activity status management (HOT, COLD, FROZEN, WARM, etc.)
- gRPC + HTTP support
- `API.Tenants` module with list, get, create, update, delete

### Parity: 110% (Elixir exceeds Python)

---

## 7. Generative Search Configuration

### Python (12+ Providers)
- OpenAI, Azure OpenAI, Cohere, ContextualAI
- Anthropic, Mistral, Databricks, Google (PaLM)
- Google Vertex AI, AWS Bedrock/SageMaker
- Ollama, XAI, FriendlyAI, NVIDIA

### Elixir
- **NOT IMPLEMENTED** - Must construct maps manually

### Gap: MAJOR (0% parity)
**Recommendation:** Create `WeaviateEx.API.GenerativeSearch` module

---

## 8. Vector Index Configuration

### Both Support
- HNSW, FLAT, DYNAMIC index types
- Product Quantization (PQ)
- Binary Quantization (BQ)
- Scalar Quantization (SQ)
- Rotational Quantization (RQ)

### Parity: 100%

---

## 9. Reranker Configuration

### Python (6 Providers)
- cohere, voyageai, jinaai, nvidia, transformers, contextualai

### Elixir (6 Providers)
- `reranker_cohere`, `reranker_voyageai`, `reranker_jinaai`
- `reranker_nvidia`, `reranker_transformers`, `reranker_contextualai`

### Parity: 100%

---

## Priority Implementation Recommendations

### High Priority
1. **Inverted Index Configuration Module**
   - Create `WeaviateEx.API.InvertedIndexConfig`
   - Add BM25, Stopwords builders

2. **Generative Search Configuration**
   - Create `WeaviateEx.API.GenerativeSearch`
   - Support 12+ provider types

3. **Type-Safe Configuration Objects**
   - Add validation helpers
   - Improve IDE autocomplete/type safety

### Medium Priority
1. Property validation layer
2. Async variants consideration
3. Configuration validation helpers

---

## Conclusion

The Elixir port has excellent coverage for vector configurations, data types, and rerankers. The main gaps are in generative search configuration builders and inverted index configuration helpers. Multi-tenancy support actually exceeds the Python client's capabilities.
