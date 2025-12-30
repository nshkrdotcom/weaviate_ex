# Quick Start: Running Integration Tests

This guide covers all methods for running integration tests in the `weaviate_ex` project.

---

## Prerequisites

- Docker and Docker Compose installed
- Elixir 1.16+ and Erlang/OTP 26+
- Project dependencies installed (`mix deps.get`)

---

## Method 1: One-Liner (Recommended)

The simplest way to run integration tests:

```bash
mix weaviate.test
```

This command:
1. Starts all required Weaviate containers
2. Waits for health checks to pass
3. Runs integration tests
4. Stops and cleans up containers

### Options

```bash
# Test against specific Weaviate version
mix weaviate.test -v 1.30.5

# Keep containers running after tests (for debugging)
mix weaviate.test --keep

# Combine options
mix weaviate.test -v 1.30.5 --keep
```

---

## Method 2: Mix Tasks (Manual Control)

For more control over the testing workflow:

### Start Containers

```bash
# Start with default version
mix weaviate.start

# Start with specific version
mix weaviate.start -v 1.30.5
```

### Check Status

```bash
mix weaviate.status
```

Output example:
```
Weaviate Containers Status
==========================

Container: weaviate_ex-weaviate-1
  Status: running
  Ports: 8080:8080, 50051:50051
  Health: healthy

Container: weaviate_ex-weaviate-rbac-1
  Status: running
  Ports: 8092:8080, 50063:50051
  Health: healthy

All services healthy!
```

### Run Tests

```bash
WEAVIATE_INTEGRATION=true mix test --include integration
```

### View Logs (if needed)

```bash
# All container logs
mix weaviate.logs

# Specific service
mix weaviate.logs --service weaviate

# Follow logs in real-time
mix weaviate.logs --follow
```

### Stop Containers

```bash
mix weaviate.stop
```

---

## Method 3: Shell Scripts (Low-Level)

For direct control or debugging infrastructure issues:

### Start All Services

```bash
# Default version (1.28.14)
./ci/start_weaviate.sh

# Specific version
./ci/start_weaviate.sh 1.30.5
```

### Run Tests

```bash
WEAVIATE_INTEGRATION=true mix test --include integration
```

### Stop All Services

```bash
./ci/stop_weaviate.sh
```

---

## Test Categories

### Run All Integration Tests

```bash
WEAVIATE_INTEGRATION=true mix test --include integration
```

### Run Specific Test File

```bash
WEAVIATE_INTEGRATION=true mix test test/integration/collections_integration_test.exs
```

### Run Specific Test

```bash
WEAVIATE_INTEGRATION=true mix test test/integration/objects_integration_test.exs:42
```

### Run Tests by Tag

```bash
# Only search tests
WEAVIATE_INTEGRATION=true mix test --include integration --only search

# Only RBAC tests (requires port 8092)
WEAVIATE_INTEGRATION=true mix test --include integration --only rbac
```

---

## Test Infrastructure Requirements

Different test suites require different Docker services:

| Test Suite | Required Port | Docker Compose File |
|------------|--------------|---------------------|
| Most tests | 8080 | `docker-compose.yml` |
| Auth/RBAC tests | 8092 | `docker-compose-rbac.yml` |
| Backup tests | 8093 | `docker-compose-backup.yml` |
| Cluster tests | 8087-8089 | `docker-compose-cluster.yml` |

When using `mix weaviate.start` or `./ci/start_weaviate.sh`, all services start automatically.

---

## Running Subset of Services

If you only need specific services (faster startup):

```bash
# Only base Weaviate
cd ci && docker compose -f docker-compose.yml up -d

# Only base + RBAC
cd ci && docker compose -f docker-compose.yml -f docker-compose-rbac.yml up -d
```

---

## Troubleshooting

### Containers Won't Start

```bash
# Check for port conflicts
lsof -i :8080
lsof -i :50051

# Force cleanup and restart
./ci/stop_weaviate.sh
docker system prune -f
./ci/start_weaviate.sh
```

### Health Check Failures

```bash
# Check container logs
docker logs weaviate_ex-weaviate-1

# Check if Weaviate is responding
curl http://localhost:8080/v1/.well-known/ready
```

### Tests Hang or Timeout

```bash
# Increase test timeout
WEAVIATE_INTEGRATION=true mix test --include integration --timeout 120000

# Check Weaviate memory usage
docker stats
```

### Connection Refused

Ensure the `WEAVIATE_INTEGRATION` environment variable is set:

```bash
# This will fail (mocks used, no real connection)
mix test --include integration

# This will work (real Weaviate connection)
WEAVIATE_INTEGRATION=true mix test --include integration
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WEAVIATE_INTEGRATION` | `false` | Enable integration test mode |
| `WEAVIATE_HOST` | `localhost` | Weaviate HTTP host |
| `WEAVIATE_PORT` | `8080` | Weaviate HTTP port |
| `WEAVIATE_GRPC_PORT` | `50051` | Weaviate gRPC port |
| `WEAVIATE_SCHEME` | `http` | HTTP scheme |
| `WEAVIATE_VERSION` | `1.28.14` | Docker image version |

---

## CI/CD

Integration tests run automatically in GitHub Actions:

1. **On every push/PR**: Tests against single Weaviate version (1.28.14)
2. **On master/tags**: Tests against version matrix (1.27-1.30)

See `.github/workflows/ci.yml` for details.

---

## Quick Reference Card

```bash
# === RECOMMENDED ===
mix weaviate.test              # Run everything, cleanup after

# === MANUAL CONTROL ===
mix weaviate.start             # Start containers
mix weaviate.status            # Check health
WEAVIATE_INTEGRATION=true mix test --include integration
mix weaviate.stop              # Stop containers

# === LOW-LEVEL ===
./ci/start_weaviate.sh         # Start via script
WEAVIATE_INTEGRATION=true mix test --include integration
./ci/stop_weaviate.sh          # Stop via script

# === UNIT TESTS (no Docker needed) ===
mix test                       # Fast, uses mocks
```

---

## Where is This Documented?

| Location | Content |
|----------|---------|
| `README.md` (lines 2166-2365) | Comprehensive testing section |
| `CONTRIBUTING.md` | Developer setup and testing guide |
| `ci/README.md` | Infrastructure documentation (if exists) |
| This guide | Quick reference for integration tests |
