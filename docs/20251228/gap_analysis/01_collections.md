# Collections & Schema Gap Analysis

## Overview

The Elixir client provides solid coverage of basic collection management but lacks many advanced configuration options available in the Python client.

## Collection CRUD Operations

| Operation | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| `create()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.create/3` |
| `get()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.get/2` |
| `list()` / `list_all()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.list/1` |
| `delete()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.delete/2` |
| `delete_all()` | Yes | **No** | **GAP**: Delete all collections at once |
| `exists()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.exists?/2` |
| `update()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.update/3` |
| `add_property()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.add_property/3` |
| `get_shards()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.get_shards/2` |
| `update_shard()` | Yes | Yes | Elixir uses `WeaviateEx.Collections.update_shard/4` |

### Missing: `delete_all()`
```python
# Python
client.collections.delete_all()
```

**Recommendation**: Add `WeaviateEx.Collections.delete_all/1`

---

## Property Types (DataType)

| Data Type | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| `text` | Yes | Yes | |
| `text[]` | Yes | Yes | |
| `int` | Yes | Yes | |
| `int[]` | Yes | Yes | |
| `boolean` | Yes | Yes | |
| `boolean[]` | Yes | Yes | |
| `number` | Yes | Yes | |
| `number[]` | Yes | Yes | |
| `date` | Yes | Yes | |
| `date[]` | Yes | Yes | |
| `uuid` | Yes | Yes | |
| `uuid[]` | Yes | Yes | |
| `geoCoordinates` | Yes | Yes | |
| `blob` | Yes | Yes | |
| `phoneNumber` | Yes | Yes | |
| `object` | Yes | Yes | |
| `object[]` | Yes | Yes | |

**Status**: Full coverage

---

## Property Configuration

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `name` | Yes | Yes | |
| `data_type` / `dataType` | Yes | Yes | |
| `description` | Yes | Yes | |
| `index_filterable` / `indexFilterable` | Yes | Yes | |
| `index_searchable` / `indexSearchable` | Yes | Yes | |
| `index_range_filters` / `indexRangeFilters` | Yes | **Partial** | **GAP**: Not documented/exposed |
| `tokenization` | Yes | Yes | |
| `skip_vectorization` / `skipVectorization` | Yes | Yes | Via moduleConfig |
| `vectorize_property_name` / `vectorizePropertyName` | Yes | Yes | Via moduleConfig |
| `nested_properties` / `nestedProperties` | Yes | Yes | For object types |

### Missing: `index_range_filters`
Python: `Property.index_range_filters: Optional[bool]`

**Recommendation**: Ensure range filter indexing is exposed in property configuration

---

## Tokenization Methods

| Tokenization | Python | Elixir | Notes |
|--------------|--------|--------|-------|
| `word` | Yes | Yes | |
| `whitespace` | Yes | Yes | |
| `lowercase` | Yes | Yes | |
| `field` | Yes | Yes | |
| `gse` | Yes | **?** | CJK segmentation |
| `trigram` | Yes | **?** | 3-char n-grams |
| `kagome_ja` | Yes | **?** | Japanese |
| `kagome_kr` | Yes | **?** | Korean |
| `gse_ch` | Yes | **?** | Chinese |

**Recommendation**: Verify international tokenization options are documented/supported

---

## Vectorizer Configurations

### Text Vectorizers (text2vec-*)

| Vectorizer | Python | Elixir | Notes |
|------------|--------|--------|-------|
| `none` | Yes | Yes | |
| `text2vec-openai` | Yes | Yes | |
| `text2vec-cohere` | Yes | Yes | |
| `text2vec-huggingface` | Yes | **?** | |
| `text2vec-transformers` | Yes | **?** | |
| `text2vec-aws` / `text2vec-aws-bedrock` | Yes | **No** | **GAP** |
| `text2vec-aws-sagemaker` | Yes | **No** | **GAP** |
| `text2vec-azure-openai` | Yes | **?** | |
| `text2vec-google` / `text2vec-palm` | Yes | **?** | |
| `text2vec-google-vertex` | Yes | **?** | |
| `text2vec-google-gemini` | Yes | **?** | |
| `text2vec-jinaai` | Yes | **?** | |
| `text2vec-voyageai` | Yes | **?** | |
| `text2vec-ollama` | Yes | **?** | |
| `text2vec-mistral` | Yes | **No** | **GAP** |
| `text2vec-nvidia` | Yes | **No** | **GAP** |
| `text2vec-databricks` | Yes | **No** | **GAP** |
| `text2vec-weaviate` | Yes | **No** | **GAP** |
| `text2vec-model2vec` | Yes | **No** | **GAP** |
| `text2vec-morph` | Yes | **No** | **GAP** |
| `text2vec-gpt4all` | Yes | **No** | Deprecated |
| `text2vec-contextionary` | Yes | **No** | Deprecated |
| `text2colbert-jinaai` | Yes | **No** | **GAP** |

### Multi-Modal Vectorizers (multi2vec-*)

| Vectorizer | Python | Elixir | Notes |
|------------|--------|--------|-------|
| `multi2vec-clip` | Yes | **?** | |
| `multi2vec-bind` | Yes | **No** | **GAP**: Audio/video/thermal support |
| `multi2vec-cohere` | Yes | **No** | **GAP** |
| `multi2vec-jinaai` | Yes | **No** | **GAP** |
| `multi2vec-google` | Yes | **No** | **GAP** |
| `multi2vec-voyageai` | Yes | **No** | **GAP** |
| `multi2vec-nvidia` | Yes | **No** | **GAP** |
| `multi2vec-aws` | Yes | **No** | **GAP** |

### Other Vectorizers

| Vectorizer | Python | Elixir | Notes |
|------------|--------|--------|-------|
| `img2vec-neural` | Yes | **?** | |
| `ref2vec-centroid` | Yes | **?** | |

**Recommendation**: Implement missing vectorizer configurations, prioritizing:
1. `text2vec-aws-bedrock` - AWS users
2. `text2vec-mistral` - Popular LLM
3. `text2vec-nvidia` - Enterprise users
4. `multi2vec-bind` - Multi-modal support

---

## Vector Index Configuration

### Index Types

| Index Type | Python | Elixir | Notes |
|------------|--------|--------|-------|
| HNSW | Yes | Yes | Default |
| Flat | Yes | Yes | |
| Dynamic | Yes | **?** | Auto-switches HNSW/Flat |

### HNSW Configuration Options

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `cleanup_interval_seconds` | Yes | Yes | |
| `distance_metric` | Yes | Yes | cosine, dot, l2-squared, hamming, manhattan |
| `dynamic_ef_factor` | Yes | **?** | |
| `dynamic_ef_max` | Yes | **?** | |
| `dynamic_ef_min` | Yes | **?** | |
| `ef` | Yes | Yes | |
| `ef_construction` | Yes | Yes | |
| `filter_strategy` | Yes | **No** | **GAP**: SWEEPING or ACORN |
| `flat_search_cutoff` | Yes | **?** | |
| `max_connections` | Yes | Yes | |
| `vector_cache_max_objects` | Yes | **?** | |
| `quantizer` | Yes | Partial | See below |
| `multi_vector` | Yes | **?** | |

### Quantization Options

| Quantizer | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| PQ (Product Quantization) | Yes | Yes | |
| BQ (Binary Quantization) | Yes | Yes | |
| SQ (Scalar Quantization) | Yes | **No** | **GAP** |
| RQ (Rotational Quantization) | Yes | **No** | **GAP** |
| None | Yes | Yes | |

### PQ Configuration

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `centroids` | Yes | **?** | |
| `encoder_distribution` | Yes | **?** | log-normal or normal |
| `encoder_type` | Yes | **?** | kmeans or tile |
| `segments` | Yes | **?** | |
| `training_limit` | Yes | **?** | |

**Recommendation**: Implement SQ and RQ quantizers, expose all PQ options

---

## Inverted Index Configuration

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `bm25_b` | Yes | **?** | |
| `bm25_k1` | Yes | **?** | |
| `cleanup_interval_seconds` | Yes | **?** | |
| `index_timestamps` | Yes | **?** | |
| `index_property_length` | Yes | **?** | |
| `index_null_state` | Yes | **?** | |
| `stopwords_preset` | Yes | **?** | en or none |
| `stopwords_additions` | Yes | **?** | |
| `stopwords_removals` | Yes | **?** | |

**Recommendation**: Verify and document inverted index configuration options

---

## Replication Configuration

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `factor` | Yes | Yes | Number of replicas |
| `async_enabled` | Yes | **?** | v1.26.0+ |
| `deletion_strategy` | Yes | **No** | **GAP**: Conflict resolution |

### Deletion Strategies (Missing)
- `DeleteOnConflict`
- `NoAutomatedResolution`
- `TimeBasedResolution`

---

## Sharding Configuration

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `virtual_per_physical` | Yes | **?** | |
| `desired_count` | Yes | **?** | |
| `desired_virtual_count` | Yes | **?** | |

---

## Generative Module Configuration

| Provider | Python | Elixir | Notes |
|----------|--------|--------|-------|
| OpenAI | Yes | Yes | Full support |
| Anthropic | Yes | Yes | Full support |
| Cohere | Yes | Yes | |
| AWS Bedrock | Yes | Yes | |
| Google Vertex | Yes | Yes | |
| Azure OpenAI | Yes | Yes | |
| Ollama | Yes | Yes | |
| Mistral | Yes | Yes | |
| NVIDIA | Yes | **?** | |
| Databricks | Yes | **?** | |
| FriendliAI | Yes | **?** | |
| XAI (Grok) | Yes | Yes | |
| ContextualAI | Yes | **?** | |
| Anyscale | Yes | **?** | |
| Together AI | Yes | **?** | |
| OctoAI | Yes | **?** | |
| HuggingFace | Yes | **?** | |
| Voyage AI | Yes | **?** | |

**Status**: Good coverage for major providers, verify edge cases

---

## Reranker Configuration

| Provider | Python | Elixir | Notes |
|----------|--------|--------|-------|
| Cohere | Yes | **?** | |
| Transformers | Yes | **?** | |
| JinaAI | Yes | **?** | |
| VoyageAI | Yes | **?** | |
| NVIDIA | Yes | **?** | |
| ContextualAI | Yes | **?** | |

**Recommendation**: Document and verify reranker support

---

## Object TTL Configuration

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `enabled` | Yes | Yes | Via `WeaviateEx.Config.ObjectTTL` |
| `ttl_seconds` | Yes | Yes | |

**Status**: Full coverage

---

## Summary of Gaps

### High Priority
1. Missing vectorizers: AWS Bedrock/SageMaker, Mistral, NVIDIA, Databricks
2. Missing quantizers: SQ, RQ
3. Missing `delete_all()` for collections
4. Missing `filter_strategy` for HNSW (ACORN support)
5. Missing replication `deletion_strategy`

### Medium Priority
1. Multi-modal vectorizers (multi2vec-bind, multi2vec-google, etc.)
2. Dynamic vector index type
3. International tokenization verification
4. Full inverted index configuration exposure

### Low Priority
1. Deprecated vectorizers (contextionary, gpt4all)
2. Edge-case reranker configurations
