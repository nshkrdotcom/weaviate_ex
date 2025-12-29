# Data Operations (CRUD) Gap Analysis

## Overview
Comprehensive comparison of Weaviate Python vs Elixir client Data Operations coverage.

**Analysis Date:** 2025-12-28
**Python Files Analyzed:** `weaviate/collections/data/executor.py`, `weaviate/collections/classes/data.py`
**Elixir Files Analyzed:** `lib/weaviate_ex/api/data.ex`, `lib/weaviate_ex/objects.ex`, `lib/weaviate_ex/api/references.ex`

---

## Executive Summary

The Elixir client has achieved **~85% parity** with Python's data operations API. Critical gaps exist around **named vector operations** and **type serializers**.

---

## Single Object Operations

### Insert

| Parameter | Python | Elixir | Status |
|-----------|--------|--------|--------|
| `properties` | ✅ Required | ✅ Required | Full |
| `references` | ✅ Optional | ❌ Missing | Gap - must use separate call |
| `uuid` | ✅ Auto/provided | ✅ Via `id` option | Full |
| `vector` | ✅ Single/named | ⚠️ Single only | Partial |
| `tenant` | ✅ Via context | ✅ Via options | Full |
| `consistency_level` | ✅ Via context | ✅ Via options | Full |

**Python Location**: `executor.py:86-144`
**Elixir Location**: `api/data.ex:91-102`

### Update / Replace

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Full replacement (PUT) | `replace()` | `update()` / `replace()` | ✅ Full |
| Partial update (PATCH) | `update()` | `patch()` | ✅ Full |
| References in update | ✅ Directly | ❌ Separate call | Gap |
| Named vectors | ✅ Dict[str, vector] | ❌ Not supported | Gap |
| Keep existing vector | ✅ Option | ✅ Option | Full |

### Delete

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Delete by ID | `delete_by_id()` | `delete_by_id()` | ✅ Full |
| Return value | Boolean | Empty map | Different |
| 404 handling | Returns false | Returns error | Different |

### Exists Check

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Check existence | `exists()` | `exists?()` | ✅ Full |
| Method | HEAD request | HEAD request | Full |

---

## Batch Operations

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| `insert_many()` | `executor.py:146-206` | `API.Batch.create_objects/3` | ✅ Full |
| DataObject wrapper | Optional | Maps only | Different |
| References in batch | ✅ Via DataObject | ❌ Not supported | Gap |
| Error details | Code + message | Message only | Limited |

---

## Reference Operations

| Operation | Python | Elixir | Status |
|-----------|--------|--------|--------|
| Add single reference | `reference_add()` | `References.add()` | ✅ Full |
| Add batch references | `reference_add_many()` | `References.add_many()` | ✅ Full |
| Delete reference | `reference_delete()` | `References.delete()` | ✅ Full |
| Replace references | `reference_replace()` | `References.replace()` | ✅ Full |
| Multi-target refs | ✅ ReferenceToMulti | ✅ Map with target_collection | Full |

**Python Location**: `executor.py:355-576`
**Elixir Location**: `api/references.ex`

---

## Named Vector Operations (CRITICAL GAP)

### Python Support
```python
# Insert with named vectors
collection.data.insert(
    properties={"title": "Test"},
    vector={"title_vector": [0.1, 0.2], "content_vector": [0.3, 0.4]}
)

# Update named vectors
collection.data.update(
    uuid="...",
    vector={"title_vector": [0.5, 0.6]}
)
```

### Elixir Status
- **Collection-level**: Named vector configuration via `NamedVectors` module ✅
- **Operation-level**: ❌ **NOT SUPPORTED** - Cannot submit named vectors in insert/update

**Required Implementation**:
- Modify `api/data.ex` to accept `vectors` parameter as map
- Modify `objects/payload.ex` to serialize named vectors
- Add validation for vector name consistency

---

## Type Serialization

### Python Serializers (`executor.py:657-693`)

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| UUID | `get_valid_uuid()` | `Types.UUID` module | ✅ Full |
| DateTime | Auto-serialization | ❌ Not implemented | Gap |
| GeoCoordinate | `GeoCoordinate._to_dict()` | ❌ Not implemented | Gap |
| PhoneNumber | `PhoneNumber._to_dict()` | ❌ Not implemented | Gap |
| Nested objects | Recursive handling | ❌ Not implemented | Gap |

### Elixir UUID Support
```elixir
WeaviateEx.Types.UUID
  - generate()        # v4 UUID
  - validate()        # Validation
  - from_string/2     # v5 deterministic (Elixir extra)
```

**Note**: Elixir has UUID v5 (deterministic) which Python lacks.

---

## Data Validation

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Explicit validation endpoint | Implicit | `validate()` explicit | Elixir provides more |
| Pre-insert validation | During insert | Via separate call | Different |
| Property validation | Pydantic | Limited | Gap |

---

## Context Options

| Option | Python | Elixir | Status |
|--------|--------|--------|--------|
| Tenant | ✅ `self._tenant` | ✅ `:tenant` option | Full |
| Consistency Level | ✅ `self._consistency_level` | ✅ `:consistency_level` | Full |

---

## Summary Table

| Operation | Python | Elixir | Coverage |
|-----------|--------|--------|----------|
| insert() | ✅ | ⚠️ | 85% (refs, named vectors) |
| insert_many() | ✅ | ⚠️ | 85% (refs, errors) |
| update() | ✅ | ⚠️ | 85% (refs, named vectors) |
| replace() | ✅ | ⚠️ | 85% (refs) |
| patch() | ✅ | ⚠️ | 85% (refs) |
| delete_by_id() | ✅ | ✅ | 100% |
| exists() | ✅ | ✅ | 100% |
| reference_add() | ✅ | ✅ | 100% |
| reference_add_many() | ✅ | ⚠️ | 90% (error tracking) |
| reference_delete() | ✅ | ✅ | 100% |
| reference_replace() | ✅ | ✅ | 100% |
| Named vectors (data) | ✅ | ❌ | 0% |
| Named vectors (config) | ✅ | ✅ | 100% |
| DateTime serialization | ✅ | ❌ | 0% |
| GeoCoordinate serialization | ✅ | ❌ | 0% |
| PhoneNumber serialization | ✅ | ❌ | 0% |

**Overall Data Operations Parity: ~85%**

---

## Recommendations

### High Priority
1. **Named Vector Operations** - Add support for submitting named vectors in insert/update/replace
2. **Type Serializers** - Implement DateTime, GeoCoordinate, PhoneNumber serialization
3. **Reference Support in CRUD** - Allow setting references during insert/update/replace

### Medium Priority
4. **Reference Support in Batch** - Add references to `insert_many()`
5. **Error Structure Enhancement** - Add error codes to match Python detail level
6. **Nested Property Validation** - Full recursive validation

### Low Priority
7. **Return Type Consistency** - Consider returning boolean for delete operations
8. **404 Error Handling** - Align with Python's false return pattern
