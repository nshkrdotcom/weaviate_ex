# Tooling & Infrastructure Porting Plan

This document outlines the plan to port all non-source tooling, scripts, and infrastructure from the Python client to our Elixir port.

## Current State

| Category | Python Client | Elixir Port |
|----------|--------------|-------------|
| CI/CD | Comprehensive GitHub Actions | None |
| Pre-commit hooks | Yes (ruff, flake8, pyright) | None |
| Docker CI | 10 compose files | 10 (copied) |
| Documentation | Sphinx + ReadTheDocs | ExDoc |
| Code coverage | Codecov | None |
| Linting | ruff, flake8 | Credo |
| Type checking | pyright | Dialyzer |
| Contributing guide | Yes | No |
| Releasing guide | Yes | No |

---

## Phase 1: Copy Directly (No Changes Needed)

### 1.1 CI Docker Infrastructure ✅ DONE
```
ci/
├── docker-compose*.yml (10 files)
├── compose.sh
├── start_weaviate.sh
├── stop_weaviate.sh
├── start_weaviate_jt.sh
└── proxy/envoy.yaml
```

### 1.2 License
```bash
cp weaviate-python-client/LICENSE .
```
BSD 3-Clause - same license applies.

---

## Phase 2: Adapt for Elixir

### 2.1 GitHub Actions Workflow

Create `.github/workflows/main.yml`:

```yaml
name: Main

on:
  push:
    branches: [master]
    tags: ['**']
    paths-ignore:
      - docs/**
      - README.md
      - LICENSE
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

env:
  WEAVIATE_128: 1.28.16
  WEAVIATE_132: 1.32.23
  WEAVIATE_135: 1.35.0
  MIX_ENV: test

jobs:
  lint-and-format:
    name: Lint & Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '27.0'
          elixir-version: '1.18'
      - uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
      - run: mix deps.get
      - run: mix format --check-formatted
      - run: mix credo --strict
      - run: mix compile --warnings-as-errors

  dialyzer:
    name: Dialyzer
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '27.0'
          elixir-version: '1.18'
      - uses: actions/cache@v4
        with:
          path: |
            deps
            _build
            priv/plts
          key: ${{ runner.os }}-dialyzer-${{ hashFiles('**/mix.lock') }}
      - run: mix deps.get
      - run: mix dialyzer

  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        otp: ['26.0', '27.0']
        elixir: ['1.16', '1.17', '1.18']
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: ${{ matrix.otp }}
          elixir-version: ${{ matrix.elixir }}
      - uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ matrix.otp }}-${{ matrix.elixir }}-${{ hashFiles('**/mix.lock') }}
      - run: mix deps.get
      - run: mix test --cover --export-coverage default
      - uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.otp }}-${{ matrix.elixir }}
          path: cover/

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        weaviate: ['1.28.16', '1.32.23', '1.35.0']
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '27.0'
          elixir-version: '1.18'
      - uses: docker/login-action@v3
        if: ${{ !github.event.pull_request.head.repo.fork }}
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      - run: mix deps.get
      - name: Start Weaviate
        run: ./ci/start_weaviate.sh ${{ matrix.weaviate }}
      - name: Run integration tests
        run: WEAVIATE_INTEGRATION=true mix test --only integration
        env:
          WEAVIATE_URL: http://localhost:8080
      - name: Stop Weaviate
        run: ./ci/stop_weaviate.sh

  test-package:
    name: Test Package
    needs: [unit-tests, integration-tests]
    runs-on: ubuntu-latest
    strategy:
      matrix:
        weaviate: ['1.28.16', '1.32.23', '1.35.0']
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '27.0'
          elixir-version: '1.18'
      - run: mix deps.get
      - run: mix hex.build
      - name: Start Weaviate
        run: ./ci/start_weaviate.sh ${{ matrix.weaviate }}
      - run: WEAVIATE_INTEGRATION=true mix test
      - name: Stop Weaviate
        run: ./ci/stop_weaviate.sh

  publish:
    name: Publish to Hex.pm
    needs: [lint-and-format, dialyzer, unit-tests, integration-tests]
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '27.0'
          elixir-version: '1.18'
      - run: mix deps.get
      - run: mix hex.publish --yes
        env:
          HEX_API_KEY: ${{ secrets.HEX_API_KEY }}

  gh-release:
    name: GitHub Release
    needs: [publish]
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')
    steps:
      - uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true
          draft: true
```

### 2.2 Dependabot

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "mix"
    directory: "/"
    schedule:
      interval: "monthly"
    open-pull-requests-limit: 10
```

### 2.3 CODEOWNERS

Create `.github/CODEOWNERS`:

```
# CI and infrastructure
/ci/ @your-team
/.github/ @your-team
```

---

## Phase 3: Documentation

### 3.1 CONTRIBUTING.md

Create `CONTRIBUTING.md`:

```markdown
# Contributing to weaviate_ex

## Setup

1. Install Elixir 1.16+ and Erlang/OTP 26+
2. Clone the repository
3. Install dependencies:
   ```bash
   mix deps.get
   ```

## Development

Install in your project with path dependency:
```elixir
{:weaviate_ex, path: "/path/to/weaviate_ex"}
```

## Testing

### Unit Tests
```bash
mix test
```

### Integration Tests
Requires running Weaviate instance:
```bash
./ci/start_weaviate.sh
WEAVIATE_INTEGRATION=true mix test
./ci/stop_weaviate.sh
```

### Mock Tests
```bash
mix test --only mock
```

## Linting

```bash
mix format --check-formatted
mix credo --strict
mix dialyzer
```

## Creating a Pull Request

1. Create a feature branch from `master`
2. Make your changes
3. Ensure all tests pass
4. Ensure code is formatted: `mix format`
5. Open a PR to `master`

## Contributor License Agreement

[Same CLA text as Python client]
```

### 3.2 RELEASING.md

Create `RELEASING.md`:

```markdown
# Releasing weaviate_ex

## Step 1: Prepare for release

1. Pull latest master
2. Determine next version (semantic versioning)
3. Update CHANGELOG.md
4. Update version in mix.exs
5. Commit and push

## Step 2: Create release

```bash
git tag -a v0.3.0 -m "v0.3.0"
git push --tags
```

## Step 3: Monitor pipeline

CI will:
1. Run all tests
2. Publish to Hex.pm automatically
3. Create GitHub release (draft)

## Notes

- Version is in `mix.exs`
- Hex.pm publishing requires `HEX_API_KEY` secret
```

### 3.3 CHANGELOG.md

Create `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Object TTL configuration module
- ContextualAI generative provider
- AWS Bedrock/SageMaker vectorizer methods
- Google Vertex/Gemini vectorizer methods
- New vectorizers: VoyageAI, Morph, Model2Vec, ColBERT, Jina
- XAI generative provider
- OpenAI O1/O3 reasoning parameters

### Changed
- Updated Docker to Weaviate 1.28.14
- Copied Python client CI infrastructure

## [0.2.0] - 2025-10-19

### Added
- Embedded mode support
- Docker management Mix tasks
- Comprehensive examples
```

---

## Phase 4: Pre-commit Hooks (Optional)

Elixir doesn't have pre-commit.com support, but we can use git hooks:

Create `.githooks/pre-commit`:

```bash
#!/bin/bash
set -e

echo "Running format check..."
mix format --check-formatted

echo "Running credo..."
mix credo --strict

echo "Running tests..."
mix test --max-failures 1

echo "All checks passed!"
```

Enable with:
```bash
git config core.hooksPath .githooks
```

---

## Phase 5: Code Coverage

### 5.1 Codecov Integration

Add to `mix.exs`:
```elixir
defp project do
  [
    # ...
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [coveralls: :test, "coveralls.html": :test]
  ]
end
```

Create `.codecov.yml`:
```yaml
coverage:
  precision: 2
  round: down
  range: "70...100"
  status:
    project:
      default:
        target: 70%
        threshold: 5%
```

---

## Phase 6: Journey Tests

Port journey test concept - create `journey_tests/` directory with:

1. Full workflow tests (create collection → insert → query → delete)
2. Phoenix/Plug integration tests (like gunicorn tests)
3. Concurrency tests

---

## Implementation Checklist

### Immediate (Copy/Create)
- [x] CI Docker infrastructure
- [ ] `.github/workflows/main.yml`
- [ ] `.github/dependabot.yml`
- [ ] `.github/CODEOWNERS`
- [ ] `CONTRIBUTING.md`
- [ ] `RELEASING.md`
- [ ] `CHANGELOG.md`
- [ ] `LICENSE` (BSD 3-Clause)

### Short-term
- [ ] Codecov integration
- [ ] Git hooks for local development
- [ ] Update README with badges

### Medium-term
- [ ] Journey tests
- [ ] ReadTheDocs/ExDoc publishing
- [ ] Performance benchmarks

### Long-term
- [ ] Property-based tests
- [ ] Cluster integration tests
- [ ] RBAC tests
- [ ] Proxy/network tests

---

## Files to Create

```
weaviate_ex/
├── .github/
│   ├── workflows/
│   │   └── main.yml
│   ├── dependabot.yml
│   └── CODEOWNERS
├── .githooks/
│   └── pre-commit
├── .codecov.yml
├── CONTRIBUTING.md
├── RELEASING.md
├── CHANGELOG.md
├── LICENSE
└── journey_tests/
    ├── full_workflow_test.exs
    └── phoenix_integration_test.exs
```

---

## Equivalent Tooling Mapping

| Python Tool | Elixir Equivalent |
|-------------|-------------------|
| pytest | ExUnit |
| ruff | mix format |
| flake8 | Credo |
| pyright | Dialyzer |
| pre-commit | .githooks |
| setuptools_scm | mix.exs version |
| twine/PyPI | hex.publish |
| Sphinx | ExDoc |
| ReadTheDocs | HexDocs |
| coverage.py | ExCoveralls |
| Codecov | Codecov (same) |
