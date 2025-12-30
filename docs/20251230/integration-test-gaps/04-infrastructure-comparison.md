# Infrastructure Comparison: Python vs Elixir

**Status**: Full Parity Achieved

---

## Overview

The `weaviate_ex` Elixir client has successfully mirrored the Docker Compose infrastructure from the canonical Python client. This document provides a side-by-side reference.

---

## Docker Compose Files

### Side-by-Side Mapping

| Python Client | Elixir Client | Purpose | Status |
|---------------|---------------|---------|--------|
| `ci/docker-compose.yml` | `ci/docker-compose.yml` | Base Weaviate instance | Identical |
| `ci/docker-compose-cluster.yml` | `ci/docker-compose-cluster.yml` | 3-node RAFT cluster | Identical |
| `ci/docker-compose-async.yml` | `ci/docker-compose-async.yml` | Async indexing | Identical |
| `ci/docker-compose-rbac.yml` | `ci/docker-compose-rbac.yml` | RBAC/Auth testing | Identical |
| `ci/docker-compose-backup.yml` | `ci/docker-compose-backup.yml` | Backup module | Identical |
| `ci/docker-compose-modules.yml` | `ci/docker-compose-modules.yml` | AI modules | Identical |
| `ci/docker-compose-proxy.yml` | `ci/docker-compose-proxy.yml` | gRPC proxy | Identical |
| `ci/docker-compose-okta-users.yml` | `ci/docker-compose-okta-users.yml` | OIDC user auth | Identical |
| `ci/docker-compose-okta-cc.yml` | `ci/docker-compose-okta-cc.yml` | OIDC client credentials | Identical |
| `ci/docker-compose-wcs.yml` | `ci/docker-compose-wcs.yml` | Cloud service simulation | Identical |

---

## Port Assignments

### Complete Port Reference

| Compose File | HTTP Port | gRPC Port | Service |
|--------------|-----------|-----------|---------|
| `docker-compose.yml` | 8080 | 50051 | Base instance |
| `docker-compose-modules.yml` | 8086 | 50057 | AI modules |
| `docker-compose-cluster.yml` | 8087, 8088, 8089 | 50058, 50059, 50060 | Cluster nodes |
| `docker-compose-async.yml` | 8090 | 50061 | Async indexing |
| `docker-compose-rbac.yml` | 8092 | 50063 | RBAC/Auth |
| `docker-compose-backup.yml` | 8093 | 50065 | Backup |
| `docker-compose-proxy.yml` | 8075 | 10000 | gRPC proxy |
| `docker-compose-okta-cc.yml` | 8082 | - | OIDC CC |
| `docker-compose-okta-users.yml` | 8083 | - | OIDC Users |
| `docker-compose-wcs.yml` | 8085 | 50056 | WCS simulation |

---

## Shell Scripts

### Script Comparison

| Python | Elixir | Function | Parity |
|--------|--------|----------|--------|
| `ci/compose.sh` | `ci/compose.sh` | Helper functions for compose management | Yes |
| `ci/start_weaviate.sh` | `ci/start_weaviate.sh` | Start all compose files, health check | Yes |
| `ci/stop_weaviate.sh` | `ci/stop_weaviate.sh` | Stop containers, cleanup data | Yes |
| `ci/start_weaviate_jt.sh` | `ci/start_weaviate_jt.sh` | Journey test variant (async only) | Yes |

### Script Functions Reference

#### `compose.sh`

```bash
# List all docker-compose files
ls_compose()

# Execute command across all compose files
exec_all <command>

# Start all services detached
compose_up_all

# Stop all services
compose_down_all

# Wait for services to be ready
wait <port>

# All Weaviate ports to check
all_weaviate_ports=("8080" "8086" "8087" ...)
```

#### `start_weaviate.sh`

```bash
#!/bin/bash

# Accept version parameter (default: 1.28.14)
WEAVIATE_VERSION="${1:-1.28.14}"

# Export for compose files
export WEAVIATE_VERSION

# Source helper functions
source "$(dirname "$0")/compose.sh"

# Cleanup any existing containers
compose_down_all

# Remove data directory
rm -rf weaviate-data

# Start all services
compose_up_all

# Health check loop
for port in "${all_weaviate_ports[@]}"; do
    echo "Waiting for Weaviate on port $port..."
    for i in {1..60}; do
        if curl -sf "http://localhost:$port/v1/.well-known/ready" > /dev/null 2>&1; then
            echo "Weaviate ready on port $port"
            break
        fi
        sleep 2
    done
done

echo "All Weaviate instances ready!"
```

#### `stop_weaviate.sh`

```bash
#!/bin/bash

source "$(dirname "$0")/compose.sh"

# Stop all containers
compose_down_all

# Clean up data
rm -rf weaviate-data

echo "Cleanup complete"
```

---

## Base Compose Configuration

### `docker-compose.yml` Details

```yaml
version: '3.8'

services:
  weaviate:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8080:8080"
      - "50051:50051"
    environment:
      # Core settings
      QUERY_DEFAULTS_LIMIT: 25
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: "true"
      PERSISTENCE_DATA_PATH: /var/lib/weaviate

      # Vectorizer
      DEFAULT_VECTORIZER_MODULE: text2vec-contextionary

      # Modules
      ENABLE_MODULES: >-
        text2vec-contextionary,
        backup-filesystem,
        generative-openai,
        reranker-cohere

      # Backup
      BACKUP_FILESYSTEM_PATH: /var/lib/weaviate/backups

      # Cluster
      CLUSTER_HOSTNAME: node1

      # gRPC
      GRPC_PORT: 50051
      GRPC_MAX_MESSAGE_SIZE: 104857600  # 100MB

      # Timeouts
      QUERY_MAXIMUM_RESULTS: 100000

      # Telemetry
      DISABLE_TELEMETRY: "true"
    volumes:
      - ./weaviate-data:/var/lib/weaviate
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/v1/.well-known/ready"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 30s

  contextionary:
    image: semitechnologies/contextionary:en0.16.0-v1.2.0
    ports:
      - "9999:9999"
    environment:
      OCCURRENCE_WEIGHT_LINEAR_FACTOR: 0.75
```

---

## RBAC Compose Configuration

### `docker-compose-rbac.yml` Details

```yaml
version: '3.8'

services:
  weaviate-rbac:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8092:8080"
      - "50063:50051"
    environment:
      # Authentication
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: "false"
      AUTHENTICATION_APIKEY_ENABLED: "true"
      AUTHENTICATION_APIKEY_ALLOWED_KEYS: "admin-key,read-only-key,custom-key"
      AUTHENTICATION_APIKEY_USERS: "admin-user,read-user,custom-user"

      # Authorization (RBAC)
      AUTHORIZATION_ENABLE_RBAC: "true"
      AUTHORIZATION_ADMIN_USERS: "admin-user"

      # OIDC (optional)
      AUTHENTICATION_OIDC_ENABLED: "false"

      # Other settings
      QUERY_DEFAULTS_LIMIT: 25
      PERSISTENCE_DATA_PATH: /var/lib/weaviate
      DEFAULT_VECTORIZER_MODULE: none
      CLUSTER_HOSTNAME: node-rbac
      GRPC_PORT: 50051
```

---

## Cluster Compose Configuration

### `docker-compose-cluster.yml` Details

```yaml
version: '3.8'

services:
  weaviate-node1:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8087:8080"
      - "50058:50051"
    environment:
      CLUSTER_HOSTNAME: node1
      CLUSTER_GOSSIP_BIND_PORT: 7100
      CLUSTER_DATA_BIND_PORT: 7101
      CLUSTER_JOIN: "weaviate-node1:7100,weaviate-node2:7100,weaviate-node3:7100"
      RAFT_BOOTSTRAP_EXPECT: 3
      # ... other settings

  weaviate-node2:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8088:8080"
      - "50059:50051"
    environment:
      CLUSTER_HOSTNAME: node2
      # ... similar settings

  weaviate-node3:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8089:8080"
      - "50060:50051"
    environment:
      CLUSTER_HOSTNAME: node3
      # ... similar settings
```

---

## Test-to-Infrastructure Mapping

### Which Tests Need Which Compose Files

| Test Suite | Required Compose Files | Ports Used |
|------------|----------------------|------------|
| `health_integration_test.exs` | `docker-compose.yml` | 8080 |
| `collections_integration_test.exs` | `docker-compose.yml` | 8080 |
| `objects_integration_test.exs` | `docker-compose.yml` | 8080 |
| `batch_integration_test.exs` | `docker-compose.yml` | 8080 |
| `query_integration_test.exs` | `docker-compose.yml` | 8080 |
| `search_integration_test.exs` | `docker-compose.yml` | 8080 |
| `filter_integration_test.exs` | `docker-compose.yml` | 8080 |
| `aggregate_integration_test.exs` | `docker-compose.yml` | 8080 |
| `auth_integration_test.exs` | `docker-compose-rbac.yml` | 8092 |
| `backup_integration_test.exs` | `docker-compose-backup.yml` | 8093 |

---

## Elixir Advantages: Mix Tasks

The Elixir client provides additional automation not present in Python:

### Mix Tasks (Elixir Only)

```bash
# Start all Weaviate containers
mix weaviate.start
mix weaviate.start -v 1.30.5  # Specific version

# Stop containers
mix weaviate.stop

# Check status
mix weaviate.status

# View logs
mix weaviate.logs
mix weaviate.logs --service weaviate
mix weaviate.logs --follow

# One-shot test run
mix weaviate.test
mix weaviate.test --keep  # Keep containers after
```

### Python Equivalent (Shell Only)

```bash
# Python requires manual shell commands
./ci/start_weaviate.sh 1.30.5
pytest integration/
./ci/stop_weaviate.sh
```

---

## Infrastructure Parity Summary

| Component | Python | Elixir | Parity |
|-----------|--------|--------|--------|
| Docker Compose files | 10 | 10 | 100% |
| Shell scripts | 4 | 4 | 100% |
| Port assignments | Same | Same | 100% |
| Health checking | curl polling | curl polling | 100% |
| Version parameterization | `$WEAVIATE_VERSION` | `$WEAVIATE_VERSION` | 100% |
| Data cleanup | `rm -rf weaviate-data` | `rm -rf weaviate-data` | 100% |
| Mix task automation | N/A | Yes | +Bonus |

**Conclusion**: Infrastructure is at complete parity, with Elixir having superior automation via Mix tasks.
