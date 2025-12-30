# Deep Gap Analysis: Collections and Schema Features

**Date:** 2025-12-29
**Comparison:** Python Weaviate Client v4.x vs WeaviateEx (Elixir)

## Executive Summary

The Elixir WeaviateEx client has achieved strong parity with the Python client for collections and schema management. Core functionality is well-implemented with some gaps in advanced features. Key areas requiring attention include:

1. **Typed configuration classes** - Python uses Pydantic models with validation; Elixir uses maps
2. **Multi-vector (ColBERT) support** - Python has Muvera encoding; Elixir lacks this
3. **Object TTL configuration** - Not implemented in Elixir
4. **Some tenant status aliases** - Python renamed HOT/COLD/FROZEN to ACTIVE/INACTIVE/OFFLOADED

---

## 1. Collection Creation/Configuration API

### Python API (Canonical)

```python
from weaviate.classes.config import Configure, Property, DataType

client.collections.create(
    name="Article",
    description="News articles",
    properties=[
        Property(name="title", data_type=DataType.TEXT),
        Property(name="content", data_type=DataType.TEXT, tokenization=Tokenization.WORD),
    ],
    vectorizer_config=Configure.Vectorizer.text2vec_openai(model="text-embedding-3-small"),
    vector_index_config=Configure.VectorIndex.hnsw(
        distance_metric=VectorDistances.COSINE,
        ef_construction=128,
        max_connections=32,
        quantizer=Configure.VectorIndex.Quantizer.pq(segments=128)
    ),
    inverted_index_config=Configure.inverted_index(
        bm25_b=0.75,
        bm25_k1=1.2,
        index_timestamps=True
    ),
    replication_config=Configure.replication(factor=3, async_enabled=True),
    multi_tenancy_config=Configure.multi_tenancy(
        enabled=True,
        auto_tenant_creation=True,
        auto_tenant_activation=True
    )
)
```

### Elixir API (WeaviateEx)

```elixir
alias WeaviateEx.API.{Collections, VectorConfig, InvertedIndexConfig}
alias WeaviateEx.Property

config = VectorConfig.new("Article")
|> VectorConfig.with_vectorizer(:text2vec_openai, model: "text-embedding-3-small")
|> VectorConfig.with_hnsw_index(
  distance: :cosine,
  ef_construction: 128,
  max_connections: 32,
  quantizer: VectorConfig.product_quantization(segments: 128)
)
|> VectorConfig.with_properties([
  Property.text("title"),
  Property.text("content", tokenization: :word)
])
|> VectorConfig.with_replication_config(factor: 3, async_enabled: true)
|> VectorConfig.with_multi_tenancy(enabled: true)

Collections.create(client, config)
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic collection creation | `collections.create()` | `Collections.create/2` | Implemented |
| Collection description | `description=` | Via config map | Implemented |
| Collection listing | `collections.list_all()` | `Collections.list/1` | Implemented |
| Collection get | `collections.get()` | `Collections.get/2` | Implemented |
| Collection delete | `collection.delete()` | `Collections.delete/2` | Implemented |
| Collection exists check | `collections.exists()` | `Collections.exists?/2` | Implemented |
| Delete all collections | `collections.delete_all()` | `Collections.delete_all/1` | Implemented |
| Builder pattern | `Configure.*` classes | `VectorConfig.*` functions | Implemented |
| Typed config validation | Pydantic models | None (maps) | Partial |
| Config object serialization | `._to_dict()` | Direct map construction | Implemented |

---

## 2. Schema Management (Properties, Nested Properties, References)

### Python Property Definition

```python
# File: weaviate/collections/classes/config.py

class Property(_ConfigCreateModel):
    name: str
    dataType: DataType
    description: Optional[str]
    indexFilterable: Optional[bool]
    indexSearchable: Optional[bool]
    indexRangeFilters: Optional[bool]
    nestedProperties: Optional[Union["Property", List["Property"]]]
    skip_vectorization: bool = False
    tokenization: Optional[Tokenization]
    vectorize_property_name: bool = True

class ReferenceProperty(_ReferencePropertyBase):
    target_collection: str
    description: Optional[str]
    MultiTarget: ClassVar[Type[_ReferencePropertyMultiTarget]]

class _NestedProperty(_ConfigBase):
    data_type: DataType
    description: Optional[str]
    index_filterable: bool
    index_searchable: bool
    name: str
    nested_properties: Optional[List["NestedProperty"]]
    tokenization: Optional[Tokenization]
```

### Elixir Property Definition

```elixir
# File: lib/weaviate_ex/property.ex

defmodule WeaviateEx.Property do
  @spec new(String.t(), atom() | String.t(), opts()) :: t()
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

  # Convenience functions
  def text(name, opts \\ []), do: new(name, :text, opts)
  def object(name, nested_properties, opts \\ [])
  def reference(name, target_collection, opts \\ [])
end
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Text properties | `DataType.TEXT` | `Property.text/2` | Implemented |
| Int properties | `DataType.INT` | `Property.int/2` | Implemented |
| Number properties | `DataType.NUMBER` | `Property.number/2` | Implemented |
| Boolean properties | `DataType.BOOL` | `Property.boolean/2` | Implemented |
| Date properties | `DataType.DATE` | `Property.date/2` | Implemented |
| UUID properties | `DataType.UUID` | `Property.uuid/2` | Implemented |
| Blob properties | `DataType.BLOB` | `Property.blob/2` | Implemented |
| GeoCoordinates | `DataType.GEO_COORDINATES` | `Property.geo_coordinates/2` | Implemented |
| Phone number | `DataType.PHONE_NUMBER` | `Property.phone_number/2` | Implemented |
| Object (nested) | `DataType.OBJECT` | `Property.object/3` | Implemented |
| Object array | `DataType.OBJECT_ARRAY` | `Property.object_array/3` | Implemented |
| Array types | `DataType.TEXT_ARRAY`, etc. | `Property.text_array/2`, etc. | Implemented |
| Cross-references | `ReferenceProperty` | `Property.reference/3` | Implemented |
| Multi-target refs | `ReferenceProperty.MultiTarget` | Not implemented | Missing |
| Nested properties | `nestedProperties=` | `nested_properties:` opt | Implemented |
| Index filterable | `index_filterable=` | `index_filterable:` opt | Implemented |
| Index searchable | `index_searchable=` | `index_searchable:` opt | Implemented |
| Index range filters | `index_range_filters=` | Not implemented | Missing |
| Skip vectorization | `skip_vectorization=` | `skip_vectorization:` opt | Implemented |
| Vectorize prop name | `vectorize_property_name=` | `vectorize_property_name:` opt | Implemented |
| Tokenization | `Tokenization` enum | `:word`, `:whitespace`, etc. | Implemented |
| Add property | `collection.config.add_property()` | `Collections.add_property/3` | Implemented |

---

## 3. Property Types and Data Type Support

### Python DataType Enum

```python
# File: weaviate/collections/classes/config.py

class DataType(str, Enum):
    TEXT = "text"
    TEXT_ARRAY = "text[]"
    INT = "int"
    INT_ARRAY = "int[]"
    NUMBER = "number"
    NUMBER_ARRAY = "number[]"
    BOOL = "boolean"
    BOOL_ARRAY = "boolean[]"
    DATE = "date"
    DATE_ARRAY = "date[]"
    UUID = "uuid"
    UUID_ARRAY = "uuid[]"
    GEO_COORDINATES = "geoCoordinates"
    BLOB = "blob"
    PHONE_NUMBER = "phoneNumber"
    OBJECT = "object"
    OBJECT_ARRAY = "object[]"
```

### Elixir DataType Module

```elixir
# File: lib/weaviate_ex/types/data_type.ex

defmodule WeaviateEx.Types.DataType do
  @data_types %{
    text: "text",
    text_array: "text[]",
    int: "int",
    int_array: "int[]",
    boolean: "boolean",
    boolean_array: "boolean[]",
    number: "number",
    number_array: "number[]",
    date: "date",
    date_array: "date[]",
    uuid: "uuid",
    uuid_array: "uuid[]",
    geo_coordinates: "geoCoordinates",
    blob: "blob",
    phone_number: "phoneNumber",
    object: "object",
    object_array: "object[]"
  }
end
```

### Feature Comparison

| Data Type | Python | Elixir | Status |
|-----------|--------|--------|--------|
| text | `DataType.TEXT` | `:text` | Implemented |
| text[] | `DataType.TEXT_ARRAY` | `:text_array` | Implemented |
| int | `DataType.INT` | `:int` | Implemented |
| int[] | `DataType.INT_ARRAY` | `:int_array` | Implemented |
| number | `DataType.NUMBER` | `:number` | Implemented |
| number[] | `DataType.NUMBER_ARRAY` | `:number_array` | Implemented |
| boolean | `DataType.BOOL` | `:boolean` | Implemented |
| boolean[] | `DataType.BOOL_ARRAY` | `:boolean_array` | Implemented |
| date | `DataType.DATE` | `:date` | Implemented |
| date[] | `DataType.DATE_ARRAY` | `:date_array` | Implemented |
| uuid | `DataType.UUID` | `:uuid` | Implemented |
| uuid[] | `DataType.UUID_ARRAY` | `:uuid_array` | Implemented |
| geoCoordinates | `DataType.GEO_COORDINATES` | `:geo_coordinates` | Implemented |
| blob | `DataType.BLOB` | `:blob` | Implemented |
| phoneNumber | `DataType.PHONE_NUMBER` | `:phone_number` | Implemented |
| object | `DataType.OBJECT` | `:object` | Implemented |
| object[] | `DataType.OBJECT_ARRAY` | `:object_array` | Implemented |

**Status: Full Parity**

---

## 4. Vector Index Configurations (HNSW, Flat, Dynamic)

### Python Vector Index API

```python
# File: weaviate/collections/classes/config_vector_index.py

class VectorIndexType(str, Enum):
    HNSW = "hnsw"
    FLAT = "flat"
    DYNAMIC = "dynamic"

class VectorFilterStrategy(str, Enum):
    SWEEPING = "sweeping"
    ACORN = "acorn"

class _VectorIndex:
    @staticmethod
    def hnsw(
        cleanup_interval_seconds: Optional[int] = None,
        distance_metric: Optional[VectorDistances] = None,
        dynamic_ef_factor: Optional[int] = None,
        dynamic_ef_max: Optional[int] = None,
        dynamic_ef_min: Optional[int] = None,
        ef: Optional[int] = None,
        ef_construction: Optional[int] = None,
        filter_strategy: Optional[VectorFilterStrategy] = None,
        flat_search_cutoff: Optional[int] = None,
        max_connections: Optional[int] = None,
        vector_cache_max_objects: Optional[int] = None,
        quantizer: Optional[_QuantizerConfigCreate] = None,
        multi_vector: Optional[_MultiVectorConfigCreate] = None,
    ) -> _VectorIndexConfigHNSWCreate

    @staticmethod
    def flat(
        distance_metric: Optional[VectorDistances] = None,
        vector_cache_max_objects: Optional[int] = None,
        quantizer: Optional[_QuantizerConfigCreate] = None,
    ) -> _VectorIndexConfigFlatCreate

    @staticmethod
    def dynamic(
        distance_metric: Optional[VectorDistances] = None,
        threshold: Optional[int] = None,
        hnsw: Optional[_VectorIndexConfigHNSWCreate] = None,
        flat: Optional[_VectorIndexConfigFlatCreate] = None,
    ) -> _VectorIndexConfigDynamicCreate

    @staticmethod
    def none() -> _VectorIndexConfigSkipCreate
```

### Elixir Vector Index API

```elixir
# File: lib/weaviate_ex/api/vector_config.ex

defmodule WeaviateEx.API.VectorConfig do
  @spec hnsw_index(keyword()) :: map()
  def hnsw_index(opts \\ []) do
    %{
      "vectorIndexType" => "hnsw",
      "vectorIndexConfig" => %{
        "distance" => distance,
        "ef" => Keyword.get(opts, :ef, -1),
        "efConstruction" => Keyword.get(opts, :ef_construction, 128),
        "maxConnections" => Keyword.get(opts, :max_connections, 32)
      }
      |> maybe_add_dynamic_ef(opts)
      |> maybe_add_vector_cache(opts)
      |> maybe_add_flat_search_cutoff(opts)
      |> maybe_add_cleanup_interval(opts)
      |> maybe_add_filter_strategy(opts)
      |> maybe_add_quantizer_option(opts)
    }
  end

  def flat_index(opts \\ [])
  def dynamic_index(opts \\ [])
end
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| HNSW index | `VectorIndex.hnsw()` | `VectorConfig.hnsw_index/1` | Implemented |
| FLAT index | `VectorIndex.flat()` | `VectorConfig.flat_index/1` | Implemented |
| DYNAMIC index | `VectorIndex.dynamic()` | `VectorConfig.dynamic_index/1` | Implemented |
| Skip indexing | `VectorIndex.none()` | Not directly | Partial |
| Distance metrics | `VectorDistances` enum | `:cosine`, `:dot`, etc. | Implemented |
| ef parameter | `ef=` | `ef:` | Implemented |
| ef_construction | `ef_construction=` | `ef_construction:` | Implemented |
| max_connections | `max_connections=` | `max_connections:` | Implemented |
| dynamic_ef_min | `dynamic_ef_min=` | `dynamic_ef_min:` | Implemented |
| dynamic_ef_max | `dynamic_ef_max=` | `dynamic_ef_max:` | Implemented |
| dynamic_ef_factor | `dynamic_ef_factor=` | `dynamic_ef_factor:` | Implemented |
| flat_search_cutoff | `flat_search_cutoff=` | `flat_search_cutoff:` | Implemented |
| cleanup_interval_seconds | `cleanup_interval_seconds=` | `cleanup_interval_seconds:` | Implemented |
| vector_cache_max_objects | `vector_cache_max_objects=` | `vector_cache_max_objects:` | Implemented |
| filter_strategy | `VectorFilterStrategy` | `:sweeping`, `:acorn` | Implemented |
| Multi-vector config | `multi_vector=` | Not implemented | Missing |
| Dynamic threshold | `threshold=` | `threshold:` | Implemented |
| Nested HNSW in Dynamic | `hnsw=` | `hnsw:` | Implemented |
| Nested Flat in Dynamic | `flat=` | `flat:` | Implemented |

---

## 5. Quantization Support (PQ, BQ, SQ, RQ)

### Python Quantizer API

```python
# File: weaviate/collections/classes/config_vector_index.py

class _VectorIndexQuantizer:
    @staticmethod
    def pq(
        bit_compression: Optional[bool] = None,  # deprecated
        centroids: Optional[int] = None,
        encoder_distribution: Optional[PQEncoderDistribution] = None,
        encoder_type: Optional[PQEncoderType] = None,
        segments: Optional[int] = None,
        training_limit: Optional[int] = None,
    ) -> _PQConfigCreate

    @staticmethod
    def bq(
        cache: Optional[bool] = None,
        rescore_limit: Optional[int] = None,
    ) -> _BQConfigCreate

    @staticmethod
    def sq(
        cache: Optional[bool] = None,
        rescore_limit: Optional[int] = None,
        training_limit: Optional[int] = None,
    ) -> _SQConfigCreate

    @staticmethod
    def rq(
        cache: Optional[bool] = None,
        bits: Optional[int] = None,
        rescore_limit: Optional[int] = None,
    ) -> _RQConfigCreate

    @staticmethod
    def none() -> _UncompressedConfigCreate
```

### Elixir Quantizer API

```elixir
# File: lib/weaviate_ex/api/quantizer.ex

defmodule WeaviateEx.API.Quantizer do
  # PQ - Product Quantization
  def pq(opts \\ []), do: PQConfig.new(opts)

  # BQ - Binary Quantization
  def bq(opts \\ []), do: BQConfig.new(opts)

  # SQ - Scalar Quantization
  def sq(opts \\ []), do: SQConfig.new(opts)

  # RQ - Rotational Quantization
  def rq(opts \\ []), do: RQConfig.new(opts)
end

# Individual config structs with to_api/from_api functions
defmodule WeaviateEx.API.Quantizer.PQConfig do
  defstruct enabled: true,
            training_limit: nil,
            segments: nil,
            centroids: nil,
            encoder: nil
end

defmodule WeaviateEx.API.Quantizer.BQConfig do
  defstruct enabled: true,
            cache: nil,
            rescore_limit: nil
end

defmodule WeaviateEx.API.Quantizer.SQConfig do
  defstruct enabled: true,
            cache: nil,
            rescore_limit: nil,
            training_limit: nil
end

defmodule WeaviateEx.API.Quantizer.RQConfig do
  defstruct enabled: true,
            bits: nil,
            cache: nil,
            rescore_limit: nil,
            training_limit: nil
end
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Product Quantization (PQ) | `Quantizer.pq()` | `Quantizer.pq/1` | Implemented |
| Binary Quantization (BQ) | `Quantizer.bq()` | `Quantizer.bq/1` | Implemented |
| Scalar Quantization (SQ) | `Quantizer.sq()` | `Quantizer.sq/1` | Implemented |
| Rotational Quantization (RQ) | `Quantizer.rq()` | `Quantizer.rq/1` | Implemented |
| Skip quantization | `Quantizer.none()` | Not implemented | Missing |
| PQ segments | `segments=` | `segments:` | Implemented |
| PQ centroids | `centroids=` | `centroids:` | Implemented |
| PQ training_limit | `training_limit=` | `training_limit:` | Implemented |
| PQ encoder type | `encoder_type=` | `encoder: %{type: ...}` | Implemented |
| PQ encoder distribution | `encoder_distribution=` | `encoder: %{distribution: ...}` | Implemented |
| BQ cache | `cache=` | `cache:` | Implemented |
| BQ rescore_limit | `rescore_limit=` | `rescore_limit:` | Implemented |
| SQ cache | `cache=` | `cache:` | Implemented |
| SQ rescore_limit | `rescore_limit=` | `rescore_limit:` | Implemented |
| SQ training_limit | `training_limit=` | `training_limit:` | Implemented |
| RQ bits | `bits=` | `bits:` | Implemented |
| RQ cache | `cache=` | `cache:` | Implemented |
| Quantizer type detection | Automatic | `Quantizer.detect_type/1` | Implemented |
| to_api conversion | `._to_dict()` | `to_api/1` | Implemented |
| from_api parsing | Schema parsing | `from_api/1` | Implemented |

**Status: Near Full Parity** (only missing `Quantizer.none()`)

---

## 6. Inverted Index Configuration

### Python Inverted Index API

```python
# File: weaviate/collections/classes/config.py

Configure.inverted_index(
    bm25_b: Optional[float] = None,
    bm25_k1: Optional[float] = None,
    cleanup_interval_seconds: Optional[int] = None,
    index_timestamps: Optional[bool] = None,
    index_property_length: Optional[bool] = None,
    index_null_state: Optional[bool] = None,
    stopwords_preset: Optional[StopwordsPreset] = None,
    stopwords_additions: Optional[List[str]] = None,
    stopwords_removals: Optional[List[str]] = None,
)

class StopwordsPreset(str, Enum):
    EN = "en"
    NONE = "none"
```

### Elixir Inverted Index API

```elixir
# File: lib/weaviate_ex/api/inverted_index_config.ex

defmodule WeaviateEx.API.InvertedIndexConfig do
  def bm25(opts \\ [])  # Returns %{b: float, k1: float}
  def stopwords(opts \\ [])  # preset, additions, removals
  def index_timestamps(enabled)
  def index_property_length(enabled)
  def index_null_state(enabled)
  def cleanup_interval_seconds(seconds)

  def build(opts \\ [])  # Complete config builder
  def validate(config)  # Validates b in 0-1, k1 positive, etc.
end
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| BM25 b parameter | `bm25_b=` | `b:` in `bm25/1` | Implemented |
| BM25 k1 parameter | `bm25_k1=` | `k1:` in `bm25/1` | Implemented |
| Cleanup interval | `cleanup_interval_seconds=` | `cleanup_interval_seconds:` | Implemented |
| Index timestamps | `index_timestamps=` | `index_timestamps:` | Implemented |
| Index property length | `index_property_length=` | `index_property_length:` | Implemented |
| Index null state | `index_null_state=` | `index_null_state:` | Implemented |
| Stopwords preset | `stopwords_preset=` | `preset:` in `stopwords/1` | Implemented |
| Stopwords additions | `stopwords_additions=` | `additions:` | Implemented |
| Stopwords removals | `stopwords_removals=` | `removals:` | Implemented |
| Config validation | Pydantic validation | `validate/1` function | Implemented |

**Status: Full Parity**

---

## 7. Replication Factor Configuration

### Python Replication API

```python
# File: weaviate/collections/classes/config.py

Configure.replication(
    factor: Optional[int] = None,
    async_enabled: Optional[bool] = None,  # v1.26.0+
    deletion_strategy: Optional[ReplicationDeletionStrategy] = None,
)

class ReplicationDeletionStrategy(str, Enum):
    DELETE_ON_CONFLICT = "DeleteOnConflict"
    NO_AUTOMATED_RESOLUTION = "NoAutomatedResolution"
    TIME_BASED_RESOLUTION = "TimeBasedResolution"
```

### Elixir Replication API

```elixir
# File: lib/weaviate_ex/api/vector_config.ex

VectorConfig.with_replication_config(config,
  factor: 3,
  async_enabled: true,
  deletion_strategy: :delete_on_conflict  # or :no_automated_resolution, :time_based_resolution
)
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Replication factor | `factor=` | `factor:` | Implemented |
| Async replication | `async_enabled=` | `async_enabled:` | Implemented |
| Deletion strategy | `deletion_strategy=` | `deletion_strategy:` | Implemented |
| DELETE_ON_CONFLICT | `ReplicationDeletionStrategy.DELETE_ON_CONFLICT` | `:delete_on_conflict` | Implemented |
| NO_AUTOMATED_RESOLUTION | `ReplicationDeletionStrategy.NO_AUTOMATED_RESOLUTION` | `:no_automated_resolution` | Implemented |
| TIME_BASED_RESOLUTION | `ReplicationDeletionStrategy.TIME_BASED_RESOLUTION` | `:time_based_resolution` | Implemented |

**Status: Full Parity**

---

## 8. Collection Update/Migration Capabilities

### Python Update API

```python
# Collection update
collection.config.update(
    vectorizer_config=Reconfigure.VectorIndex.hnsw(
        ef=200,
        quantizer=Reconfigure.VectorIndex.Quantizer.pq(enabled=True)
    )
)

# Named vector update
collection.config.update(
    vector_config=[
        Reconfigure.NamedVectors.update(
            name="title_vector",
            vector_index_config=Reconfigure.VectorIndex.hnsw(ef=150)
        )
    ]
)
```

### Elixir Update API

```elixir
# Collection update
Collections.update(client, "Article", %{
  "vectorIndexConfig" => %{
    "ef" => 200,
    "pq" => %{"enabled" => true}
  }
})

# Named vector update
update = NamedVectors.update_config("title_vector",
  vector_index: [ef: 200, dynamic_ef_max: 500]
)
Collections.update(client, "Article", NamedVectors.update_to_api(update))
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Update collection config | `collection.config.update()` | `Collections.update/4` | Implemented |
| Update vector index | `Reconfigure.VectorIndex.*` | Direct map | Implemented |
| Update quantizer | `Reconfigure.VectorIndex.Quantizer.*` | Via vector index config | Implemented |
| Update named vectors | `Reconfigure.NamedVectors.update()` | `NamedVectors.update_config/2` | Implemented |
| Batch named vector updates | List of updates | `NamedVectors.build_update_config/1` | Implemented |
| Update inverted index | Via config.update | Via update payload | Implemented |
| Update replication | Via config.update | Via update payload | Implemented |
| Reconfigure class | `Reconfigure` factory | Not structured | Partial |

---

## 9. Named Vectors Support

### Python Named Vectors API

```python
# File: weaviate/collections/classes/config_named_vectors.py

from weaviate.classes.config import Configure

Configure.NamedVectors.text2vec_openai(
    name="title_vector",
    source_properties=["title"],
    model="text-embedding-3-small",
    dimensions=512
)

Configure.NamedVectors.none(name="custom_vector")

# Multi-vector (ColBERT) support
Configure.NamedVectors.text2colbert_jinaai(
    name="colbert_vector",
    source_properties=["content"]
)

# Collection with multiple named vectors
client.collections.create(
    name="Article",
    vector_config=[
        Configure.NamedVectors.text2vec_openai(name="title"),
        Configure.NamedVectors.text2vec_cohere(name="content"),
        Configure.NamedVectors.none(name="custom")
    ]
)
```

### Elixir Named Vectors API

```elixir
# File: lib/weaviate_ex/api/named_vectors.ex

alias WeaviateEx.API.NamedVectors

configs = [
  NamedVectors.text2vec_openai(
    name: "title_vector",
    source_properties: ["title"],
    model: "text-embedding-3-small"
  ),
  NamedVectors.text2vec_cohere(
    name: "content_vector",
    source_properties: ["content"]
  ),
  NamedVectors.self_provided(name: "custom_vector")
]

vectorizer_config = NamedVectors.build_vectorizer_config(configs)
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Named vector config | `Configure.NamedVectors.*` | `NamedVectors.*` | Implemented |
| text2vec-openai | `text2vec_openai()` | `text2vec_openai/1` | Implemented |
| text2vec-cohere | `text2vec_cohere()` | `text2vec_cohere/1` | Implemented |
| text2vec-huggingface | `text2vec_huggingface()` | `text2vec_huggingface/1` | Implemented |
| text2vec-voyageai | `text2vec_voyageai()` | `text2vec_voyageai/1` | Implemented |
| text2vec-jinaai | `text2vec_jinaai()` | `text2vec_jinaai/1` | Implemented |
| text2vec-ollama | `text2vec_ollama()` | `text2vec_ollama/1` | Implemented |
| text2vec-mistral | `text2vec_mistral()` | `text2vec_mistral/1` | Implemented |
| text2vec-nvidia | `text2vec_nvidia()` | `text2vec_nvidia/1` | Implemented |
| text2vec-azure-openai | `text2vec_azure_openai()` | `text2vec_azure_openai/1` | Implemented |
| text2vec-google | `text2vec_google_vertex()` | `text2vec_google_vertex/1` | Implemented |
| multi2vec-clip | `multi2vec_clip()` | `multi2vec_clip/1` | Implemented |
| multi2vec-bind | `multi2vec_bind()` | `multi2vec_bind/1` | Implemented |
| Self-provided (none) | `none()` | `self_provided/1` | Implemented |
| source_properties | `source_properties=` | `source_properties:` | Implemented |
| vector_index_type | Implicit | `vector_index_type:` | Implemented |
| Build vectorConfig | Automatic | `build_vectorizer_config/1` | Implemented |
| Update named vector | `Reconfigure.NamedVectors.update()` | `update_config/2` | Implemented |
| text2colbert-jinaai | `text2colbert_jinaai()` | Not implemented | Missing |
| Multi-vector (Muvera) | `multi_vector_config=` | Not implemented | Missing |

---

## 10. Multi-Tenancy Configuration

### Python Multi-Tenancy API

```python
# File: weaviate/collections/classes/config.py

Configure.multi_tenancy(
    enabled: bool = True,
    auto_tenant_creation: Optional[bool] = None,
    auto_tenant_activation: Optional[bool] = None,
)

# File: weaviate/collections/classes/tenants.py

class TenantActivityStatus(str, Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    OFFLOADED = "OFFLOADED"
    OFFLOADING = "OFFLOADING"
    ONLOADING = "ONLOADING"
    # Deprecated aliases
    HOT = "HOT"      # -> ACTIVE
    COLD = "COLD"    # -> INACTIVE
    FROZEN = "FROZEN"  # -> OFFLOADED

class Tenant(BaseModel):
    name: str
    activity_status: TenantActivityStatus
```

### Elixir Multi-Tenancy API

```elixir
# File: lib/weaviate_ex/api/vector_config.ex
VectorConfig.with_multi_tenancy(config, enabled: true)

# File: lib/weaviate_ex/api/tenants.ex
defmodule WeaviateEx.API.Tenants do
  @type activity_status :: :hot | :cold | :frozen

  def list(client, collection_name)
  def get(client, collection_name, tenant_name)
  def create(client, collection_name, tenant_names, opts \\ [])
  def update(client, collection_name, tenant_names, opts)
  def delete(client, collection_name, tenant_names)

  # Convenience functions
  def activate(client, collection_name, tenant_names)  # -> HOT
  def deactivate(client, collection_name, tenant_names)  # -> COLD
  def freeze(client, collection_name, tenant_names)  # -> FROZEN
  def offload(client, collection_name, tenant_names)  # -> OFFLOADED

  def exists?(client, collection_name, tenant_name)
  def count(client, collection_name)
  def list_active(client, collection_name)
  def list_inactive(client, collection_name)
end
```

### Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Enable multi-tenancy | `multi_tenancy_config=` | `with_multi_tenancy/2` | Implemented |
| auto_tenant_creation | `auto_tenant_creation=` | Not implemented | Missing |
| auto_tenant_activation | `auto_tenant_activation=` | Not implemented | Missing |
| List tenants | `collection.tenants.get()` | `Tenants.list/2` | Implemented |
| Get tenant | Via get() | `Tenants.get/3` | Implemented |
| Create tenant | `collection.tenants.create()` | `Tenants.create/4` | Implemented |
| Update tenant | `collection.tenants.update()` | `Tenants.update/4` | Implemented |
| Delete tenant | `collection.tenants.remove()` | `Tenants.delete/3` | Implemented |
| ACTIVE status | `TenantActivityStatus.ACTIVE` | `:hot` (legacy) | Partial |
| INACTIVE status | `TenantActivityStatus.INACTIVE` | `:cold` (legacy) | Partial |
| OFFLOADED status | `TenantActivityStatus.OFFLOADED` | `:frozen` (legacy) | Partial |
| OFFLOADING status | `TenantActivityStatus.OFFLOADING` | `:offloading` | Implemented |
| ONLOADING status | `TenantActivityStatus.ONLOADING` | `:onloading` | Implemented |
| Tenant exists | Via get() | `Tenants.exists?/3` | Implemented |
| Tenant count | Via len() | `Tenants.count/2` | Implemented |
| List active tenants | Filter | `Tenants.list_active/2` | Implemented |
| List inactive tenants | Filter | `Tenants.list_inactive/2` | Implemented |
| gRPC support | Yes | Yes | Implemented |

---

## Summary: Gaps and Priorities

### Critical Gaps (High Priority)

| Gap | Python Feature | Impact | Recommendation |
|-----|----------------|--------|----------------|
| Multi-target references | `ReferenceProperty.MultiTarget` | Blocks polymorphic references | Add `reference_multi_target/3` function |
| Auto tenant creation | `auto_tenant_creation=True` | Blocks auto-provisioning | Add to `with_multi_tenancy/2` |
| Auto tenant activation | `auto_tenant_activation=True` | Blocks lazy activation | Add to `with_multi_tenancy/2` |
| Tenant status aliases | ACTIVE/INACTIVE/OFFLOADED | Python deprecated old names | Add aliases with deprecation warnings |

### Medium Priority Gaps

| Gap | Python Feature | Impact | Recommendation |
|-----|----------------|--------|----------------|
| Multi-vector (Muvera) | `multi_vector_config=` | Blocks ColBERT support | Add multi-vector encoding support |
| text2colbert-jinaai | `text2colbert_jinaai()` | Blocks ColBERT vectorizer | Add to NamedVectors module |
| Object TTL | `object_ttl_config=` | Blocks auto-expiration | Add ObjectTTLConfig module |
| Index range filters | `index_range_filters=` | Blocks range filter indexing | Add to Property options |
| Quantizer.none() | `Quantizer.none()` | Minor - skip quantization | Add `uncompressed/0` function |
| Reconfigure class | `Reconfigure` factory | Ergonomics for updates | Add Reconfigure module |

### Low Priority Gaps

| Gap | Python Feature | Impact | Recommendation |
|-----|----------------|--------|----------------|
| Typed config validation | Pydantic models | Type safety at compile time | Consider Ecto.Changeset |
| VectorIndex.none() | Skip vector indexing | Rare use case | Add to VectorConfig |
| Property name validation | Reserved name check | Compile-time safety | Add validation |

### Fully Implemented Features

- All 17 data types
- All 4 quantization methods (PQ, BQ, SQ, RQ)
- All 3 vector index types (HNSW, Flat, Dynamic)
- HNSW parameters (ef, ef_construction, max_connections, dynamic_ef_*, filter_strategy)
- Inverted index config (BM25, stopwords, timestamps, property length, null state)
- Replication config (factor, async, deletion_strategy)
- Named vectors with 15+ vectorizers
- Property builder with nested objects
- Cross-references (single target)
- Multi-tenancy CRUD with gRPC
- Collection CRUD operations

---

## Code Examples: API Differences

### Creating a Complete Collection

**Python:**
```python
from weaviate.classes.config import Configure, Property, DataType, Tokenization

client.collections.create(
    name="Article",
    description="News articles with multi-tenancy",
    properties=[
        Property(
            name="title",
            data_type=DataType.TEXT,
            index_searchable=True,
            tokenization=Tokenization.WORD
        ),
        Property(
            name="content",
            data_type=DataType.TEXT,
            skip_vectorization=True
        ),
        Property(
            name="metadata",
            data_type=DataType.OBJECT,
            nested_properties=[
                Property(name="author", data_type=DataType.TEXT),
                Property(name="published", data_type=DataType.DATE)
            ]
        )
    ],
    references=[
        ReferenceProperty(name="hasAuthor", target_collection="Author")
    ],
    vectorizer_config=Configure.Vectorizer.text2vec_openai(
        model="text-embedding-3-small",
        dimensions=512
    ),
    vector_index_config=Configure.VectorIndex.hnsw(
        ef_construction=200,
        max_connections=48,
        quantizer=Configure.VectorIndex.Quantizer.pq(segments=128)
    ),
    inverted_index_config=Configure.inverted_index(
        bm25_b=0.8,
        bm25_k1=1.5,
        index_timestamps=True
    ),
    replication_config=Configure.replication(factor=3),
    multi_tenancy_config=Configure.multi_tenancy(
        enabled=True,
        auto_tenant_creation=True
    )
)
```

**Elixir:**
```elixir
alias WeaviateEx.API.{Collections, VectorConfig, InvertedIndexConfig}
alias WeaviateEx.Property

config = VectorConfig.new("Article")
|> Map.put("description", "News articles with multi-tenancy")
|> VectorConfig.with_vectorizer(:text2vec_openai,
  model: "text-embedding-3-small",
  dimensions: 512
)
|> VectorConfig.with_hnsw_index(
  ef_construction: 200,
  max_connections: 48,
  quantizer: VectorConfig.product_quantization(segments: 128, enabled: true)
)
|> VectorConfig.with_replication_config(factor: 3)
|> VectorConfig.with_multi_tenancy(enabled: true)
|> VectorConfig.with_properties([
  Property.text("title", index_searchable: true, tokenization: :word),
  Property.text("content", skip_vectorization: true),
  Property.object("metadata", [
    Property.text("author"),
    Property.date("published")
  ]),
  Property.reference("hasAuthor", "Author")
])
|> Map.merge(%{
  "invertedIndexConfig" => InvertedIndexConfig.build(
    bm25: [b: 0.8, k1: 1.5],
    index_timestamps: true
  )
})

Collections.create(client, config)
```

### Working with Named Vectors

**Python:**
```python
client.collections.create(
    name="MultiVectorArticle",
    vector_config=[
        Configure.NamedVectors.text2vec_openai(
            name="title_vector",
            source_properties=["title"],
            model="text-embedding-3-small"
        ),
        Configure.NamedVectors.text2vec_cohere(
            name="content_vector",
            source_properties=["content"],
            model="embed-english-v3.0"
        ),
        Configure.NamedVectors.none(
            name="custom_vector",
            vector_index_config=Configure.VectorIndex.hnsw(ef=100)
        )
    ]
)
```

**Elixir:**
```elixir
alias WeaviateEx.API.NamedVectors

named_vectors = [
  NamedVectors.text2vec_openai(
    name: "title_vector",
    source_properties: ["title"],
    model: "text-embedding-3-small"
  ),
  NamedVectors.text2vec_cohere(
    name: "content_vector",
    source_properties: ["content"],
    model: "embed-english-v3.0"
  ),
  NamedVectors.self_provided(
    name: "custom_vector",
    hnsw_opts: %{"ef" => 100}
  )
]

config = %{
  "class" => "MultiVectorArticle",
  "vectorConfig" => NamedVectors.build_vectorizer_config(named_vectors),
  "properties" => [
    Property.text("title"),
    Property.text("content")
  ]
}

Collections.create(client, config)
```

---

## Conclusion

The WeaviateEx Elixir client has achieved **approximately 90% feature parity** with the Python client for collections and schema management. The core functionality is well-implemented with idiomatic Elixir patterns.

**Key strengths:**
- Comprehensive property type support
- Full quantization support (PQ, BQ, SQ, RQ)
- Well-designed named vectors API
- Complete inverted index configuration
- gRPC-enabled tenant management

**Priority improvements:**
1. Add `auto_tenant_creation` and `auto_tenant_activation` to multi-tenancy config
2. Add `ReferenceProperty.MultiTarget` equivalent
3. Update tenant status names to match Python (ACTIVE/INACTIVE/OFFLOADED)
4. Add Object TTL configuration support
5. Add multi-vector (Muvera/ColBERT) encoding support
