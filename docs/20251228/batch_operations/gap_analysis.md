# Batch Operations Gap Analysis

## Python Weaviate Client vs Elixir WeaviateEx

**Date:** 2025-12-28
**Python Client Version:** v4.x (collections API)
**Elixir Port:** WeaviateEx

---

## Executive Summary

The Elixir implementation provides a solid foundation for batch operations with support for fixed-size, dynamic, and rate-limited batching modes. However, several advanced Python features are missing, particularly around gRPC streaming, server-side batching, concurrent threading, and sophisticated error recovery.

---

## 1. Batch Insert

### Python Implementation

**Location:** `weaviate/collections/batch/base.py`, `weaviate/collections/batch/grpc_batch.py`

**Features:**
- Object insertion with auto-generated UUIDs
- Pydantic-based validation (`BatchObject` model)
- Support for properties, vectors, references, and tenants
- Named vectors support (multi-vector per object)
- Internal retry counting (`retry_count` field)
- Index tracking for error mapping
- Batch size up to 1000 objects (configurable `MAX_BATCH_SIZE`)
- Concurrent request support (up to 10 via `ThreadPoolExecutor`)
- Automatic queue management with blocking when overloaded
- gRPC-based insertion with protobuf serialization

### Elixir Implementation

**Location:** `lib/weaviate_ex/batch.ex`, `lib/weaviate_ex/batch/fixed_size.ex`, `lib/weaviate_ex/api/batch.ex`

**Features:**
- Object insertion with auto-generated UUIDs (`WeaviateEx.Types.UUID`)
- Properties, vectors, tenants supported
- Batch size configurable (default 100)
- gRPC and HTTP fallback support
- Three batching modes: fixed, dynamic, rate-limited
- Context manager pattern (`with_batch/3`)
- Error tracking via `Results` struct

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| Named Vectors | Python supports `Dict[str, vector]` for named vectors | High |
| Concurrent Requests | Python uses `ThreadPoolExecutor` with 2-10 concurrent requests | High |
| Pydantic Validation | Python has comprehensive input validation | Medium |
| Retry Count Tracking | Python tracks retry count per object | Medium |
| Queue Blocking | Python blocks when queue is overloaded | Low |

---

## 2. Batch Delete

### Python Implementation

**Location:** `weaviate/collections/batch/grpc_batch_delete.py`

**Features:**
- gRPC-based batch delete
- Filter-based deletion with `_FilterToGRPC` converter
- Verbose/minimal output modes
- Dry run support
- Tenant support
- Returns `DeleteManyReturn` with matches, successful, failed counts
- Per-object status when verbose

### Elixir Implementation

**Location:** `lib/weaviate_ex/api/batch.ex`, `lib/weaviate_ex/batch/delete_result.ex`

**Features:**
- gRPC and HTTP support
- Filter-based deletion
- Dry run support
- Verbose mode with per-object results
- `DeleteResult` struct with status helpers
- Tenant support

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| Filter Conversion Parity | Python has comprehensive `_FilterToGRPC` converter | Medium |
| Delete by ID List | Python supports direct UUID list deletion | Low |

---

## 3. Batch Reference

### Python Implementation

**Location:** `weaviate/collections/batch/base.py`, `weaviate/collections/batch/rest.py`

**Features:**
- REST-based reference insertion (not gRPC)
- Multi-target references (`ReferenceToMulti`)
- Beacon URL construction
- Reference queue with UUID lookup to avoid sending refs before objects
- Concurrent sending with objects
- Tenant support
- Error tracking with `BatchReferenceReturn`

### Elixir Implementation

**Location:** `lib/weaviate_ex/batch/fixed_size.ex`, `lib/weaviate_ex/batch.ex`

**Features:**
- HTTP-based reference insertion
- Single-target and multi-target references
- Beacon URL construction
- Tenant support
- Reference buffering

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| UUID Lookup | Python tracks pending object UUIDs to avoid ref race conditions | High |
| gRPC Reference Batching | Python sends refs via REST, but Elixir could use gRPC | Medium |
| Concurrent Reference Sending | Python sends refs concurrently with objects | Medium |

---

## 4. Dynamic Batching

### Python Implementation

**Location:** `weaviate/collections/batch/base.py` (`_DynamicBatching`, `__dynamic_batching`)

**Features:**
- Server queue depth monitoring via `/nodes` endpoint
- Automatic batch size adjustment (10-1000 range)
- Rate-based adjustment with `batch_length / rate` ratio
- Concurrent requests adjustment (2-10)
- Scale-up cooldown timer
- Rate queue (50-entry deque) for averaging
- Vectorizer batching mode with different step size (48)
- Async indexing detection (auto-switches to fixed 1000/10)

### Elixir Implementation

**Location:** `lib/weaviate_ex/batch/dynamic.ex`

**Features:**
- GenServer-based dynamic batcher
- Batch size adjustment based on reported queue size
- Configurable min/max batch size (10-1000)
- Concurrent requests support
- Queue threshold-based adjustment

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| Server Queue Monitoring | Python actively polls `/nodes` for `batchStats` | Critical |
| Rate-Based Adjustment | Python uses `ratePerSecond` for precise tuning | High |
| Vectorizer Batching Mode | Python has special mode for slow vectorizers | High |
| Async Indexing Detection | Python detects and switches mode automatically | High |
| Scale-up Cooldown | Python prevents rapid scaling oscillation | Medium |
| Rate Queue Averaging | Python uses 50-sample moving average | Medium |

---

## 5. Rate Limiting

### Python Implementation

**Location:** `weaviate/collections/batch/base.py` (`_RateLimitedBatching`)

**Features:**
- Configurable `requests_per_minute`
- 62-second base window (buffer for per-minute calculation)
- Multiple batch distribution across time window
- Automatic rate limit error detection (OpenAI, Cohere patterns)
- Dynamic base time adjustment on rate limit hits
- Sleep-based throttling between batches
- Re-add objects to queue on rate limit with incremented retry count
- Max 5 retries per object before giving up

### Elixir Implementation

**Location:** `lib/weaviate_ex/batch/rate_limited.ex`

**Features:**
- GenServer-based rate limiter
- Configurable `requests_per_minute`
- 60-second sliding window
- Request time tracking and cleanup
- Wait for capacity before sending
- Retry support with exponential backoff

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| Provider-Specific Detection | Python detects OpenAI/Cohere/Huggingface rate limits | High |
| Object Re-queue on Rate Limit | Python re-adds failed objects to front of queue | High |
| Dynamic Base Time Adjustment | Python increases window on repeated failures | Medium |
| Per-Object Retry Tracking | Python tracks and limits retries per object | Medium |

---

## 6. Fixed Size Batching

### Python Implementation

**Location:** `weaviate/collections/batch/base.py` (`_FixedSizeBatching`)

**Features:**
- Configurable `batch_size` (default 100)
- Configurable `concurrent_requests` (default 2)
- Simple fixed-size strategy
- Works with both objects and references

### Elixir Implementation

**Location:** `lib/weaviate_ex/batch/fixed_size.ex`

**Features:**
- Configurable `batch_size` (default 100)
- Configurable `concurrent_requests` (default 2)
- Buffer management with `get_batches/1`
- Reference batching support
- `ready_to_send?/1` helper

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| None Identified | Elixir implementation is feature-complete | N/A |

---

## 7. Error Handling

### Python Implementation

**Location:** `weaviate/collections/batch/base.py`, `weaviate/collections/classes/batch.py`

**Features:**
- `ErrorObject` and `ErrorReference` dataclasses
- `BatchObjectReturn` with uuids/errors dictionaries
- `BatchReferenceReturn` with errors dictionary
- `BatchResult` combining both
- `MAX_STORED_RESULTS = 100000` limit to prevent memory issues
- Error logging with rate limiting (30 log messages max)
- Background thread exception propagation
- `WeaviateBatchValidationError`, `WeaviateBatchStreamError` exceptions
- Automatic retry for transient errors (rate limits, 503s)
- Re-queue of failed objects for retry

### Elixir Implementation

**Location:** `lib/weaviate_ex/batch/error_tracking.ex`, `lib/weaviate_ex/batch/batch_retry.ex`

**Features:**
- `ErrorObject` and `ErrorReference` structs
- `Results` struct with `failed_objects`, `failed_references`, `successful_uuids`
- `has_errors?/1`, `number_errors/1` helpers
- Statistics computation
- `BatchRetry.with_retry/2` for retry logic
- Exponential backoff calculation
- Rate limit pattern detection

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| Memory Limiting | Python caps stored results at 100,000 | Medium |
| Error Log Rate Limiting | Python limits to 30 error logs | Low |
| Object Re-queue on Error | Python puts failed objects back in queue | High |
| Custom Exception Types | Python has batch-specific exceptions | Low |

---

## 8. Batch Callbacks

### Python Implementation

**Location:** `weaviate/collections/batch/base.py`, `weaviate/collections/batch/batch_wrapper.py`

**Features:**
- `on_flush` callback (implicit via context manager pattern)
- `failed_objects` property on wrapper
- `failed_references` property on wrapper
- `results` property on wrapper
- `number_errors` property on batch
- `wait_for_vector_indexing` method

### Elixir Implementation

**Location:** `lib/weaviate_ex/batch.ex`, `lib/weaviate_ex/batch/dynamic.ex`

**Features:**
- `:on_flush` callback option
- `:on_error` callback option
- `wait_for_vector_indexing/3` function
- Results struct with all aggregated data

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| Progress Callbacks | Python could report batch progress | Low |
| Wrapper Properties | Python provides direct property access on wrapper | Low |

---

## 9. Context Manager

### Python Implementation

**Location:** `weaviate/collections/batch/batch_wrapper.py`, `weaviate/collections/batch/collection.py`

**Features:**
- `__enter__` / `__exit__` protocol
- `_ContextManagerWrapper` generic class
- Automatic flush on exit
- Background thread management
- `_start()` / `_shutdown()` lifecycle hooks
- `dynamic()`, `fixed_size()`, `rate_limit()` factory methods
- Vectorizer batching detection (checks collection config)

### Elixir Implementation

**Location:** `lib/weaviate_ex/batch.ex`

**Features:**
- `with_batch/3` callback-based context
- Automatic flush on callback completion
- `try`/`catch` cleanup for dynamic/rate-limited modes
- Mode selection via `:mode` option
- GenServer lifecycle management

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| Vectorizer Detection | Python auto-detects vectorizer for batch mode | Medium |
| True Context Manager | Python uses `with` statement directly | Low |

---

## 10. gRPC Batch

### Python Implementation

**Location:** `weaviate/collections/batch/grpc_batch.py`, `weaviate/collections/batch/base.py`

**Features:**
- `_BatchGRPC` class for gRPC operations
- Protobuf object construction (`grpc_object`, `grpc_objects`)
- Protobuf reference construction (`grpc_reference`, `grpc_references`)
- Streaming batch support (`stream` method)
- `BatchStreamRequest` / `BatchStreamReply` protocol
- Server-side batching mode (`_ServerSideBatching`)
- Stream request generation with size chunking
- Backoff handling from server
- Graceful shutdown with `shutting_down` / `shutdown` messages
- Reconnection logic with exponential backoff
- Consistency level ALL handling (waits for all nodes healthy)
- Background send/receive threads
- Object/reference cache for retry on stream failure
- gRPC max message size handling

### Elixir Implementation

**Location:** `lib/weaviate_ex/grpc/services/batch.ex`, `lib/weaviate_ex/api/batch.ex`

**Features:**
- `insert_objects/3` - unary gRPC batch insert
- `insert_references/3` - unary gRPC batch references
- `delete_objects/4` - gRPC batch delete with filters
- Protobuf construction for objects and references
- Vector byte encoding
- Consistency level mapping
- Error conversion from gRPC errors

### Gaps

| Gap | Description | Criticality |
|-----|-------------|-------------|
| Streaming Batch | Python has bidirectional streaming for server-side batching | Critical |
| Server-Side Batching | Python supports Weaviate 1.34+ streaming mode | Critical |
| Backoff Message Handling | Python adjusts batch size based on server feedback | High |
| Stream Reconnection | Python handles graceful and ungraceful shutdown | High |
| Object Cache for Retry | Python caches objects to retry on stream failure | High |
| gRPC Max Message Chunking | Python chunks based on message size limits | Medium |
| Consistency Level ALL Handling | Python waits for all nodes on reconnect | Medium |

---

## Summary: Criticality Distribution

| Criticality | Count | Key Missing Features |
|-------------|-------|---------------------|
| Critical | 3 | Server queue monitoring, gRPC streaming, server-side batching |
| High | 12 | Concurrent requests, named vectors, rate limit detection, object re-queue, stream reconnection |
| Medium | 11 | Various validation, adjustment algorithms, caching |
| Low | 5 | Logging limits, exception types, progress callbacks |

---

## Recommended Implementation Priority

### Phase 1: Critical (Immediate)
1. **Server Queue Monitoring** - Poll `/nodes` endpoint for `batchStats`
2. **gRPC Streaming Support** - Implement `BatchStreamRequest`/`BatchStreamReply`
3. **Server-Side Batching Mode** - Enable experimental streaming for Weaviate 1.34+

### Phase 2: High Priority (Short-term)
4. **Concurrent Request Handling** - Use `Task.async_stream` for parallel batches
5. **Named Vectors Support** - Support `%{name => vector}` format
6. **Provider-Specific Rate Limit Detection** - OpenAI, Cohere, Huggingface patterns
7. **Object Re-queue on Failure** - Re-add failed objects to front of buffer
8. **UUID Lookup for References** - Track pending objects to avoid race conditions
9. **Stream Reconnection Logic** - Handle graceful/ungraceful shutdowns

### Phase 3: Medium Priority (Mid-term)
10. **Vectorizer Detection** - Auto-detect collection vectorizer configuration
11. **Rate-Based Batch Adjustment** - Use `ratePerSecond` for tuning
12. **Async Indexing Detection** - Switch to high-throughput mode automatically
13. **gRPC Message Size Chunking** - Respect max message size limits
14. **Memory Limiting** - Cap stored results to prevent OOM

### Phase 4: Low Priority (Long-term)
15. **Error Log Rate Limiting** - Prevent log spam
16. **Custom Exception Types** - Batch-specific error structs
17. **Progress Callbacks** - Report batch completion progress

---

## Files Analyzed

### Python
- `weaviate-python-client/weaviate/collections/batch/__init__.py`
- `weaviate-python-client/weaviate/collections/batch/base.py`
- `weaviate-python-client/weaviate/collections/batch/collection.py`
- `weaviate-python-client/weaviate/collections/batch/client.py`
- `weaviate-python-client/weaviate/collections/batch/grpc_batch.py`
- `weaviate-python-client/weaviate/collections/batch/grpc_batch_delete.py`
- `weaviate-python-client/weaviate/collections/batch/batch_wrapper.py`
- `weaviate-python-client/weaviate/collections/batch/rest.py`
- `weaviate-python-client/weaviate/collections/classes/batch.py`

### Elixir
- `lib/weaviate_ex/batch.ex`
- `lib/weaviate_ex/api/batch.ex`
- `lib/weaviate_ex/batch/dynamic.ex`
- `lib/weaviate_ex/batch/rate_limited.ex`
- `lib/weaviate_ex/batch/fixed_size.ex`
- `lib/weaviate_ex/batch/batch_retry.ex`
- `lib/weaviate_ex/batch/error_tracking.ex`
- `lib/weaviate_ex/batch/delete_result.ex`
- `lib/weaviate_ex/grpc/services/batch.ex`
