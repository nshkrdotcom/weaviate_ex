# Shell Scripts and Mix Tasks

This document provides complete, copy-ready scripts for managing the Weaviate Docker stack.

---

## Directory Structure

```
weaviate_ex/
├── ci/
│   ├── docker/
│   │   ├── docker-compose.yml
│   │   ├── docker-compose-cluster.yml
│   │   ├── docker-compose-async.yml
│   │   ├── docker-compose-rbac.yml
│   │   └── docker-compose-backup.yml
│   ├── compose.sh          # Helper functions
│   ├── start_weaviate.sh   # Start all containers
│   ├── stop_weaviate.sh    # Stop all containers
│   └── wait_for_weaviate.sh # Wait for readiness
├── lib/
│   └── mix/
│       └── tasks/
│           └── weaviate.ex  # Mix tasks
└── ...
```

---

## Shell Scripts

### ci/compose.sh

```bash
#!/bin/bash
# Helper functions for Docker Compose management
# Source this file in other scripts: source ./ci/compose.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# List all docker-compose files
ls_compose() {
    find "$DOCKER_DIR" -maxdepth 1 -name "docker-compose*.yml" -type f 2>/dev/null | sort
}

# Execute docker compose command on all files
exec_all() {
    local cmd="$@"
    for f in $(ls_compose); do
        local basename=$(basename "$f")
        echo -e "${YELLOW}Running: docker compose -f $basename $cmd${NC}"
        docker compose -f "$f" $cmd || true
    done
}

# Start all containers
compose_up_all() {
    echo -e "${GREEN}Starting all Weaviate containers...${NC}"
    exec_all "up -d"
}

# Stop all containers
compose_down_all() {
    echo -e "${YELLOW}Stopping all Weaviate containers...${NC}"
    exec_all "down --remove-orphans --volumes"
}

# Get all Weaviate ports
all_weaviate_ports() {
    echo "8080 8087 8088 8089 8090 8092 8093"
}

# Get all gRPC ports
all_grpc_ports() {
    echo "50051 50058 50059 50060 50061 50063 50065"
}

# Wait for a single port
wait_for_port() {
    local port=$1
    local timeout=${2:-60}
    local start_time=$(date +%s)

    echo -n "  Waiting for port $port..."

    while true; do
        if curl -sf "http://localhost:$port/v1/.well-known/ready" > /dev/null 2>&1; then
            echo -e " ${GREEN}ready!${NC}"
            return 0
        fi

        local elapsed=$(($(date +%s) - start_time))
        if [ $elapsed -ge $timeout ]; then
            echo -e " ${RED}TIMEOUT!${NC}"
            return 1
        fi

        sleep 1
    done
}

# Wait for all Weaviate instances
wait_for_all() {
    local timeout=${1:-60}
    local failed=0

    echo -e "${GREEN}Waiting for Weaviate instances...${NC}"

    for port in $(all_weaviate_ports); do
        wait_for_port $port $timeout || ((failed++))
    done

    if [ $failed -gt 0 ]; then
        echo -e "${RED}$failed instance(s) failed to start${NC}"
        return 1
    fi

    echo -e "${GREEN}All instances ready!${NC}"
    return 0
}

# Check status of all containers
check_status() {
    echo -e "${GREEN}Weaviate container status:${NC}"
    docker ps --filter "name=weaviate" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# View logs for specific container
view_logs() {
    local service=${1:-weaviate}
    local lines=${2:-50}
    docker compose -f "$DOCKER_DIR/docker-compose.yml" logs --tail=$lines $service
}

# Clean up all data
cleanup_data() {
    echo -e "${YELLOW}Cleaning up Weaviate data...${NC}"
    rm -rf "$SCRIPT_DIR/../weaviate-data" 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
}
```

### ci/start_weaviate.sh

```bash
#!/bin/bash
# Start Weaviate containers for integration testing
# Usage: ./ci/start_weaviate.sh [VERSION] [--config CONFIG]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compose.sh"

# Parse arguments
VERSION=${1:-1.28.14}
shift || true

CONFIG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG="$2"
            shift 2
            ;;
        --all)
            CONFIG="all"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Export version for docker-compose
export WEAVIATE_VERSION="$VERSION"

echo -e "${GREEN}=== Weaviate Integration Test Setup ===${NC}"
echo "Version: $WEAVIATE_VERSION"
echo "Config: ${CONFIG:-default}"

# Stop existing containers
compose_down_all

# Clean up old data
cleanup_data

# Start containers based on config
if [ "$CONFIG" = "all" ]; then
    compose_up_all
elif [ -n "$CONFIG" ]; then
    config_file="$DOCKER_DIR/docker-compose-${CONFIG}.yml"
    if [ -f "$config_file" ]; then
        echo "Starting $CONFIG configuration..."
        docker compose -f "$config_file" up -d
    else
        echo -e "${RED}Config file not found: $config_file${NC}"
        exit 1
    fi
else
    # Default: just base config
    docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d
fi

# Wait for containers to be ready
if [ "$CONFIG" = "all" ]; then
    wait_for_all 120
else
    wait_for_port 8080 60
fi

echo ""
echo -e "${GREEN}=== Weaviate is Ready ===${NC}"
check_status
echo ""
echo "Run tests with: WEAVIATE_INTEGRATION=true mix test --include integration"
```

### ci/stop_weaviate.sh

```bash
#!/bin/bash
# Stop all Weaviate containers and clean up
# Usage: ./ci/stop_weaviate.sh [--keep-data]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compose.sh"

KEEP_DATA=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${YELLOW}=== Stopping Weaviate Containers ===${NC}"

# Stop all containers
compose_down_all

# Clean up data unless --keep-data specified
if [ "$KEEP_DATA" = false ]; then
    cleanup_data
fi

echo -e "${GREEN}=== Cleanup Complete ===${NC}"
```

### ci/wait_for_weaviate.sh

```bash
#!/bin/bash
# Wait for Weaviate to be ready
# Usage: ./ci/wait_for_weaviate.sh [PORT] [TIMEOUT]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compose.sh"

PORT=${1:-8080}
TIMEOUT=${2:-60}

wait_for_port $PORT $TIMEOUT
```

---

## Mix Tasks

### lib/mix/tasks/weaviate.ex

```elixir
defmodule Mix.Tasks.Weaviate do
  @moduledoc """
  Weaviate Docker stack management for integration testing.

  ## Available Tasks

      mix weaviate.start    # Start Weaviate containers
      mix weaviate.stop     # Stop Weaviate containers
      mix weaviate.status   # Check container status
      mix weaviate.logs     # View container logs
      mix weaviate.test     # Run integration tests

  """
end

defmodule Mix.Tasks.Weaviate.Start do
  use Mix.Task

  @shortdoc "Start Weaviate Docker containers"

  @moduledoc """
  Start Weaviate Docker containers for integration testing.

  ## Usage

      mix weaviate.start              # Start with default version
      mix weaviate.start --version 1.32.23  # Specific version
      mix weaviate.start --all        # Start all configurations
      mix weaviate.start --config rbac # Start specific config

  ## Options

      --version VERSION    Weaviate version (default: 1.28.14)
      --all               Start all docker-compose configurations
      --config CONFIG     Start specific config (cluster, rbac, async, backup)
      --timeout SECONDS   Wait timeout (default: 60)

  """

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        version: :string,
        all: :boolean,
        config: :string,
        timeout: :integer
      ]
    )

    version = opts[:version] || "1.28.14"
    timeout = opts[:timeout] || 60

    # Ensure :httpc is available
    {:ok, _} = Application.ensure_all_started(:inets)

    Mix.shell().info("Starting Weaviate #{version}...")

    # Build command
    cmd_args = ["./ci/start_weaviate.sh", version]
    cmd_args = if opts[:all], do: cmd_args ++ ["--all"], else: cmd_args
    cmd_args = if opts[:config], do: cmd_args ++ ["--config", opts[:config]], else: cmd_args

    case System.cmd("bash", cmd_args, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info("Weaviate started successfully!")
        wait_for_ready(8080, timeout)

      {_, code} ->
        Mix.raise("Failed to start Weaviate (exit code: #{code})")
    end
  end

  defp wait_for_ready(port, timeout) do
    Mix.shell().info("Waiting for Weaviate on port #{port}...")
    deadline = System.monotonic_time(:second) + timeout

    do_wait(port, deadline)
  end

  defp do_wait(port, deadline) do
    url = ~c"http://localhost:#{port}/v1/.well-known/ready"

    case :httpc.request(:get, {url, []}, [{:timeout, 5000}], []) do
      {:ok, {{_, 200, _}, _, _}} ->
        Mix.shell().info("Weaviate is ready!")
        :ok

      _ ->
        if System.monotonic_time(:second) < deadline do
          Process.sleep(1000)
          do_wait(port, deadline)
        else
          Mix.raise("Timeout waiting for Weaviate")
        end
    end
  end
end

defmodule Mix.Tasks.Weaviate.Stop do
  use Mix.Task

  @shortdoc "Stop Weaviate Docker containers"

  @moduledoc """
  Stop all Weaviate Docker containers.

  ## Usage

      mix weaviate.stop            # Stop and clean up
      mix weaviate.stop --keep-data # Stop but preserve data

  ## Options

      --keep-data    Don't delete Weaviate data volumes

  """

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [keep_data: :boolean]
    )

    Mix.shell().info("Stopping Weaviate containers...")

    cmd_args = ["./ci/stop_weaviate.sh"]
    cmd_args = if opts[:keep_data], do: cmd_args ++ ["--keep-data"], else: cmd_args

    case System.cmd("bash", cmd_args, into: IO.stream(:stdio, :line)) do
      {_, 0} -> Mix.shell().info("Weaviate stopped.")
      {_, code} -> Mix.raise("Failed to stop Weaviate (exit code: #{code})")
    end
  end
end

defmodule Mix.Tasks.Weaviate.Status do
  use Mix.Task

  @shortdoc "Check Weaviate container status"

  @impl Mix.Task
  def run(_args) do
    {output, _} = System.cmd("docker", [
      "ps",
      "--filter", "name=weaviate",
      "--format", "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ])

    if String.trim(output) == "" do
      Mix.shell().info("No Weaviate containers running.")
    else
      Mix.shell().info("Weaviate containers:\n#{output}")
    end
  end
end

defmodule Mix.Tasks.Weaviate.Logs do
  use Mix.Task

  @shortdoc "View Weaviate container logs"

  @moduledoc """
  View logs from Weaviate containers.

  ## Usage

      mix weaviate.logs           # Last 50 lines from main container
      mix weaviate.logs --lines 100  # More lines
      mix weaviate.logs --follow  # Follow logs (Ctrl+C to stop)

  """

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [lines: :integer, follow: :boolean]
    )

    lines = opts[:lines] || 50

    cmd_args = ["compose", "-f", "./ci/docker/docker-compose.yml", "logs"]
    cmd_args = if opts[:follow], do: cmd_args ++ ["-f"], else: cmd_args ++ ["--tail=#{lines}"]
    cmd_args = cmd_args ++ ["weaviate"]

    System.cmd("docker", cmd_args, into: IO.stream(:stdio, :line))
  end
end

defmodule Mix.Tasks.Weaviate.Test do
  use Mix.Task

  @shortdoc "Start Weaviate and run integration tests"

  @moduledoc """
  Start Weaviate, run integration tests, then stop Weaviate.

  ## Usage

      mix weaviate.test            # Run integration tests
      mix weaviate.test --all      # Run all test types
      mix weaviate.test --keep     # Keep Weaviate running after tests

  ## Options

      --version VERSION   Weaviate version
      --all              Include all test tags (rbac, cluster, etc.)
      --keep             Keep Weaviate running after tests
      --only TAG         Only run tests with specific tag

  """

  @impl Mix.Task
  def run(args) do
    {opts, extra_args, _} = OptionParser.parse(args,
      switches: [
        version: :string,
        all: :boolean,
        keep: :boolean,
        only: :string
      ]
    )

    # Start Weaviate
    start_args = []
    start_args = if opts[:version], do: ["--version", opts[:version]] ++ start_args, else: start_args
    start_args = if opts[:all], do: ["--all"] ++ start_args, else: start_args

    Mix.Task.run("weaviate.start", start_args)

    # Set environment for integration tests
    System.put_env("WEAVIATE_INTEGRATION", "true")

    # Build test arguments
    test_args = ["--include", "integration"]
    test_args = if opts[:all], do: test_args ++ ["--include", "rbac", "--include", "cluster"], else: test_args
    test_args = if opts[:only], do: test_args ++ ["--only", opts[:only]], else: test_args
    test_args = test_args ++ extra_args

    # Run tests
    try do
      Mix.Task.run("test", test_args)
    after
      # Stop Weaviate unless --keep specified
      unless opts[:keep] do
        Mix.Task.run("weaviate.stop")
      end
    end
  end
end
```

---

## Docker Compose Files

### ci/docker/docker-compose.yml

```yaml
# Base Weaviate configuration for integration testing
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

### ci/docker/docker-compose-cluster.yml

```yaml
# 3-node Weaviate cluster for cluster testing
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
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/v1/.well-known/ready"]
      interval: 5s
      timeout: 10s
      retries: 30

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

### ci/docker/docker-compose-rbac.yml

```yaml
# RBAC-enabled Weaviate for authentication testing
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
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/v1/.well-known/ready"]
      interval: 5s
      timeout: 10s
      retries: 30
```

### ci/docker/docker-compose-async.yml

```yaml
# Async indexing configuration for testing
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
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/v1/.well-known/ready"]
      interval: 5s
      timeout: 10s
      retries: 30
```

### ci/docker/docker-compose-backup.yml

```yaml
# Backup/restore testing configuration
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
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/v1/.well-known/ready"]
      interval: 5s
      timeout: 10s
      retries: 30

volumes:
  backup-data:
```

---

## Usage Examples

### Shell Commands

```bash
# Start default Weaviate
./ci/start_weaviate.sh

# Start specific version
./ci/start_weaviate.sh 1.32.23

# Start all configurations
./ci/start_weaviate.sh 1.28.14 --all

# Start only RBAC config
./ci/start_weaviate.sh 1.28.14 --config rbac

# Stop all containers
./ci/stop_weaviate.sh

# Stop but keep data
./ci/stop_weaviate.sh --keep-data

# Run integration tests
./ci/start_weaviate.sh && \
WEAVIATE_INTEGRATION=true mix test --include integration && \
./ci/stop_weaviate.sh
```

### Mix Tasks

```bash
# Start Weaviate
mix weaviate.start
mix weaviate.start --version 1.32.23
mix weaviate.start --all

# Stop Weaviate
mix weaviate.stop
mix weaviate.stop --keep-data

# Check status
mix weaviate.status

# View logs
mix weaviate.logs
mix weaviate.logs --lines 100
mix weaviate.logs --follow

# Run integration tests (starts, tests, stops automatically)
mix weaviate.test
mix weaviate.test --all
mix weaviate.test --keep  # Keep running after tests
```

---

## Setup Instructions

### Make Scripts Executable

```bash
chmod +x ci/compose.sh
chmod +x ci/start_weaviate.sh
chmod +x ci/stop_weaviate.sh
chmod +x ci/wait_for_weaviate.sh
```

### First-Time Setup

```bash
# Create directories
mkdir -p ci/docker

# Copy docker-compose files to ci/docker/
# (Use the templates above)

# Make scripts executable
chmod +x ci/*.sh

# Test the setup
./ci/start_weaviate.sh
./ci/stop_weaviate.sh
```
