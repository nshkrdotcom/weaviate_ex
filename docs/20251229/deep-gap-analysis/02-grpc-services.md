# Deep Gap Analysis: gRPC Services Implementation

## Executive Summary

This document provides a detailed gap analysis comparing the gRPC implementation between the canonical Python Weaviate client (`weaviate-python-client`) and the Elixir port (`weaviate_ex`). The analysis focuses on channel management, service implementations, proto message handling, streaming support, error handling, retry logic, and connection pooling.

**Overall Assessment:** The Elixir implementation has achieved approximately 85% feature parity for core gRPC services, with significant improvements including a proper retry module. Key remaining gaps include connection pooling, advanced authentication token refresh, and some search query options.

---

## 1. gRPC Channel Management and Connection Handling

### 1.1 Python Implementation

**Files:**
- `/weaviate-python-client/weaviate/connect/v4.py` - Main connection class
- `/weaviate-python-client/weaviate/connect/base.py` - Connection parameters

#### Channel Creation

```python
# From base.py lines 107-137
def _grpc_channel(
    self, proxies: Dict[str, str], grpc_msg_size: Optional[int], is_async: bool
) -> Union[AsyncChannel, SyncChannel]:
    if grpc_msg_size is None:
        grpc_msg_size = MAX_GRPC_MESSAGE_LENGTH
    opts = [
        ("grpc.max_send_message_length", grpc_msg_size),
        ("grpc.max_receive_message_length", grpc_msg_size),
        ("grpc.default_authority", self.grpc.host),
    ]

    if (p := proxies.get("grpc")) is not None:
        options: list = [*opts, ("grpc.http_proxy", p)]
    else:
        options = opts

    if is_async:
        mod = grpc.aio
    else:
        mod = grpc
    if self.grpc.secure:
        return mod.secure_channel(
            target=self._grpc_target,
            credentials=ssl_channel_credentials(),
            options=options,
        )
    else:
        return mod.insecure_channel(target=self._grpc_target, options=options)
```

**Key Features:**
| Feature | Implementation Details |
|---------|----------------------|
| Sync/Async Support | Both `grpc.Channel` and `grpc.aio.Channel` |
| Max Message Size | 104,858,000 bytes (100MB), configurable from server meta |
| TLS/SSL | `ssl_channel_credentials()` for secure connections |
| Proxy Support | `grpc.http_proxy` option for gRPC proxy |
| Authority Header | `grpc.default_authority` set to hostname |
| Channel Options | Full gRPC options support |

### 1.2 Elixir Implementation

**File:** `/lib/weaviate_ex/grpc/channel.ex`

```elixir
# From channel.ex lines 49-72
@spec connect(config(), keyword()) :: {:ok, GRPC.Channel.t()} | {:error, Error.t()}
def connect(config, opts \\ []) do
  timeout = Keyword.get(opts, :timeout, @default_timeout)
  tls = Map.get(config, :tls, false)
  max_message_size = Map.get(config, :max_message_size, @default_max_message_size)

  host = "#{config.grpc_host}:#{config.grpc_port}"

  channel_opts = build_channel_opts(tls, max_message_size, timeout)

  case GRPC.Stub.connect(host, channel_opts) do
    {:ok, channel} ->
      {:ok, channel}
    {:error, reason} ->
      {:error, connection_error(reason)}
  end
end
```

**Key Features:**
| Feature | Implementation Details |
|---------|----------------------|
| Async Model | Gun adapter (HTTP/2 async by default) |
| Max Message Size | 104,858,000 bytes (100MB) - defined but NOT passed to options |
| TLS/SSL | `GRPC.Credential.new(ssl: [])` for secure connections |
| Proxy Support | **NOT IMPLEMENTED** |
| Authority Header | **NOT IMPLEMENTED** |
| Channel Options | Limited to adapter transport timeout |

### 1.3 Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| Secure Channel | Yes | Yes | COMPLETE | - |
| Insecure Channel | Yes | Yes | COMPLETE | - |
| Max Message Size Config | Yes (applied) | Yes (stored but not applied) | **GAP** | High |
| Proxy Support | Yes | No | **MISSING** | High |
| Authority Header | Yes | No | **MISSING** | Medium |
| Sync/Async Mode | Both | Async only | PARTIAL | Low |
| Connection Health Check | Yes (`connected?`) | Yes | COMPLETE | - |
| Connection Cleanup | Yes (`close()`) | Yes (`disconnect/1`) | COMPLETE | - |

### 1.4 Specific Gap: Max Message Size Not Applied

**Python:** Applies message size to channel options
**Elixir:** Stores value but does not pass to gRPC options

```elixir
# Current code (channel.ex line 159-181)
defp build_channel_opts(tls, _max_message_size, timeout) do  # <-- max_message_size unused!
  base_opts = [
    adapter: GRPC.Client.Adapters.Gun,
    adapter_opts: %{
      transport_opts: %{
        timeout: timeout
      }
    }
  ]
  # ...
end
```

---

## 2. Service Definitions Comparison

### 2.1 Python Service Definition

**File:** `/weaviate-python-client/weaviate/proto/v1/v6300/v1/weaviate_pb2_grpc.py`

```python
class WeaviateStub(object):
    def __init__(self, channel):
        self.Search = channel.unary_unary('/weaviate.v1.Weaviate/Search', ...)
        self.BatchObjects = channel.unary_unary('/weaviate.v1.Weaviate/BatchObjects', ...)
        self.BatchReferences = channel.unary_unary('/weaviate.v1.Weaviate/BatchReferences', ...)
        self.BatchDelete = channel.unary_unary('/weaviate.v1.Weaviate/BatchDelete', ...)
        self.TenantsGet = channel.unary_unary('/weaviate.v1.Weaviate/TenantsGet', ...)
        self.Aggregate = channel.unary_unary('/weaviate.v1.Weaviate/Aggregate', ...)
        self.BatchStream = channel.stream_stream('/weaviate.v1.Weaviate/BatchStream', ...)
```

### 2.2 Elixir Service Definition

**File:** `/lib/weaviate_ex/grpc/generated/v1/weaviate.pb.ex`

```elixir
defmodule Weaviate.V1.Weaviate.Service do
  use GRPC.Service, name: "weaviate.v1.Weaviate", protoc_gen_elixir_version: "0.15.0"

  rpc(:Search, Weaviate.V1.SearchRequest, Weaviate.V1.SearchReply)
  rpc(:BatchObjects, Weaviate.V1.BatchObjectsRequest, Weaviate.V1.BatchObjectsReply)
  rpc(:BatchReferences, Weaviate.V1.BatchReferencesRequest, Weaviate.V1.BatchReferencesReply)
  rpc(:BatchDelete, Weaviate.V1.BatchDeleteRequest, Weaviate.V1.BatchDeleteReply)
  rpc(:TenantsGet, Weaviate.V1.TenantsGetRequest, Weaviate.V1.TenantsGetReply)
  rpc(:Aggregate, Weaviate.V1.AggregateRequest, Weaviate.V1.AggregateReply)
  rpc(:BatchStream, stream(Weaviate.V1.BatchStreamRequest), stream(Weaviate.V1.BatchStreamReply))
end
```

### 2.3 Service Parity

| Service | Python | Elixir | Implementation File |
|---------|--------|--------|---------------------|
| Search | Yes | Yes | `services/search.ex` |
| BatchObjects | Yes | Yes | `services/batch.ex` |
| BatchReferences | Yes | Yes | `services/batch.ex` |
| BatchDelete | Yes | Yes | `services/batch.ex` |
| TenantsGet | Yes | Yes | `services/tenants.ex` |
| Aggregate | Yes | Yes | `services/aggregate.ex` |
| BatchStream | Yes | Yes | `services/batch_stream.ex` |

**Status:** COMPLETE - All 7 gRPC service methods are defined in both implementations.

---

## 3. Search Service Deep Dive

### 3.1 Python Query Building

**File:** `/weaviate-python-client/weaviate/collections/grpc/query.py`

The Python `_QueryGRPC` class (lines 76-600) provides comprehensive search request building:

```python
def __create_request(
    self,
    limit: Optional[int] = None,
    offset: Optional[int] = None,
    after: Optional[UUID] = None,
    filters: Optional[_Filters] = None,
    metadata: Optional[_MetadataQuery] = None,
    return_properties: Union[PROPERTIES, bool, None] = None,
    return_references: Optional[REFERENCES] = None,
    generative: Optional[_Generative] = None,
    rerank: Optional[Rerank] = None,
    autocut: Optional[int] = None,
    group_by: Optional[_GroupBy] = None,
    near_vector: Optional[base_search_pb2.NearVector] = None,
    sort_by: Optional[Sequence[search_get_pb2.SortBy]] = None,
    hybrid_search: Optional[base_search_pb2.Hybrid] = None,
    bm25: Optional[base_search_pb2.BM25] = None,
    near_object: Optional[base_search_pb2.NearObject] = None,
    near_text: Optional[base_search_pb2.NearTextSearch] = None,
    near_audio: Optional[base_search_pb2.NearAudioSearch] = None,
    near_depth: Optional[base_search_pb2.NearDepthSearch] = None,
    near_image: Optional[base_search_pb2.NearImageSearch] = None,
    near_imu: Optional[base_search_pb2.NearIMUSearch] = None,
    near_thermal: Optional[base_search_pb2.NearThermalSearch] = None,
    near_video: Optional[base_search_pb2.NearVideoSearch] = None,
) -> search_get_pb2.SearchRequest:
```

### 3.2 Elixir Search Implementation

**File:** `/lib/weaviate_ex/grpc/services/search.ex`

```elixir
defp build_search_request(collection, opts) do
  %SearchRequest{
    collection: collection,
    tenant: Keyword.get(opts, :tenant, ""),
    limit: Keyword.get(opts, :limit, 10),
    offset: Keyword.get(opts, :offset, 0),
    autocut: Keyword.get(opts, :autocut, 0),
    properties: build_properties_request(opts),
    metadata: build_metadata_request(opts),
    uses_127_api: true
  }
end
```

### 3.3 Search Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| near_vector | Yes | Yes | COMPLETE |
| near_text | Yes | Yes | COMPLETE |
| near_object | Yes | Yes | COMPLETE |
| bm25 | Yes | Yes | COMPLETE |
| hybrid | Yes | Yes | COMPLETE |
| near_image | Yes | Partial (proto only) | **GAP** - No high-level function |
| near_audio | Yes | Partial (proto only) | **GAP** - No high-level function |
| near_video | Yes | Partial (proto only) | **GAP** - No high-level function |
| near_depth | Yes | Partial (proto only) | **GAP** - No high-level function |
| near_thermal | Yes | Partial (proto only) | **GAP** - No high-level function |
| near_imu | Yes | Partial (proto only) | **GAP** - No high-level function |
| filters | Yes | Yes | COMPLETE |
| sort_by | Yes | Partial | **GAP** - Not exposed in high-level API |
| group_by | Yes | Partial | **GAP** - Not exposed in high-level API |
| generative | Yes | Yes | COMPLETE |
| rerank | Yes | Partial | **GAP** - Not exposed in high-level API |
| autocut | Yes | Yes | COMPLETE |
| after (cursor) | Yes | No | **MISSING** |
| consistency_level | Yes | Partial | **GAP** - Only for batch |
| target_vectors | Yes | No | **MISSING** - Named vector targeting |
| uses_125_api | Yes | No | **MISSING** |
| uses_127_api | Yes | Yes | COMPLETE |

### 3.4 Specific Gap: Multi-Modal Search Methods

**Python:** Has dedicated methods for each media type
```python
def near_media(self, *, media: str, type_: Literal["audio", "depth", "image", ...], ...):
```

**Elixir:** Only has proto definitions, no high-level wrapper functions.

---

## 4. Batch Service Deep Dive

### 4.1 Python Batch Implementation

**Files:**
- `/weaviate-python-client/weaviate/collections/batch/grpc_batch.py` - Batch objects
- `/weaviate-python-client/weaviate/collections/batch/grpc_batch_delete.py` - Batch delete

```python
# From grpc_batch.py lines 100-171
def objects(
    self,
    connection: Connection,
    *,
    objects: List[_BatchObject],
    timeout: Union[int, float],
    max_retries: float,
) -> executor.Result[BatchObjectReturn]:
    weaviate_objs = self.grpc_objects(objects)
    request = batch_pb2.BatchObjectsRequest(
        objects=weaviate_objs,
        consistency_level=self._consistency_level,
    )
    return executor.execute(
        response_callback=resp,
        method=connection.grpc_batch_objects,
        request=request,
        timeout=timeout,
        max_retries=max_retries,
    )
```

### 4.2 Elixir Batch Implementation

**File:** `/lib/weaviate_ex/grpc/services/batch.ex`

```elixir
# From batch.ex lines 78-87
def insert_objects(channel, objects, opts \\ []) when is_list(objects) do
  batch_objects = Enum.map(objects, &build_batch_object/1)

  request = %BatchObjectsRequest{
    objects: batch_objects,
    consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level))
  }

  execute_batch_objects(channel, request, opts)
end
```

### 4.3 Batch Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| insert_objects | Yes | Yes | COMPLETE |
| insert_references | Yes | Yes | COMPLETE |
| delete_objects | Yes | Yes | COMPLETE |
| consistency_level | Yes | Yes | COMPLETE |
| vector_bytes | Yes | Yes | COMPLETE |
| named_vectors | Yes | Yes | COMPLETE |
| max_retries | Yes | No | **GAP** - Uses generic retry module |
| timeout | Yes | Yes | COMPLETE |
| property serialization | Yes | Yes | COMPLETE |
| multi_target_refs | Yes | Yes | COMPLETE |
| single_target_refs | Yes | Yes | COMPLETE |
| number_array_properties | Yes | Yes (proto) | PARTIAL |
| text_array_properties | Yes | Yes (proto) | PARTIAL |
| object_properties | Yes | Yes (proto) | PARTIAL |
| empty_list_props | Yes | Yes (proto) | PARTIAL |

### 4.4 Batch Delete Comparison

**Python:** `/weaviate-python-client/weaviate/collections/batch/grpc_batch_delete.py`

```python
def batch_delete(
    self,
    connection: Connection,
    *,
    name: str,
    filters: _Filters,
    verbose: bool,
    dry_run: bool,
    tenant: Optional[str],
) -> executor.Result[...]:
```

**Elixir:** `/lib/weaviate_ex/grpc/services/batch.ex`

```elixir
def delete_objects(channel, collection, filter, opts \\ []) do
  request = %BatchDeleteRequest{
    collection: collection,
    filters: build_filter(filter),
    consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level)),
    tenant: Keyword.get(opts, :tenant, ""),
    verbose: Keyword.get(opts, :verbose, false),
    dry_run: Keyword.get(opts, :dry_run, false)
  }
end
```

**Status:** COMPLETE - Full parity on batch delete functionality.

---

## 5. Aggregate Service Deep Dive

### 5.1 Python Aggregate Implementation

**File:** `/weaviate-python-client/weaviate/collections/grpc/aggregate.py`

```python
class _AggregateGRPC(_BaseGRPC):
    def objects_count(self, connection: Connection) -> executor.Result[int]:
        ...
    def hybrid(self, *, query, alpha, vector, properties, ...):
        ...
    def near_media(self, *, media, type_, certainty, distance, ...):
        ...
    def near_object(self, *, near_object, certainty, distance, ...):
        ...
    def near_text(self, *, near_text, certainty, distance, ...):
        ...
    def near_vector(self, *, near_vector, certainty, distance, ...):
        ...
    def over_all(self, *, aggregations, filters, group_by, limit, ...):
        ...
```

### 5.2 Elixir Aggregate Implementation

**File:** `/lib/weaviate_ex/grpc/services/aggregate.ex`

```elixir
defmodule WeaviateEx.GRPC.Services.Aggregate do
  def count(channel, collection, opts \\ [])
  def over_property(channel, collection, property, opts \\ [])
  def group_by(channel, collection, property, opts \\ [])
  def execute(channel, %AggregateRequest{} = request, opts \\ [])
end
```

### 5.3 Aggregate Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| objects_count | Yes | Yes (`count/3`) | COMPLETE |
| hybrid | Yes | Partial | **GAP** - via request struct only |
| near_media | Yes | Partial | **GAP** - via request struct only |
| near_object | Yes | Partial (opts) | PARTIAL |
| near_text | Yes | Partial (opts) | PARTIAL |
| near_vector | Yes | Partial (opts) | PARTIAL |
| over_all | Yes | Yes (`over_property/4`) | COMPLETE |
| group_by | Yes | Yes | COMPLETE |
| number aggregations | Yes | Yes | COMPLETE |
| integer aggregations | Yes | Yes | COMPLETE |
| text aggregations | Yes | Yes | COMPLETE |
| boolean aggregations | Yes | Yes | COMPLETE |
| date aggregations | Yes | Yes | COMPLETE |
| filters | Yes | Yes | COMPLETE |
| object_limit | Yes | Partial | **GAP** |

---

## 6. Tenants Service Deep Dive

### 6.1 Python Tenants Implementation

**File:** `/weaviate-python-client/weaviate/collections/grpc/tenants.py`

```python
class _TenantsGRPC(_BaseGRPC):
    def get(self, names: Optional[Sequence[str]]) -> tenants_pb2.TenantsGetRequest:
        return tenants_pb2.TenantsGetRequest(
            collection=self._name,
            names=tenants_pb2.TenantNames(values=names) if names is not None else None,
        )

    def map_activity_status(self, status: tenants_pb2.TenantActivityStatus) -> TenantActivityStatus:
        # Maps proto status to Python enum
```

### 6.2 Elixir Tenants Implementation

**File:** `/lib/weaviate_ex/grpc/services/tenants.ex`

```elixir
defmodule WeaviateEx.GRPC.Services.Tenants do
  def list(channel, collection, opts \\ [])
  def get(channel, collection, tenant_names, opts \\ [])
  def exists?(channel, collection, tenant_name, opts \\ [])
  def parse_status(status)  # Maps proto status to atoms
end
```

### 6.3 Tenants Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| list all tenants | Yes | Yes | COMPLETE |
| get by name | Yes | Yes | COMPLETE |
| exists check | No | Yes | **BETTER** |
| activity status parsing | Yes | Yes | COMPLETE |
| HOT status | Yes | Yes (`:hot`) | COMPLETE |
| COLD status | Yes | Yes (`:cold`) | COMPLETE |
| WARM status | Yes | Yes (`:warm`) | COMPLETE |
| FROZEN status | Yes | Yes (`:frozen`) | COMPLETE |
| OFFLOADED status | Yes | Yes (`:offloaded`) | COMPLETE |
| OFFLOADING status | Yes | Yes (`:offloading`) | COMPLETE |
| ONLOADING status | Yes | Yes (`:onloading`) | COMPLETE |

---

## 7. Health Service Deep Dive

### 7.1 Python Health Implementation

**File:** `/weaviate-python-client/weaviate/connect/v4.py` (lines 294-334)

```python
def _ping_grpc(self, colour: executor.Colour) -> Union[None, Awaitable[None]]:
    res = self._grpc_channel.unary_unary(
        "/grpc.health.v1.Health/Check",
        request_serializer=health_weaviate_pb2.WeaviateHealthCheckRequest.SerializeToString,
        response_deserializer=health_weaviate_pb2.WeaviateHealthCheckResponse.FromString,
    )(health_weaviate_pb2.WeaviateHealthCheckRequest(), timeout=self.timeout_config.init)
```

### 7.2 Elixir Health Implementation

**File:** `/lib/weaviate_ex/grpc/services/health.ex`

```elixir
defmodule WeaviateEx.GRPC.Services.Health do
  def ping(channel, opts \\ [])
  def check(channel, opts \\ [])
  def healthy?(channel, opts \\ [])
  def wait_for_ready(channel, opts \\ [])  # Polling with configurable interval
end
```

### 7.3 Health Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| health check | Yes | Yes | COMPLETE |
| SERVING status | Yes | Yes | COMPLETE |
| NOT_SERVING status | Yes | Yes | COMPLETE |
| UNKNOWN status | Yes | Yes | COMPLETE |
| ping shorthand | No | Yes | **BETTER** |
| healthy? boolean | No | Yes | **BETTER** |
| wait_for_ready | Yes (polling) | Yes (polling) | COMPLETE |
| init timeout | Yes | Yes | COMPLETE |

---

## 8. Streaming Support (BatchStream)

### 8.1 Python Streaming Implementation

**File:** `/weaviate-python-client/weaviate/connect/v4.py` (lines 1000-1016)

```python
def grpc_batch_stream(
    self,
    requests: Generator[batch_pb2.BatchStreamRequest, None, None],
) -> Generator[batch_pb2.BatchStreamReply, None, None]:
    for msg in self.grpc_stub.BatchStream(
        request_iterator=requests, metadata=self.grpc_headers()
    ):
        yield msg
```

### 8.2 Elixir Streaming Implementation

**File:** `/lib/weaviate_ex/grpc/services/batch_stream.ex`

```elixir
defmodule WeaviateEx.GRPC.Services.BatchStream do
  def open(channel, opts \\ [])
  def send_objects(stream, objects)
  def send_references(stream, references)
  def receive_results(stream, timeout \\ 30_000)
  def close(stream)
  def start_message(opts \\ [])
  def stop_message()
  def data_message(objects, references)
  def build_batch_object(obj)
  def build_batch_reference(ref)
  def parse_reply(reply)
  def consistency_level_to_proto(level)
end
```

### 8.3 Streaming Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Bidirectional stream | Yes | Yes | COMPLETE |
| Start message | Yes | Yes | COMPLETE |
| Stop message | Yes | Yes | COMPLETE |
| Data message (objects) | Yes | Yes | COMPLETE |
| Data message (refs) | Yes | Yes | COMPLETE |
| Results parsing | Yes | Yes | COMPLETE |
| Backoff handling | Yes | Yes | COMPLETE |
| Acks handling | Yes | Yes | COMPLETE |
| Shutdown handling | Yes | Yes | COMPLETE |
| Named vectors | Yes | Yes | COMPLETE |
| Error detail parsing | Yes | Yes | COMPLETE |
| Success detail parsing | Yes | Yes | COMPLETE |

---

## 9. Error Handling and Retry Logic

### 9.1 Python Retry Implementation

**File:** `/weaviate-python-client/weaviate/retry.py`

```python
class _Retry:
    def __init__(self, n: float = 4) -> None:
        self.n = n

    async def awith_exponential_backoff(
        self, count: int, error: str, f: Callable[P, Awaitable[T]], *args, **kwargs
    ) -> T:
        try:
            return await f(*args, **kwargs)
        except AioRpcError as e:
            if e.code() != StatusCode.UNAVAILABLE:
                raise e
            await asyncio.sleep(2**count)
            if count > self.n:
                raise WeaviateRetryError(str(e), count) from e
            return await self.awith_exponential_backoff(count + 1, error, f, *args, **kwargs)

    def with_exponential_backoff(self, count, error, f, *args, **kwargs) -> T:
        # Sync version with time.sleep
```

**Python Retry Details:**
- Default max retries: 4
- Retryable status code: `UNAVAILABLE` only
- Backoff formula: `2^count` seconds
- Both sync and async variants

### 9.2 Elixir Retry Implementation

**File:** `/lib/weaviate_ex/grpc/retry.ex`

```elixir
defmodule WeaviateEx.GRPC.Retry do
  @default_max_retries 4
  @default_base_delay_ms 1000
  @max_backoff_ms 32_000

  # Retryable status codes
  @unavailable 14
  @resource_exhausted 8
  @aborted 10
  @deadline_exceeded 4

  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    do_retry(fun, 0, max_retries, base_delay_ms)
  end

  def calculate_backoff(attempt) when is_integer(attempt) and attempt >= 0 do
    delay = :math.pow(2, attempt) * 1000
    min(trunc(delay), @max_backoff_ms)
  end

  def retryable?(%GRPC.RPCError{status: status}), do: retryable_status?(status)

  def retryable_status?(status) when is_integer(status) do
    status in [@unavailable, @resource_exhausted, @aborted, @deadline_exceeded]
  end
end
```

### 9.3 Retry Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Exponential backoff | Yes | Yes | COMPLETE |
| Max retries config | Yes (4) | Yes (4) | COMPLETE |
| UNAVAILABLE retry | Yes | Yes | COMPLETE |
| RESOURCE_EXHAUSTED retry | No | Yes | **BETTER** |
| ABORTED retry | No | Yes | **BETTER** |
| DEADLINE_EXCEEDED retry | No | Yes | **BETTER** |
| Backoff cap | No | Yes (32s) | **BETTER** |
| Configurable base delay | No | Yes | **BETTER** |
| Async variant | Yes | N/A (inherent) | N/A |
| Error exhausted | Yes | Yes | COMPLETE |

**Elixir Advantage:** Broader retry coverage with more retryable status codes and backoff cap.

### 9.4 Service Integration

| Service | Uses Retry | Python | Elixir |
|---------|------------|--------|--------|
| Search | Yes | Yes | Yes |
| BatchObjects | Yes | Yes | Yes |
| BatchDelete | No | No | Yes |
| TenantsGet | Yes | Yes | Yes |
| Aggregate | Yes | Yes | Yes |
| Health | Reduced | Yes (2 retries) | Yes (2 retries) |

---

## 10. Connection Pooling and Keepalive

### 10.1 Python Connection Pooling

**File:** `/weaviate-python-client/weaviate/config.py`

```python
@dataclass
class ConnectionConfig:
    session_pool_connections: int = 20
    session_pool_maxsize: int = 100
    session_pool_max_retries: int = 3
    session_pool_timeout: int = 5
```

**Python Pooling Features:**
- HTTP connection pool via httpx `Limits`
- Configurable pool size and connections
- Max keepalive connections
- Pool timeout configuration
- Used for REST endpoints (gRPC uses single channel)

### 10.2 Elixir Connection Pooling

**Current Implementation:** No connection pooling.

Each `WeaviateEx.GRPC.Channel.connect/2` creates a single gRPC connection.

### 10.3 Pooling Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| HTTP connection pool | Yes | No | **MISSING** |
| Pool size config | Yes | No | **MISSING** |
| Max connections | Yes | No | **MISSING** |
| Pool timeout | Yes | No | **MISSING** |
| Keepalive connections | Yes | No | **MISSING** |
| gRPC pooling | No (single) | No (single) | N/A |

**Note:** gRPC multiplexes requests over a single connection, so gRPC pooling is less critical than HTTP pooling.

---

## 11. Metadata and Header Handling

### 11.1 Python Metadata Handling

**File:** `/weaviate-python-client/weaviate/connect/v4.py` (lines 256-292)

```python
def _prepare_grpc_headers(self) -> None:
    self.__metadata_list: List[Tuple[str, str]] = []
    if len(self.additional_headers):
        for key, val in self.additional_headers.items():
            if val is not None:
                self.__metadata_list.append((key.lower(), val))

    if self._auth is not None:
        if "X-Weaviate-Cluster-URL" in self._headers:
            self.__metadata_list.append(
                ("x-weaviate-cluster-url", self._headers["X-Weaviate-Cluster-URL"])
            )
        if isinstance(self._auth, AuthApiKey):
            self.__metadata_list.append(("authorization", "Bearer " + self._auth.api_key))
        else:
            self.__metadata_list.append(
                ("authorization", "dummy_will_be_refreshed_for_each_call")
            )
```

### 11.2 Elixir Metadata Handling

**File:** `/lib/weaviate_ex/grpc/channel.ex` (lines 129-148)

```elixir
def build_metadata(config) when is_map(config) do
  auth_metadata =
    case Map.get(config, :api_key) do
      nil -> %{}
      "" -> %{}
      api_key -> %{"authorization" => "Bearer #{api_key}"}
    end

  additional_metadata =
    config
    |> Map.get(:additional_headers, %{})
    |> lowercase_header_keys()

  Map.merge(auth_metadata, additional_metadata)
end
```

### 11.3 Metadata Feature Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Authorization header | Yes | Yes | COMPLETE |
| Bearer token | Yes | Yes | COMPLETE |
| Additional headers | Yes | Yes | COMPLETE |
| Lowercase keys | Yes | Yes | COMPLETE |
| Cluster URL header | Yes | No | **MISSING** |
| OAuth token refresh | Yes | No | **MISSING** |
| Dynamic token update | Yes | No | **MISSING** |

---

## 12. Proto Message Handling and Serialization

### 12.1 Proto File Coverage

| Proto File | Python | Elixir | Status |
|------------|--------|--------|--------|
| weaviate.proto | Yes | Yes | COMPLETE |
| search_get.proto | Yes | Yes | COMPLETE |
| batch.proto | Yes | Yes | COMPLETE |
| batch_delete.proto | Yes | Yes | COMPLETE |
| aggregate.proto | Yes | Yes | COMPLETE |
| tenants.proto | Yes | Yes | COMPLETE |
| health_weaviate.proto | Yes | Yes | COMPLETE |
| base.proto | Yes | Yes | COMPLETE |
| base_search.proto | Yes | Yes | COMPLETE |
| properties.proto | Yes | Yes | COMPLETE |
| generative.proto | Yes | Yes | COMPLETE |
| file_replication.proto | Yes | No | **MISSING** (low priority) |

### 12.2 Vector Encoding

**Python:**
```python
vector_bytes = struct.pack("{}f".format(len(vector)), *vector)
```

**Elixir:**
```elixir
vector_bytes = vector
  |> Enum.map(&<<&1::float-little-32>>)
  |> IO.iodata_to_binary()
```

**Status:** COMPLETE - Both use little-endian 32-bit float encoding.

### 12.3 Named Vector Support

Both implementations support named vectors via the `Vectors` message type with `name` and `vector_bytes` fields.

---

## 13. Recommendations

### 13.1 Critical Priority (Production Blockers)

1. **Apply Max Message Size to Channel Options**
   - File: `lib/weaviate_ex/grpc/channel.ex`
   - Change: Pass `max_message_size` to gRPC options

2. **Add Connection Health Monitoring**
   - Implement periodic health checks
   - Auto-reconnect on connection loss

### 13.2 High Priority

3. **Add Proxy Support**
   - Support `GRPC_PROXY` environment variable
   - Add proxy config option

4. **Complete Search API**
   - Add `near_image/4`, `near_audio/4`, etc. high-level functions
   - Add `sort_by`, `group_by`, `rerank` to search opts
   - Add `after` cursor pagination

5. **OAuth Token Refresh**
   - Background token refresh for enterprise auth

### 13.3 Medium Priority

6. **Cluster URL Header**
   - Add `x-weaviate-cluster-url` header for WCS

7. **HTTP Connection Pooling**
   - Add pooling for REST endpoints if needed

8. **Target Vectors**
   - Support named vector targeting in searches

### 13.4 Low Priority

9. **File Replication Service**
   - Only needed for cluster management

10. **Compression**
    - gRPC compression support

---

## 14. Summary Table

| Category | Python Features | Elixir Features | Parity |
|----------|-----------------|-----------------|--------|
| Channel Management | 8 | 5 | 62% |
| Search Service | 22 | 16 | 73% |
| Batch Service | 15 | 14 | 93% |
| Aggregate Service | 12 | 9 | 75% |
| Tenants Service | 7 | 8 | 100%+ |
| Health Service | 4 | 6 | 100%+ |
| BatchStream | 12 | 12 | 100% |
| Retry Logic | 3 | 6 | 100%+ |
| Metadata Handling | 6 | 4 | 67% |
| Proto Coverage | 12 | 11 | 92% |

**Overall Feature Parity: ~85%**

---

## Appendix: File Reference

### Python Files Analyzed

| File | Purpose |
|------|---------|
| `weaviate/connect/v4.py` | Main connection, all gRPC calls |
| `weaviate/connect/base.py` | Channel creation, connection params |
| `weaviate/retry.py` | Retry mechanism |
| `weaviate/config.py` | Timeout and pool configuration |
| `weaviate/exceptions.py` | Error types |
| `weaviate/collections/grpc/query.py` | Search request building |
| `weaviate/collections/grpc/aggregate.py` | Aggregate request building |
| `weaviate/collections/grpc/tenants.py` | Tenants request building |
| `weaviate/collections/grpc/shared.py` | Shared gRPC utilities |
| `weaviate/collections/batch/grpc_batch.py` | Batch operations |
| `weaviate/collections/batch/grpc_batch_delete.py` | Batch delete |
| `weaviate/proto/v1/v6300/v1/weaviate_pb2_grpc.py` | Generated stubs |

### Elixir Files Analyzed

| File | Purpose |
|------|---------|
| `lib/weaviate_ex/grpc/channel.ex` | Channel management |
| `lib/weaviate_ex/grpc/retry.ex` | Retry mechanism |
| `lib/weaviate_ex/grpc/services/search.ex` | Search service |
| `lib/weaviate_ex/grpc/services/batch.ex` | Batch service |
| `lib/weaviate_ex/grpc/services/aggregate.ex` | Aggregate service |
| `lib/weaviate_ex/grpc/services/tenants.ex` | Tenants service |
| `lib/weaviate_ex/grpc/services/health.ex` | Health service |
| `lib/weaviate_ex/grpc/services/batch_stream.ex` | Streaming batch |
| `lib/weaviate_ex/grpc/generated/v1/weaviate.pb.ex` | Generated stubs |
| `lib/weaviate_ex/client/config.ex` | Client configuration |
