#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_VERSION="${WEAVIATE_VERSION:-latest}"
DEFAULT_LOG_FILE="docker-compose.yml"
DEFAULT_TAIL=20

print_help() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  start         Start the full Weaviate stack via mix (default version: ${DEFAULT_VERSION})
  status        Show status for all compose profiles
  logs          Tail logs (default file: ${DEFAULT_LOG_FILE}, tail: ${DEFAULT_TAIL})
  stop          Stop the stack (default version: ${DEFAULT_VERSION})
  cycle         Run start -> status -> logs -> stop
  help          Show this help message

Global Options:
  -v, --version <tag>   Override Docker image tag used for start/stop (env: WEAVIATE_VERSION)

Command-specific Options:
  start:
    -p, --profile <name>   Select profile (full|async, default: full)

  logs:
    -f, --file <name>      Compose file to target (default: ${DEFAULT_LOG_FILE})
    -t, --tail <lines>     Number of lines to show (default: ${DEFAULT_TAIL})
    --follow               Follow log output

Examples:
  $(basename "$0") start --version 1.34.0
  $(basename "$0") logs --file docker-compose-async.yml --follow
  $(basename "$0") cycle
EOF
}

run_mix() {
  pushd "${PROJECT_ROOT}" >/dev/null
  mix "$@"
  popd >/dev/null
}

cmd_start() {
  local version="$1"
  local profile="$2"

  echo "→ Starting Weaviate (profile: ${profile}, version: ${version})"
  run_mix weaviate.start --version "${version}" --profile "${profile}"
}

cmd_status() {
  echo "→ Checking stack status"
  run_mix weaviate.status
}

cmd_logs() {
  local file="$1"
  local tail="$2"
  local follow_flag="$3"

  echo "→ Tail logs (file: ${file}, tail: ${tail}${follow_flag:+, follow})"
  local args=(weaviate.logs --file "${file}" --tail "${tail}")
  if [[ -n "${follow_flag}" ]]; then
    args+=(--follow)
  fi
  run_mix "${args[@]}"
}

cmd_stop() {
  local version="$1"

  echo "→ Stopping Weaviate (version: ${version})"
  run_mix weaviate.stop --version "${version}"
}

cmd_cycle() {
  local version="$1"
  local profile="$2"
  local file="$3"
  local tail="$4"
  local follow_flag="$5"

  cmd_start "${version}" "${profile}"
  cmd_status
  cmd_logs "${file}" "${tail}" "${follow_flag}"
  cmd_stop "${version}"
}

parse_args() {
  local command=""
  local version="${DEFAULT_VERSION}"
  local profile="full"
  local log_file="${DEFAULT_LOG_FILE}"
  local log_tail="${DEFAULT_TAIL}"
  local follow_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      start|status|logs|stop|cycle|help)
        command="$1"
        shift
        break
        ;;
      -v|--version)
        version="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done

  case "${command}" in
    start)
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -p|--profile)
            profile="$2"
            shift 2
            ;;
          -v|--version)
            version="$2"
            shift 2
            ;;
          *)
            echo "Unknown start option: $1" >&2
            exit 1
            ;;
        esac
      done
      cmd_start "${version}" "${profile}"
      ;;
    status)
      cmd_status
      ;;
    logs)
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -f|--file)
            log_file="$2"
            shift 2
            ;;
          -t|--tail)
            log_tail="$2"
            shift 2
            ;;
          --follow)
            follow_flag="--follow"
            shift
            ;;
          *)
            echo "Unknown logs option: $1" >&2
            exit 1
            ;;
        esac
      done
      cmd_logs "${log_file}" "${log_tail}" "${follow_flag}"
      ;;
    stop)
      cmd_stop "${version}"
      ;;
    cycle)
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -p|--profile)
            profile="$2"
            shift 2
            ;;
          -f|--file)
            log_file="$2"
            shift 2
            ;;
          -t|--tail)
            log_tail="$2"
            shift 2
            ;;
          --follow)
            follow_flag="--follow"
            shift
            ;;
          -v|--version)
            version="$2"
            shift 2
            ;;
          *)
            echo "Unknown cycle option: $1" >&2
            exit 1
            ;;
        esac
      done
      cmd_cycle "${version}" "${profile}" "${log_file}" "${log_tail}" "${follow_flag}"
      ;;
    help|"")
      print_help
      ;;
    *)
      echo "Unknown command: ${command}" >&2
      exit 1
      ;;
  esac
}

parse_args "$@"
