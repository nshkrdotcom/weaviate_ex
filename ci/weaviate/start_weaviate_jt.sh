#!/usr/bin/env bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export WEAVIATE_VERSION=$1

source "${SCRIPT_DIR}/compose.sh"

cd "${PROJECT_ROOT}"

echo "Stop existing session if running"
docker compose -f "${SCRIPT_DIR}/docker-compose-async.yml" down --remove-orphans
rm -rf weaviate-data || true

echo "Run Docker compose"
docker compose -f "${SCRIPT_DIR}/docker-compose-async.yml" up -d

echo "Wait until the container is up"

wait "http://localhost:8090"

echo "All containers running"
