# Gap Analysis: Generative AI (RAG) and References
## Python Client vs Elixir Client (WeaviateEx)

**Date:** 2025-12-28
**Scope:** Generative Search (RAG), Cross-References, and Related Features
**Python Client Version:** Latest (weaviate-python-client)
**Elixir Client Version:** WeaviateEx (current development)

---

## Executive Summary

The Elixir client (WeaviateEx) has implemented basic generative search functionality with support for 17+ AI providers. However, significant gaps exist compared to the Python client's comprehensive RAG and reference handling capabilities:

### Critical Gaps
1. **Missing Provider Configurations**: Python has typed configuration classes for each provider with full parameter support; Elixir uses a simplified generic approach
2. **No Reference API**: Complete absence of cross-reference CRUD operations in Elixir
3. **Missing Multimodal Support**: No image/media handling in generative queries
4. **No Metadata Return**: Cannot retrieve generation metadata (tokens, latency, etc.)

### High Priority Gaps
1. **Missing Nested Reference Queries**: Cannot query deeply nested references
2. **No Typed Reference Types**: Missing `ReferenceToMulti`, `CrossReference` equivalents
3. **Limited Query Integration**: Generate not integrated with all query types (BM25, hybrid, near_vector, etc.)
4. **No Debug Mode**: Cannot access prompt debugging information

### Coverage Statistics
| Feature Area | Python Coverage | Elixir Coverage | Gap |
|--------------|-----------------|-----------------|-----|
| Provider Configurations | 17 providers, typed | 17 providers, untyped | 60% |
| Generation Parameters | Full per-provider | Basic common params | 40% |
| Reference CRUD | Complete | Batch add only | 20% |
| Reference Queries | Full nested | Not implemented | 0% |
| Multimodal Generation | Full | Not implemented | 0% |
| Generation Metadata | Full | Not implemented | 0% |

---

## Detailed Comparison Table

### 1. Generative Search (RAG) Features

| Feature | Python Client | Elixir Client | Priority |
|---------|---------------|---------------|----------|
| Single prompt generation | `GenerativeParameters.single_prompt()` | `Generative.single_prompt/4` | Implemented |
| Grouped task generation | `GenerativeParameters.grouped_task()` | `Generative.grouped_task/4` | Implemented |
| Property interpolation | `{property_name}` syntax | `{property_name}` syntax | Implemented |
| Debug mode | `debug=True` parameter | Not implemented | High |
| Return metadata | `metadata=True` | Not implemented | Critical |
| Image properties | `image_properties=["prop"]` | Not implemented | High |
| External images | `images=[path, base64]` | Not implemented | High |
| Non-blob properties | `non_blob_properties=["prop"]` | Not implemented | Medium |
| Typed prompt objects | `_SinglePrompt`, `_GroupedTask` | Not implemented | Medium |

### 2. Provider Configuration Classes

| Provider | Python Config Class | Elixir Support | Missing Parameters |
|----------|---------------------|----------------|-------------------|
| OpenAI | `_GenerativeOpenAI` | Basic via atoms | `frequency_penalty`, `presence_penalty`, `stop`, `api_version`, `base_url`, `deployment_id`, `resource_name`, `is_azure` |
| Anthropic | `_GenerativeAnthropic` | Basic | `base_url`, `stop_sequences`, `top_k` |
| Cohere | `_GenerativeCohere` | Basic | `base_url`, `k`, `p`, `presence_penalty`, `stop_sequences` |
| AWS Bedrock | `_GenerativeAWS` | Basic | `endpoint`, `region`, `service`, `target_model`, `target_variant`, `top_k`, `stop_sequences` |
| AWS SageMaker | `_GenerativeAWS` | Basic | Same as Bedrock |
| Azure OpenAI | `_GenerativeOpenAI` (is_azure=True) | Basic | All Azure-specific params |
| Google/Vertex | `_GenerativeGoogle` | Basic | `api_endpoint`, `endpoint_id`, `frequency_penalty`, `presence_penalty`, `project_id`, `region`, `stop_sequences`, `top_k` |
| Mistral | `_GenerativeMistral` | Basic | `base_url` |
| Ollama | `_GenerativeOllama` | Basic | `api_endpoint` |
| NVIDIA | `_GenerativeNvidia` | Not supported | All params |
| Databricks | `_GenerativeDatabricks` | Not supported | All params |
| FriendliAI | `_GenerativeFriendliai` | Not supported | All params |
| XAI (Grok) | `_GenerativeXAI` | Basic | `base_url` |
| ContextualAI | `_GenerativeContextualAI` | Basic | `knowledge` array |
| Anyscale | `_GenerativeAnyscale` | Basic | `base_url` |
| Dummy | `_GenerativeDummy` | Not supported | N/A |

### 3. Cross-Reference Operations

| Operation | Python Method | Elixir Method | Status |
|-----------|---------------|---------------|--------|
| Add single reference | `data.reference_add()` | Not implemented | Critical |
| Add many references | `data.reference_add_many()` | `Batch.add_references/2` | Partial |
| Delete reference | `data.reference_delete()` | Not implemented | Critical |
| Replace references | `data.reference_replace()` | Not implemented | Critical |
| Insert with references | `data.insert(references={})` | Not implemented | Critical |
| Update with references | `data.update(references={})` | Not implemented | Critical |
| Multi-target references | `ReferenceToMulti` | Not implemented | High |

### 4. Reference Query Features

| Feature | Python Implementation | Elixir Implementation | Priority |
|---------|----------------------|----------------------|----------|
| `QueryReference` | Full class with options | Not implemented | Critical |
| `QueryReference.MultiTarget` | Full class | Not implemented | Critical |
| Nested reference queries | Up to N levels deep | Not implemented | High |
| Return reference metadata | `return_metadata=MetadataQuery()` | Not implemented | High |
| Return reference properties | `return_properties=[...]` | Not implemented | High |
| Include vector from refs | `include_vector=True` | Not implemented | Medium |
| TypedDict references | `CrossReference[Props, Refs]` | Not implemented | Medium |
| Cross-reference annotation | `CrossReferenceAnnotation` | Not implemented | Low |

### 5. Generation Return Types

| Type | Python Class | Elixir Equivalent | Status |
|------|--------------|-------------------|--------|
| `GenerativeReturn` | Typed generic class | Map/tuple | Partial |
| `GenerativeObject` | Typed with properties | Map | Partial |
| `GenerativeSingle` | Debug + metadata + text | Not implemented | Critical |
| `GenerativeGrouped` | Metadata + text | Not implemented | Critical |
| `GenerativeMetadata` | Provider-specific metadata | Not implemented | High |
| `GenerativeGroupByReturn` | Groups with generation | Not implemented | Medium |

---

## Missing Features with Code Examples

### 1. Provider Configuration Classes (Critical)

**Python Implementation:**
```python
from weaviate.classes.generate import GenerativeConfig

# Fully typed OpenAI configuration
config = GenerativeConfig.openai(
    model="gpt-4",
    temperature=0.7,
    max_tokens=500,
    top_p=0.9,
    frequency_penalty=0.5,
    presence_penalty=0.3,
    stop=["\n\n"],
    base_url="https://api.openai.com/v1",
    reasoning_effort="high",  # For O1/O3 models
    verbosity="medium"        # For O1/O3 models
)

# Use with generate query
result = collection.generate.near_text(
    query="artificial intelligence",
    single_prompt="Summarize: {content}",
    generative_provider=config
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Generative.Config do
  @moduledoc """
  Typed configuration structs for each generative provider.
  """

  defmodule OpenAI do
    @moduledoc "OpenAI generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :frequency_penalty,
      :presence_penalty,
      :stop,
      :base_url,
      :api_version,
      :deployment_id,
      :resource_name,
      :is_azure,
      :verbosity,
      :reasoning_effort
    ]

    @type t :: %__MODULE__{
      model: String.t() | nil,
      temperature: float() | nil,
      max_tokens: integer() | nil,
      top_p: float() | nil,
      frequency_penalty: float() | nil,
      presence_penalty: float() | nil,
      stop: [String.t()] | nil,
      base_url: String.t() | nil,
      api_version: String.t() | nil,
      deployment_id: String.t() | nil,
      resource_name: String.t() | nil,
      is_azure: boolean(),
      verbosity: :low | :medium | :high | nil,
      reasoning_effort: :minimal | :low | :medium | :high | nil
    }

    def new(opts \\ []) do
      %__MODULE__{
        model: Keyword.get(opts, :model),
        temperature: Keyword.get(opts, :temperature),
        max_tokens: Keyword.get(opts, :max_tokens),
        top_p: Keyword.get(opts, :top_p),
        frequency_penalty: Keyword.get(opts, :frequency_penalty),
        presence_penalty: Keyword.get(opts, :presence_penalty),
        stop: Keyword.get(opts, :stop),
        base_url: Keyword.get(opts, :base_url),
        api_version: Keyword.get(opts, :api_version),
        deployment_id: Keyword.get(opts, :deployment_id),
        resource_name: Keyword.get(opts, :resource_name),
        is_azure: Keyword.get(opts, :is_azure, false),
        verbosity: Keyword.get(opts, :verbosity),
        reasoning_effort: Keyword.get(opts, :reasoning_effort)
      }
    end
  end

  defmodule Anthropic do
    defstruct [:model, :temperature, :max_tokens, :top_p, :top_k, :stop_sequences, :base_url]

    @type t :: %__MODULE__{
      model: String.t() | nil,
      temperature: float() | nil,
      max_tokens: integer() | nil,
      top_p: float() | nil,
      top_k: integer() | nil,
      stop_sequences: [String.t()] | nil,
      base_url: String.t() | nil
    }
  end

  # ... Similar structs for all other providers

  @doc "Factory function to create provider configs"
  def openai(opts \\ []), do: OpenAI.new(opts)
  def anthropic(opts \\ []), do: struct(Anthropic, opts)
  def azure_openai(opts \\ []), do: OpenAI.new(Keyword.put(opts, :is_azure, true))
end

# Usage
config = WeaviateEx.Generative.Config.openai(
  model: "gpt-4",
  temperature: 0.7,
  max_tokens: 500,
  reasoning_effort: :high
)

{:ok, result} = WeaviateEx.Query.near_text(client, "Article",
  query: "artificial intelligence",
  generate: %{
    single_prompt: "Summarize: {content}",
    provider_config: config
  }
)
```

### 2. Reference CRUD Operations (Critical)

**Python Implementation:**
```python
# Add a single reference
collection.data.reference_add(
    from_uuid="source-uuid",
    from_property="hasAuthor",
    to=target_uuid
)

# Add reference to multi-target property
collection.data.reference_add(
    from_uuid="source-uuid",
    from_property="relatedTo",
    to=ReferenceToMulti(
        target_collection="OtherCollection",
        uuids=target_uuid
    )
)

# Delete a reference
collection.data.reference_delete(
    from_uuid="source-uuid",
    from_property="hasAuthor",
    to=target_uuid
)

# Replace all references on a property
collection.data.reference_replace(
    from_uuid="source-uuid",
    from_property="hasAuthors",
    to=[uuid1, uuid2, uuid3]
)

# Insert with references
collection.data.insert(
    properties={"title": "Article"},
    references={"hasAuthor": author_uuid}
)

# Batch add references
collection.data.reference_add_many([
    DataReference(
        from_property="hasAuthor",
        from_uuid=article_uuid,
        to_uuid=author_uuid
    ),
    DataReference.MultiTarget(
        from_property="relatedTo",
        from_uuid=article_uuid,
        to_uuid=other_uuid,
        target_collection="OtherCollection"
    )
])
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.API.References do
  @moduledoc """
  Cross-reference operations for Weaviate objects.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type uuid :: String.t()
  @type reference_input :: uuid() | [uuid()] | reference_to_multi()
  @type reference_to_multi :: %{
    target_collection: String.t(),
    uuids: uuid() | [uuid()]
  }

  @doc """
  Add a reference from one object to another.

  ## Examples

      # Single target reference
      {:ok, _} = References.add(client, "Article", source_uuid, "hasAuthor", target_uuid)

      # Multi-target reference
      {:ok, _} = References.add(client, "Article", source_uuid, "relatedTo", %{
        target_collection: "Category",
        uuids: category_uuid
      })
  """
  @spec add(Client.t(), String.t(), uuid(), String.t(), reference_input(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def add(client, collection, from_uuid, from_property, to, opts \\ []) do
    path = "/v1/objects/#{collection}/#{from_uuid}/references/#{from_property}"
    beacon = build_beacon(to)

    Client.request(client, :post, path, beacon, opts)
  end

  @doc """
  Delete a reference from an object.
  """
  @spec delete(Client.t(), String.t(), uuid(), String.t(), reference_input(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete(client, collection, from_uuid, from_property, to, opts \\ []) do
    path = "/v1/objects/#{collection}/#{from_uuid}/references/#{from_property}"
    beacon = build_beacon(to)

    Client.request(client, :delete, path, beacon, opts)
  end

  @doc """
  Replace all references on a property.
  """
  @spec replace(Client.t(), String.t(), uuid(), String.t(), [reference_input()], keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def replace(client, collection, from_uuid, from_property, references, opts \\ []) do
    path = "/v1/objects/#{collection}/#{from_uuid}/references/#{from_property}"
    beacons = Enum.flat_map(references, &build_beacons/1)

    Client.request(client, :put, path, beacons, opts)
  end

  @doc """
  Add multiple references in batch.
  """
  @spec add_many(Client.t(), String.t(), [data_reference()], keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def add_many(client, collection, references, opts \\ []) do
    batch_refs = Enum.map(references, fn ref ->
      %{
        "from" => "weaviate://localhost/#{collection}/#{ref.from_uuid}/#{ref.from_property}",
        "to" => build_beacon_url(ref.to_uuid, ref[:target_collection])
      }
    end)

    Client.request(client, :post, "/v1/batch/references", batch_refs, opts)
  end

  # Private helpers
  defp build_beacon(uuid) when is_binary(uuid) do
    %{"beacon" => "weaviate://localhost/#{uuid}"}
  end

  defp build_beacon(%{target_collection: collection, uuids: uuid}) when is_binary(uuid) do
    %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
  end

  defp build_beacon(%{target_collection: collection, uuids: uuids}) when is_list(uuids) do
    Enum.map(uuids, fn uuid ->
      %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
    end)
  end

  defp build_beacons(ref), do: List.wrap(build_beacon(ref))

  defp build_beacon_url(uuid, nil), do: "weaviate://localhost/#{uuid}"
  defp build_beacon_url(uuid, collection), do: "weaviate://localhost/#{collection}/#{uuid}"
end

# Data module extension for reference support
defmodule WeaviateEx.API.Data do
  # Add reference support to insert/update

  @doc """
  Insert object with references.
  """
  def insert(client, collection, data, opts \\ []) do
    body = prepare_body_with_references(data, collection)
    Client.request(client, :post, "/v1/objects", body, opts)
  end

  defp prepare_body_with_references(data, collection) do
    properties = Map.get(data, :properties, %{})
    references = Map.get(data, :references, %{})

    # Convert references to beacon format
    ref_props = references
    |> Enum.map(fn {prop, ref} -> {prop, build_reference_value(ref)} end)
    |> Map.new()

    %{
      "class" => collection,
      "properties" => Map.merge(properties, ref_props),
      "id" => Map.get(data, :id) || UUID.uuid4()
    }
  end

  defp build_reference_value(uuid) when is_binary(uuid) do
    [%{"beacon" => "weaviate://localhost/#{uuid}"}]
  end

  defp build_reference_value(uuids) when is_list(uuids) do
    Enum.map(uuids, fn uuid -> %{"beacon" => "weaviate://localhost/#{uuid}"} end)
  end

  defp build_reference_value(%{target_collection: col, uuids: uuids}) do
    uuids
    |> List.wrap()
    |> Enum.map(fn uuid -> %{"beacon" => "weaviate://localhost/#{col}/#{uuid}"} end)
  end
end
```

### 3. Reference Query Support (Critical)

**Python Implementation:**
```python
from weaviate.classes.query import QueryReference, MetadataQuery

# Simple reference query
result = collection.query.bm25(
    query="search",
    return_references=QueryReference(
        link_on="hasAuthor",
        return_properties=["name", "email"]
    )
)

# Nested reference query (3 levels deep)
result = collection.query.bm25(
    query="search",
    return_references=QueryReference(
        link_on="hasAuthor",
        return_properties=["name"],
        return_metadata=MetadataQuery(creation_time=True),
        return_references=QueryReference(
            link_on="worksAt",
            return_properties=["company_name"],
            return_references=QueryReference(
                link_on="locatedIn",
                return_properties=["city", "country"]
            )
        )
    )
)

# Multi-target reference query
result = collection.query.fetch_objects(
    return_references=QueryReference.MultiTarget(
        link_on="relatedTo",
        target_collection="Category",
        return_properties=["name"],
        return_metadata=MetadataQuery(last_update_time=True)
    )
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.Reference do
  @moduledoc """
  Reference query configuration for retrieving cross-references.
  """

  defstruct [
    :link_on,
    :return_properties,
    :return_metadata,
    :return_references,
    :include_vector,
    :target_collection  # For multi-target only
  ]

  @type t :: %__MODULE__{
    link_on: String.t(),
    return_properties: [String.t()] | nil,
    return_metadata: metadata_query() | nil,
    return_references: t() | [t()] | nil,
    include_vector: boolean(),
    target_collection: String.t() | nil
  }

  @type metadata_query :: %{
    optional(:creation_time) => boolean(),
    optional(:last_update_time) => boolean(),
    optional(:distance) => boolean(),
    optional(:certainty) => boolean()
  }

  @doc """
  Create a reference query configuration.

  ## Examples

      # Simple reference
      ref = Reference.new("hasAuthor", return_properties: ["name"])

      # With metadata
      ref = Reference.new("hasAuthor",
        return_properties: ["name"],
        return_metadata: %{creation_time: true}
      )

      # Nested references
      ref = Reference.new("hasAuthor",
        return_properties: ["name"],
        return_references: Reference.new("worksAt", return_properties: ["company"])
      )
  """
  def new(link_on, opts \\ []) do
    %__MODULE__{
      link_on: link_on,
      return_properties: Keyword.get(opts, :return_properties),
      return_metadata: Keyword.get(opts, :return_metadata),
      return_references: Keyword.get(opts, :return_references),
      include_vector: Keyword.get(opts, :include_vector, false),
      target_collection: nil
    }
  end

  @doc """
  Create a multi-target reference query.
  """
  def multi_target(link_on, target_collection, opts \\ []) do
    %__MODULE__{
      link_on: link_on,
      target_collection: target_collection,
      return_properties: Keyword.get(opts, :return_properties),
      return_metadata: Keyword.get(opts, :return_metadata),
      return_references: Keyword.get(opts, :return_references),
      include_vector: Keyword.get(opts, :include_vector, false)
    }
  end

  @doc false
  def to_graphql(%__MODULE__{} = ref, indent \\ 2) do
    props = build_properties(ref.return_properties)
    meta = build_metadata(ref.return_metadata)
    nested = build_nested_refs(ref.return_references, indent + 2)

    """
    #{ref.link_on} {
    #{String.duplicate(" ", indent)}... on #{target_type(ref)} {
    #{String.duplicate(" ", indent + 2)}#{Enum.join(props, "\n" <> String.duplicate(" ", indent + 2))}
    #{meta}#{nested}
    #{String.duplicate(" ", indent)}}
    }
    """
  end

  defp target_type(%{target_collection: nil}), do: "_any_"
  defp target_type(%{target_collection: col}), do: col

  defp build_properties(nil), do: []
  defp build_properties(props), do: props

  defp build_metadata(nil), do: ""
  defp build_metadata(meta) do
    fields = meta
    |> Enum.filter(fn {_, v} -> v end)
    |> Enum.map(fn {k, _} -> to_camel_case(k) end)
    |> Enum.join(" ")

    if fields != "" do
      "_additional { #{fields} }"
    else
      ""
    end
  end

  defp build_nested_refs(nil, _), do: ""
  defp build_nested_refs(refs, indent) when is_list(refs) do
    Enum.map_join(refs, "\n", &to_graphql(&1, indent))
  end
  defp build_nested_refs(ref, indent), do: to_graphql(ref, indent)

  defp to_camel_case(atom) do
    atom
    |> Atom.to_string()
    |> Macro.camelize()
    |> String.replace_prefix(~r/^[A-Z]/, &String.downcase/1)
  end
end

# Query module integration
defmodule WeaviateEx.Query do
  alias WeaviateEx.Query.Reference

  def bm25(client, collection, query, opts \\ []) do
    return_refs = Keyword.get(opts, :return_references)

    ref_clause = case return_refs do
      nil -> ""
      %Reference{} = ref -> Reference.to_graphql(ref)
      refs when is_list(refs) -> Enum.map_join(refs, "\n", &Reference.to_graphql/1)
    end

    graphql_query = build_bm25_query(collection, query, ref_clause, opts)
    Client.request(client, :post, "/v1/graphql", %{"query" => graphql_query}, opts)
  end
end
```

### 4. Multimodal Generation (High)

**Python Implementation:**
```python
from weaviate.classes.generate import GenerativeParameters

# External images
result = collection.generate.near_text(
    query="describe this scene",
    single_prompt=GenerativeParameters.single_prompt(
        prompt="Describe what you see in detail",
        images=["/path/to/image.png", base64_encoded_image],
        metadata=True
    ),
    generative_provider=GenerativeConfig.anthropic()
)

# Image properties from objects
result = collection.generate.near_text(
    query="describe products",
    grouped_task=GenerativeParameters.grouped_task(
        prompt="Compare these products",
        image_properties=["product_image", "thumbnail"],
        non_blob_properties=["name", "description"],
        metadata=True
    ),
    generative_provider=GenerativeConfig.openai()
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Generative.Parameters do
  @moduledoc """
  Parameters for generative queries with multimodal support.
  """

  defmodule SinglePrompt do
    defstruct [
      :prompt,
      :images,
      :image_properties,
      :metadata,
      :debug
    ]

    @type t :: %__MODULE__{
      prompt: String.t(),
      images: [String.t()] | nil,  # paths or base64
      image_properties: [String.t()] | nil,
      metadata: boolean(),
      debug: boolean()
    }
  end

  defmodule GroupedTask do
    defstruct [
      :prompt,
      :images,
      :image_properties,
      :non_blob_properties,
      :metadata
    ]

    @type t :: %__MODULE__{
      prompt: String.t(),
      images: [String.t()] | nil,
      image_properties: [String.t()] | nil,
      non_blob_properties: [String.t()] | nil,
      metadata: boolean()
    }
  end

  @doc """
  Create a single prompt parameter object.
  """
  def single_prompt(prompt, opts \\ []) do
    images = opts
    |> Keyword.get(:images, [])
    |> Enum.map(&parse_image/1)

    %SinglePrompt{
      prompt: prompt,
      images: if(images == [], do: nil, else: images),
      image_properties: Keyword.get(opts, :image_properties),
      metadata: Keyword.get(opts, :metadata, false),
      debug: Keyword.get(opts, :debug, false)
    }
  end

  @doc """
  Create a grouped task parameter object.
  """
  def grouped_task(prompt, opts \\ []) do
    images = opts
    |> Keyword.get(:images, [])
    |> Enum.map(&parse_image/1)

    %GroupedTask{
      prompt: prompt,
      images: if(images == [], do: nil, else: images),
      image_properties: Keyword.get(opts, :image_properties),
      non_blob_properties: Keyword.get(opts, :non_blob_properties),
      metadata: Keyword.get(opts, :metadata, false)
    }
  end

  defp parse_image(path) when is_binary(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> Base.encode64()
    else
      # Assume it's already base64
      path
    end
  end
end
```

### 5. Generation Metadata and Debug (High)

**Python Implementation:**
```python
# Query with metadata
result = collection.generate.near_text(
    query="AI",
    single_prompt=GenerativeParameters.single_prompt(
        prompt="Summarize",
        metadata=True,
        debug=True
    ),
    generative_provider=GenerativeConfig.openai()
)

# Access results
for obj in result.objects:
    print(obj.generative.text)           # Generated text
    print(obj.generative.metadata)       # Provider-specific metadata
    print(obj.generative.debug)          # Debug info (full prompt)

# Grouped result
print(result.generative.text)            # Grouped generation
print(result.generative.metadata)        # Metadata for grouped
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Generative.Result do
  @moduledoc """
  Typed result structures for generative queries.
  """

  defmodule Single do
    @moduledoc "Result for single prompt generation"
    defstruct [:text, :metadata, :debug]

    @type t :: %__MODULE__{
      text: String.t() | nil,
      metadata: map() | nil,  # Provider-specific
      debug: debug_info() | nil
    }

    @type debug_info :: %{
      full_prompt: String.t()
    }
  end

  defmodule Grouped do
    @moduledoc "Result for grouped task generation"
    defstruct [:text, :metadata]

    @type t :: %__MODULE__{
      text: String.t() | nil,
      metadata: map() | nil
    }
  end

  defmodule GenerativeObject do
    @moduledoc "Object with generative result"
    defstruct [:uuid, :properties, :references, :vector, :collection, :generative]

    @type t :: %__MODULE__{
      uuid: String.t(),
      properties: map(),
      references: map() | nil,
      vector: map(),
      collection: String.t(),
      generative: Single.t() | nil
    }
  end

  defmodule GenerativeReturn do
    @moduledoc "Full return type for generative queries"
    defstruct [:objects, :generative]

    @type t :: %__MODULE__{
      objects: [GenerativeObject.t()],
      generative: Grouped.t() | nil
    }
  end
end

# Parsing the response
defmodule WeaviateEx.Generative.ResponseParser do
  alias WeaviateEx.Generative.Result

  def parse_generative_response(response) do
    objects = parse_objects(response)
    grouped = parse_grouped(response)

    %Result.GenerativeReturn{
      objects: objects,
      generative: grouped
    }
  end

  defp parse_objects(%{"data" => %{"Get" => get}}) do
    get
    |> Map.values()
    |> List.flatten()
    |> Enum.map(&parse_object/1)
  end

  defp parse_object(obj) do
    generative = get_in(obj, ["_additional", "generate"])

    %Result.GenerativeObject{
      uuid: get_in(obj, ["_additional", "id"]),
      properties: Map.drop(obj, ["_additional"]),
      generative: parse_single_result(generative)
    }
  end

  defp parse_single_result(nil), do: nil
  defp parse_single_result(%{"singleResult" => text} = gen) do
    %Result.Single{
      text: text,
      metadata: gen["metadata"],
      debug: parse_debug(gen["debug"])
    }
  end

  defp parse_debug(nil), do: nil
  defp parse_debug(%{"fullPrompt" => prompt}) do
    %{full_prompt: prompt}
  end
end
```

### 6. ReferenceToMulti Type (High)

**Python Implementation:**
```python
from weaviate.classes.data import ReferenceToMulti

# Create multi-target reference
ref = ReferenceToMulti(
    target_collection="Category",
    uuids=["uuid1", "uuid2"]
)

# Use in insert
collection.data.insert(
    properties={"title": "Article"},
    references={"categories": ref}
)

# Use in reference operations
collection.data.reference_add(
    from_uuid=article_uuid,
    from_property="categories",
    to=ReferenceToMulti(target_collection="Category", uuids=cat_uuid)
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Data.ReferenceToMulti do
  @moduledoc """
  Multi-target reference specification.

  Use this when you have a reference property that can point to
  multiple different collections (multi-target reference).
  """

  defstruct [:target_collection, :uuids]

  @type t :: %__MODULE__{
    target_collection: String.t(),
    uuids: String.t() | [String.t()]
  }

  @doc """
  Create a new multi-target reference.

  ## Examples

      ref = ReferenceToMulti.new("Category", "cat-uuid")
      ref = ReferenceToMulti.new("Category", ["uuid1", "uuid2"])
  """
  def new(target_collection, uuids) do
    %__MODULE__{
      target_collection: target_collection,
      uuids: uuids
    }
  end

  @doc """
  Convert to beacon format for API requests.
  """
  def to_beacons(%__MODULE__{target_collection: col, uuids: uuids}) do
    uuids
    |> List.wrap()
    |> Enum.map(fn uuid ->
      %{"beacon" => "weaviate://localhost/#{col}/#{uuid}"}
    end)
  end
end
```

---

## Priority Recommendations

### Critical (Must Have for Production)
1. **Reference CRUD Operations** - Without these, the client cannot manage relationships between objects
2. **Provider Configuration Classes** - Required for proper provider-specific parameter handling
3. **Reference Query Support** - Essential for retrieving related data
4. **Generation Return Types** - Needed for proper result handling

### High Priority
1. **Multimodal Support** - Vision models are increasingly important
2. **Generation Metadata** - Required for debugging and monitoring
3. **Nested Reference Queries** - Common requirement for complex data models
4. **ReferenceToMulti Type** - Required for multi-target reference properties
5. **Debug Mode** - Essential for development and troubleshooting

### Medium Priority
1. **Typed Prompt Objects** - Improves type safety and API clarity
2. **Query Integration** - Generate with all query types (BM25, hybrid, etc.)
3. **Non-blob Properties** - Control which properties are sent to LLM
4. **CrossReference Type** - TypedDict-style reference definitions

### Low Priority
1. **CrossReferenceAnnotation** - Advanced typing feature
2. **Dummy Provider** - Testing utility
3. **Deprecated Field Handling** - Backward compatibility

---

## Implementation Roadmap

### Phase 1: Critical (Estimated: 2-3 weeks)
- [ ] Implement `WeaviateEx.API.References` module
- [ ] Add reference support to `WeaviateEx.API.Data`
- [ ] Create typed provider configuration structs
- [ ] Implement `WeaviateEx.Query.Reference` for query support
- [ ] Add typed generation return structs

### Phase 2: High Priority (Estimated: 2 weeks)
- [ ] Add multimodal support (images)
- [ ] Implement generation metadata parsing
- [ ] Add nested reference query support
- [ ] Implement `ReferenceToMulti` type
- [ ] Add debug mode support

### Phase 3: Medium Priority (Estimated: 1-2 weeks)
- [ ] Create typed prompt objects (`SinglePrompt`, `GroupedTask`)
- [ ] Integrate generate with all query types
- [ ] Add non-blob properties support
- [ ] Implement `CrossReference` type helpers

### Phase 4: Low Priority (As needed)
- [ ] Add `CrossReferenceAnnotation` support
- [ ] Implement Dummy provider
- [ ] Add deprecation warnings for legacy fields

---

## Appendix: Full Provider Parameter Comparison

### OpenAI Parameters
| Parameter | Python | Elixir Current | Elixir Proposed |
|-----------|--------|----------------|-----------------|
| model | Yes | Yes | Yes |
| temperature | Yes | Yes | Yes |
| max_tokens | Yes | Yes | Yes |
| top_p | Yes | Yes | Yes |
| frequency_penalty | Yes | No | Yes |
| presence_penalty | Yes | No | Yes |
| stop | Yes | No | Yes |
| api_version | Yes | No | Yes |
| base_url | Yes | No | Yes |
| deployment_id | Yes | No | Yes |
| resource_name | Yes | No | Yes |
| is_azure | Yes | No | Yes |
| verbosity | Yes | Yes | Yes |
| reasoning_effort | Yes | Yes | Yes |

### Anthropic Parameters
| Parameter | Python | Elixir Current | Elixir Proposed |
|-----------|--------|----------------|-----------------|
| model | Yes | Yes | Yes |
| temperature | Yes | Yes | Yes |
| max_tokens | Yes | Yes | Yes |
| top_p | Yes | Yes | Yes |
| top_k | Yes | No | Yes |
| stop_sequences | Yes | No | Yes |
| base_url | Yes | No | Yes |

### Cohere Parameters
| Parameter | Python | Elixir Current | Elixir Proposed |
|-----------|--------|----------------|-----------------|
| model | Yes | Yes | Yes |
| temperature | Yes | Yes | Yes |
| max_tokens | Yes | Yes | Yes |
| k | Yes | No | Yes |
| p | Yes | No | Yes |
| presence_penalty | Yes | No | Yes |
| stop_sequences | Yes | No | Yes |
| base_url | Yes | No | Yes |

### AWS (Bedrock/SageMaker) Parameters
| Parameter | Python | Elixir Current | Elixir Proposed |
|-----------|--------|----------------|-----------------|
| model | Yes | Yes | Yes |
| temperature | Yes | Yes | Yes |
| max_tokens | Yes | Yes | Yes |
| region | Yes | No | Yes |
| endpoint | Yes | No | Yes |
| service | Yes | No | Yes |
| target_model | Yes | No | Yes |
| target_variant | Yes | No | Yes |
| top_k | Yes | No | Yes |
| top_p | Yes | No | Yes |
| stop_sequences | Yes | No | Yes |

### Google (Vertex/Gemini) Parameters
| Parameter | Python | Elixir Current | Elixir Proposed |
|-----------|--------|----------------|-----------------|
| model | Yes | Yes | Yes |
| temperature | Yes | Yes | Yes |
| max_tokens | Yes | Yes | Yes |
| top_p | Yes | Yes | Yes |
| top_k | Yes | No | Yes |
| api_endpoint | Yes | No | Yes |
| endpoint_id | Yes | No | Yes |
| frequency_penalty | Yes | No | Yes |
| presence_penalty | Yes | No | Yes |
| project_id | Yes | No | Yes |
| region | Yes | No | Yes |
| stop_sequences | Yes | No | Yes |

### Missing Providers in Elixir
- NVIDIA (`_GenerativeNvidia`)
- Databricks (`_GenerativeDatabricks`)
- FriendliAI (`_GenerativeFriendliai`)
- Dummy (`_GenerativeDummy`)

---

## Conclusion

The Elixir WeaviateEx client has a solid foundation for generative search but requires significant enhancements to achieve feature parity with the Python client. The most critical gaps are in cross-reference handling and typed provider configurations. The proposed implementations follow Elixir idioms while maintaining API compatibility with the Python client's design patterns.
