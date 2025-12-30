# Gap Analysis: Testing Tooling

**Priority**: P2 - Nice to Have
**Effort**: Medium
**Status**: Not Implemented

---

## Overview

The Python client includes several testing tools that enhance code quality and performance monitoring. These are considered "nice to have" rather than critical for parity.

---

## Gap 1: Benchmark Suite

### Python Implementation

```
# requirements-test.txt
pytest-benchmark==5.1.0
```

Usage in tests:

```python
def test_batch_insert_performance(benchmark):
    result = benchmark(batch_insert_1000_objects)
    assert result is not None
```

### Current Elixir Status

No formal benchmark suite. Performance is tested informally.

### Recommended Implementation

Add `benchee` for Elixir benchmarking:

```elixir
# mix.exs
defp deps do
  [
    {:benchee, "~> 1.3", only: :dev}
  ]
end
```

Create benchmark files:

```
weaviate_ex/
├── bench/
│   ├── batch_bench.exs
│   ├── query_bench.exs
│   └── connection_bench.exs
```

Example benchmark (`bench/batch_bench.exs`):

```elixir
alias WeaviateEx.Client

{:ok, client} = Client.connect("http://localhost:8080")

# Setup: Create test collection
collection_name = "BenchmarkTest"
Client.collections_create(client, %{name: collection_name, vectorizer: "none"})

# Generate test data
objects_100 = for i <- 1..100, do: %{properties: %{index: i}}
objects_1000 = for i <- 1..1000, do: %{properties: %{index: i}}
objects_10000 = for i <- 1..10000, do: %{properties: %{index: i}}

Benchee.run(
  %{
    "batch_insert_100" => fn -> Client.batch_create(client, collection_name, objects_100) end,
    "batch_insert_1000" => fn -> Client.batch_create(client, collection_name, objects_1000) end,
    "batch_insert_10000" => fn -> Client.batch_create(client, collection_name, objects_10000) end
  },
  time: 10,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ]
)

# Cleanup
Client.collections_delete(client, collection_name)
Client.close(client)
```

Add mix task:

```elixir
# lib/mix/tasks/weaviate.bench.ex
defmodule Mix.Tasks.Weaviate.Bench do
  use Mix.Task

  @shortdoc "Run Weaviate client benchmarks"

  def run(args) do
    Mix.Task.run("app.start")

    bench_files = Path.wildcard("bench/**/*.exs")

    case args do
      [] -> Enum.each(bench_files, &Code.eval_file/1)
      [name] ->
        file = Enum.find(bench_files, &String.contains?(&1, name))
        if file, do: Code.eval_file(file), else: IO.puts("Benchmark not found: #{name}")
    end
  end
end
```

---

## Gap 2: Profiling Tools

### Python Implementation

```
# requirements-test.txt
pytest-profiling==1.8.1
py-spy==0.4.1
```

### Current Elixir Status

No profiling integration. Elixir has built-in tools but no project configuration.

### Recommended Implementation

Elixir has excellent built-in profiling tools. Document their usage:

```elixir
# mix.exs - already available via :tools
```

Add convenience mix tasks:

```elixir
# lib/mix/tasks/weaviate.profile.ex
defmodule Mix.Tasks.Weaviate.Profile do
  use Mix.Task

  @shortdoc "Profile Weaviate client operations"

  def run(args) do
    Mix.Task.run("app.start")

    case args do
      ["fprof" | rest] -> run_fprof(rest)
      ["eprof" | rest] -> run_eprof(rest)
      ["cprof" | rest] -> run_cprof(rest)
      _ -> print_help()
    end
  end

  defp run_fprof(args) do
    # Function profiling
    :fprof.apply(&profile_target/0, [])
    :fprof.profile()
    :fprof.analyse(dest: 'fprof.analysis')
    IO.puts("Profile written to fprof.analysis")
  end

  defp run_eprof(_args) do
    # Time profiling
    :eprof.start()
    :eprof.start_profiling([self()])
    profile_target()
    :eprof.stop_profiling()
    :eprof.analyze()
  end

  defp run_cprof(_args) do
    # Call count profiling
    :cprof.start()
    profile_target()
    :cprof.pause()
    :cprof.analyse()
  end

  defp profile_target do
    {:ok, client} = WeaviateEx.Client.connect("http://localhost:8080")
    # Run representative operations
    WeaviateEx.Client.meta(client)
    WeaviateEx.Client.close(client)
  end

  defp print_help do
    IO.puts("""
    Usage: mix weaviate.profile <profiler>

    Profilers:
      fprof  - Function profiling (detailed call graph)
      eprof  - Time profiling (wall clock time per function)
      cprof  - Call count profiling (number of calls per function)
    """)
  end
end
```

---

## Gap 3: Pre-commit Hooks

### Python Implementation

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.14.7
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/RobertCraiworthy/pyright-pre-commit
    hooks:
      - id: pyright
```

### Current Elixir Status

No pre-commit configuration.

### Recommended Implementation

Create `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict

  - repo: local
    hooks:
      - id: mix-format
        name: mix format
        entry: mix format --check-formatted
        language: system
        types: [elixir]
        pass_filenames: false

      - id: mix-credo
        name: mix credo
        entry: mix credo --strict
        language: system
        types: [elixir]
        pass_filenames: false

      - id: mix-compile-warnings
        name: mix compile warnings
        entry: mix compile --warnings-as-errors
        language: system
        types: [elixir]
        pass_filenames: false

      - id: mix-dialyzer
        name: mix dialyzer
        entry: mix dialyzer
        language: system
        types: [elixir]
        pass_filenames: false
        stages: [manual]  # Only run manually, too slow for every commit
```

Installation instructions for README:

```markdown
## Pre-commit Hooks (Optional)

Install pre-commit hooks for automatic code quality checks:

```bash
# Install pre-commit (if not already installed)
pip install pre-commit

# Install hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files
```
```

---

## Gap 4: Code Coverage in CI

### Python Implementation

```yaml
# .github/workflows/main.yaml
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage.xml
    fail_ci_if_error: true
```

`coveragerc`:

```ini
[run]
omit = *tests*/*,*__init__.py,weaviate/proto/**

[report]
exclude_lines =
  pragma: not covered
  @overload
  @abstractmethod
```

### Current Elixir Status

Coverage is available locally via `mix test --cover` but not integrated into CI.

### Recommended Implementation

#### Step 1: Add excoveralls dependency

```elixir
# mix.exs
defp deps do
  [
    {:excoveralls, "~> 0.18", only: :test}
  ]
end

# In project/0
def project do
  [
    # ... existing config
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      "coveralls.github": :test
    ]
  ]
end
```

#### Step 2: Create coveralls.json

```json
{
  "coverage_options": {
    "treat_no_relevant_lines_as_covered": true,
    "minimum_coverage": 80
  },
  "skip_files": [
    "lib/weaviate_ex/proto/",
    "test/"
  ]
}
```

#### Step 3: Update CI workflow

```yaml
# .github/workflows/ci.yml
unit-tests:
  name: Unit Tests
  runs-on: ubuntu-latest

  steps:
    # ... existing steps

    - name: Run tests with coverage
      run: mix coveralls.github
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v4
      with:
        files: ./cover/excoveralls.json
        fail_ci_if_error: false
```

#### Step 4: Add Codecov configuration

Create `codecov.yml`:

```yaml
coverage:
  precision: 2
  round: down
  range: "70...100"

  status:
    project:
      default:
        target: 80%
        threshold: 2%
    patch:
      default:
        target: 80%

ignore:
  - "lib/weaviate_ex/proto/**/*"
  - "test/**/*"

comment:
  layout: "reach,diff,flags,tree"
  behavior: default
  require_changes: true
```

---

## Gap 5: Protocol Buffer Version Matrix Testing

### Python Implementation

```yaml
# .github/workflows/main.yaml
proto-tests:
  strategy:
    matrix:
      grpcio-version: [1.60.0, 1.61.0, 1.62.0, ...]
      protobuf-version: [4.25.0, 4.25.1, 5.26.0, ...]
```

### Current Elixir Status

Single grpc/protobuf version tested.

### Recommended Implementation

This is lower priority for Elixir as the gRPC ecosystem is more stable.

If needed, add to CI:

```yaml
grpc-compatibility:
  name: gRPC Compatibility
  runs-on: ubuntu-latest

  strategy:
    matrix:
      grpc-version: ["0.7.0", "0.8.0"]
      protobuf-version: ["0.12.0", "0.13.0"]

  steps:
    - uses: actions/checkout@v4

    - name: Override dependencies
      run: |
        # Update mix.exs with specific versions
        sed -i 's/{:grpc, "~> [^"]*"}/{:grpc, "~> ${{ matrix.grpc-version }}"}/' mix.exs
        sed -i 's/{:protobuf, "~> [^"]*"}/{:protobuf, "~> ${{ matrix.protobuf-version }}"}/' mix.exs

    - name: Install dependencies
      run: mix deps.get

    - name: Run tests
      run: mix test
```

---

## Summary: Tooling Gaps

| Tool | Python | Elixir Equivalent | Priority | Effort |
|------|--------|-------------------|----------|--------|
| Benchmarks | pytest-benchmark | benchee | P2 | 4 hours |
| Profiling | py-spy, pytest-profiling | Built-in (fprof, eprof) | P2 | 2 hours |
| Pre-commit | .pre-commit-config.yaml | Same (local hooks) | P2 | 1 hour |
| Code Coverage CI | Codecov | excoveralls + Codecov | P2 | 2 hours |
| Proto version matrix | 8x8 matrix | Not needed | P3 | - |

---

## Acceptance Criteria

### Benchmarks
- [ ] `benchee` added as dev dependency
- [ ] `bench/` directory with at least 3 benchmarks
- [ ] `mix weaviate.bench` task works

### Profiling
- [ ] `mix weaviate.profile` task documented
- [ ] Example profiling workflow in README

### Pre-commit
- [ ] `.pre-commit-config.yaml` created
- [ ] Installation documented in README/CONTRIBUTING

### Code Coverage
- [ ] `excoveralls` integrated
- [ ] Codecov badge in README
- [ ] Coverage reports uploaded in CI

---

## Total Effort Estimate

| Task | Effort |
|------|--------|
| Benchmark suite | 4 hours |
| Profiling documentation | 2 hours |
| Pre-commit hooks | 1 hour |
| Code coverage CI | 2 hours |
| **Total** | **9 hours** |
