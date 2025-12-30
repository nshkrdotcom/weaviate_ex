# Docker Stack Management

## Python Client Docker Infrastructure

The Python client has a comprehensive Docker infrastructure for testing. Here's what we need to replicate:

### Docker Compose Files in Python Client

Located in `/weaviate-python-client/ci/`:

| File | Purpose | Ports | Key Features |
|------|---------|-------|--------------|
| `docker-compose.yml` | Base config | 8080/50051 | Contextionary, backup-filesystem |
| `docker-compose-cluster.yml` | 3-node cluster | 8087-8089/50058-50060 | RAFT consensus testing |
| `docker-compose-async.yml` | Async indexing | 8090/50061 | `ASYNC_INDEXING: 'true'` |
| `docker-compose-rbac.yml` | RBAC/Auth | 8092/50063 | API key auth, RBAC, OIDC |
| `docker-compose-backup.yml` | Backup testing | 8093/50065 | Backup filesystem module |
| `docker-compose-proxy.yml` | gRPC proxy | 8075/10000 | Envoy proxy for gRPC tunneling |
| `docker-compose-okta-users.yml` | OIDC auth | 8083 | Okta user authentication |
| `docker-compose-okta-cc.yml` | OIDC auth | 8082 | Okta client credentials |
| `docker-compose-modules.yml` | Module testing | 8086/50057 | OpenAI, Cohere, Colbert modules |
| `docker-compose-wcs.yml` | WCS testing | 8085/50056 | Cloud service simulation |

### Shell Scripts in Python Client

#### `ci/compose.sh` - Helper Functions
```bash
#!/bin/bash

ls_compose() {
    ls -1 "$SCRIPT_DIR"/docker-compose*.yml
}

exec_all() {
    for f in $(ls_compose); do
        echo "Running: docker compose -f $f $@"
        docker compose -f "$f" "$@"
    done
}

compose_up_all() {
    exec_all "up -d"
}

compose_down_all() {
    exec_all "down --remove-orphans"
}

all_weaviate_ports() {
    echo "8090 8093 8087 8088 8089 8086 8082 8083 8075 8092 8085 8080"
}

wait() {
    for port in $(all_weaviate_ports); do
        echo -n "Waiting for Weaviate on port $port..."
        for i in {1..60}; do
            if curl -sf "http://localhost:$port/v1/.well-known/ready" > /dev/null 2>&1; then
                echo " ready!"
                break
            fi
            sleep 1
        done
    done
}
```

#### `ci/start_weaviate.sh`
```bash
#!/bin/bash
export WEAVIATE_VERSION=${1:-latest}
source $(dirname "$0")/compose.sh
compose_down_all
rm -rf weaviate-data
compose_up_all
wait
```

#### `ci/stop_weaviate.sh`
```bash
#!/bin/bash
source $(dirname "$0")/compose.sh
compose_down_all
rm -rf weaviate-data
```

---

## Elixir Client Docker Setup Plan

### Current State

We have only one basic `docker-compose.yml`:
```yaml
services:
  weaviate:
    image: cr.weaviate.io/semitechnologies/weaviate:1.28.14
    ports:
      - 8080:8080
      - 40051:50051
    environment:
      QUERY_DEFAULTS_LIMIT: 25
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      DEFAULT_VECTORIZER_MODULE: 'none'
      ENABLE_API_BASED_MODULES: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      CLUSTER_HOSTNAME: 'node1'
    volumes:
      - weaviate_data:/var/lib/weaviate
    restart: "no"
```

### Proposed Directory Structure

```
weaviate_ex/
├── ci/
│   ├── docker/
│   │   ├── docker-compose.yml           # Base configuration
│   │   ├── docker-compose-cluster.yml   # 3-node cluster
│   │   ├── docker-compose-async.yml     # Async indexing
│   │   ├── docker-compose-rbac.yml      # RBAC/Auth testing
│   │   ├── docker-compose-backup.yml    # Backup/restore
│   │   ├── docker-compose-modules.yml   # AI module testing
│   │   └── docker-compose-proxy.yml     # Proxy testing
│   ├── compose.sh                       # Helper functions
│   ├── start_weaviate.sh               # Start all containers
│   ├── stop_weaviate.sh                # Stop all containers
│   └── wait_for_weaviate.exs           # Elixir health check script
├── docker-compose.yml                   # Dev convenience (keep existing)
└── ...
```

### Docker Compose Files to Create

#### 1. `ci/docker/docker-compose.yml` (Base)
```yaml
services:
  weaviate:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    command:
      - --host=0.0.0.0
      - --port=8080
      - --scheme=http
    ports:
      - "8080:8080"
      - "50051:50051"
    restart: on-failure:0
    environment:
      QUERY_DEFAULTS_LIMIT: 25
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      DEFAULT_VECTORIZER_MODULE: 'none'
      ENABLE_API_BASED_MODULES: 'true'
      CLUSTER_HOSTNAME: 'node1'
      ENABLE_MODULES: 'backup-filesystem,generative-dummy,reranker-dummy'
      BACKUP_FILESYSTEM_PATH: '/var/lib/weaviate/backups'
      DISABLE_TELEMETRY: 'true'
      GRPC_MAX_MESSAGE_SIZE: 100000000
    volumes:
      - weaviate-data:/var/lib/weaviate
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/v1/.well-known/ready"]
      interval: 5s
      timeout: 10s
      retries: 30
      start_period: 30s

volumes:
  weaviate-data:
```

#### 2. `ci/docker/docker-compose-cluster.yml`
```yaml
services:
  weaviate-node-1:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8087:8080"
      - "50058:50051"
    environment:
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      DEFAULT_VECTORIZER_MODULE: 'none'
      CLUSTER_HOSTNAME: 'node1'
      CLUSTER_GOSSIP_BIND_PORT: '7100'
      CLUSTER_DATA_BIND_PORT: '7101'
      CLUSTER_JOIN: 'weaviate-node-1:7100,weaviate-node-2:7100,weaviate-node-3:7100'
      RAFT_BOOTSTRAP_EXPECT: 3
      DISABLE_TELEMETRY: 'true'

  weaviate-node-2:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8088:8080"
      - "50059:50051"
    environment:
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      DEFAULT_VECTORIZER_MODULE: 'none'
      CLUSTER_HOSTNAME: 'node2'
      CLUSTER_GOSSIP_BIND_PORT: '7100'
      CLUSTER_DATA_BIND_PORT: '7101'
      CLUSTER_JOIN: 'weaviate-node-1:7100,weaviate-node-2:7100,weaviate-node-3:7100'
      RAFT_BOOTSTRAP_EXPECT: 3
      DISABLE_TELEMETRY: 'true'

  weaviate-node-3:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8089:8080"
      - "50060:50051"
    environment:
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      DEFAULT_VECTORIZER_MODULE: 'none'
      CLUSTER_HOSTNAME: 'node3'
      CLUSTER_GOSSIP_BIND_PORT: '7100'
      CLUSTER_DATA_BIND_PORT: '7101'
      CLUSTER_JOIN: 'weaviate-node-1:7100,weaviate-node-2:7100,weaviate-node-3:7100'
      RAFT_BOOTSTRAP_EXPECT: 3
      DISABLE_TELEMETRY: 'true'
```

#### 3. `ci/docker/docker-compose-async.yml`
```yaml
services:
  weaviate-async:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8090:8080"
      - "50061:50051"
    environment:
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      DEFAULT_VECTORIZER_MODULE: 'none'
      ASYNC_INDEXING: 'true'
      DISABLE_TELEMETRY: 'true'
```

#### 4. `ci/docker/docker-compose-rbac.yml`
```yaml
services:
  weaviate-rbac:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8092:8080"
      - "50063:50051"
    environment:
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'false'
      AUTHENTICATION_APIKEY_ENABLED: 'true'
      AUTHENTICATION_APIKEY_ALLOWED_KEYS: 'admin-key,readonly-key,custom-key'
      AUTHENTICATION_APIKEY_USERS: 'admin-user,readonly-user,custom-user'
      AUTHENTICATION_DB_USERS_ENABLED: 'true'
      AUTHORIZATION_ENABLE_RBAC: 'true'
      AUTHORIZATION_ADMIN_USERS: 'admin-user'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      DEFAULT_VECTORIZER_MODULE: 'none'
      DISABLE_TELEMETRY: 'true'
```

#### 5. `ci/docker/docker-compose-backup.yml`
```yaml
services:
  weaviate-backup:
    image: cr.weaviate.io/semitechnologies/weaviate:${WEAVIATE_VERSION:-1.28.14}
    ports:
      - "8093:8080"
      - "50065:50051"
    environment:
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      DEFAULT_VECTORIZER_MODULE: 'none'
      ENABLE_MODULES: 'backup-filesystem'
      BACKUP_FILESYSTEM_PATH: '/var/lib/weaviate/backups'
      DISABLE_TELEMETRY: 'true'
    volumes:
      - backup-data:/var/lib/weaviate

volumes:
  backup-data:
```

---

## Mix Tasks for Docker Management

Create `lib/mix/tasks/weaviate.ex`:

```elixir
defmodule Mix.Tasks.Weaviate do
  @moduledoc "Weaviate Docker stack management tasks"
end

defmodule Mix.Tasks.Weaviate.Start do
  use Mix.Task
  @shortdoc "Start Weaviate Docker containers for integration testing"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [
      version: :string,
      config: :string,
      all: :boolean
    ])

    version = opts[:version] || "1.28.14"
    System.put_env("WEAVIATE_VERSION", version)

    configs = case {opts[:all], opts[:config]} do
      {true, _} -> all_configs()
      {_, nil} -> ["docker-compose.yml"]
      {_, config} -> [config]
    end

    IO.puts("Starting Weaviate #{version}...")

    for config <- configs do
      path = Path.join(["ci", "docker", config])
      if File.exists?(path) do
        IO.puts("  Starting #{config}...")
        System.cmd("docker", ["compose", "-f", path, "up", "-d"],
          into: IO.stream(:stdio, :line))
      end
    end

    IO.puts("Waiting for Weaviate to be ready...")
    wait_for_ready(ports_for_configs(configs))
    IO.puts("Weaviate is ready!")
  end

  defp all_configs do
    Path.wildcard("ci/docker/docker-compose*.yml")
    |> Enum.map(&Path.basename/1)
  end

  defp ports_for_configs(configs) do
    config_ports = %{
      "docker-compose.yml" => [8080],
      "docker-compose-cluster.yml" => [8087, 8088, 8089],
      "docker-compose-async.yml" => [8090],
      "docker-compose-rbac.yml" => [8092],
      "docker-compose-backup.yml" => [8093]
    }
    configs |> Enum.flat_map(&(config_ports[&1] || []))
  end

  defp wait_for_ready(ports, timeout \\ 60_000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Enum.each(ports, fn port ->
      wait_for_port(port, deadline)
    end)
  end

  defp wait_for_port(port, deadline) do
    url = "http://localhost:#{port}/v1/.well-known/ready"

    case check_ready(url) do
      :ok ->
        IO.puts("    Port #{port} ready")
      :not_ready ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(1000)
          wait_for_port(port, deadline)
        else
          Mix.raise("Timeout waiting for Weaviate on port #{port}")
        end
    end
  end

  defp check_ready(url) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _, _}} -> :ok
      _ -> :not_ready
    end
  rescue
    _ -> :not_ready
  end
end

defmodule Mix.Tasks.Weaviate.Stop do
  use Mix.Task
  @shortdoc "Stop Weaviate Docker containers"

  @impl Mix.Task
  def run(_args) do
    IO.puts("Stopping Weaviate containers...")

    for config <- Path.wildcard("ci/docker/docker-compose*.yml") do
      System.cmd("docker", ["compose", "-f", config, "down", "--remove-orphans"],
        into: IO.stream(:stdio, :line))
    end

    IO.puts("Weaviate containers stopped.")
  end
end

defmodule Mix.Tasks.Weaviate.Status do
  use Mix.Task
  @shortdoc "Check Weaviate Docker container status"

  @impl Mix.Task
  def run(_args) do
    System.cmd("docker", ["ps", "--filter", "name=weaviate"],
      into: IO.stream(:stdio, :line))
  end
end
```

---

## Shell Scripts (Alternative to Mix Tasks)

#### `ci/start_weaviate.sh`
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WEAVIATE_VERSION=${1:-1.28.14}

source "$SCRIPT_DIR/compose.sh"

echo "Stopping existing containers..."
compose_down_all

echo "Cleaning up data..."
rm -rf "$SCRIPT_DIR/../weaviate-data" 2>/dev/null || true

echo "Starting Weaviate $WEAVIATE_VERSION..."
compose_up_all

echo "Waiting for Weaviate to be ready..."
wait_for_all

echo "Weaviate is ready!"
```

#### `ci/compose.sh`
```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"

ls_compose() {
    ls -1 "$DOCKER_DIR"/docker-compose*.yml 2>/dev/null
}

compose_up_all() {
    for f in $(ls_compose); do
        echo "Starting $(basename $f)..."
        docker compose -f "$f" up -d
    done
}

compose_down_all() {
    for f in $(ls_compose); do
        docker compose -f "$f" down --remove-orphans 2>/dev/null || true
    done
}

all_weaviate_ports() {
    echo "8080 8087 8088 8089 8090 8092 8093"
}

wait_for_port() {
    local port=$1
    local timeout=${2:-60}

    echo -n "  Waiting for port $port..."
    for i in $(seq 1 $timeout); do
        if curl -sf "http://localhost:$port/v1/.well-known/ready" > /dev/null 2>&1; then
            echo " ready!"
            return 0
        fi
        sleep 1
    done
    echo " TIMEOUT!"
    return 1
}

wait_for_all() {
    for port in $(all_weaviate_ports); do
        wait_for_port $port || true
    done
}
```

#### `ci/stop_weaviate.sh`
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compose.sh"

echo "Stopping Weaviate containers..."
compose_down_all

echo "Cleaning up data..."
rm -rf "$SCRIPT_DIR/../weaviate-data" 2>/dev/null || true

echo "Done."
```

---

## Port Assignments

| Service | HTTP Port | gRPC Port | Purpose |
|---------|-----------|-----------|---------|
| Base Weaviate | 8080 | 50051 | General testing |
| Cluster Node 1 | 8087 | 50058 | Cluster testing |
| Cluster Node 2 | 8088 | 50059 | Cluster testing |
| Cluster Node 3 | 8089 | 50060 | Cluster testing |
| Async Weaviate | 8090 | 50061 | Async indexing tests |
| RBAC Weaviate | 8092 | 50063 | Auth/RBAC tests |
| Backup Weaviate | 8093 | 50065 | Backup/restore tests |

---

## Usage Examples

### Shell Scripts
```bash
# Start all containers with default version
./ci/start_weaviate.sh

# Start with specific version
./ci/start_weaviate.sh 1.32.23

# Stop all containers
./ci/stop_weaviate.sh
```

### Mix Tasks
```bash
# Start base configuration
mix weaviate.start

# Start specific version
mix weaviate.start --version 1.32.23

# Start all configurations
mix weaviate.start --all

# Stop all containers
mix weaviate.stop

# Check status
mix weaviate.status
```

### Running Tests
```bash
# Start containers, run integration tests, stop containers
./ci/start_weaviate.sh && \
WEAVIATE_INTEGRATION=true mix test --include integration && \
./ci/stop_weaviate.sh
```
