# Error Handling & Retry Logic Gap Analysis

## Overview
Comprehensive comparison of Weaviate Python vs Elixir client error handling and retry mechanisms.

**Analysis Date:** 2025-12-28
**Python Files Analyzed:** `weaviate/exceptions.py`, `weaviate/error_msgs.py`, `weaviate/retry.py`
**Elixir Files Analyzed:** `lib/weaviate_ex/error.ex`, `lib/weaviate_ex/retry.ex`, `lib/weaviate_ex/batch/error_tracking.ex`

---

## Executive Summary

Python uses a **comprehensive exception hierarchy** with 30+ specific exception types, while Elixir uses a **simplified error struct** with type atoms. The Elixir retry logic is actually more comprehensive for HTTP operations, but lacks gRPC-specific handling.

---

## Exception Hierarchy Comparison

### Python Exception Types (30+ types)

| Category | Exception | Purpose |
|----------|-----------|---------|
| **Base** | `WeaviateBaseError` | Root exception |
| **Status** | `UnexpectedStatusCodeError` | HTTP/gRPC status |
| **Status** | `ResponseCannotBeDecodedError` | JSON decode failure |
| **Status** | `InsufficientPermissionsError` | HTTP 403 |
| **Auth** | `AuthenticationFailedError` | Auth failures |
| **Auth** | `MissingScopeError` | OAuth scope |
| **Query** | `WeaviateQueryError` | Query failures |
| **Batch** | `WeaviateBatchError` | gRPC batch |
| **Batch** | `WeaviateBatchSendError` | gRPC batch send |
| **Batch** | `WeaviateBatchStreamError` | gRPC streaming |
| **Batch** | `WeaviateDeleteManyError` | gRPC delete |
| **Batch** | `WeaviateTenantGetError` | gRPC tenant |
| **Validation** | `WeaviateInvalidInputError` | Input validation |
| **Validation** | `SchemaValidationError` | Schema validation |
| **Validation** | `WeaviateBatchValidationError` | Batch validation |
| **Validation** | `WeaviateInsertInvalidPropertyError` | Property validation |
| **Data** | `ObjectAlreadyExistsError` | 409 conflict |
| **Data** | `AdditionalPropertiesError` | Duplicate properties |
| **Connection** | `WeaviateConnectionError` | Connection failures |
| **Connection** | `WeaviateTimeoutError` | Request timeout |
| **Connection** | `WeaviateClosedClientError` | Closed client |
| **Connection** | `WeaviateGRPCUnavailableError` | gRPC health fail |
| **Connection** | `EmptyResponseError` | Empty HTTP response |
| **Retry** | `WeaviateRetryError` | Max retries exceeded |
| **Retry** | `WeaviateInsertManyAllFailedError` | All insertions failed |
| **Feature** | `WeaviateStartUpError` | Startup failure |
| **Feature** | `WeaviateEmbeddedInvalidVersionError` | Invalid version |
| **Feature** | `WeaviateUnsupportedFeatureError` | Version requirement |
| **Feature** | `WeaviateAddInvalidPropertyError` | Property addition |
| **Feature** | `WeaviateAgentsNotInstalledError` | Missing deps |
| **Special** | `WeaviateProtobufIncompatibility` | gRPC/protobuf |

### Elixir Error Struct

```elixir
defmodule WeaviateEx.Error do
  defexception [
    :type,        # atom (e.g., :bad_request, :not_found)
    :message,     # String.t()
    :details,     # map()
    :status_code  # integer() | nil
  ]
end
```

### Elixir Error Types (via `status_to_type/1`)

| Status Code | Type Atom | Python Equivalent |
|-------------|-----------|-------------------|
| 400 | `:bad_request` | `WeaviateInvalidInputError` |
| 401 | `:authentication_failed` | `AuthenticationFailedError` |
| 403 | `:forbidden` | `InsufficientPermissionsError` |
| 404 | `:not_found` | `UnexpectedStatusCodeError` |
| 409 | `:conflict` | `ObjectAlreadyExistsError` |
| 422 | `:validation_error` | `SchemaValidationError` |
| 500 | `:server_error` | `UnexpectedStatusCodeError` |
| 503 | `:service_unavailable` | `WeaviateConnectionError` |
| Other | `:unknown_error` | `UnexpectedStatusCodeError` |

Additional Elixir types used:
- `:connection_error` - Transport/connection errors
- `:timeout_error` - Timeout errors

---

## Retry Logic Comparison

### Python Retry (`retry.py`)

```python
class _Retry:
    def __init__(self, n: int = 4):  # Default 4 retries
        self.n = n

    async def awith_exponential_backoff(self, count, error, f, *args):
        try:
            return await f(*args)
        except AioRpcError as e:
            if e.code() != StatusCode.UNAVAILABLE:
                raise e  # Only retry UNAVAILABLE
            await asyncio.sleep(2**count)  # 1s, 2s, 4s, 8s
            if count > self.n:
                raise WeaviateRetryError(str(e), count)
            return await self.awith_exponential_backoff(count + 1, ...)
```

**Limitations**:
- gRPC-only
- Only `StatusCode.UNAVAILABLE` retryable
- No jitter (thundering herd risk)

### Elixir Retry (`retry.ex`)

```elixir
def with_exponential_backoff(fun, opts \\ []) do
  max_attempts = Keyword.get(opts, :max_attempts, 3)
  base_delay = Keyword.get(opts, :base_delay, 100)
  max_delay = Keyword.get(opts, :max_delay, 5000)

  do_retry(fun, 0, max_attempts, base_delay, max_delay)
end

defp do_retry(fun, attempt, max, base, cap) do
  case fun.() do
    {:ok, result} -> {:ok, result}
    {:error, reason} when attempt < max and retryable?(reason) ->
      delay = min(base * :math.pow(2, attempt), cap) |> add_jitter()
      Process.sleep(delay)
      do_retry(fun, attempt + 1, max, base, cap)
    {:error, reason} -> {:error, reason}
  end
end
```

**Retryable HTTP Status Codes**:
- 429 (Too Many Requests)
- 502 (Bad Gateway)
- 503 (Service Unavailable)
- 504 (Gateway Timeout)

**Retryable Connection Errors**:
- `:timeout`
- `:econnrefused`
- `:econnreset`
- `:closed`
- `:nxdomain`

**Advantages over Python**:
- More comprehensive coverage (5 status codes + 5 connection errors)
- Includes jitter (±10%) to prevent thundering herd
- Delay cap prevents unbounded waits
- Protocol-agnostic

---

## Batch Error Tracking

### Python Batch Errors

```python
@dataclass
class ErrorObject:
    message: str
    object_: WeaviateObject
    original_uuid: Optional[UUID]

errors: Dict[int, ErrorObject]  # Keyed by index
uuids: Dict[int, UUID]          # Keyed by index
has_errors: bool
```

### Elixir Batch Errors

```elixir
defmodule WeaviateEx.Batch.ErrorTracking.ErrorObject do
  defstruct [:message, :object, :original_uuid, :retry_count]
end

defmodule WeaviateEx.Batch.ErrorTracking.Results do
  defstruct [
    failed_objects: [],
    failed_references: [],
    successful_uuids: %{},  # index => uuid
    elapsed_seconds: 0.0
  ]
end
```

**Elixir Advantage**: Includes `retry_count` and `elapsed_seconds`

---

## Missing Error Types in Elixir

### High Priority

| Python Exception | Recommended Elixir Type |
|------------------|------------------------|
| `WeaviateQueryError` | `:query_error` |
| `WeaviateBatchError` | `:batch_error` |
| `WeaviateBatchSendError` | `:batch_send_error` |
| `WeaviateBatchStreamError` | `:batch_stream_error` |
| `MissingScopeError` | `:missing_scope` |

### Medium Priority

| Python Exception | Recommended Elixir Type |
|------------------|------------------------|
| `WeaviateGRPCUnavailableError` | `:grpc_unavailable` |
| `WeaviateUnsupportedFeatureError` | `:unsupported_feature` |
| `SchemaValidationError` | `:schema_validation_error` |
| `WeaviateBatchValidationError` | `:batch_validation_error` |

### Low Priority

| Python Exception | Recommended Elixir Type |
|------------------|------------------------|
| `WeaviateStartUpError` | `:startup_error` |
| `WeaviateEmbeddedInvalidVersionError` | `:invalid_version` |
| `EmptyResponseError` | `:empty_response` |
| `WeaviateClosedClientError` | `:closed_client` |

---

## Batch-Specific Retry (`batch_retry.ex`)

### Rate Limit Detection

```elixir
defp rate_limit_error?(error) do
  message = error.message || ""
  String.contains?(String.downcase(message), [
    "rate limit",
    "tokens per min",
    "support@cohere.com",
    "503 error",
    "too many requests",
    "retry after"
  ])
end
```

### Retry Strategy
- Delay: `2^attempt * 1000` ms
- Max retries: 5
- Max backoff: 30 seconds
- Callback support for retry notifications

---

## Summary Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| **Exception Hierarchy** | 30+ types | 1 struct + atoms | HIGH gap |
| **Specific Error Types** | 20+ exceptions | 10 atom types | HIGH gap |
| **Query/Batch Errors** | 5 specific types | Generic | MEDIUM gap |
| **Validation Errors** | 4 specific types | Generic | MEDIUM gap |
| **gRPC Errors** | Full hierarchy | Basic | MEDIUM gap |
| **Connection Errors** | 4 specific types | Generic | MEDIUM gap |
| **Retry (HTTP)** | N/A | 5 codes + 5 reasons | Elixir better |
| **Retry (gRPC)** | UNAVAILABLE only | N/A | Python only |
| **Jitter** | No | Yes (±10%) | Elixir better |
| **Batch Tracking** | Exception-based | Structured Results | Elixir better |
| **Error Codes** | ERROR_CODE_EXPLANATION | None | LOW gap |

---

## Recommendations

### High Priority
1. Add batch-specific error types: `:batch_error`, `:batch_send_error`, `:batch_stream_error`
2. Add query error type: `:query_error`, `:grpc_error`
3. Distinguish validation errors: `:schema_validation_error`, `:batch_validation_error`

### Medium Priority
4. Add `:grpc_unavailable` for gRPC health check failures
5. Add batch-specific metadata to Error struct
6. Implement OAuth error type: `:missing_scope`

### Low Priority
7. Add error code explanations
8. Add configuration error types
9. Consider structured error details

---

## Architectural Note

The architectural differences reflect language paradigms:

**Python**: Exception-based (throwing/catching)
- Rich type hierarchy for type-specific catching
- Detailed context in exception properties

**Elixir**: Tuple-based ({:error, reason})
- Flat error struct with type discrimination
- Better composition with pipes and pattern matching
- More functional and composable

Both approaches are valid; Elixir's is more functional while Python's is more granular.
