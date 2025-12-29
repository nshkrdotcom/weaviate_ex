# Collections/Schema Management Gap Analysis

## Executive Summary

This document provides a comprehensive analysis of the gaps between the Python Weaviate client's collections module and the Elixir WeaviateEx client's collections implementation. The analysis covers collection creation, configuration, property types, vectorizers, indexing, multi-tenancy, and helper utilities.

**Overall Gap Status:** The Elixir client covers approximately 40% of the Python client's collections functionality. Critical gaps exist in:

1. **Type-Safe Configuration Classes** - Python uses strongly-typed Pydantic models; Elixir uses raw maps
2. **Named Vectors (Multi-Vector)** - Partially implemented in Elixir
3. **Collection Iterator/Cursor** - Completely missing
4. **Rich Configuration Parsing** - Missing structured config response objects
5. **Advanced Tenant Management** - Missing activate/deactivate/offload operations
6. **Config Update Operations** - Missing merge-with-existing pattern
7. **Reranker Configuration** - Missing structured configuration builders

---

## Detailed Comparison Table

| Feature | Python Client | Elixir Client | Status | Priority |
|---------|--------------|---------------|--------|----------|
| **Collection CRUD** |
| Create collection | `client.collections.create()` | `WeaviateEx.Collections.create/3` | Partial | High |
| Delete collection | `client.collections.delete()` | `WeaviateEx.Collections.delete/2` | Complete | - |
| Delete multiple collections | `client.collections.delete([names])` | Missing | Missing | Medium |
| Delete all collections | `client.collections.delete_all()` | `WeaviateEx.API.Collections.delete_all/1` | Complete | - |
| Check collection exists | `client.collections.exists()` | `WeaviateEx.Collections.exists?/2` | Complete | - |
| List all collections | `client.collections.list_all()` | `WeaviateEx.Collections.list/1` | Partial | Medium |
| Export config | `client.collections.export_config()` | `WeaviateEx.Collections.get/2` | Partial | Low |
| Get collection handle | `client.collections.use()` | Missing | Missing | High |
| **Configuration Types** |
| CollectionConfig dataclass | Rich typed object | Raw map | Missing | Critical |
| CollectionConfigSimple | Simplified config object | Missing | Missing | High |
| Property dataclass | `Property` class with validation | Raw map | Missing | High |
| ReferenceProperty | Typed reference class | Raw map | Missing | Medium |
| NestedProperty | Nested object properties | Missing | Missing | Medium |
| **Property Types (DataType)** |
| TEXT/TEXT_ARRAY | Supported | `["text"]` | Complete | - |
| INT/INT_ARRAY | Supported | `["int"]` | Complete | - |
| BOOL/BOOL_ARRAY | Supported | `["boolean"]` | Complete | - |
| NUMBER/NUMBER_ARRAY | Supported | `["number"]` | Complete | - |
| DATE/DATE_ARRAY | Supported | `["date"]` | Complete | - |
| UUID/UUID_ARRAY | Supported | `["uuid"]` | Complete | - |
| GEO_COORDINATES | Supported | `["geoCoordinates"]` | Complete | - |
| BLOB | Supported | `["blob"]` | Complete | - |
| PHONE_NUMBER | Supported | `["phoneNumber"]` | Complete | - |
| OBJECT/OBJECT_ARRAY | Nested objects | Missing builder | Missing | Medium |
| **Tokenization** |
| word | `Tokenization.WORD` | `"word"` | Complete | - |
| whitespace | `Tokenization.WHITESPACE` | `"whitespace"` | Complete | - |
| lowercase | `Tokenization.LOWERCASE` | `"lowercase"` | Complete | - |
| field | `Tokenization.FIELD` | `"field"` | Complete | - |
| gse (Chinese/Japanese) | `Tokenization.GSE` | Missing | Missing | Low |
| trigram | `Tokenization.TRIGRAM` | Missing | Missing | Low |
| kagome_ja (Japanese) | `Tokenization.KAGOME_JA` | Missing | Missing | Low |
| kagome_kr (Korean) | `Tokenization.KAGOME_KR` | Missing | Missing | Low |
| gse_ch (Chinese) | `Tokenization.GSE_CH` | Missing | Missing | Low |
| **Vectorizer Configurations** |
| text2vec-openai | `Configure.Vectorizer.text2vec_openai()` | `VectorConfig.text2vec_openai/1` | Complete | - |
| text2vec-cohere | Full config | `VectorConfig.text2vec_cohere/1` | Complete | - |
| text2vec-huggingface | Full config | `VectorConfig.text2vec_huggingface/1` | Complete | - |
| text2vec-transformers | Full config | `VectorConfig.text2vec_transformers/1` | Complete | - |
| text2vec-contextionary | Full config | `VectorConfig.text2vec_contextionary/1` | Complete | - |
| text2vec-gpt4all | Full config | `VectorConfig.text2vec_gpt4all/1` | Complete | - |
| text2vec-palm/google | Full config | `VectorConfig.text2vec_google_vertex/1` | Complete | - |
| text2vec-aws | Full config | `VectorConfig.text2vec_aws_bedrock/1` | Complete | - |
| text2vec-azure-openai | Full config | Missing | Missing | High |
| text2vec-mistral | Full config | Missing | Missing | Medium |
| text2vec-nvidia | Full config | Missing | Missing | Medium |
| text2vec-ollama | Full config | Missing | Missing | Medium |
| text2vec-voyageai | Full config | `VectorConfig.text2vec_voyageai/1` | Complete | - |
| text2vec-weaviate | Full config | Missing | Missing | Medium |
| text2vec-jinaai | Full config | Missing | Missing | Medium |
| text2vec-databricks | Full config | Missing | Missing | Low |
| text2vec-model2vec | Full config | `VectorConfig.text2vec_model2vec/1` | Complete | - |
| text2colbert-jinaai | Full config | `VectorConfig.text2colbert_jinaai/1` | Complete | - |
| img2vec-neural | Full config | Missing | Missing | Low |
| multi2vec-clip | Full config | `VectorConfig.multi2vec_clip/1` | Complete | - |
| multi2vec-bind | Full config | `VectorConfig.multi2vec_bind/1` | Complete | - |
| multi2vec-palm/google | Full config | Missing | Missing | Low |
| multi2vec-cohere | Full config | Missing | Missing | Medium |
| multi2vec-jinaai | Full config | Missing | Missing | Medium |
| multi2vec-voyageai | Full config | Missing | Missing | Medium |
| multi2vec-nvidia | Full config | Missing | Missing | Medium |
| ref2vec-centroid | Full config | Missing | Missing | Low |
| Custom vectorizer | `Configure.Vectorizer.custom()` | Missing | Missing | Low |
| **Named Vectors (Multi-Vector)** |
| Named vector creation | `Configure.NamedVectors.text2vec_*()` | `VectorConfig.with_named_vectors/2` | Partial | Critical |
| Named vector update | `Reconfigure.NamedVectors.update()` | Missing | Missing | High |
| Add vector to collection | `collection.config.add_vector()` | Missing | Missing | High |
| Multi-vector support | `Configure.MultiVectors.muvera()` | Missing | Missing | High |
| **Vector Index Configuration** |
| HNSW index | `Configure.VectorIndex.hnsw()` | `VectorConfig.hnsw_index/1` | Complete | - |
| FLAT index | `Configure.VectorIndex.flat()` | `VectorConfig.flat_index/1` | Complete | - |
| DYNAMIC index | `Configure.VectorIndex.dynamic()` | `VectorConfig.dynamic_index/1` | Complete | - |
| Skip index | `Configure.VectorIndex.none()` | Missing | Missing | Low |
| PQ quantization | `Configure.VectorIndex.Quantizer.pq()` | `VectorConfig.product_quantization/1` | Complete | - |
| BQ quantization | `Configure.VectorIndex.Quantizer.bq()` | `VectorConfig.binary_quantization/1` | Complete | - |
| SQ quantization | `Configure.VectorIndex.Quantizer.sq()` | `VectorConfig.scalar_quantization/1` | Complete | - |
| RQ quantization | `Configure.VectorIndex.Quantizer.rq()` | Missing | Missing | Medium |
| Filter strategy (SWEEPING/ACORN) | `VectorFilterStrategy` enum | Missing | Missing | Low |
| **Inverted Index Configuration** |
| BM25 config (b, k1) | `Configure.inverted_index(bm25_*)` | Raw map in create | Partial | Medium |
| Cleanup interval | Supported | Missing builder | Missing | Low |
| Index timestamps | Supported | Missing builder | Missing | Low |
| Index property length | Supported | Missing builder | Missing | Low |
| Index null state | Supported | Missing builder | Missing | Low |
| Stopwords (preset, additions, removals) | Full config | Missing | Missing | Medium |
| **Replication Configuration** |
| Replication factor | `Configure.replication(factor=N)` | `VectorConfig.with_replication_config/2` | Partial | Medium |
| Async replication | `async_enabled` param | Missing | Missing | Medium |
| Deletion strategy | `ReplicationDeletionStrategy` enum | Missing | Missing | Low |
| **Sharding Configuration** |
| Virtual per physical | Supported | `VectorConfig.with_sharding_config/2` | Partial | Low |
| Desired count | Supported | Partial | Partial | Low |
| Desired virtual count | Supported | Missing | Missing | Low |
| Sharding key/strategy/function | Supported | Missing | Missing | Low |
| **Multi-Tenancy** |
| Enable multi-tenancy | `Configure.multi_tenancy(enabled=True)` | `VectorConfig.with_multi_tenancy/2` | Complete | - |
| Auto tenant creation | `auto_tenant_creation` param | Missing | Missing | High |
| Auto tenant activation | `auto_tenant_activation` param | Missing | Missing | High |
| Create tenants | `collection.tenants.create()` | `WeaviateEx.Collections.add_tenants/3` | Complete | - |
| Remove tenants | `collection.tenants.remove()` | `WeaviateEx.Collections.remove_tenants/3` | Complete | - |
| Get tenants | `collection.tenants.get()` | `WeaviateEx.Collections.get_tenants/2` | Complete | - |
| Get tenant by name | `collection.tenants.get_by_name()` | Missing | Missing | Medium |
| Get tenants by names | `collection.tenants.get_by_names()` | Missing | Missing | Medium |
| Update tenants | `collection.tenants.update()` | Missing | Missing | High |
| Tenant exists | `collection.tenants.exists()` | Missing | Missing | Medium |
| Activate tenant | `collection.tenants.activate()` | Missing | Missing | High |
| Deactivate tenant | `collection.tenants.deactivate()` | Missing | Missing | High |
| Offload tenant | `collection.tenants.offload()` | Missing | Missing | Medium |
| Tenant activity status | `TenantActivityStatus` enum | Missing | Missing | High |
| **Object TTL Configuration** |
| Enable TTL | `Configure.object_ttl()` | `WeaviateEx.Config.ObjectTTL` | Complete | - |
| Time to live | `default_ttl` param | Supported | Complete | - |
| Delete on (creation/update time) | `delete_on` param | Supported | Complete | - |
| Filter expired objects | `filter_expired_objects` param | Supported | Complete | - |
| **Generative Configuration** |
| OpenAI config | `Configure.Generative.openai()` | Via API.Generative | Partial | Medium |
| Azure OpenAI config | `Configure.Generative.azure_openai()` | Via API.Generative | Partial | Medium |
| Cohere config | `Configure.Generative.cohere()` | Via API.Generative | Partial | Medium |
| Anthropic config | `Configure.Generative.anthropic()` | Via API.Generative | Partial | Medium |
| AWS Bedrock config | `Configure.Generative.aws_bedrock()` | Via API.Generative | Partial | Medium |
| AWS SageMaker config | `Configure.Generative.aws_sagemaker()` | Via API.Generative | Partial | Medium |
| Google Vertex config | `Configure.Generative.google_vertex()` | Via API.Generative | Partial | Medium |
| Google Gemini config | `Configure.Generative.google_gemini()` | Via API.Generative | Partial | Medium |
| Mistral config | `Configure.Generative.mistral()` | Via API.Generative | Partial | Medium |
| Nvidia config | `Configure.Generative.nvidia()` | Missing at collection level | Missing | Low |
| Ollama config | `Configure.Generative.ollama()` | Via API.Generative | Partial | Medium |
| XAI config | `Configure.Generative.xai()` | Via API.Generative | Partial | Medium |
| ContextualAI config | `Configure.Generative.contextualai()` | Via API.Generative | Partial | Medium |
| Databricks config | `Configure.Generative.databricks()` | Missing | Missing | Low |
| FriendliAI config | `Configure.Generative.friendliai()` | Missing | Missing | Low |
| Anyscale config | `Configure.Generative.anyscale()` | Missing | Missing | Low |
| Custom generative | `Configure.Generative.custom()` | Missing | Missing | Low |
| **Reranker Configuration** |
| Cohere reranker | `Configure.Reranker.cohere()` | `VectorConfig.reranker_cohere/1` | Partial | Medium |
| Transformers reranker | `Configure.Reranker.transformers()` | Missing | Missing | Medium |
| VoyageAI reranker | `Configure.Reranker.voyageai()` | Missing | Missing | Medium |
| JinaAI reranker | `Configure.Reranker.jinaai()` | Missing | Missing | Medium |
| Nvidia reranker | `Configure.Reranker.nvidia()` | Missing | Missing | Medium |
| ContextualAI reranker | `Configure.Reranker.contextualai()` | Missing | Missing | Medium |
| Custom reranker | `Configure.Reranker.custom()` | Missing | Missing | Low |
| **Collection Config Operations** |
| Get config | `collection.config.get()` | `WeaviateEx.Collections.get/2` | Partial | Medium |
| Get simple config | `collection.config.get(simple=True)` | Missing | Missing | Low |
| Update config | `collection.config.update()` | `WeaviateEx.Collections.update/3` | Partial | High |
| Add property | `collection.config.add_property()` | `WeaviateEx.Collections.add_property/3` | Complete | - |
| Add reference | `collection.config.add_reference()` | Missing | Missing | Medium |
| Add vector | `collection.config.add_vector()` | Missing | Missing | High |
| Get shards | `collection.config.get_shards()` | `WeaviateEx.Collections.get_shards/2` | Complete | - |
| Update shards | `collection.config.update_shards()` | `WeaviateEx.Collections.update_shard/4` | Partial | Low |
| **Collection Iterator/Cursor** |
| Object iterator | `collection.iterator()` | Missing | Missing | Critical |
| Async iterator | `collection.iterator()` async | Missing | Missing | High |
| Iterator with cache size | `cache_size` param | Missing | Missing | Medium |
| Iterator with after cursor | `after` param | Missing | Missing | Medium |
| **Collection Handle (OOP)** |
| Collection object | `client.collections.get("Name")` | Missing | Missing | Critical |
| With tenant | `collection.with_tenant("tenant")` | Missing (via opts) | Partial | High |
| Collection data operations | `collection.data.*` | Separate module | Different API | Medium |
| Collection query operations | `collection.query.*` | Separate module | Different API | Medium |
| Collection aggregate operations | `collection.aggregate.*` | Separate module | Different API | Medium |
| **Validation & Utilities** |
| Input validation | Pydantic validation | Missing | Missing | High |
| Type coercion | Automatic | Missing | Missing | Medium |
| Capitalize first letter | `_capitalize_first_letter()` | Missing | Missing | Low |
| Config to dict | `config.to_dict()` | N/A (already maps) | N/A | - |
| Config from JSON | `_collection_config_from_json()` | Missing | Missing | High |

---

## Priority Breakdown

### Critical (Must Have)
1. **Collection Handle/Object Pattern** - Python's OOP approach with `client.collections.get("Name")` returning a collection object
2. **Named Vectors Full Support** - Complete multi-vector configuration including all vectorizer types
3. **Collection Iterator** - Stream-based iteration over collection objects
4. **Typed Configuration Classes** - Structs/types for Property, CollectionConfig, etc.

### High Priority
1. **Tenant Management Extensions** - activate/deactivate/offload, status checking
2. **Config Update with Merge** - Smart merging of updates with existing config
3. **Add Vector to Collection** - Dynamic vector addition
4. **Missing Vectorizers** - text2vec-azure-openai, text2vec-mistral, text2vec-nvidia, text2vec-ollama
5. **Input Validation** - Validate configuration before API calls
6. **Delete Multiple Collections** - Batch delete by name list

### Medium Priority
1. **RQ Quantization** - Rotational quantization support
2. **All Reranker Configs** - Complete reranker provider support
3. **Stopwords Configuration** - BM25 stopwords customization
4. **Async Replication** - Replication async settings
5. **Get Tenant by Name(s)** - Specific tenant retrieval
6. **Multi2vec Additional Providers** - cohere, jinaai, voyageai, nvidia

### Low Priority
1. **CJK Tokenization** - GSE, Kagome tokenizers
2. **Sharding Advanced Options** - Full sharding customization
3. **Filter Strategy** - SWEEPING/ACORN strategies
4. **Skip Index** - Disable vector indexing
5. **Ref2vec Centroid** - Reference-based vectorization
6. **Custom Generative/Reranker** - Custom module support

---

## Feature Details with Code Examples

### 1. Collection Handle Pattern (Critical)

**Python Implementation:**
```python
# Get a collection handle for operations
collection = client.collections.get("Article")

# All operations are now scoped to this collection
response = collection.query.near_text(
    query="AI technology",
    limit=10
)

# Data operations
collection.data.insert({"title": "New Article"})

# Config operations
config = collection.config.get()
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Collection do
  @moduledoc """
  Collection handle for scoped operations.
  """

  defstruct [:client, :name, :tenant]

  @doc "Get a collection handle"
  def get(client, name, opts \\ []) do
    tenant = Keyword.get(opts, :tenant)
    %__MODULE__{client: client, name: name, tenant: tenant}
  end

  @doc "Scope to a specific tenant"
  def with_tenant(%__MODULE__{} = collection, tenant) do
    %{collection | tenant: tenant}
  end

  # Delegate to sub-modules
  defdelegate query(collection, opts), to: WeaviateEx.Collection.Query
  defdelegate data(collection), to: WeaviateEx.Collection.Data
  defdelegate config(collection), to: WeaviateEx.Collection.Config
  defdelegate aggregate(collection, opts), to: WeaviateEx.Collection.Aggregate
end

# Usage:
collection = WeaviateEx.Collection.get(client, "Article")
collection = WeaviateEx.Collection.with_tenant(collection, "tenant1")
{:ok, results} = WeaviateEx.Collection.Query.near_text(collection, "AI", limit: 10)
```

### 2. Named Vectors Full Support (Critical)

**Python Implementation:**
```python
from weaviate.classes.config import Configure

client.collections.create(
    name="Article",
    vectorizer_config=[
        Configure.NamedVectors.text2vec_openai(
            name="title_vector",
            source_properties=["title"],
            model="text-embedding-3-small"
        ),
        Configure.NamedVectors.text2vec_cohere(
            name="content_vector",
            source_properties=["content"],
            model="embed-multilingual-v3.0"
        )
    ]
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Config.NamedVectors do
  @moduledoc """
  Named vector configuration builders.
  """

  @doc "Create OpenAI named vector"
  def text2vec_openai(name, opts \\ []) do
    %{
      name: name,
      vectorizer: %{
        "text2vec-openai" => %{
          "model" => Keyword.get(opts, :model),
          "properties" => Keyword.get(opts, :source_properties),
          "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
        }
      },
      vectorIndexType: Keyword.get(opts, :vector_index_type, "hnsw"),
      vectorIndexConfig: Keyword.get(opts, :vector_index_config)
    }
  end

  @doc "Create Cohere named vector"
  def text2vec_cohere(name, opts \\ []) do
    %{
      name: name,
      vectorizer: %{
        "text2vec-cohere" => %{
          "model" => Keyword.get(opts, :model),
          "truncate" => Keyword.get(opts, :truncate),
          "properties" => Keyword.get(opts, :source_properties),
          "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
        }
      },
      vectorIndexType: Keyword.get(opts, :vector_index_type, "hnsw"),
      vectorIndexConfig: Keyword.get(opts, :vector_index_config)
    }
  end

  # Add all other vectorizers...
end

# Usage:
alias WeaviateEx.Config.NamedVectors

config = %{
  "class" => "Article",
  "vectorConfig" => %{
    "title_vector" => NamedVectors.text2vec_openai("title_vector",
      source_properties: ["title"],
      model: "text-embedding-3-small"
    ),
    "content_vector" => NamedVectors.text2vec_cohere("content_vector",
      source_properties: ["content"],
      model: "embed-multilingual-v3.0"
    )
  }
}
```

### 3. Collection Iterator (Critical)

**Python Implementation:**
```python
# Iterate over all objects in a collection
for obj in collection.iterator(include_vector=True):
    print(obj.properties)
    print(obj.vector)

# With cursor for resumption
for obj in collection.iterator(after=last_uuid):
    process(obj)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Collection.Iterator do
  @moduledoc """
  Stream-based iterator for collection objects.
  """

  @default_batch_size 100

  @doc """
  Create a stream that iterates over all objects in a collection.

  ## Options
    - `:include_vector` - Include vectors in response (default: false)
    - `:properties` - Properties to return
    - `:batch_size` - Number of objects per batch (default: 100)
    - `:after` - UUID to start after (for resumption)
  """
  def stream(collection, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    after_cursor = Keyword.get(opts, :after)

    Stream.resource(
      fn -> {after_cursor, false} end,
      fn
        {_, true} -> {:halt, nil}
        {cursor, false} ->
          case fetch_batch(collection, cursor, batch_size, opts) do
            {:ok, []} -> {:halt, nil}
            {:ok, objects} ->
              last_uuid = List.last(objects) |> Map.get("_additional") |> Map.get("id")
              {objects, {last_uuid, false}}
            {:error, _} -> {:halt, nil}
          end
      end,
      fn _ -> :ok end
    )
  end

  defp fetch_batch(collection, after_cursor, limit, opts) do
    # Build GraphQL query with after cursor
    query = build_fetch_query(collection, after_cursor, limit, opts)
    # Execute and return results
  end
end

# Usage:
collection
|> WeaviateEx.Collection.Iterator.stream(include_vector: true)
|> Stream.take(1000)
|> Enum.each(fn obj ->
  IO.inspect(obj["properties"])
end)
```

### 4. Typed Configuration Structs (Critical)

**Python Implementation:**
```python
@dataclass
class Property:
    name: str
    data_type: DataType
    description: Optional[str]
    index_filterable: bool
    index_searchable: bool
    tokenization: Optional[Tokenization]
    vectorizer_config: Optional[PropertyVectorizerConfig]

@dataclass
class CollectionConfig:
    name: str
    description: Optional[str]
    properties: List[Property]
    references: List[ReferenceProperty]
    vectorizer_config: Optional[VectorizerConfig]
    vector_index_config: VectorIndexConfig
    # ... more fields
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Config.Property do
  @moduledoc """
  Property configuration struct with validation.
  """

  @type data_type :: :text | :text_array | :int | :int_array | :bool | :bool_array |
                     :number | :number_array | :date | :date_array | :uuid | :uuid_array |
                     :geo_coordinates | :blob | :phone_number | :object | :object_array

  @type tokenization :: :word | :whitespace | :lowercase | :field | :gse | :trigram

  @type t :: %__MODULE__{
    name: String.t(),
    data_type: data_type(),
    description: String.t() | nil,
    index_filterable: boolean(),
    index_searchable: boolean(),
    index_range_filters: boolean(),
    tokenization: tokenization() | nil,
    skip_vectorization: boolean(),
    vectorize_property_name: boolean(),
    nested_properties: [t()] | nil
  }

  defstruct [
    :name,
    :data_type,
    :description,
    index_filterable: true,
    index_searchable: true,
    index_range_filters: false,
    tokenization: nil,
    skip_vectorization: false,
    vectorize_property_name: true,
    nested_properties: nil
  ]

  @doc "Create a new property with validation"
  def new(name, data_type, opts \\ []) do
    %__MODULE__{
      name: name,
      data_type: data_type,
      description: Keyword.get(opts, :description),
      index_filterable: Keyword.get(opts, :index_filterable, true),
      index_searchable: Keyword.get(opts, :index_searchable, true),
      index_range_filters: Keyword.get(opts, :index_range_filters, false),
      tokenization: Keyword.get(opts, :tokenization),
      skip_vectorization: Keyword.get(opts, :skip_vectorization, false),
      vectorize_property_name: Keyword.get(opts, :vectorize_property_name, true),
      nested_properties: Keyword.get(opts, :nested_properties)
    }
  end

  @doc "Convert to API-compatible map"
  def to_map(%__MODULE__{} = prop) do
    %{
      "name" => prop.name,
      "dataType" => [data_type_to_string(prop.data_type)],
      "description" => prop.description,
      "indexFilterable" => prop.index_filterable,
      "indexSearchable" => prop.index_searchable,
      "indexRangeFilters" => prop.index_range_filters,
      "tokenization" => tokenization_to_string(prop.tokenization)
    }
    |> maybe_add_nested(prop)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp data_type_to_string(:text), do: "text"
  defp data_type_to_string(:text_array), do: "text[]"
  defp data_type_to_string(:int), do: "int"
  defp data_type_to_string(:int_array), do: "int[]"
  # ... etc
end

defmodule WeaviateEx.Config.CollectionConfig do
  @moduledoc """
  Full collection configuration struct.
  """

  alias WeaviateEx.Config.{Property, VectorIndexConfig, ReplicationConfig}

  @type t :: %__MODULE__{
    name: String.t(),
    description: String.t() | nil,
    properties: [Property.t()],
    vectorizer: String.t() | nil,
    vectorizer_config: map() | nil,
    vector_index_type: :hnsw | :flat | :dynamic,
    vector_index_config: VectorIndexConfig.t() | nil,
    vector_config: map() | nil,
    inverted_index_config: map() | nil,
    replication_config: ReplicationConfig.t() | nil,
    sharding_config: map() | nil,
    multi_tenancy_config: map() | nil,
    generative_config: map() | nil,
    reranker_config: map() | nil
  }

  defstruct [
    :name,
    :description,
    properties: [],
    vectorizer: nil,
    vectorizer_config: nil,
    vector_index_type: :hnsw,
    vector_index_config: nil,
    vector_config: nil,
    inverted_index_config: nil,
    replication_config: nil,
    sharding_config: nil,
    multi_tenancy_config: nil,
    generative_config: nil,
    reranker_config: nil
  ]

  @doc "Parse from API response JSON"
  def from_json(json) when is_map(json) do
    %__MODULE__{
      name: json["class"],
      description: json["description"],
      properties: parse_properties(json["properties"]),
      vectorizer: json["vectorizer"],
      # ... parse all other fields
    }
  end
end
```

### 5. Tenant Management Extensions (High)

**Python Implementation:**
```python
# Create tenants with activity status
collection.tenants.create([
    Tenant(name="tenant1", activity_status=TenantActivityStatus.ACTIVE),
    Tenant(name="tenant2", activity_status=TenantActivityStatus.INACTIVE)
])

# Update tenant status
collection.tenants.update([
    Tenant(name="tenant1", activity_status=TenantActivityStatus.INACTIVE)
])

# Convenience methods
collection.tenants.activate("tenant1")
collection.tenants.deactivate("tenant1")
collection.tenants.offload("tenant1")

# Check existence
exists = collection.tenants.exists("tenant1")

# Get specific tenant
tenant = collection.tenants.get_by_name("tenant1")
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Tenants do
  @moduledoc """
  Extended tenant management operations.
  """

  @type activity_status :: :active | :inactive | :offloaded | :offloading | :onloading

  @doc "Update tenant activity status"
  def update(client, collection_name, tenants, opts \\ []) do
    tenant_updates = Enum.map(tenants, fn
      %{name: name, activity_status: status} ->
        %{"name" => name, "activityStatus" => status_to_string(status)}
      name when is_binary(name) ->
        %{"name" => name}
    end)

    Client.request(client, :put, "/v1/schema/#{collection_name}/tenants", tenant_updates, opts)
  end

  @doc "Activate tenants"
  def activate(client, collection_name, tenants, opts \\ []) do
    tenant_list = List.wrap(tenants)
    updates = Enum.map(tenant_list, &%{name: &1, activity_status: :active})
    update(client, collection_name, updates, opts)
  end

  @doc "Deactivate tenants"
  def deactivate(client, collection_name, tenants, opts \\ []) do
    tenant_list = List.wrap(tenants)
    updates = Enum.map(tenant_list, &%{name: &1, activity_status: :inactive})
    update(client, collection_name, updates, opts)
  end

  @doc "Offload tenants to cold storage"
  def offload(client, collection_name, tenants, opts \\ []) do
    tenant_list = List.wrap(tenants)
    updates = Enum.map(tenant_list, &%{name: &1, activity_status: :offloaded})
    update(client, collection_name, updates, opts)
  end

  @doc "Check if tenant exists"
  def exists?(client, collection_name, tenant_name, opts \\ []) do
    case Client.request(client, :head, "/v1/schema/#{collection_name}/tenants/#{tenant_name}", nil, opts) do
      {:ok, _} -> {:ok, true}
      {:error, %{type: :not_found}} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Get specific tenant by name"
  def get_by_name(client, collection_name, tenant_name, opts \\ []) do
    Client.request(client, :get, "/v1/schema/#{collection_name}/tenants/#{tenant_name}", nil, opts)
  end

  @doc "Get multiple tenants by names"
  def get_by_names(client, collection_name, tenant_names, opts \\ []) do
    # Use gRPC if available, otherwise batch REST calls
    Enum.reduce_while(tenant_names, {:ok, %{}}, fn name, {:ok, acc} ->
      case get_by_name(client, collection_name, name, opts) do
        {:ok, tenant} -> {:cont, {:ok, Map.put(acc, name, tenant)}}
        {:error, %{type: :not_found}} -> {:cont, {:ok, acc}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp status_to_string(:active), do: "ACTIVE"
  defp status_to_string(:inactive), do: "INACTIVE"
  defp status_to_string(:offloaded), do: "OFFLOADED"
end
```

### 6. Missing Vectorizers (High)

**Python Implementation:**
```python
# Azure OpenAI
Configure.Vectorizer.text2vec_azure_openai(
    resource_name="my-resource",
    deployment_id="my-deployment",
    model="text-embedding-ada-002"
)

# Mistral
Configure.Vectorizer.text2vec_mistral(
    model="mistral-embed",
    base_url="https://api.mistral.ai"
)

# Nvidia
Configure.Vectorizer.text2vec_nvidia(
    model="NV-Embed-QA",
    base_url="https://integrate.api.nvidia.com"
)

# Ollama
Configure.Vectorizer.text2vec_ollama(
    model="nomic-embed-text",
    api_endpoint="http://localhost:11434"
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.API.VectorConfig do
  # Add these functions to existing module

  @doc """
  Configure text2vec-azure-openai vectorizer.

  ## Options (Required)
    - `:resource_name` - Azure resource name
    - `:deployment_id` - Azure deployment ID

  ## Options (Optional)
    - `:base_url` - Base URL for API
    - `:model` - Model name
    - `:dimensions` - Output dimensions
    - `:vectorize_collection_name` - Whether to vectorize collection name (default: true)
  """
  def text2vec_azure_openai(opts) do
    config = %{
      "resourceName" => Keyword.fetch!(opts, :resource_name),
      "deploymentId" => Keyword.fetch!(opts, :deployment_id),
      "isAzure" => true,
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> maybe_put("baseURL", Keyword.get(opts, :base_url))
    |> maybe_put("model", Keyword.get(opts, :model))
    |> maybe_put("dimensions", Keyword.get(opts, :dimensions))

    %{
      "vectorizer" => "text2vec-openai",
      "moduleConfig" => %{"text2vec-openai" => config}
    }
  end

  @doc """
  Configure text2vec-mistral vectorizer.
  """
  def text2vec_mistral(opts \\ []) do
    config = %{
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> maybe_put("model", Keyword.get(opts, :model))
    |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{
      "vectorizer" => "text2vec-mistral",
      "moduleConfig" => %{"text2vec-mistral" => config}
    }
  end

  @doc """
  Configure text2vec-nvidia vectorizer.
  """
  def text2vec_nvidia(opts \\ []) do
    config = %{
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> maybe_put("model", Keyword.get(opts, :model))
    |> maybe_put("baseURL", Keyword.get(opts, :base_url))
    |> maybe_put("truncate", Keyword.get(opts, :truncate))

    %{
      "vectorizer" => "text2vec-nvidia",
      "moduleConfig" => %{"text2vec-nvidia" => config}
    }
  end

  @doc """
  Configure text2vec-ollama vectorizer.
  """
  def text2vec_ollama(opts \\ []) do
    config = %{
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> maybe_put("model", Keyword.get(opts, :model))
    |> maybe_put("apiEndpoint", Keyword.get(opts, :api_endpoint))

    %{
      "vectorizer" => "text2vec-ollama",
      "moduleConfig" => %{"text2vec-ollama" => config}
    }
  end

  @doc """
  Configure text2vec-jinaai vectorizer.
  """
  def text2vec_jinaai(opts \\ []) do
    config = %{
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> maybe_put("model", Keyword.get(opts, :model))
    |> maybe_put("baseURL", Keyword.get(opts, :base_url))
    |> maybe_put("dimensions", Keyword.get(opts, :dimensions))

    %{
      "vectorizer" => "text2vec-jinaai",
      "moduleConfig" => %{"text2vec-jinaai" => config}
    }
  end

  @doc """
  Configure text2vec-weaviate (hosted embeddings) vectorizer.
  """
  def text2vec_weaviate(opts \\ []) do
    config = %{
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> maybe_put("model", Keyword.get(opts, :model))
    |> maybe_put("baseURL", Keyword.get(opts, :base_url))
    |> maybe_put("dimensions", Keyword.get(opts, :dimensions))

    %{
      "vectorizer" => "text2vec-weaviate",
      "moduleConfig" => %{"text2vec-weaviate" => config}
    }
  end
end
```

### 7. Config Update with Merge (High)

**Python Implementation:**
```python
# Python automatically merges updates with existing config
collection.config.update(
    description="Updated description",
    inverted_index_config=Reconfigure.inverted_index(
        bm25_b=0.8,
        bm25_k1=1.5
    ),
    vector_index_config=Reconfigure.VectorIndex.hnsw(
        ef=200,
        dynamic_ef_factor=10
    )
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Config.Update do
  @moduledoc """
  Collection configuration update with automatic merging.
  """

  @doc """
  Update collection configuration, merging with existing.

  ## Options
    - `:description` - Update description
    - `:inverted_index_config` - Inverted index updates
    - `:vector_index_config` - Vector index updates
    - `:replication_config` - Replication updates
    - `:multi_tenancy_config` - Multi-tenancy updates
  """
  def update(client, collection_name, updates, opts \\ []) do
    with {:ok, existing} <- WeaviateEx.Collections.get(client, collection_name, opts) do
      merged = merge_config(existing, updates)
      WeaviateEx.Collections.update(client, collection_name, merged, opts)
    end
  end

  defp merge_config(existing, updates) do
    existing
    |> maybe_update(:description, updates)
    |> maybe_merge(:inverted_index_config, updates, "invertedIndexConfig")
    |> maybe_merge(:vector_index_config, updates, "vectorIndexConfig")
    |> maybe_merge(:replication_config, updates, "replicationConfig")
    |> maybe_merge(:multi_tenancy_config, updates, "multiTenancyConfig")
  end

  defp maybe_update(config, key, updates) do
    case Keyword.get(updates, key) do
      nil -> config
      value -> Map.put(config, to_string(key), value)
    end
  end

  defp maybe_merge(config, key, updates, json_key) do
    case Keyword.get(updates, key) do
      nil -> config
      update_map when is_map(update_map) ->
        existing_section = Map.get(config, json_key, %{})
        merged_section = deep_merge(existing_section, update_map)
        Map.put(config, json_key, merged_section)
    end
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2), do: deep_merge(v1, v2), else: v2
    end)
  end
end
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
1. Implement `WeaviateEx.Config.Property` struct
2. Implement `WeaviateEx.Config.CollectionConfig` struct
3. Add config parsing from JSON responses
4. Add input validation utilities

### Phase 2: Collection Handle (Week 2-3)
1. Implement `WeaviateEx.Collection` module
2. Add `with_tenant/2` support
3. Create sub-modules for Query, Data, Config operations
4. Integrate with existing API modules

### Phase 3: Named Vectors (Week 3-4)
1. Implement `WeaviateEx.Config.NamedVectors` module
2. Add all vectorizer configurations
3. Implement `add_vector/2` for dynamic vector addition
4. Add vector update operations

### Phase 4: Iterator (Week 4)
1. Implement `WeaviateEx.Collection.Iterator`
2. Add Stream-based iteration
3. Support cursor-based resumption
4. Add async/parallel options

### Phase 5: Tenant Management (Week 5)
1. Add `update/4` for tenant updates
2. Implement activate/deactivate/offload
3. Add exists?/get_by_name/get_by_names
4. Add activity status support

### Phase 6: Polish (Week 6)
1. Add remaining vectorizers
2. Add all reranker configurations
3. Implement config update with merge
4. Add comprehensive tests

---

## Conclusion

The Elixir WeaviateEx client has a solid foundation for basic collection operations but lacks the sophisticated configuration builders, type safety, and helper utilities that make the Python client developer-friendly. The priority should be on implementing the Collection Handle pattern, Named Vectors support, and Collection Iterator, as these represent the core functionality gaps that would most benefit users.

The proposed implementations follow Elixir idioms (structs, pattern matching, streams) while maintaining API compatibility with the Python client's concepts. This will enable Elixir developers to follow Python examples and documentation with minimal translation effort.
