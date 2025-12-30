# gRPC Protocol Deep Gap Analysis

## Executive Summary

This document provides a comprehensive gap analysis comparing the gRPC protocol implementation between the canonical Python Weaviate client (`weaviate-python-client`) and the Elixir port (`weaviate_ex`). The analysis covers channel management, proto definitions, services, streaming, error handling, and protocol-level features.

**Overall Assessment:** The Elixir implementation covers ~75% of core gRPC functionality with well-implemented services but has notable gaps in connection pooling, retry mechanisms, compression, and the file replication service.

---

## 1. gRPC Channel Management and Connection Pooling

### Python Implementation

**Location:** `weaviate-python-client/weaviate/connect/base.py`, `weaviate-python-client/weaviate/connect/v4.py`

| Feature | Python Implementation |
|---------|----------------------|
| Channel Types | Supports both sync (`grpc.Channel`) and async (`grpc.aio.Channel`) |
| Connection Creation | `_grpc_channel()` method in `ConnectionParams` class |
| TLS Support | Automatic SSL credential handling via `ssl_channel_credentials()` |
| Proxy Support | Full proxy configuration via `grpc.http_proxy` option |
| Max Message Size | Configurable via `grpcMaxMessageSize` from server meta endpoint |
| Default Message Size | 104,858,000 bytes (~100MB) |
| Channel Options | `grpc.max_send_message_length`, `grpc.max_receive_message_length`, `grpc.default_authority` |
| Connection Pooling | Uses httpx connection pools with configurable `session_pool_maxsize`, `session_pool_connections` |
| Connection Lifecycle | `open_connection_grpc()`, `close()` methods with proper cleanup |

```python
# Python channel options example
opts = [
    ("grpc.max_send_message_length", grpc_msg_size),
    ("grpc.max_receive_message_length", grpc_msg_size),
    ("grpc.default_authority", self.grpc.host),
]
```

### Elixir Implementation

**Location:** `lib/weaviate_ex/grpc/channel.ex`

| Feature | Elixir Implementation |
|---------|----------------------|
| Channel Types | Uses GRPC Elixir library (`GRPC.Stub.connect`) |
| Connection Creation | `connect/2` function with config map |
| TLS Support | Basic TLS via `GRPC.Credential.new(ssl: [])` |
| Proxy Support | **NOT IMPLEMENTED** |
| Max Message Size | Configurable but not passed to gRPC options |
| Default Message Size | 104,858,000 bytes (~100MB) |
| Channel Options | Limited to adapter transport timeout |
| Connection Pooling | **NOT IMPLEMENTED** - single connection per channel |
| Connection Lifecycle | `connect/2`, `disconnect/1`, `connected?/1` |

```elixir
# Elixir channel options
base_opts = [
  adapter: GRPC.Client.Adapters.Gun,
  adapter_opts: %{
    transport_opts: %{
      timeout: timeout
    }
  }
]
```

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Async/Sync Channel Support | PARTIAL | Medium | Elixir uses async by nature via Gun adapter |
| Proxy Support | MISSING | High | No `grpc.http_proxy` equivalent |
| Connection Pooling | MISSING | High | Single connection, no pool management |
| Dynamic Max Message Size | MISSING | Medium | Not fetched from server meta |
| Channel Options | PARTIAL | Medium | Missing max message length options |
| TLS Options | PARTIAL | Low | Basic TLS, no custom cert paths |

---

## 2. Proto Definitions Completeness

### Python Proto Files

**Location:** `weaviate-python-client/weaviate/proto/v1/v6300/v1/`

| Proto File | Python | Description |
|------------|--------|-------------|
| `weaviate_pb2.py` | YES | Main Weaviate service definition |
| `weaviate_pb2_grpc.py` | YES | gRPC service stubs |
| `search_get_pb2.py` | YES | Search request/reply messages |
| `batch_pb2.py` | YES | Batch operations messages |
| `batch_delete_pb2.py` | YES | Batch delete messages |
| `aggregate_pb2.py` | YES | Aggregation messages |
| `tenants_pb2.py` | YES | Multi-tenancy messages |
| `health_weaviate_pb2.py` | YES | Health check messages |
| `health_weaviate_pb2_grpc.py` | YES | Health service stubs |
| `base_pb2.py` | YES | Base types (filters, vectors, etc.) |
| `base_search_pb2.py` | YES | Base search types (Hybrid, BM25, etc.) |
| `properties_pb2.py` | YES | Property types |
| `generative_pb2.py` | YES | Generative AI types |
| `file_replication_pb2.py` | YES | File replication service |
| `file_replication_pb2_grpc.py` | YES | File replication stubs |

**Note:** Python supports multiple protobuf versions (v4216, v5261, v6300) for compatibility.

### Elixir Proto Files

**Location:** `lib/weaviate_ex/grpc/generated/v1/`

| Proto File | Elixir | Description |
|------------|--------|-------------|
| `weaviate.pb.ex` | YES | Main Weaviate service definition |
| `search_get.pb.ex` | YES | Search request/reply messages |
| `batch.pb.ex` | YES | Batch operations messages |
| `batch_delete.pb.ex` | YES | Batch delete messages |
| `aggregate.pb.ex` | YES | Aggregation messages |
| `tenants.pb.ex` | YES | Multi-tenancy messages |
| `health_weaviate.pb.ex` | YES | Health check messages |
| `health_weaviate_service.pb.ex` | YES | Health service stubs |
| `base.pb.ex` | YES | Base types |
| `base_search.pb.ex` | YES | Base search types |
| `properties.pb.ex` | YES | Property types |
| `generative.pb.ex` | YES | Generative AI types |
| `file_replication.pb.ex` | **MISSING** | File replication service |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Core Service Protos | COMPLETE | - | All main services defined |
| Search Types | COMPLETE | - | Full search message support |
| Batch Types | COMPLETE | - | Full batch message support |
| Aggregate Types | COMPLETE | - | Full aggregation support |
| Tenants Types | COMPLETE | - | Full multi-tenancy support |
| Health Types | COMPLETE | - | Health check support |
| Generative Types | COMPLETE | - | RAG/generative support |
| File Replication | MISSING | Low | Used for cluster replication |
| Multi-Version Support | MISSING | Low | Single proto version only |

---

## 3. gRPC Services Implemented

### Python Service Methods

**Location:** `weaviate-python-client/weaviate/proto/v1/v6300/v1/weaviate_pb2_grpc.py`

| Service Method | Type | Description |
|----------------|------|-------------|
| `Search` | Unary | Vector/text search |
| `BatchObjects` | Unary | Batch insert objects |
| `BatchReferences` | Unary | Batch insert references |
| `BatchDelete` | Unary | Batch delete by filter |
| `TenantsGet` | Unary | Get tenant information |
| `Aggregate` | Unary | Aggregation queries |
| `BatchStream` | Bidirectional Stream | Streaming batch operations |

### Elixir Service Methods

**Location:** `lib/weaviate_ex/grpc/generated/v1/weaviate.pb.ex`, `lib/weaviate_ex/grpc/services/`

| Service Method | Type | Implementation | File |
|----------------|------|----------------|------|
| `Search` | Unary | IMPLEMENTED | `services/search.ex` |
| `BatchObjects` | Unary | IMPLEMENTED | `services/batch.ex` |
| `BatchReferences` | Unary | IMPLEMENTED | `services/batch.ex` |
| `BatchDelete` | Unary | IMPLEMENTED | `services/batch.ex` |
| `TenantsGet` | Unary | IMPLEMENTED | `services/tenants.ex` |
| `Aggregate` | Unary | IMPLEMENTED | `services/aggregate.ex` |
| `BatchStream` | Bidirectional Stream | IMPLEMENTED | `services/batch_stream.ex` |

### Service Implementation Comparison

#### Search Service

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| near_vector | YES | YES | COMPLETE |
| near_text | YES | YES | COMPLETE |
| near_object | YES | YES | COMPLETE |
| bm25 | YES | YES | COMPLETE |
| hybrid | YES | YES | COMPLETE |
| near_image | YES | YES | COMPLETE |
| near_audio | YES | YES | COMPLETE |
| near_video | YES | YES | COMPLETE |
| near_depth | YES | YES | COMPLETE |
| near_thermal | YES | YES | COMPLETE |
| near_imu | YES | YES | COMPLETE |
| generative | YES | YES | COMPLETE |
| rerank | YES | YES | COMPLETE |
| filters | YES | YES | COMPLETE |
| group_by | YES | YES | COMPLETE |
| sort_by | YES | YES | COMPLETE |

#### Batch Service

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| insert_objects | YES | YES | COMPLETE |
| insert_references | YES | YES | COMPLETE |
| delete_objects | YES | YES | COMPLETE |
| consistency_level | YES | YES | COMPLETE |
| vector_bytes | YES | YES | COMPLETE |
| named_vectors | YES | YES | COMPLETE |

#### Aggregate Service

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| count | YES | YES | COMPLETE |
| number aggregations | YES | YES | COMPLETE |
| text aggregations | YES | YES | COMPLETE |
| boolean aggregations | YES | YES | COMPLETE |
| date aggregations | YES | YES | COMPLETE |
| reference aggregations | YES | YES | COMPLETE |
| group_by | YES | YES | COMPLETE |
| near_vector | YES | YES | COMPLETE |
| near_text | YES | YES | COMPLETE |
| filters | YES | YES | COMPLETE |

#### Tenants Service

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| list tenants | YES | YES | COMPLETE |
| get by name | YES | YES | COMPLETE |
| activity status | YES | YES | COMPLETE |

### Gap Analysis

| Service | Status | Priority | Notes |
|---------|--------|----------|-------|
| Search | COMPLETE | - | Full feature parity |
| Batch | COMPLETE | - | Full feature parity |
| Aggregate | COMPLETE | - | Full feature parity |
| Tenants | COMPLETE | - | Full feature parity |
| FileReplication | MISSING | Low | Cluster-level service |

---

## 4. gRPC Health Checks

### Python Implementation

**Location:** `weaviate-python-client/weaviate/connect/v4.py`

```python
def _ping_grpc(self, colour: executor.Colour) -> Union[None, Awaitable[None]]:
    res = self._grpc_channel.unary_unary(
        "/grpc.health.v1.Health/Check",
        request_serializer=health_weaviate_pb2.WeaviateHealthCheckRequest.SerializeToString,
        response_deserializer=health_weaviate_pb2.WeaviateHealthCheckResponse.FromString,
    )(health_weaviate_pb2.WeaviateHealthCheckRequest(), timeout=self.timeout_config.init)
```

| Feature | Python |
|---------|--------|
| Health Endpoint | `/grpc.health.v1.Health/Check` |
| Custom Weaviate Health | `WeaviateHealthCheckRequest/Response` |
| Status Values | `SERVING`, `NOT_SERVING`, `UNKNOWN` |
| Timeout | Configurable via `timeout_config.init` |
| Init Check | Automatic during connection |

### Elixir Implementation

**Location:** `lib/weaviate_ex/grpc/services/health.ex`

```elixir
def check(channel, opts \\ []) do
  request = %WeaviateHealthCheckRequest{service: service}
  WeaviateHealthStub.check(channel, request, opts)
end
```

| Feature | Elixir |
|---------|--------|
| Health Endpoint | `weaviate.v1.WeaviateHealth/Check` |
| Custom Weaviate Health | `WeaviateHealthCheckRequest/Response` |
| Status Values | `:SERVING`, `:NOT_SERVING`, `:UNKNOWN` |
| Timeout | Configurable via opts |
| Ping Function | `ping/2` for quick connectivity check |
| Wait for Ready | `wait_for_ready/2` with polling |
| Healthy Check | `healthy?/2` boolean helper |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Basic Health Check | COMPLETE | - | Full implementation |
| Status Parsing | COMPLETE | - | All status values handled |
| Timeout Handling | COMPLETE | - | Configurable timeouts |
| Wait for Ready | COMPLETE | - | Better than Python (polling) |
| Init Health Check | PARTIAL | Low | Not automatic on connect |

---

## 5. Streaming Support

### Python Implementation

**Location:** `weaviate-python-client/weaviate/connect/v4.py`

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

| Feature | Python |
|---------|--------|
| Stream Type | Bidirectional (stream_stream) |
| Protocol | Start -> Data* -> Stop |
| Backoff Support | Server can send Backoff messages |
| Acks | Server sends acknowledgments |
| Results | Final results on completion |
| Error Handling | `StatusCode.ABORTED` for shutdown |

### Elixir Implementation

**Location:** `lib/weaviate_ex/grpc/services/batch_stream.ex`

```elixir
def open(channel, opts \\ []) do
  stream = Weaviate.V1.Weaviate.Stub.batch_stream(channel, metadata: metadata, timeout: timeout)
  {:ok, stream}
end
```

| Feature | Elixir |
|---------|--------|
| Stream Type | Bidirectional (stream_stream) |
| Protocol | Start -> Data* -> Stop |
| Message Builders | `start_message/1`, `data_message/2`, `stop_message/0` |
| Send Functions | `send_objects/2`, `send_references/2` |
| Receive Function | `receive_results/2` |
| Reply Parsing | `parse_reply/1` for all message types |
| Close Function | `close/1` for graceful shutdown |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Bidirectional Streaming | COMPLETE | - | Full implementation |
| Start/Stop Protocol | COMPLETE | - | Proper message handling |
| Data Messages | COMPLETE | - | Objects and references |
| Backoff Handling | COMPLETE | - | Parsed from replies |
| Acks Handling | COMPLETE | - | Parsed from replies |
| Results Handling | COMPLETE | - | Success/error parsing |
| Named Vectors | COMPLETE | - | `encode_named_vectors/1` |
| Error Recovery | PARTIAL | Medium | Less robust than Python |

---

## 6. Error Handling and Retries

### Python Implementation

**Location:** `weaviate-python-client/weaviate/retry.py`, `weaviate-python-client/weaviate/connect/v4.py`

```python
class _Retry:
    def __init__(self, n: float = 4) -> None:
        self.n = n

    def with_exponential_backoff(self, count, error, f, *args, **kwargs):
        try:
            return f(*args, **kwargs)
        except RpcError as e:
            if err.code() != StatusCode.UNAVAILABLE:
                raise e
            time.sleep(2**count)
            if count > self.n:
                raise WeaviateRetryError(str(e), count) from e
            return self.with_exponential_backoff(count + 1, error, f, *args, **kwargs)
```

| Feature | Python |
|---------|--------|
| Retry Mechanism | Exponential backoff |
| Max Retries | Configurable (default: 4) |
| Retryable Codes | `StatusCode.UNAVAILABLE` only |
| Backoff Formula | `2^count` seconds |
| Async Support | `awith_exponential_backoff` |
| Error Types | Specific exceptions per operation |
| Permission Denied | Special handling with `InsufficientPermissionsError` |

**Error Types:**
- `WeaviateRetryError`
- `WeaviateQueryError`
- `WeaviateBatchError`
- `WeaviateBatchStreamError`
- `WeaviateDeleteManyError`
- `WeaviateTenantGetError`
- `InsufficientPermissionsError`

### Elixir Implementation

**Location:** `lib/weaviate_ex/error.ex`

```elixir
def from_grpc_error(%GRPC.RPCError{status: status, message: message}) do
  status_atom = grpc_code_to_atom(status)
  from_grpc_status(status_atom, message)
end

def grpc_retryable?(:unavailable), do: true
def grpc_retryable?(:resource_exhausted), do: true
def grpc_retryable?(:aborted), do: true
def grpc_retryable?(:deadline_exceeded), do: true
def grpc_retryable?(_), do: false
```

| Feature | Elixir |
|---------|--------|
| Retry Mechanism | **NOT IMPLEMENTED** |
| Retryable Codes | Defined in `grpc_retryable?/1` |
| Error Struct | `WeaviateEx.Error` with type/message/details |
| gRPC Mapping | Full status code to atom mapping |
| Error Categories | RBAC, Backup, Cluster specific errors |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Exponential Backoff | MISSING | **Critical** | Core reliability feature |
| Max Retry Config | MISSING | **Critical** | Needed for production |
| Retryable Code Detection | COMPLETE | - | `grpc_retryable?/1` implemented |
| Error Type Mapping | COMPLETE | - | Full gRPC status mapping |
| Async Retry Support | MISSING | High | OTP patterns could help |
| Permission Denied | PARTIAL | Medium | Error type exists, no special handling |
| Operation-Specific Errors | PARTIAL | Low | Generic error struct |

---

## 7. Metadata Handling

### Python Implementation

**Location:** `weaviate-python-client/weaviate/connect/v4.py`

```python
def _prepare_grpc_headers(self) -> None:
    self.__metadata_list: List[Tuple[str, str]] = []
    if len(self.additional_headers):
        for key, val in self.additional_headers.items():
            if val is not None:
                self.__metadata_list.append((key.lower(), val))

    if self._auth is not None:
        if isinstance(self._auth, AuthApiKey):
            self.__metadata_list.append(("authorization", "Bearer " + self._auth.api_key))
        else:
            self.__metadata_list.append(("authorization", "dummy_will_be_refreshed_for_each_call"))
```

| Feature | Python |
|---------|--------|
| Format | Tuple of tuples |
| Auth Header | Bearer token with API key |
| Cluster URL | `x-weaviate-cluster-url` header |
| Custom Headers | From `additional_headers` config |
| Dynamic Refresh | OAuth tokens refreshed before calls |
| Case Sensitivity | Lowercased keys |

### Elixir Implementation

**Location:** `lib/weaviate_ex/grpc/channel.ex`

```elixir
def build_metadata(config) when is_map(config) do
  case Map.get(config, :api_key) do
    nil -> %{}
    "" -> %{}
    api_key -> %{"authorization" => "Bearer #{api_key}"}
  end
end
```

| Feature | Elixir |
|---------|--------|
| Format | Map |
| Auth Header | Bearer token with API key |
| Cluster URL | **NOT IMPLEMENTED** |
| Custom Headers | **NOT IMPLEMENTED** |
| Dynamic Refresh | **NOT IMPLEMENTED** |
| Case Sensitivity | Maintained |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Auth Header | COMPLETE | - | Bearer token support |
| Cluster URL Header | MISSING | Medium | WCS-specific feature |
| Custom Headers | MISSING | Medium | Extensibility feature |
| OAuth Token Refresh | MISSING | High | Enterprise auth feature |
| Header Normalization | PARTIAL | Low | Not lowercasing keys |

---

## 8. Message Serialization/Deserialization

### Python Implementation

The Python client uses generated protobuf code with automatic serialization:

```python
request_serializer=v1_dot_search__get__pb2.SearchRequest.SerializeToString,
response_deserializer=v1_dot_search__get__pb2.SearchReply.FromString,
```

| Feature | Python |
|---------|--------|
| Library | `protobuf` package (multiple versions) |
| Serialization | `SerializeToString` method |
| Deserialization | `FromString` class method |
| Binary Format | Standard protobuf wire format |
| Version Support | v4.21.6, v5.26.1, v6.30.0 |

### Elixir Implementation

The Elixir client uses `protobuf-elixir` with automatic handling:

```elixir
use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
```

| Feature | Elixir |
|---------|--------|
| Library | `protobuf-elixir` |
| Serialization | Automatic via GRPC library |
| Deserialization | Automatic via GRPC library |
| Binary Format | Standard protobuf wire format |
| Version | 0.15.0 (single version) |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Protobuf Encoding | COMPLETE | - | Standard wire format |
| Automatic Handling | COMPLETE | - | Via GRPC library |
| Proto3 Syntax | COMPLETE | - | All protos use proto3 |
| Multi-Version Support | MISSING | Low | Single protobuf version |

---

## 9. Vector Encoding/Decoding

### Python Implementation

**Location:** Various service files, proto definitions

```python
# Vector is deprecated, vector_bytes is preferred
field(:vector, 2, repeated: true, type: :float, deprecated: true)
field(:vector_bytes, 19, type: :bytes, json_name: "vectorBytes")
```

| Feature | Python |
|---------|--------|
| Legacy Vector | Repeated float (deprecated) |
| Vector Bytes | Binary encoding (preferred) |
| Named Vectors | `Vectors` message with name + bytes |
| Encoding | Little-endian 32-bit floats |

### Elixir Implementation

**Location:** `lib/weaviate_ex/grpc/services/search.ex`, `lib/weaviate_ex/grpc/services/batch_stream.ex`

```elixir
defp build_near_vector(vector, opts) when is_list(vector) do
  vector_bytes =
    vector
    |> Enum.map(&<<&1::float-little-32>>)
    |> IO.iodata_to_binary()

  %NearVector{
    vector_bytes: vector_bytes,
    certainty: Keyword.get(opts, :certainty),
    distance: Keyword.get(opts, :distance)
  }
end

defp encode_named_vectors(vectors) when is_map(vectors) do
  Enum.map(vectors, fn {name, vector} ->
    %Weaviate.V1.Vectors{
      name: to_string(name),
      vector_bytes: encode_vector(vector)
    }
  end)
end
```

| Feature | Elixir |
|---------|--------|
| Legacy Vector | Supported in proto |
| Vector Bytes | Binary encoding (used) |
| Named Vectors | `Weaviate.V1.Vectors` message |
| Encoding | Little-endian 32-bit floats |
| Decoding | **NOT IMPLEMENTED** |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Vector Encoding | COMPLETE | - | Little-endian float32 |
| Named Vectors | COMPLETE | - | Full support |
| Vector Decoding | MISSING | Medium | Response parsing incomplete |
| Multi-Target Vectors | COMPLETE | - | Named vector support |

---

## 10. Timeout and Deadline Handling

### Python Implementation

**Location:** `weaviate-python-client/weaviate/connect/v4.py`

```python
res = self.grpc_stub.Search(
    request,
    metadata=self.grpc_headers(),
    timeout=self.timeout_config.query,
)
```

| Feature | Python |
|---------|--------|
| Timeout Config | `TimeoutConfig` with query/insert/init |
| Query Timeout | `timeout_config.query` |
| Insert Timeout | `timeout_config.insert` |
| Init Timeout | `timeout_config.init` |
| Per-Call Timeout | Passed to stub methods |
| Default Timeout | Configurable at client level |

### Elixir Implementation

**Location:** `lib/weaviate_ex/grpc/services/*.ex`

```elixir
def execute_search(channel, request, opts) do
  timeout = Keyword.get(opts, :timeout, 30_000)
  WeaviateStub.search(channel, request, timeout: timeout, metadata: metadata)
end
```

| Feature | Elixir |
|---------|--------|
| Timeout Config | Per-call via opts |
| Query Timeout | Default 30,000ms |
| Insert Timeout | Default 90,000ms |
| Init Timeout | Default 5,000ms (health) |
| Per-Call Timeout | Passed to stub methods |
| Default Timeout | Hardcoded in services |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Per-Call Timeout | COMPLETE | - | All services support |
| Query/Insert Distinction | PARTIAL | Low | Hardcoded defaults |
| Centralized Config | MISSING | Medium | No `TimeoutConfig` equivalent |
| gRPC Deadline | PARTIAL | Low | Relies on GRPC library |

---

## 11. gRPC Compression

### Python Implementation

**Location:** `weaviate-python-client/weaviate/proto/v1/v6300/v1/weaviate_pb2_grpc.py`

```python
@staticmethod
def Search(request, target, options=(), channel_credentials=None,
        call_credentials=None, insecure=False, compression=None,
        wait_for_ready=None, timeout=None, metadata=None):
    return grpc.experimental.unary_unary(
        request, target, '/weaviate.v1.Weaviate/Search',
        ...
        compression,
        ...
    )
```

| Feature | Python |
|---------|--------|
| Compression Parameter | Available in experimental API |
| Compression Types | gzip, deflate (via grpc) |
| Per-Call Compression | Supported |
| Default | None (no compression) |

### Elixir Implementation

| Feature | Elixir |
|---------|--------|
| Compression Parameter | **NOT AVAILABLE** |
| Compression Types | N/A |
| Per-Call Compression | N/A |
| Default | N/A |

### Gap Analysis

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| gRPC Compression | MISSING | Low | Not commonly used |
| gzip Support | MISSING | Low | GRPC library limitation |
| Per-Call Config | MISSING | Low | Would need library update |

---

## 12. Additional Python Features Missing in Elixir

### File Replication Service

**Python Location:** `weaviate-python-client/weaviate/proto/v1/v6300/v1/file_replication_pb2.py`

| Service Method | Type | Description |
|----------------|------|-------------|
| `PauseFileActivity` | Unary | Pause file activity for shard |
| `ResumeFileActivity` | Unary | Resume file activity |
| `ListFiles` | Unary | List shard files |
| `GetFileMetadata` | Bidirectional Stream | Get file metadata |
| `GetFile` | Bidirectional Stream | Stream file content |

**Status:** MISSING - Low priority for client usage

### Version Detection and Compatibility

| Feature | Python | Elixir |
|---------|--------|--------|
| Server Version Check | YES | YES (via REST) |
| Proto Version Selection | YES | NO |
| Feature Flag APIs | YES | PARTIAL |
| `uses_127_api` flag | YES | YES |

---

## Priority Recommendations

### Critical (Must Have)

1. **Implement Exponential Backoff Retry**
   - Add `WeaviateEx.GRPC.Retry` module
   - Support `UNAVAILABLE` status code
   - Configurable max retries

2. **Add Connection Pooling**
   - Use `:poolboy` or similar
   - Configurable pool size
   - Connection health monitoring

### High Priority

3. **OAuth Token Refresh**
   - Background token refresh for enterprise auth
   - Support `AuthClientCredentials`

4. **Proxy Support**
   - Add proxy configuration
   - Support GRPC_PROXY environment variable

5. **Custom Headers Support**
   - Allow additional headers in config
   - Support `x-weaviate-cluster-url`

### Medium Priority

6. **Centralized Timeout Config**
   - Create `TimeoutConfig` struct
   - Apply consistently across services

7. **Vector Decoding**
   - Parse `vector_bytes` in responses
   - Convert to float list

8. **Dynamic Max Message Size**
   - Fetch from server meta endpoint
   - Apply to gRPC channel options

### Low Priority

9. **gRPC Compression**
   - Wait for GRPC library support
   - Optional gzip compression

10. **File Replication Service**
    - For cluster management only
    - Not typical client usage

11. **Multi-Version Proto Support**
    - Single version sufficient
    - Regenerate protos as needed

---

## Implementation Roadmap

### Phase 1: Reliability (Week 1-2)
- [ ] Implement exponential backoff retry
- [ ] Add connection pooling
- [ ] Centralize timeout configuration

### Phase 2: Authentication (Week 3)
- [ ] OAuth token refresh support
- [ ] Custom headers support
- [ ] Cluster URL header

### Phase 3: Performance (Week 4)
- [ ] Dynamic max message size
- [ ] Vector decoding optimization
- [ ] Proxy support

### Phase 4: Completeness (Week 5+)
- [ ] File replication service (if needed)
- [ ] gRPC compression (pending library support)
- [ ] Multi-version proto support (if needed)

---

## Appendix: File Locations

### Python Files Analyzed

| File | Purpose |
|------|---------|
| `weaviate-python-client/weaviate/connect/v4.py` | Main connection handling |
| `weaviate-python-client/weaviate/connect/base.py` | Connection parameters |
| `weaviate-python-client/weaviate/retry.py` | Retry mechanism |
| `weaviate-python-client/weaviate/proto/v1/__init__.py` | Proto version selection |
| `weaviate-python-client/weaviate/proto/v1/v6300/v1/*.py` | Generated proto files |

### Elixir Files Analyzed

| File | Purpose |
|------|---------|
| `lib/weaviate_ex/grpc/channel.ex` | Channel management |
| `lib/weaviate_ex/grpc/services/search.ex` | Search service |
| `lib/weaviate_ex/grpc/services/batch.ex` | Batch service |
| `lib/weaviate_ex/grpc/services/aggregate.ex` | Aggregate service |
| `lib/weaviate_ex/grpc/services/tenants.ex` | Tenants service |
| `lib/weaviate_ex/grpc/services/health.ex` | Health service |
| `lib/weaviate_ex/grpc/services/batch_stream.ex` | Streaming batch |
| `lib/weaviate_ex/grpc/generated/v1/*.pb.ex` | Generated proto files |
| `lib/weaviate_ex/error.ex` | Error handling |
