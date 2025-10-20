#!/usr/bin/env bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export WEAVIATE_VERSION=$1

source "${SCRIPT_DIR}/compose.sh"

cd "${PROJECT_ROOT}"

compose_down_all
rm -rf weaviate-data || true
