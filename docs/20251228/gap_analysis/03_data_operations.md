# Data Operations (CRUD) Gap Analysis

## Overview

The Elixir client provides basic CRUD operations through `WeaviateEx.Objects` but is missing several methods available in the Python client's `collection.data` namespace.

## Single Object Operations

| Operation | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| `insert()` | Yes | Yes | `WeaviateEx.Objects.create/2` |
| `replace()` (PUT) | Yes | **No** | **GAP**: Full replacement |
| `update()` (PATCH) | Yes | **No** | **GAP**: Partial update |
| `delete_by_id()` | Yes | Yes | `WeaviateEx.Objects.delete/2` |
| `exists()` | Yes | **?** | HEAD request check |

---

## Missing: `replace()` (PUT) - HIGH PRIORITY

Completely replace an object's properties while preserving the UUID.

```python
# Python
collection.data.replace(
    uuid="uuid",
    properties={"title": "New title", "content": "New content"},
    vector=[0.1, 0.2, ...],
    references={"hasAuthor": "author-uuid"},
)
```

**Current Elixir Workaround**: Delete + Create (loses creation timestamp)

**Recommendation**: Implement `WeaviateEx.Objects.replace/3`
```elixir
# Proposed Elixir API
WeaviateEx.Objects.replace("Article", "uuid", %{
  properties: %{title: "New title"},
  vector: [0.1, 0.2, ...]
})
```

---

## Missing: `update()` (PATCH) - HIGH PRIORITY

Partially update an object's properties without replacing the entire object.

```python
# Python
collection.data.update(
    uuid="uuid",
    properties={"title": "Updated title"},  # Only updates title
    # vector and references are optional
)
```

**Current Elixir Workaround**: None - must use replace

**Recommendation**: Implement `WeaviateEx.Objects.update/3`
```elixir
# Proposed Elixir API
WeaviateEx.Objects.update("Article", "uuid", %{
  properties: %{title: "Updated title"}
})
```

---

## Missing: `exists()` - MEDIUM PRIORITY

Check if an object exists without fetching it (HEAD request).

```python
# Python
exists = collection.data.exists(uuid="uuid")
# Returns: bool
```

**Recommendation**: Implement `WeaviateEx.Objects.exists?/2`
```elixir
# Proposed Elixir API
{:ok, true} = WeaviateEx.Objects.exists?("Article", "uuid")
```

---

## Insert Operation Details

### Python `insert()` Parameters

| Parameter | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| `properties` | Yes | Yes | Required |
| `uuid` | Yes | Yes | Optional, auto-generated |
| `vector` | Yes | Yes | Optional |
| `references` | Yes | **?** | Verify support |

### Vector Input Types

| Type | Python | Elixir | Notes |
|------|--------|--------|-------|
| `list[float]` | Yes | Yes | |
| `numpy.ndarray` | Yes | N/A | Python-specific |
| `torch.Tensor` | Yes | N/A | Python-specific |
| `Dict[str, vector]` (named) | Yes | Yes | Named vectors |

---

## Reference Operations

| Operation | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| `reference_add()` | Yes | Yes | `WeaviateEx.API.References.add/4` |
| `reference_add_many()` | Yes | **?** | Batch reference add |
| `reference_delete()` | Yes | Yes | `WeaviateEx.API.References.delete/4` |
| `reference_replace()` | Yes | **No** | **GAP**: Replace all refs |

### Missing: `reference_replace()` - MEDIUM PRIORITY

Replace all references on a property (not add/remove individual).

```python
# Python
collection.data.reference_replace(
    from_uuid="article-uuid",
    from_property="hasAuthors",
    to=["author1-uuid", "author2-uuid"],  # Replaces ALL references
)
```

**Recommendation**: Implement `WeaviateEx.API.References.replace/4`

### Missing: `reference_add_many()` - MEDIUM PRIORITY

Add multiple references in batch.

```python
# Python
from weaviate.classes.data import DataReference

collection.data.reference_add_many([
    DataReference(
        from_uuid="article1",
        from_property="hasAuthor",
        to_uuid="author1"
    ),
    DataReference(
        from_uuid="article2",
        from_property="hasAuthor",
        to_uuid="author2"
    ),
])
# Returns: BatchReferenceReturn with errors dict
```

**Recommendation**: Implement `WeaviateEx.API.References.add_many/2`

---

## Multi-Target References

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| `ReferenceToMulti` | Yes | Yes | `WeaviateEx.Data.ReferenceToMulti` |
| Target collection | Yes | Yes | Required for multi-target |
| Multiple UUIDs | Yes | Yes | |

**Status**: Full coverage

---

## DataObject for Batch Insert

| Field | Python | Elixir | Notes |
|-------|--------|--------|-------|
| `properties` | Yes | Yes | |
| `uuid` | Yes | Yes | Optional |
| `vector` | Yes | Yes | Optional |
| `references` | Yes | **?** | Verify support |

### Python DataObject

```python
from weaviate.classes.data import DataObject

objects = [
    DataObject(
        properties={"title": "Article 1"},
        uuid=uuid.uuid4(),
        vector=[0.1, 0.2, ...],
        references={"hasAuthor": "author-uuid"}
    ),
    ...
]
collection.data.insert_many(objects)
```

### Elixir Equivalent

```elixir
# Current Elixir - via Batch API
objects = [
  %{class: "Article", properties: %{title: "Article 1"}, id: UUID.uuid4(), vector: [0.1, 0.2, ...]},
  ...
]
WeaviateEx.Batch.create_objects(objects)
```

**Status**: Functional but different API structure

---

## Delete Operations

### Single Delete

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Delete by UUID | Yes | Yes | `WeaviateEx.Objects.delete/2` |
| Return deleted | No | No | Just success/failure |
| Consistency level | Yes | **?** | |

### Batch Delete

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Delete by filter | Yes | Yes | `WeaviateEx.Batch.delete_objects/2` |
| `verbose` option | Yes | **?** | Return deleted objects |
| `dry_run` option | Yes | Yes | Via `dryRun` key |

---

## Error Handling

### Python Error Types

| Exception | Purpose | Elixir Equivalent |
|-----------|---------|-------------------|
| `WeaviateInsertInvalidPropertyError` | Reserved property name | `WeaviateEx.Error` |
| `UnexpectedStatusCodeError` | Non-OK response | `WeaviateEx.Error` |
| `WeaviateConnectionError` | Network failure | `WeaviateEx.Error` |

**Status**: Elixir has unified `WeaviateEx.Error` - sufficient coverage

---

## Consistency Levels

| Level | Python | Elixir | Notes |
|-------|--------|--------|-------|
| `ONE` | Yes | **?** | Fastest |
| `QUORUM` | Yes | **?** | Default |
| `ALL` | Yes | **?** | Most consistent |

**Recommendation**: Verify consistency level support in all data operations

---

## Return Types

### Python BatchObjectReturn

```python
@dataclass
class BatchObjectReturn:
    uuids: Dict[int, uuid.UUID]      # Success: index -> UUID
    errors: Dict[int, ErrorObject]   # Failure: index -> error
    has_errors: bool
    elapsed_seconds: float
```

### Elixir Equivalent

```elixir
# WeaviateEx.API.Batch.Result
%WeaviateEx.API.Batch.Result{
  successful: [...],
  failed: [...],
  statistics: %{...},
  errors: [...]
}
```

**Status**: Different structure but equivalent functionality

---

## Iterator / Cursor

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Cursor iteration | Yes | Yes | `WeaviateEx.Iterator` |
| Memory-efficient | Yes | Yes | |
| Include vector | Yes | **?** | |
| Custom properties | Yes | **?** | |

### Python Iterator

```python
for item in collection.iterator(
    include_vector=True,
    return_properties=["title", "content"]
):
    process(item)
```

### Elixir Iterator

```elixir
WeaviateEx.Iterator.stream(client, "Article")
|> Stream.each(&process/1)
|> Stream.run()
```

**Status**: Basic iterator exists, verify all options

---

## Summary of Data Operations Gaps

### High Priority
1. **`replace()`** - Full object replacement (PUT)
2. **`update()`** - Partial object update (PATCH)
3. **`exists()`** - Object existence check (HEAD)

### Medium Priority
1. **`reference_replace()`** - Replace all references on a property
2. **`reference_add_many()`** - Batch add references
3. Verify consistency level support

### Low Priority
1. Verify iterator options (include_vector, custom properties)
2. Verify verbose option in batch delete
