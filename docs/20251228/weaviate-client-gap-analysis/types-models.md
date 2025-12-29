# Types & Data Models Gap Analysis

## Overview
Comprehensive comparison of Weaviate Python vs Elixir client type definitions and data models.

**Analysis Date:** 2025-12-28
**Python Files Analyzed:** `weaviate/types.py`, `weaviate/outputs/`, `weaviate/collections/classes/`
**Elixir Files Analyzed:** `lib/weaviate_ex/types/`, various API modules

---

## Executive Summary

Python has **130+ type definitions** with comprehensive Pydantic models and generics. Elixir has **~50 types** with implicit map-based structures. Approximately **70+ type definitions are missing** in Elixir.

---

## Primitive Types

### UUID Handling

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| UUID type | `UUID = Union[str, uuid.UUID]` | `WeaviateEx.Types.UUID` | ✅ Full |
| UUID validation | `uuid.UUID` validation | `UUID.validate/1` regex | ✅ Full |
| UUID generation | `uuid.uuid4()` | `UUID.generate/0` | ✅ Full |
| Deterministic UUID (v5) | Not in core | `UUID.from_string/2` | ✅ Elixir Extra |
| UUID constants | `UUIDS = Sequence[UUID]` | Implicit | ⚠️ Gap |

### DateTime Handling

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Date type | `DATE = datetime.datetime` | `:date` atom | ⚠️ Basic |
| Date array | `date[]` datatype | `:date_array` atom | ✅ Full |
| Time alias | `TIME = datetime.datetime` | Not defined | ❌ Gap |
| DateTime parsing | Pydantic auto | Native DateTime | ✅ Full |

### Complex Primitive Types

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| GeoCoordinate | `GeoCoordinate` class | `Types.GeoCoordinate` | ✅ Full |
| PhoneNumber (input) | `PhoneNumber` class | `Types.PhoneNumber` | ✅ Full |
| PhoneNumber (output) | `_PhoneNumber` | `Types.PhoneNumber.Output` | ✅ Full |
| Blob | `BLOB_INPUT` type | `Types.Blob` | ✅ Full |

---

## DataType Enumeration

| Python | Elixir | Status |
|--------|--------|--------|
| `text` | `:text` | ✅ |
| `text[]` | `:text_array` | ✅ |
| `int` | `:int` | ✅ |
| `int[]` | `:int_array` | ✅ |
| `boolean` | `:boolean` | ✅ |
| `boolean[]` | `:boolean_array` | ✅ |
| `number` | `:number` | ✅ |
| `number[]` | `:number_array` | ✅ |
| `date` | `:date` | ✅ |
| `date[]` | `:date_array` | ✅ |
| `uuid` | `:uuid` | ✅ |
| `uuid[]` | `:uuid_array` | ✅ |
| `geoCoordinates` | `:geo_coordinates` | ✅ |
| `phoneNumber` | `:phone_number` | ✅ |
| `blob` | `:blob` | ✅ |
| `object` | `:object` | ✅ |
| `object[]` | `:object_array` | ✅ |

---

## Vector Types

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| Single Vector | `Sequence[NUMBER]` | Map/list of floats | ✅ Full |
| Named Vectors | `Mapping[str, Sequence]` | `NamedVectors` module | ✅ Full |
| Multi-vector | `_MultiVectors` class | Builder functions | ✅ Full |
| Vector Include | `INCLUDE_VECTOR` union | Keyword opts | ⚠️ Implicit |
| Vector Input Type | `NearVectorInputType` | Not defined | ❌ Gap |

---

## Response Models (MAJOR GAP)

### Object Response Models

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `Object[P, R]` | Generic dataclass | Implicit maps | ❌ Gap |
| `MetadataReturn` | 8 optional fields | Implicit | ❌ Gap |
| `ObjectSingleReturn` | Single object type | Implicit | ❌ Gap |
| `GroupByObject` | With `belongs_to_group` | Not documented | ❌ Gap |

### Metadata Fields

| Field | Python Type | Elixir Status |
|-------|-------------|---------------|
| `creation_time` | `datetime` | ❌ Implicit |
| `last_update_time` | `datetime` | ❌ Implicit |
| `distance` | `Optional[float]` | ❌ Implicit |
| `certainty` | `Optional[float]` | ❌ Implicit |
| `score` | `Optional[float]` | ❌ Implicit |
| `explain_score` | `Optional[str]` | ❌ Implicit |
| `is_consistent` | `Optional[bool]` | ❌ Implicit |
| `rerank_score` | `Optional[float]` | ❌ Implicit |

### Query Response Models

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `QueryReturn[P, R]` | Generic container | Implicit | ❌ Gap |
| `QuerySingleReturn[P, R]` | Single fetch | Implicit | ❌ Gap |
| `Sorting` | Class in grpc.py | Not defined | ❌ Gap |

### Generative Response Models

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `GenerativeObject[P, R]` | Extends Object | Via module | ⚠️ Implicit |
| `GenerativeReturn[P, R]` | Container | Via module | ⚠️ Implicit |
| `GenerativeGroup[P, R]` | Grouped results | Via module | ⚠️ Implicit |
| `GenerativeSingle` | Single result | Implicit | ❌ Gap |
| `GenerativeGroupByReturn` | Grouped generation | Not typed | ❌ Gap |

---

## Aggregate Response Models (ALL MISSING)

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `AggregateInteger` | 7 metrics | ❌ Missing | Gap |
| `AggregateNumber` | 7 metrics | ❌ Missing | Gap |
| `AggregateText` | With TopOccurrence | ❌ Missing | Gap |
| `AggregateBoolean` | 5 metrics | ❌ Missing | Gap |
| `AggregateDate` | max/min/median | ❌ Missing | Gap |
| `AggregateReference` | pointing_to list | ❌ Missing | Gap |
| `AggregateReturn[R]` | Container | ❌ Missing | Gap |
| `AggregateGroup[R]` | Group result | ❌ Missing | Gap |
| `AggregateGroupByReturn[R]` | Grouped agg | ❌ Missing | Gap |
| `GroupedBy` | path, value | ❌ Missing | Gap |

---

## Batch Response Models

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `BatchObjectReturn` | Result data | `API.Batch.Result` | ⚠️ Partial |
| `BatchReferenceReturn` | Reference result | Implicit | ❌ Gap |
| `BatchResult` | Container | Implicit | ❌ Gap |
| `ErrorObject` | message, code, uuid | Implicit | ❌ Gap |
| `ErrorReference` | message | Implicit | ❌ Gap |
| `DeleteManyObject` | Object identifier | Implicit | ❌ Gap |
| `DeleteManyReturn[T]` | Delete result | Implicit | ❌ Gap |

---

## Configuration Models

### Vector Index Configuration

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `VectorIndexType` | Enum | Atom-based | ⚠️ Implicit |
| `VectorFilterStrategy` | Enum | Keyword opts | ⚠️ Implicit |
| `_VectorIndexConfigCreate` | Base class | Builder methods | ⚠️ Different |
| `_VectorIndexConfigHNSWCreate` | HNSW specific | `hnsw_index/1` | ✅ Full |
| `_VectorIndexConfigFlatCreate` | FLAT specific | `flat_index/1` | ✅ Full |
| `_VectorIndexConfigDynamicCreate` | DYNAMIC | `dynamic_index/1` | ✅ Full |

### Quantization Configuration (ALL MISSING)

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `_PQConfigCreate` | Product Quantization | ❌ Missing | Gap |
| `_PQEncoderConfigCreate` | PQ Encoder | ❌ Missing | Gap |
| `PQEncoderType` | Enum | ❌ Missing | Gap |
| `PQEncoderDistribution` | Enum | ❌ Missing | Gap |
| `_BQConfigCreate` | Binary Quantization | ❌ Missing | Gap |
| `_SQConfigCreate` | Scalar Quantization | ❌ Missing | Gap |
| `_RQConfigCreate` | Residual Quantization | ❌ Missing | Gap |

### Inverted Index Configuration

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `_InvertedIndexConfigCreate` | Full config | ❌ Not typed | Gap |
| `_InvertedIndexConfigUpdate` | Update | ❌ Not typed | Gap |
| `_BM25ConfigCreate` | BM25 params | Via vector config | ⚠️ Implicit |
| `_StopwordsCreate` | Stopwords | ❌ Not exposed | Gap |
| `Tokenization` | Enum | Keyword opts | ⚠️ Implicit |

### Replication & Sharding

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `_ReplicationConfigCreate` | Replication | `with_replication_config/2` | ✅ Full |
| `ReplicationDeletionStrategy` | Enum | Atom options | ✅ Full |
| `_ShardingConfigCreate` | Sharding | `with_sharding_config/2` | ✅ Full |
| `_MultiTenancyConfigCreate` | Multi-tenancy | `with_multi_tenancy/2` | ✅ Full |

---

## Reference Types

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `ReferenceInput` | Type definition | ❌ Not defined | Gap |
| `ReferenceInputs` | Type alias | ❌ Not defined | Gap |
| `DataReference` | dataclass | Via batch ops | ⚠️ Implicit |
| `BEACON` | Constant | ❌ Not defined | Gap |
| `_CrossReference` | Generic | `reference_to_multi` | ⚠️ Different |
| `_QueryReference` | Query refs | ❌ Not exposed | Gap |

---

## Generic Type System

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Generic Properties | `P = TypeVar` | Implicit maps | ❌ Gap |
| Generic References | `R = TypeVar` | Implicit | ❌ Gap |
| Generic Metadata | `M = TypeVar` | Not exposed | ❌ Gap |
| `WeaviateField` | Union of 12+ types | Implicit | ❌ Gap |
| `WeaviateProperties` | Type alias | Implicit | ❌ Gap |

---

## Summary Statistics

| Category | Python Count | Elixir Count | Gap |
|----------|-------------|--------------|-----|
| Primitive Types | 7 | 5 | 2 |
| Response Models | 15+ | 2 | 13+ |
| Config Models | 60+ | 30 | 30+ |
| Aggregate Types | 10 | 0 | 10 |
| Batch Types | 8 | 1 | 7 |
| Query Types | 10+ | 2 | 8+ |
| Vector Types | 8 | 6 | 2 |
| Reference Types | 6 | 1 | 5 |
| **Total** | **130+** | **~50** | **~70** |

---

## Recommendations

### Phase 1 (Critical)
1. Response metadata types (`MetadataReturn`, etc.)
2. Query/Object response generics (`Object[P,R]`, `QueryReturn[P,R]`)
3. Batch result types (`ErrorObject`, `BatchObjectReturn`)
4. Reference types (`ReferenceInput`, `BEACON`)

### Phase 2 (High)
1. Aggregate response types (`AggregateInteger`, etc.)
2. Query filter types (`MetadataQuery`, `GroupBy`, `Sorting`)
3. Config update types (`_InvertedIndexConfigUpdate`, etc.)
4. Type aliases (`WeaviateField`, `WeaviateProperties`)

### Phase 3 (Medium)
1. Generative provider config types (10+)
2. Reranker config types (6+)
3. Generic TypeVar system

### Phase 4 (Low)
1. Deprecated or rarely-used types
2. Internal implementation types
3. Experimental features
