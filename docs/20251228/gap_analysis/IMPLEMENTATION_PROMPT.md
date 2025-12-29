# WeaviateEx Gap Implementation Agent Prompt

You are an expert Elixir developer tasked with implementing all missing features in the WeaviateEx client to achieve feature parity with the Python Weaviate client. You will use Test-Driven Development (TDD) throughout.

## Your Mission

Implement all gaps identified in the gap analysis documents using TDD. For each feature:
1. Write failing tests first
2. Implement the minimum code to pass tests
3. Refactor while keeping tests green

## Step 1: Read All Gap Analysis Documents

Read these documents thoroughly to understand ALL gaps that need implementation:

```
docs/20251228/gap_analysis/01_collections_schema.md
docs/20251228/gap_analysis/02_query_search.md
docs/20251228/gap_analysis/03_batch_operations.md
docs/20251228/gap_analysis/04_auth_connection.md
docs/20251228/gap_analysis/07_generative_references.md
docs/20251228/gap_analysis/08_vectors_datatypes.md
docs/20251228/gap_analysis/00_SUMMARY.md
```

## Step 2: Read Existing Elixir Source Files

Understand the current codebase structure:

```
lib/weaviate_ex.ex
lib/weaviate_ex/api/collections.ex
lib/weaviate_ex/api/batch.ex
lib/weaviate_ex/api/vector_config.ex
lib/weaviate_ex/api/generative.ex
lib/weaviate_ex/api/query_advanced.ex
lib/weaviate_ex/api/data.ex
lib/weaviate_ex/api/aggregate.ex
lib/weaviate_ex/api/tenants.ex
lib/weaviate_ex/batch.ex
lib/weaviate_ex/collections.ex
lib/weaviate_ex/query.ex
lib/weaviate_ex/filter.ex
lib/weaviate_ex/objects.ex
lib/weaviate_ex/health.ex
lib/weaviate_ex/error.ex
lib/weaviate_ex/protocol.ex
lib/weaviate_ex/embedded.ex
lib/weaviate_ex/application.ex
lib/weaviate_ex/client/config.ex
```

Also read existing tests to understand patterns:
```
test/weaviate_ex/query_test.exs
test/weaviate_ex/filter_test.exs
test/weaviate_ex/batch_test.exs
test/weaviate_ex/api/vector_config_test.exs
test/weaviate_ex/api/generative_test.exs
test/integration/batch_integration_test.exs
test/integration/query_integration_test.exs
test/support/mocks.ex
```

## Step 3: Implementation Order (TDD)

Implement in this order, using TDD for each module:

### Phase 1: Foundation Types & Config

#### 1.1 Data Types Module
**File**: `lib/weaviate_ex/types/data_type.ex`
**Test**: `test/weaviate_ex/types/data_type_test.exs`

Implement:
- DataType enum with all Weaviate types
- `to_string/1` and `from_string/1` conversions
- Type validation

#### 1.2 GeoCoordinate Type
**File**: `lib/weaviate_ex/types/geo_coordinate.ex`
**Test**: `test/weaviate_ex/types/geo_coordinate_test.exs`

Implement:
- Struct with latitude/longitude
- Validation (-90 to 90, -180 to 180)
- `new/2`, `new!/2`, `to_map/1`, `from_map/1`

#### 1.3 PhoneNumber Type
**File**: `lib/weaviate_ex/types/phone_number.ex`
**Test**: `test/weaviate_ex/types/phone_number_test.exs`

Implement:
- Input struct (number, default_country)
- Output struct (parsed fields)
- Conversion functions

#### 1.4 Blob Utilities
**File**: `lib/weaviate_ex/types/blob.ex`
**Test**: `test/weaviate_ex/types/blob_test.exs`

Implement:
- `encode/1`, `decode/1`
- `encode_file/1`, `encode_file!/1`
- `decode_to_file/2`

#### 1.5 UUID Utilities
**File**: `lib/weaviate_ex/types/uuid.ex`
**Test**: `test/weaviate_ex/types/uuid_test.exs`

Implement:
- `generate/0` (UUID v4)
- `validate/1`, `valid?/1`
- `from_string/2` (deterministic UUID v5)

### Phase 2: Authentication & Connection

#### 2.1 Auth Module
**File**: `lib/weaviate_ex/auth.ex`
**Test**: `test/weaviate_ex/auth_test.exs`

Implement:
- `api_key/1` - returns auth map
- `bearer_token/2` - with expires_in, refresh_token opts
- `client_credentials/2` - OIDC client credentials
- `client_password/3` - OIDC password flow

#### 2.2 Timeout Config
**File**: `lib/weaviate_ex/config/timeout.ex`
**Test**: `test/weaviate_ex/config/timeout_test.exs`

Implement:
- Struct with init (2s), query (30s), insert (90s)
- `new/1` with keyword opts
- `for_method/3` returns appropriate timeout

#### 2.3 Connection Config
**File**: `lib/weaviate_ex/config/connection.ex`
**Test**: `test/weaviate_ex/config/connection_test.exs`

Implement:
- Pool configuration struct
- `new/1`, `to_finch_pools/2`

#### 2.4 Proxy Config
**File**: `lib/weaviate_ex/config/proxies.ex`
**Test**: `test/weaviate_ex/config/proxies_test.exs`

Implement:
- Struct with http, https, grpc
- `new/1` (accepts string, keyword, or struct)
- `from_env/0` reads HTTP_PROXY, etc.

#### 2.5 Connect Factory
**File**: `lib/weaviate_ex/connect.ex`
**Test**: `test/weaviate_ex/connect_test.exs`

Implement:
- `to_weaviate_cloud/1`
- `to_local/1`
- `to_embedded/1`
- `to_custom/1`

#### 2.6 OIDC Token Manager
**File**: `lib/weaviate_ex/auth/oidc.ex`
**Test**: `test/weaviate_ex/auth/oidc_test.exs`

Implement:
- GenServer for token lifecycle
- `init_auth/2`, `get_access_token/0`
- Automatic token refresh before expiry
- Support for client_credentials and password flows

#### 2.7 Retry Module
**File**: `lib/weaviate_ex/retry.ex`
**Test**: `test/weaviate_ex/retry_test.exs`

Implement:
- `with_exponential_backoff/2`
- Configurable max_retries, base_delay, max_delay
- Retryable error detection

#### 2.8 Integrations (Headers)
**File**: `lib/weaviate_ex/integrations.ex`
**Test**: `test/weaviate_ex/integrations_test.exs`

Implement:
- `openai/1`, `cohere/1`, `huggingface/1`
- `voyageai/1`, `jinaai/1`, `mistral/1`
- `merge/1` to combine multiple configs

### Phase 3: Property & Schema Builders

#### 3.1 Property Builder
**File**: `lib/weaviate_ex/property.ex`
**Test**: `test/weaviate_ex/property_test.exs`

Implement:
- `new/3` with name, data_type, opts
- Convenience: `text/2`, `int/2`, `number/2`, `boolean/2`, `date/2`, `uuid/2`, `blob/2`, `geo_coordinates/2`, `phone_number/2`
- `object/3`, `object_array/3` with nested_properties
- `reference/3` for cross-references
- Tokenization support

#### 3.2 Named Vectors Builder
**File**: `lib/weaviate_ex/api/named_vectors.ex`
**Test**: `test/weaviate_ex/api/named_vectors_test.exs`

Implement:
- `self_provided/1`
- `text2vec_openai/1` with name, source_properties, model, dimensions
- `text2vec_cohere/1`, `text2vec_huggingface/1`
- All other vectorizers from gap analysis
- Proper vector_index_config integration

### Phase 4: Missing Vectorizers

#### 4.1 Add to VectorConfig
**File**: `lib/weaviate_ex/api/vector_config.ex` (extend existing)
**Test**: `test/weaviate_ex/api/vector_config_test.exs` (extend existing)

Add these vectorizers:
- `text2vec_ollama/1`
- `text2vec_mistral/1`
- `text2vec_nvidia/1`
- `text2vec_jinaai/1`
- `text2vec_weaviate/1`
- `text2vec_azure_openai/1`
- `text2vec_databricks/1`
- `multi2vec_google/1`
- `multi2vec_cohere/1`
- `multi2vec_jinaai/1`
- `multi2vec_voyageai/1`
- `multi2vec_nvidia/1`
- `multi2vec_aws/1`
- `img2vec_neural/1`
- `ref2vec_centroid/1`
- `text2colbert_jinaai/1`

#### 4.2 RQ Quantization
Add `rotational_quantization/1` to VectorConfig

#### 4.3 Vector Index Reconfigure
**File**: `lib/weaviate_ex/api/vector_config/reconfigure.ex`
**Test**: `test/weaviate_ex/api/vector_config/reconfigure_test.exs`

Implement:
- `hnsw/1` for HNSW updates
- `flat/1` for Flat updates
- `update_vector/1` for named vector updates

### Phase 5: Multi-Vector Support

#### 5.1 Multi-Vector Module
**File**: `lib/weaviate_ex/api/multi_vector.ex`
**Test**: `test/weaviate_ex/api/multi_vector_test.exs`

Implement:
- `muvera_encoding/1`
- `multi_vector_config/1`
- `self_provided/1`
- `text2colbert_jinaai/1`

### Phase 6: Query Enhancements

#### 6.1 Query Move
**File**: `lib/weaviate_ex/query/move.ex`
**Test**: `test/weaviate_ex/query/move_test.exs`

Implement:
- Struct with force, concepts, objects
- `to/2` builder function

#### 6.2 Query Rerank
**File**: `lib/weaviate_ex/query/rerank.ex`
**Test**: `test/weaviate_ex/query/rerank_test.exs`

Implement:
- Struct with prop, query
- `new/2` builder

#### 6.3 Target Vectors
**File**: `lib/weaviate_ex/query/target_vectors.ex`
**Test**: `test/weaviate_ex/query/target_vectors_test.exs`

Implement:
- `single/1`
- `sum/1`, `average/1`, `minimum/1`
- `manual_weights/1`, `relative_score/1`

#### 6.4 BM25 Operator
**File**: `lib/weaviate_ex/query/bm25_operator.ex`
**Test**: `test/weaviate_ex/query/bm25_operator_test.exs`

Implement:
- `or_/1` with minimum_match
- `and_/0`

#### 6.5 Hybrid Vector
**File**: `lib/weaviate_ex/query/hybrid_vector.ex`
**Test**: `test/weaviate_ex/query/hybrid_vector_test.exs`

Implement:
- `near_text/2` with move_to, move_away, certainty, distance
- `near_vector/2`

#### 6.6 Query Reference
**File**: `lib/weaviate_ex/query/reference.ex`
**Test**: `test/weaviate_ex/query/reference_test.exs`

Implement:
- Struct with link_on, return_properties, return_references, include_vector
- `new/2` with nested reference support

#### 6.7 Query Sort
**File**: `lib/weaviate_ex/query/sort.ex`
**Test**: `test/weaviate_ex/query/sort_test.exs`

Implement:
- `by_property/2`
- `by_creation_time/2`, `by_update_time/2`, `by_id/2`
- Chainable API

#### 6.8 Query GroupBy
**File**: `lib/weaviate_ex/query/group_by.ex`
**Test**: `test/weaviate_ex/query/group_by_test.exs`

Implement:
- Struct with prop, objects_per_group, number_of_groups
- `new/2` builder

#### 6.9 Query Metadata
**File**: `lib/weaviate_ex/query/metadata.ex`
**Test**: `test/weaviate_ex/query/metadata_test.exs`

Implement:
- `full/0` returns all metadata fields
- `select/1` for custom selection

#### 6.10 Extend Query Module
**File**: `lib/weaviate_ex/query.ex` (extend existing)
**Test**: `test/weaviate_ex/query_test.exs` (extend existing)

Add:
- `move_to/2`, `move_away/2` for near_text
- `rerank/2`
- `target_vector/2`
- `consistency_level/2`
- `tenant/2`
- `return_references/2`
- `sort/2`
- `auto_limit/2` (autocut)

#### 6.11 Filter Extensions
**File**: `lib/weaviate_ex/filter.ex` (extend existing)
**Test**: `test/weaviate_ex/filter_test.exs` (extend existing)

Add:
- `contains_none/2`
- `by_creation_time/2`
- `by_update_time/2`
- `by_ref_count/3`

### Phase 7: Iterator

#### 7.1 Collection Iterator
**File**: `lib/weaviate_ex/iterator.ex`
**Test**: `test/weaviate_ex/iterator_test.exs`

Implement:
- `new/3` with client, collection, opts
- `stream/1` returns Elixir Stream
- Support for include_vector, return_properties, batch_size, after cursor
- Cursor-based pagination internally

### Phase 8: Batch Operations

#### 8.1 Batch Error Tracking
**File**: `lib/weaviate_ex/batch/error_tracking.ex`
**Test**: `test/weaviate_ex/batch/error_tracking_test.exs`

Implement:
- `ErrorObject` struct (message, object, original_uuid, retry_count)
- `ErrorReference` struct (message, reference)
- `Results` struct with failed_objects, failed_references, successful_uuids
- Helper functions: `add_error/2`, `add_success/3`, `has_errors?/1`, `number_errors/1`

#### 8.2 Fixed-Size Batch
**File**: `lib/weaviate_ex/batch/fixed_size.ex`
**Test**: `test/weaviate_ex/batch/fixed_size_test.exs`

Implement:
- Struct with batch_size, concurrent_requests, objects_buffer, results
- `new/2`
- `add_object/4`
- `flush/1`
- Task.Supervisor for concurrent sends

#### 8.3 Rate-Limited Batch
**File**: `lib/weaviate_ex/batch/rate_limited.ex`
**Test**: `test/weaviate_ex/batch/rate_limited_test.exs`

Implement:
- GenServer with requests_per_minute control
- Sleep timing calculation
- Rate limit error detection and retry
- Re-queue failed objects

#### 8.4 Dynamic Batch
**File**: `lib/weaviate_ex/batch/dynamic.ex`
**Test**: `test/weaviate_ex/batch/dynamic_test.exs`

Implement:
- GenServer with auto-optimization
- Cluster stats monitoring via /nodes endpoint
- Recommended batch size adjustment (10-1000)
- Concurrent requests scaling (2-10)
- Background send process

#### 8.5 Batch Context
**File**: `lib/weaviate_ex/batch/context.ex`
**Test**: `test/weaviate_ex/batch/context_test.exs`

Implement:
- `with_batch/3` macro for context manager pattern
- `start/2`, `flush/1`, `shutdown/1`, `get_results/1`
- Support for :dynamic, :fixed_size, :rate_limit modes
- Automatic cleanup in try/after

#### 8.6 Batch Executor
**File**: `lib/weaviate_ex/batch/executor.ex`
**Test**: `test/weaviate_ex/batch/executor_test.exs`

Implement:
- `send_concurrent/2` with Task.async_stream
- Result merging
- Error isolation per batch

#### 8.7 Batch Retry
**File**: `lib/weaviate_ex/batch/retry.ex`
**Test**: `test/weaviate_ex/batch/retry_test.exs`

Implement:
- Rate limit pattern detection (OpenAI, Cohere patterns)
- `with_retry/2`
- `partition_rate_limited/1`
- Backoff sleep calculation

#### 8.8 Wait for Indexing
**File**: `lib/weaviate_ex/batch/indexing.ex`
**Test**: `test/weaviate_ex/batch/indexing_test.exs`

Implement:
- `wait_for_vector_indexing/2`
- Shard status checking via /v1/schema/{collection}/shards
- Retry with exponential backoff

### Phase 9: Tenant Extensions

#### 9.1 Extended Tenants Module
**File**: `lib/weaviate_ex/tenants.ex`
**Test**: `test/weaviate_ex/tenants_test.exs`

Implement:
- `update/4` for tenant status updates
- `activate/4`, `deactivate/4`, `offload/4`
- `exists?/3`
- `get_by_name/3`, `get_by_names/3`
- Activity status support (:active, :inactive, :offloaded)

### Phase 10: Reference Operations

#### 10.1 References Module
**File**: `lib/weaviate_ex/api/references.ex`
**Test**: `test/weaviate_ex/api/references_test.exs`

Implement:
- `add/5` - add reference from object to target
- `delete/5` - delete specific reference
- `replace/5` - replace all references on property
- `add_many/4` - batch add references
- Support for multi-target references

### Phase 11: Generative Enhancements

#### 11.1 Generative Configs
**File**: `lib/weaviate_ex/generative/config.ex`
**Test**: `test/weaviate_ex/generative/config_test.exs`

Implement typed configs for all 17+ providers:
- `openai/1`, `azure_openai/1`
- `cohere/1`, `anthropic/1`
- `aws_bedrock/1`, `aws_sagemaker/1`
- `google_vertex/1`, `google_gemini/1`
- `mistral/1`, `nvidia/1`, `ollama/1`
- `xai/1`, `contextualai/1`
- `databricks/1`, `friendliai/1`, `anyscale/1`
- `custom/1`

Each with proper parameter validation.

### Phase 12: Collection Handle (Optional Advanced)

#### 12.1 Collection Module
**File**: `lib/weaviate_ex/collection.ex`
**Test**: `test/weaviate_ex/collection_test.exs`

Implement:
- Struct with client, name, tenant
- `get/3` to get collection handle
- `with_tenant/2` to scope to tenant
- Delegate to Query, Data, Config sub-modules

## TDD Process for Each Feature

For EVERY feature above, follow this exact process:

### 1. Write the Test First
```elixir
# test/weaviate_ex/types/geo_coordinate_test.exs
defmodule WeaviateEx.Types.GeoCoordinateTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.GeoCoordinate

  describe "new/2" do
    test "creates valid coordinate" do
      assert {:ok, coord} = GeoCoordinate.new(52.3676, 4.9041)
      assert coord.latitude == 52.3676
      assert coord.longitude == 4.9041
    end

    test "rejects invalid latitude" do
      assert {:error, _} = GeoCoordinate.new(91.0, 0.0)
      assert {:error, _} = GeoCoordinate.new(-91.0, 0.0)
    end

    test "rejects invalid longitude" do
      assert {:error, _} = GeoCoordinate.new(0.0, 181.0)
      assert {:error, _} = GeoCoordinate.new(0.0, -181.0)
    end
  end

  describe "to_map/1" do
    test "converts to Weaviate API format" do
      {:ok, coord} = GeoCoordinate.new(52.3676, 4.9041)
      assert GeoCoordinate.to_map(coord) == %{
        "latitude" => 52.3676,
        "longitude" => 4.9041
      }
    end
  end
end
```

### 2. Run Test (Should Fail)
```bash
mix test test/weaviate_ex/types/geo_coordinate_test.exs
```

### 3. Write Minimum Implementation
```elixir
# lib/weaviate_ex/types/geo_coordinate.ex
defmodule WeaviateEx.Types.GeoCoordinate do
  defstruct [:latitude, :longitude]

  def new(lat, lon) when lat >= -90 and lat <= 90 and lon >= -180 and lon <= 180 do
    {:ok, %__MODULE__{latitude: lat, longitude: lon}}
  end
  def new(lat, _lon) when lat < -90 or lat > 90 do
    {:error, "Latitude must be between -90 and 90"}
  end
  def new(_lat, lon) do
    {:error, "Longitude must be between -180 and 180"}
  end

  def to_map(%__MODULE__{latitude: lat, longitude: lon}) do
    %{"latitude" => lat, "longitude" => lon}
  end
end
```

### 4. Run Test (Should Pass)
```bash
mix test test/weaviate_ex/types/geo_coordinate_test.exs
```

### 5. Refactor if Needed
Keep tests green while improving code quality.

### 6. Run Full Test Suite
```bash
mix test
```

## Integration Tests

For features that interact with Weaviate, create integration tests:

```elixir
# test/integration/batch_context_test.exs
defmodule WeaviateEx.Integration.BatchContextTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  import WeaviateEx.Batch.Context

  setup do
    # Setup test collection
    {:ok, _} = WeaviateEx.Collections.create(client(), "TestBatch", %{...})
    on_exit(fn -> WeaviateEx.Collections.delete(client(), "TestBatch") end)
    :ok
  end

  test "with_batch dynamic mode inserts objects" do
    results = with_batch :dynamic, connection: client() do
      batch |> add_object("TestBatch", %{title: "Test 1"})
      batch |> add_object("TestBatch", %{title: "Test 2"})
    end

    assert length(results.successful_uuids) == 2
    assert results.failed_objects == []
  end
end
```

## Dialyzer & Type Specs

Add @spec and @type annotations to all public functions:

```elixir
@type t :: %__MODULE__{
  latitude: float(),
  longitude: float()
}

@spec new(float(), float()) :: {:ok, t()} | {:error, String.t()}
def new(lat, lon) do
  # ...
end
```

Run dialyzer after implementation:
```bash
mix dialyzer
```

## Documentation

Add @moduledoc and @doc to all modules and public functions:

```elixir
@moduledoc """
Represents a geographic coordinate (latitude/longitude).

## Example

    {:ok, coord} = GeoCoordinate.new(52.3676, 4.9041)
    GeoCoordinate.to_map(coord)
    # => %{"latitude" => 52.3676, "longitude" => 4.9041}
"""

@doc """
Create a new GeoCoordinate.

## Parameters
  - `latitude` - Latitude value (-90 to 90)
  - `longitude` - Longitude value (-180 to 180)

## Examples

    iex> GeoCoordinate.new(52.3676, 4.9041)
    {:ok, %GeoCoordinate{latitude: 52.3676, longitude: 4.9041}}

    iex> GeoCoordinate.new(91.0, 0.0)
    {:error, "Latitude must be between -90 and 90"}
"""
```

## Final Checklist

After implementing all features, verify:

- [ ] All tests pass: `mix test`
- [ ] No dialyzer warnings: `mix dialyzer`
- [ ] Code formatted: `mix format`
- [ ] Documentation complete: `mix docs`
- [ ] No compiler warnings: `mix compile --warnings-as-errors`

## Notes

- Prefer structs over maps for type safety
- Use GenServer for stateful processes (OIDC, Dynamic Batch)
- Use Task.Supervisor for concurrent operations
- Follow existing code patterns in the codebase
- Keep functions small and focused
- Use pattern matching extensively
- Leverage Elixir's Stream for lazy iteration
