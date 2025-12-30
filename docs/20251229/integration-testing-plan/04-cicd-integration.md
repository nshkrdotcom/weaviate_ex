# CI/CD Integration for Integration Tests

## Python Client CI/CD Analysis

The Python client uses GitHub Actions with comprehensive testing:

### Workflow Structure
```yaml
# .github/workflows/main.yaml
name: Main

on:
  push:
    branches: [main]
    tags: ['**']
  pull_request:
    branches: ['**']

concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true

env:
  WEAVIATE_127: 1.27.27
  WEAVIATE_128: 1.28.16
  # ... 9 versions total
  WEAVIATE_135: 1.35.0
```

### Job Types

| Job | Docker | Purpose | Matrix |
|-----|--------|---------|--------|
| lint-and-format | No | Code quality | Single |
| type-checking | No | Type safety | Python 3.10-3.14, 3 folders |
| unit-tests | No | Unit tests | Python 3.10-3.14, 2 folders |
| proto-test | No | gRPC compat | 8 gRPC × 8 protobuf = 64 |
| integration-tests-embedded | No | Embedded client | Python 3.10-3.14 |
| integration-tests | Yes | Full integration | 5 Python/gRPC pairs |
| journey-tests | Yes | E2E tests | Python 3.10-3.14 |
| test-package | Yes | Package testing | 9 Weaviate versions |

---

## Current Elixir CI/CD

### Existing Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'
      - run: mix deps.get
      - run: mix test
      - run: mix dialyzer
```

**Limitations:**
- Only runs unit tests (mocked)
- No Docker/Weaviate integration
- No version matrix testing
- No integration test coverage

---

## Proposed CI/CD Enhancement

### Phase 1: Basic Integration Tests

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true

env:
  MIX_ENV: test
  WEAVIATE_VERSION: "1.28.14"

jobs:
  # ============================================
  # UNIT TESTS (no Docker required)
  # ============================================
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'

      - name: Cache deps
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-

      - name: Install dependencies
        run: mix deps.get

      - name: Compile
        run: mix compile --warnings-as-errors

      - name: Run unit tests
        run: mix test --exclude integration --exclude rbac --exclude cluster

      - name: Run Dialyzer
        run: mix dialyzer

  # ============================================
  # FORMAT AND LINT
  # ============================================
  format:
    name: Format & Lint
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'

      - name: Check formatting
        run: mix format --check-formatted

      - name: Run Credo
        run: mix credo --strict

  # ============================================
  # INTEGRATION TESTS (requires Docker)
  # ============================================
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    needs: [unit-tests, format]

    services:
      weaviate:
        image: cr.weaviate.io/semitechnologies/weaviate:1.28.14
        ports:
          - 8080:8080
          - 50051:50051
        env:
          AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
          PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
          DEFAULT_VECTORIZER_MODULE: 'none'
          ENABLE_API_BASED_MODULES: 'true'
          CLUSTER_HOSTNAME: 'node1'
          DISABLE_TELEMETRY: 'true'
        options: >-
          --health-cmd "wget -q --spider http://localhost:8080/v1/.well-known/ready || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 30

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'

      - name: Cache deps
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-

      - name: Install dependencies
        run: mix deps.get

      - name: Wait for Weaviate
        run: |
          for i in {1..30}; do
            if curl -sf http://localhost:8080/v1/.well-known/ready; then
              echo "Weaviate is ready"
              exit 0
            fi
            echo "Waiting for Weaviate..."
            sleep 2
          done
          echo "Weaviate failed to start"
          exit 1

      - name: Run integration tests
        run: mix test --include integration
        env:
          WEAVIATE_INTEGRATION: "true"
          WEAVIATE_URL: "http://localhost:8080"
          WEAVIATE_GRPC_PORT: "50051"
```

### Phase 2: Multi-Version Matrix Testing

```yaml
  # ============================================
  # MULTI-VERSION INTEGRATION TESTS
  # ============================================
  integration-matrix:
    name: Integration (${{ matrix.weaviate_version }})
    runs-on: ubuntu-latest
    needs: [unit-tests]

    strategy:
      fail-fast: false
      matrix:
        weaviate_version:
          - "1.27.27"
          - "1.28.14"
          - "1.29.11"
          - "1.30.22"
          - "1.31.20"

    services:
      weaviate:
        image: cr.weaviate.io/semitechnologies/weaviate:${{ matrix.weaviate_version }}
        ports:
          - 8080:8080
          - 50051:50051
        env:
          AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
          PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
          DEFAULT_VECTORIZER_MODULE: 'none'
          DISABLE_TELEMETRY: 'true'
        options: >-
          --health-cmd "wget -q --spider http://localhost:8080/v1/.well-known/ready || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 30

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'

      - name: Cache deps
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}

      - name: Install dependencies
        run: mix deps.get

      - name: Run integration tests
        run: mix test --include integration
        env:
          WEAVIATE_INTEGRATION: "true"
          WEAVIATE_VERSION: ${{ matrix.weaviate_version }}
```

### Phase 3: RBAC and Cluster Testing

```yaml
  # ============================================
  # RBAC INTEGRATION TESTS
  # ============================================
  rbac-tests:
    name: RBAC Tests
    runs-on: ubuntu-latest
    needs: [integration-tests]

    services:
      weaviate-rbac:
        image: cr.weaviate.io/semitechnologies/weaviate:1.28.14
        ports:
          - 8092:8080
          - 50063:50051
        env:
          AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'false'
          AUTHENTICATION_APIKEY_ENABLED: 'true'
          AUTHENTICATION_APIKEY_ALLOWED_KEYS: 'admin-key,readonly-key'
          AUTHENTICATION_APIKEY_USERS: 'admin-user,readonly-user'
          AUTHORIZATION_ENABLE_RBAC: 'true'
          AUTHORIZATION_ADMIN_USERS: 'admin-user'
          DISABLE_TELEMETRY: 'true'
        options: >-
          --health-cmd "wget -q --spider http://localhost:8080/v1/.well-known/ready || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 30

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'

      - name: Install dependencies
        run: mix deps.get

      - name: Run RBAC tests
        run: mix test --include rbac
        env:
          WEAVIATE_INTEGRATION: "true"
          WEAVIATE_RBAC_URL: "http://localhost:8092"
          WEAVIATE_ADMIN_KEY: "admin-key"

  # ============================================
  # CLUSTER TESTS
  # ============================================
  cluster-tests:
    name: Cluster Tests
    runs-on: ubuntu-latest
    needs: [integration-tests]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'

      - name: Start cluster via Docker Compose
        run: |
          docker compose -f ci/docker/docker-compose-cluster.yml up -d
          sleep 30  # Wait for cluster formation

      - name: Wait for cluster
        run: |
          for port in 8087 8088 8089; do
            for i in {1..30}; do
              if curl -sf http://localhost:$port/v1/.well-known/ready; then
                echo "Node on port $port is ready"
                break
              fi
              sleep 2
            done
          done

      - name: Install dependencies
        run: mix deps.get

      - name: Run cluster tests
        run: mix test --include cluster
        env:
          WEAVIATE_INTEGRATION: "true"

      - name: Stop cluster
        if: always()
        run: docker compose -f ci/docker/docker-compose-cluster.yml down
```

### Phase 4: Full Pipeline

```yaml
name: Full CI Pipeline

on:
  push:
    branches: [master]
    tags: ['v*']
  pull_request:
    branches: [master]

concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true

jobs:
  # Quality Gates
  format:
    name: Format & Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'
      - run: mix deps.get
      - run: mix format --check-formatted
      - run: mix credo --strict

  dialyzer:
    name: Dialyzer
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'
      - uses: actions/cache@v4
        with:
          path: |
            deps
            _build
            priv/plts
          key: ${{ runner.os }}-dialyzer-${{ hashFiles('**/mix.lock') }}
      - run: mix deps.get
      - run: mix dialyzer

  # Unit Tests
  unit-tests:
    name: Unit Tests (OTP ${{ matrix.otp }}, Elixir ${{ matrix.elixir }})
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
          - elixir: '1.17.3'
            otp: '27'
          - elixir: '1.18.4'
            otp: '28'
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ matrix.elixir }}
          otp-version: ${{ matrix.otp }}
      - run: mix deps.get
      - run: mix test --exclude integration

  # Integration Tests
  integration-tests:
    name: Integration (Weaviate ${{ matrix.weaviate }})
    runs-on: ubuntu-latest
    needs: [format, unit-tests]
    strategy:
      fail-fast: false
      matrix:
        weaviate: ["1.27.27", "1.28.14", "1.29.11", "1.30.22", "1.31.20"]
    services:
      weaviate:
        image: cr.weaviate.io/semitechnologies/weaviate:${{ matrix.weaviate }}
        ports:
          - 8080:8080
          - 50051:50051
        env:
          AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
          DEFAULT_VECTORIZER_MODULE: 'none'
          DISABLE_TELEMETRY: 'true'
        options: >-
          --health-cmd "wget -q --spider http://localhost:8080/v1/.well-known/ready"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 30
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'
      - run: mix deps.get
      - run: mix test --include integration
        env:
          WEAVIATE_INTEGRATION: "true"

  # Advanced Tests (only on main/tags)
  rbac-tests:
    name: RBAC Tests
    if: github.ref == 'refs/heads/master' || startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    needs: [integration-tests]
    # ... RBAC service and tests ...

  cluster-tests:
    name: Cluster Tests
    if: github.ref == 'refs/heads/master' || startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    needs: [integration-tests]
    # ... Cluster setup and tests ...

  # Release (only on tags)
  release:
    name: Release to Hex.pm
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    needs: [integration-tests, rbac-tests, cluster-tests]
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'
      - run: mix deps.get
      - run: mix hex.publish --yes
        env:
          HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
```

---

## Test Coverage Reporting

### Adding ExCoveralls

```elixir
# mix.exs
defp deps do
  [
    {:excoveralls, "~> 0.18", only: :test}
  ]
end

def project do
  [
    # ...
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.html": :test,
      "coveralls.github": :test
    ]
  ]
end
```

### CI Coverage Upload

```yaml
  coverage:
    name: Coverage Report
    runs-on: ubuntu-latest
    needs: [integration-tests]
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '28'
      # Start Weaviate service...
      - run: mix deps.get
      - run: mix coveralls.github --include integration
        env:
          WEAVIATE_INTEGRATION: "true"
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Workflow Triggers and Conditions

### PR Workflow
- Runs: unit-tests, format, dialyzer
- Integration tests: Basic (single Weaviate version)
- Skip: RBAC, cluster, performance

### Main Branch Workflow
- Runs: All PR tests
- Integration tests: Full matrix (5 versions)
- Include: RBAC, cluster tests

### Tag/Release Workflow
- Runs: Full test suite
- Include: All advanced tests
- Trigger: Hex.pm publish

---

## Environment Variables Reference

| Variable | Purpose | Where Set |
|----------|---------|-----------|
| `WEAVIATE_INTEGRATION` | Enable live tests | CI env |
| `WEAVIATE_VERSION` | Weaviate image tag | CI matrix |
| `WEAVIATE_URL` | HTTP endpoint | CI env |
| `WEAVIATE_GRPC_PORT` | gRPC port | CI env |
| `WEAVIATE_ADMIN_KEY` | RBAC admin key | CI secrets |
| `HEX_API_KEY` | Hex.pm publish | CI secrets |
| `GITHUB_TOKEN` | Coverage upload | CI secrets |

---

## Estimated CI Times

| Job | Duration | Parallelism |
|-----|----------|-------------|
| Format & Lint | 1 min | N/A |
| Dialyzer | 3 min | N/A |
| Unit Tests | 2 min | 2 OTP versions |
| Integration Tests | 5 min | 5 Weaviate versions |
| RBAC Tests | 3 min | N/A |
| Cluster Tests | 5 min | N/A |
| **Total (PR)** | ~8 min | Parallel |
| **Total (Main)** | ~15 min | Parallel |
