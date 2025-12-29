# Authentication, Connection & Configuration Gap Analysis

## Executive Summary

This analysis compares Authentication, Connection, and Configuration between the Python client and the Elixir port.

**Overall Feature Parity: ~55%**

The Elixir port implements a hybrid gRPC/HTTP architecture but falls short in several critical areas including proxy support, OIDC token management, and connection pooling configuration.

## Feature Comparison Matrix

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| API Key Auth | Full | Full | PARITY |
| Bearer Token | Full | Full | PARITY |
| OIDC Client Credentials | Full (with token mgmt) | Config only | **GAP** |
| OIDC Password Flow | Full (with token mgmt) | Config only | **GAP** |
| HTTP Pool Config | Full | None | **CRITICAL** |
| gRPC Channel | Comprehensive | Basic | GAP |
| Timeout Config | Multi-level | Multi-level | PARITY |
| Retry Logic | Implemented | Implemented | PARITY |
| Proxy Support | Full (HTTP, HTTPS, gRPC) | None | **CRITICAL** |
| SSL/TLS | Basic | Basic | PARITY |
| Embedded Support | Full | Full | PARITY |
| Health Checks | gRPC protocol | Basic | GAP |
| Connection State | Tracked | Basic | GAP |
| Client Init | Comprehensive | Comprehensive | PARITY |

---

## 1. Authentication Methods

### API Key Authentication
**Both**: Fully implemented and equivalent
```python
# Python
Auth.api_key(api_key="...")
```
```elixir
# Elixir
Auth.api_key("...")
```

### Bearer Token Authentication
**Both**: Fully implemented
- Python defaults expires_in to 60s
- Elixir defaults to nil

### OIDC Client Credentials Flow

**Python (Complete)**
```python
Auth.client_credentials(client_secret, scope=None)
# Uses authlib library (AsyncOAuth2Client, OAuth2Client)
# Automatic token fetching
# Token refresh mechanism
```

**Elixir (Basic)**
```elixir
Auth.client_credentials(client_id, client_secret, opts)
# Returns map structure
# NO TOKEN MANAGEMENT
```

**Missing in Elixir:**
- No automatic token fetching logic
- No token refresh mechanism
- No OIDC configuration retrieval from Weaviate
- No token endpoint discovery

### OIDC Resource Owner Password Flow

**Python (Complete)**
- Uses authlib for token fetching
- Validates server supports password grant type
- Rejects Microsoft/Azure (not supported)

**Elixir (Basic)**
- Stores credentials only
- No automatic token exchange

---

## 2. Connection Pooling and Management

### HTTP Connection Pooling

**Python (Configurable)**
```python
ConnectionConfig:
  session_pool_connections: 20
  session_pool_maxsize: 100
  session_pool_max_retries: 3
  session_pool_timeout: 5
```

**Elixir**
- Uses Finch HTTP client with hardcoded settings
- **No configurable pool parameters**

**Gap: CRITICAL**
- No pool size configuration
- No max connections configuration
- No keepalive connection configuration

---

## 3. gRPC Channel Management

### Python
- Configurable message size (MAX_GRPC_MESSAGE_SIZE = 104MB)
- Custom options: grpc.max_send/receive_message_length
- grpc.default_authority
- grpc.http_proxy support

### Elixir
- Configurable max_message_size (default 100MB)
- Uses Gun HTTP client adapter
- TLS support via GRPC.Credential

**Gap**: Python has explicit proxy configuration for gRPC

---

## 4. HTTP Client Configuration

### Python (Comprehensive)
```python
# Per-method timeout configuration:
Query operations: 30s default
Insert/batch operations: 90s default
Init timeout: 2s default

# Automatic headers
Content-Type: application/json
X-Weaviate-Cluster-URL for WCD domains
User-Agent version tracking
```

### Elixir (Basic)
- Single configurable timeout (default 60s)
- No per-method timeout differentiation
- Limited header management

---

## 5. Timeout Configuration

### Python (Multi-Component)
```python
Timeout model:
  connect: 5s
  write: 5s
  read: operation-specific
  pool: 5s

# Three levels:
init: 2s
query: 30s
insert: 90s
```

### Elixir (Multi-Level)
```elixir
Timeout.init/0    # 2s
Timeout.query/0   # 30s
Timeout.insert/0  # 90s
```

**Status**: Mostly parity, Python has pool timeout component

---

## 6. Retry Configuration

### Python
- 4 retries for search, 3 for others
- Handles gRPC status codes (UNAVAILABLE, RESOURCE_EXHAUSTED)
- Different retry counts per operation type

### Elixir
```elixir
Retry module:
  max_retries: 3 (default)
  base_delay: 100ms
  max_delay: 5000ms
  jitter: +/- 10%

Retryable errors:
  HTTP 429, 502, 503, 504
  gRPC UNAVAILABLE, RESOURCE_EXHAUSTED, ABORTED, DEADLINE_EXCEEDED
  Connection errors
```

**Status**: Elixir's retry is more configurable

---

## 7. Proxy Support

### Python (Full)
```python
Proxies model:
  http: Optional[str]
  https: Optional[str]
  grpc: Optional[str]

# Environment variable support
HTTP_PROXY, HTTPS_PROXY, GRPC_PROXY
# Case-insensitive env var lookup
```

### Elixir
**COMPLETELY MISSING**
- No HTTP proxy support
- No HTTPS proxy support
- No gRPC proxy support
- No environment variable reading

**Gap: CRITICAL**

---

## 8. SSL/TLS Configuration

### Both
- HTTP secure via scheme detection
- gRPC TLS via credentials
- Automatic TLS selection based on port 443

### Missing in Both
- Custom CA bundle paths
- Client certificate support
- SSL context customization

---

## 9. Embedded Weaviate Support

### Python
- `EmbeddedV4` class
- Automatic binary download/caching
- Version management
- Startup period configuration (default 10s)

### Elixir
- `Embedded` module
- GitHub releases API for version lookup
- Platform detection (Linux, Darwin)
- Ready timeout (default 30s)
- Checks both HTTP and gRPC readiness

**Status**: PARITY (different implementations)

---

## 10. Connection Health Checks

### Python
- `_ping_grpc()` uses gRPC Health v1 protocol
- HTTP readiness check: `/.well-known/ready`
- Response validation (SERVING status)
- Automatic health check on client initialization

### Elixir
- `Channel.connected?()` checks process/reference alive
- HTTP `/v1/.well-known/ready` check (Embedded)
- TCP port connectivity check for gRPC
- **No gRPC Health protocol implementation**

**Gap**: No gRPC Health protocol in Elixir

---

## 11. Client Initialization Options

### Python
```python
connect_to_weaviate_cloud()
connect_to_local()
connect_to_custom()
connect_to_embedded()
use_async_with_*()  # Async variants

AdditionalConfig:
  connection: ConnectionConfig
  proxies: Proxies
  timeout_: Timeout
  trust_env: bool
```

### Elixir
```elixir
Connect.to_weaviate_cloud()
Connect.to_local()
Connect.to_custom()
Connect.to_embedded()

Client.Config:
  base_url, grpc_host, grpc_port
  api_key, timeout
  grpc_max_message_size
```

**Missing in Elixir:**
- Connection pooling config
- Proxy configuration
- Trust environment flag
- Async variants

---

## Priority Implementation Recommendations

### Critical (Must Implement)

1. **OIDC Token Management**
   - Implement token exchange for client_credentials
   - Add token refresh mechanism
   - Add OIDC configuration discovery

2. **HTTP Proxy Support**
   - Add HTTP_PROXY, HTTPS_PROXY support
   - Add gRPC proxy support
   - Read from environment variables

3. **Connection Pooling Configuration**
   - Expose pool size parameters
   - Add keepalive configuration
   - Add max connections setting

4. **gRPC Health Checks**
   - Implement gRPC Health v1 protocol
   - Add health check on client initialization

### High Priority

5. **Per-Method Timeout Configuration**
   - Different timeouts for init/query/insert

6. **Connection State Tracking**
   - Track server version and capabilities
   - Track gRPC max message size

### Medium Priority

7. **SSL/TLS Customization**
   - Custom CA bundle paths
   - Client certificate support

---

## Conclusion

The Elixir port successfully implements core authentication and connection management but lacks critical features for enterprise deployments: proxy support, OIDC token management, and connection pooling configuration. The embedded Weaviate support is well-implemented with both ports achieving feature parity.
