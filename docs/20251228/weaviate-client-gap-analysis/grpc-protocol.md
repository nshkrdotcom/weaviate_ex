# gRPC & Protocol Support Gap Analysis

## Overview
Comprehensive comparison of Weaviate Python vs Elixir client protocol support.

**Analysis Date:** 2025-12-28
**Python Files Analyzed:** `weaviate/proto/`, `weaviate/connect/`, `weaviate/config.py`
**Elixir Files Analyzed:** `lib/weaviate_ex/protocol/`, `lib/weaviate_ex/client.ex`

---

## Executive Summary

The Elixir client implements **HTTP-only** via Finch, while Python provides **dual protocol support (HTTP + gRPC)** with intelligent fallback. This is a **critical gap** for production deployments requiring high-performance batch operations.

---

## Protocol Support Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| HTTP/1.1 & 2 | ✅ via httpx | ✅ via Finch | Full |
| gRPC (unary-unary) | ✅ Full | ❌ Missing | **CRITICAL** |
| gRPC (bidirectional streaming) | ✅ Full | ❌ Missing | **CRITICAL** |
| Protocol negotiation | ✅ Auto | ❌ N/A | Missing |
| Protocol fallback | ✅ gRPC → HTTP | ❌ N/A | Missing |

---

## Python gRPC Implementation

### Proto Definitions (`weaviate/proto/v1/v4216/v1/`)

**12 gRPC Services**:
- `weaviate_pb2_grpc.py` - Main Weaviate service
- `batch_pb2.py` - Batch operations
- `batch_delete_pb2.py` - Batch deletion
- `search_get_pb2.py` - Vector search
- `aggregate_pb2.py` - Aggregation queries
- `tenants_pb2.py` - Multi-tenancy
- `properties_pb2.py` - Property configuration
- `generative_pb2.py` - RAG operations
- `file_replication_pb2.py` - File replication
- `health_weaviate_pb2.py` - Health checks

### RPC Methods
```
Unary-Unary:
- Search(SearchRequest) → SearchReply
- BatchObjects(BatchObjectsRequest) → BatchObjectsReply
- BatchReferences(BatchReferencesRequest) → BatchReferencesReply
- BatchDelete(BatchDeleteRequest) → BatchDeleteReply
- TenantsGet(TenantsGetRequest) → TenantsGetReply
- Aggregate(AggregateRequest) → AggregateReply

Bidirectional Streaming:
- BatchStream(stream BatchStreamRequest) → stream BatchStreamReply
```

### gRPC Configuration
```python
# Max message size: 100MB
grpc_msg_size = 104_858_000

options = [
    ("grpc.max_send_message_length", grpc_msg_size),
    ("grpc.max_receive_message_length", grpc_msg_size),
    ("grpc.default_authority", host),
]
```

---

## Elixir Protocol Implementation

### Current State
```elixir
# Protocol behavior (protocol.ex)
@callback request(client, method, path, body, opts) :: response()

# HTTP implementation (protocol/http/client.ex)
# Uses Finch with connection pooling
```

### Missing Components
- ❌ gRPC client module
- ❌ Proto definitions / compilation
- ❌ gRPC dependency in mix.exs
- ❌ Streaming support
- ❌ gRPC health checks

---

## Connection Management

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Connection pooling | 20-100 connections | Finch pool | ⚠️ Limited config |
| Timeout config (per-op) | query/insert/init | Single value | ❌ Missing |
| Retry with backoff | ✅ Exponential | ❌ Basic | Gap |
| SSL/TLS certificates | ✅ Full | ❌ Basic | Gap |
| Proxy support | HTTP/HTTPS/gRPC | ❌ None | Gap |
| Custom headers | ✅ Full | ⚠️ API key only | Gap |

### Python Timeout Configuration
```python
class Timeout(BaseModel):
    query: Union[int, float] = 30      # Read operations
    insert: Union[int, float] = 90     # Write operations
    init: Union[int, float] = 2        # Initialization
```

### Elixir Timeout Configuration
```elixir
# Single timeout value, not operation-specific
# Defaults: init: 2000ms, query: 30000ms, insert: 90000ms
```

---

## Retry Logic Comparison

### Python Retry (`retry.py`)
```python
class _Retry:
    # gRPC-only retry
    # Only retries on StatusCode.UNAVAILABLE
    # Formula: 2^count seconds delay
    # Max retries: 4 (default)
```

### Elixir Retry (`retry.ex`)
```elixir
# HTTP + connection error retry
# Retryable: 429, 502, 503, 504, :timeout, :econnrefused, etc.
# Formula: base_delay * 2^attempt with ±10% jitter
# Max retries: 3 (default), Max delay: 5000ms
```

**Elixir Advantage**: More comprehensive retry coverage with jitter

---

## Health Checks

| Check Type | Python | Elixir | Status |
|------------|--------|--------|--------|
| HTTP `/v1/meta` | ✅ | ✅ | Full |
| gRPC Health/Check | ✅ | ❌ | Missing |
| Startup validation | ✅ | ✅ | Full |
| Version compatibility | ✅ | ❌ | Missing |

### Python gRPC Health Check
```python
def _ping_grpc(colour):
    res = self._grpc_channel.unary_unary(
        "/grpc.health.v1.Health/Check",
        request_serializer=WeaviateHealthCheckRequest.SerializeToString,
        response_deserializer=WeaviateHealthCheckResponse.FromString,
    )(WeaviateHealthCheckRequest(), timeout=self.timeout_config.init)

    if res.status != WeaviateHealthCheckResponse.SERVING:
        raise WeaviateGRPCUnavailableError()
```

---

## Embedded Weaviate Support

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Binary download | ✅ | ✅ | Full |
| Platform detection | ✅ | ✅ | Full |
| Version management | ✅ | ✅ | Full |
| HTTP readiness | ✅ | ✅ | Full |
| gRPC readiness | ✅ | ❌ | Missing |
| Persistence config | ✅ | ⚠️ Basic | Partial |

---

## Feature Parity Matrix

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| **Protocol Support** | | | |
| HTTP/1.1 & 2 | ✅ | ✅ | Full |
| gRPC (unary) | ✅ | ❌ | **MISSING** |
| gRPC (streaming) | ✅ | ❌ | **MISSING** |
| Protocol negotiation | ✅ | ❌ | **MISSING** |
| **Connection** | | | |
| Pool configuration | ✅ | ⚠️ | Limited |
| Per-op timeout | ✅ | ❌ | **MISSING** |
| Retry + backoff | ✅ | ⚠️ | Partial |
| SSL/TLS certs | ✅ | ❌ | **MISSING** |
| Proxy support | ✅ | ❌ | **MISSING** |
| Custom headers | ✅ | ❌ | **MISSING** |
| **Auth** | | | |
| API Key | ✅ | ✅ | Full |
| OAuth2 | ✅ | ❌ | **MISSING** |
| Token refresh | ✅ | ❌ | **MISSING** |
| **Health** | | | |
| HTTP health | ✅ | ✅ | Full |
| gRPC health | ✅ | ❌ | **MISSING** |
| Version check | ✅ | ❌ | **MISSING** |
| **Batch** | | | |
| gRPC batch (unary) | ✅ | ❌ | **MISSING** |
| gRPC batch (stream) | ✅ | ❌ | **MISSING** |
| Rate-limited streaming | ✅ | ❌ | **MISSING** |

---

## Implementation Roadmap

### Phase 1: Critical (2 weeks)
**Effort: 40-60 hours**

1. **Add gRPC Dependencies**
   ```elixir
   {:grpc, "~> 0.7"},
   {:protobuf, "~> 0.12"}
   ```

2. **Generate Proto Code**
   - Create `protobufs/` directory
   - Download Weaviate proto files
   - Compile to `.pb.ex` files

3. **Implement gRPC Client**
   - Basic unary RPCs
   - Connection pooling via GenServer
   - Metadata/header handling

### Phase 2: Important (2 weeks)
**Effort: 30-40 hours**

4. **Streaming Support**
   - Bidirectional streaming for batch
   - Backpressure handling

5. **Protocol Negotiation**
   - Auto-selection logic
   - Fallback mechanism

6. **Retry & Resilience**
   - gRPC-specific retry
   - Circuit breaker pattern

### Phase 3: Enhancement (2 weeks)
**Effort: 30-40 hours**

7. **Advanced Connection**
   - SSL/TLS configuration
   - Proxy support
   - Pool tuning

8. **Authentication**
   - OAuth2 support
   - Token refresh

9. **Health & Version**
   - gRPC health endpoint
   - Version compatibility

---

## Recommended gRPC Client Structure

```elixir
defmodule WeaviateEx.Protocol.GRPC.Client do
  @behaviour WeaviateEx.Protocol

  @impl true
  def request(client, method, path, body, opts) do
    {:ok, channel} = get_channel(client.config)
    grpc_method = map_to_grpc_method(method, path)
    request_msg = build_request_message(grpc_method, body)

    case make_rpc_call(channel, grpc_method, request_msg, opts) do
      {:ok, reply} -> {:ok, parse_reply(reply)}
      {:error, error} -> {:error, map_grpc_error(error)}
    end
  end

  @impl true
  def stream(client, path, body_stream, opts) do
    # Bidirectional streaming implementation
  end

  @impl true
  def health_check(client, opts) do
    # gRPC health check endpoint
  end
end
```

---

## Summary

The lack of gRPC support is the **single largest gap** in the Elixir client. It impacts:

1. **Batch Performance** - HTTP is significantly slower for bulk operations
2. **Streaming Operations** - No bidirectional streaming possible
3. **Resource Efficiency** - gRPC uses less bandwidth
4. **Feature Access** - Some operations are gRPC-only in Weaviate

**Estimated Implementation Time**: 12-16 weeks with 1-2 developers
