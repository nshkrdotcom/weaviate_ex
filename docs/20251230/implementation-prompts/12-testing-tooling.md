# Prompt - Testing Tooling (Benchmarks, Profiling, Pre-commit)

## Objective

Implement testing tooling for developer experience: benchmark suite with Benchee, profiling documentation, and pre-commit hooks for consistent code quality.

## Priority

P2 - Medium (Developer experience, polish)

## Required Reading (Docs)

- `docs/20251230/integration-test-gaps/03-tooling-gaps.md`
- `README.md`
- `CONTRIBUTING.md`
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `mix.exs` - Current dependencies
- `test/test_helper.exs` - Test configuration
- `.github/workflows/ci.yml` - CI configuration

## Required Reading (Python Reference)

- `../weaviate-python-client/requirements-test.txt` - pytest-benchmark
- `../weaviate-python-client/.pre-commit-config.yaml`

## Context

### Current State
- No formal benchmark suite
- No profiling documentation
- No pre-commit hooks
- Formatting and Credo run manually or in CI

### Gap
Python has:
- pytest-benchmark for performance testing
- py-spy and pytest-profiling for profiling
- .pre-commit-config.yaml for automated code quality checks

## Implementation Instructions

### Part 1: Benchmark Suite

#### Step 1: Add Benchee Dependency

Update `mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps
    {:benchee, "~> 1.3", only: :dev},
    {:benchee_html, "~> 1.0", only: :dev}
  ]
end
```

#### Step 2: Create Benchmark Directory

```bash
mkdir -p bench
```

#### Step 3: Create Batch Benchmark

Create `bench/batch_bench.exs`:

```elixir
# Batch Operations Benchmark
#
# Run with: mix run bench/batch_bench.exs
# Requires: Running Weaviate instance on localhost:8080

alias WeaviateEx.{Client, Collections, Batch}

# Setup
{:ok, client} = Client.connect("http://localhost:8080")

collection_name = "BenchmarkBatch"

# Cleanup any existing collection
Collections.delete(client, collection_name)

# Create test collection
{:ok, _} = Collections.create(client, collection_name, %{
  vectorizer: "none",
  properties: [
    %{name: "index", dataType: ["int"]},
    %{name: "data", dataType: ["text"]}
  ]
})

# Generate test data
generate_objects = fn count ->
  for i <- 1..count do
    %{
      properties: %{index: i, data: "Test data #{i}"},
      vector: for(_ <- 1..128, do: :rand.uniform())
    }
  end
end

objects_100 = generate_objects.(100)
objects_1000 = generate_objects.(1000)

Benchee.run(
  %{
    "batch_100_objects" => fn ->
      Batch.create_objects(client, collection_name, objects_100)
    end,
    "batch_1000_objects" => fn ->
      Batch.create_objects(client, collection_name, objects_1000)
    end
  },
  time: 10,
  memory_time: 2,
  warmup: 2,
  formatters: [
    {Benchee.Formatters.HTML, file: "bench/output/batch.html"},
    Benchee.Formatters.Console
  ],
  before_each: fn _ ->
    # Clear collection before each run
    Batch.delete_objects(client, collection_name, %{})
  end
)

# Cleanup
Collections.delete(client, collection_name)
Client.close(client)

IO.puts("\nBenchmark complete! See bench/output/batch.html for detailed results.")
```

#### Step 4: Create Query Benchmark

Create `bench/query_bench.exs`:

```elixir
# Query Operations Benchmark
#
# Run with: mix run bench/query_bench.exs

alias WeaviateEx.{Client, Collections, Batch, Query}

{:ok, client} = Client.connect("http://localhost:8080")

collection_name = "BenchmarkQuery"

# Setup collection with data
Collections.delete(client, collection_name)
{:ok, _} = Collections.create(client, collection_name, %{
  vectorizer: "none",
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ]
})

# Insert test data
objects = for i <- 1..10_000 do
  %{
    properties: %{
      title: "Document #{i}",
      content: "This is the content of document number #{i} with some searchable text."
    },
    vector: for(_ <- 1..128, do: :rand.uniform())
  }
end

Batch.create_objects(client, collection_name, objects)

# Wait for indexing
Process.sleep(2000)

# Generate query vector
query_vector = for(_ <- 1..128, do: :rand.uniform())

Benchee.run(
  %{
    "near_vector_limit_10" => fn ->
      Query.get(collection_name)
      |> Query.near_vector(query_vector)
      |> Query.limit(10)
      |> Query.execute(client)
    end,
    "near_vector_limit_100" => fn ->
      Query.get(collection_name)
      |> Query.near_vector(query_vector)
      |> Query.limit(100)
      |> Query.execute(client)
    end,
    "bm25_limit_10" => fn ->
      Query.get(collection_name)
      |> Query.bm25("document searchable text", ["title", "content"])
      |> Query.limit(10)
      |> Query.execute(client)
    end,
    "hybrid_limit_10" => fn ->
      Query.get(collection_name)
      |> Query.hybrid("document text", query_vector)
      |> Query.limit(10)
      |> Query.execute(client)
    end
  },
  time: 10,
  memory_time: 2,
  formatters: [
    {Benchee.Formatters.HTML, file: "bench/output/query.html"},
    Benchee.Formatters.Console
  ]
)

# Cleanup
Collections.delete(client, collection_name)
Client.close(client)
```

#### Step 5: Create Mix Task

Create `lib/mix/tasks/weaviate.bench.ex`:

```elixir
defmodule Mix.Tasks.Weaviate.Bench do
  @moduledoc """
  Runs WeaviateEx benchmarks.

  ## Usage

      mix weaviate.bench           # Run all benchmarks
      mix weaviate.bench batch     # Run batch benchmark
      mix weaviate.bench query     # Run query benchmark

  ## Requirements

  Requires a running Weaviate instance on localhost:8080.
  """

  use Mix.Task

  @shortdoc "Run WeaviateEx benchmarks"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    # Ensure output directory exists
    File.mkdir_p!("bench/output")

    bench_files = case args do
      [] -> Path.wildcard("bench/*_bench.exs")
      [name] -> [Path.join("bench", "#{name}_bench.exs")]
    end

    Enum.each(bench_files, fn file ->
      if File.exists?(file) do
        IO.puts("\n=== Running #{file} ===\n")
        Code.eval_file(file)
      else
        IO.puts("Benchmark file not found: #{file}")
      end
    end)
  end
end
```

### Part 2: Profiling Documentation

#### Step 6: Add Profiling Guide

Create `guides/profiling.md`:

```markdown
# Profiling WeaviateEx

Elixir provides built-in profiling tools. Here's how to use them with WeaviateEx.

## fprof - Function Profiling

Detailed function call analysis:

\`\`\`elixir
# Start profiling
:fprof.apply(fn ->
  {:ok, client} = WeaviateEx.Client.connect("http://localhost:8080")
  WeaviateEx.Query.get("MyCollection")
  |> WeaviateEx.Query.near_vector(vector)
  |> WeaviateEx.Query.execute(client)
end, [])

# Analyze results
:fprof.profile()
:fprof.analyse(dest: 'fprof.analysis')
\`\`\`

## eprof - Time Profiling

Wall-clock time per function:

\`\`\`elixir
:eprof.start()
:eprof.start_profiling([self()])

# Run operations
{:ok, client} = WeaviateEx.Client.connect("http://localhost:8080")
# ... your code ...

:eprof.stop_profiling()
:eprof.analyze()
\`\`\`

## cprof - Call Count Profiling

Count function calls:

\`\`\`elixir
:cprof.start()

# Run operations
# ...

:cprof.pause()
:cprof.analyse()
\`\`\`

## ExProf (Optional)

For more user-friendly profiling, add `{:exprof, "~> 0.2", only: :dev}`:

\`\`\`elixir
import ExProf.Macro

profile do
  WeaviateEx.Query.get("Collection")
  |> WeaviateEx.Query.execute(client)
end
\`\`\`

## Benchee for Performance Comparison

See `bench/` directory for benchmark examples:

\`\`\`bash
mix weaviate.bench
\`\`\`
```

### Part 3: Pre-commit Hooks

#### Step 7: Create Pre-commit Config

Create `.pre-commit-config.yaml`:

```yaml
# Pre-commit hooks for WeaviateEx
# Install: pip install pre-commit && pre-commit install

repos:
  # Standard hooks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      - id: mixed-line-ending
        args: ['--fix=lf']

  # Elixir hooks (local)
  - repo: local
    hooks:
      - id: mix-format
        name: mix format
        entry: mix format --check-formatted
        language: system
        files: '\.(ex|exs)$'
        pass_filenames: false

      - id: mix-compile
        name: mix compile (warnings as errors)
        entry: mix compile --warnings-as-errors
        language: system
        files: '\.(ex|exs)$'
        pass_filenames: false

      - id: mix-credo
        name: mix credo
        entry: mix credo --strict
        language: system
        files: '\.(ex|exs)$'
        pass_filenames: false

      # Dialyzer is slow, run manually
      - id: mix-dialyzer
        name: mix dialyzer
        entry: mix dialyzer
        language: system
        files: '\.(ex|exs)$'
        pass_filenames: false
        stages: [manual]
```

#### Step 8: Update CONTRIBUTING.md

Add pre-commit section:

```markdown
## Pre-commit Hooks

We use pre-commit hooks for consistent code quality. To set up:

\`\`\`bash
# Install pre-commit (Python package)
pip install pre-commit

# Or with Homebrew
brew install pre-commit

# Install hooks
pre-commit install

# Run on all files (optional)
pre-commit run --all-files

# Run manually (including slow dialyzer)
pre-commit run --all-files --hook-stage manual
\`\`\`

The hooks automatically run:
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `mix credo --strict`

Dialyzer runs manually due to its speed.
```

#### Step 9: Add .gitignore Entries

Update `.gitignore`:

```
# Benchmark output
/bench/output/
```

## Tests to Verify

No new tests, but verify:

1. Benchmark runs: `mix weaviate.bench`
2. Pre-commit installs: `pre-commit install`
3. Pre-commit runs: `pre-commit run --all-files`

## Docs Updates

### README.md

Add tooling section:

```markdown
## Development Tools

### Benchmarks

Run performance benchmarks:

\`\`\`bash
# Start Weaviate
mix weaviate.start

# Run all benchmarks
mix weaviate.bench

# Run specific benchmark
mix weaviate.bench query
\`\`\`

Results saved to `bench/output/`.

### Pre-commit Hooks

Install pre-commit hooks for automatic code quality checks:

\`\`\`bash
pip install pre-commit
pre-commit install
\`\`\`

### Profiling

See `guides/profiling.md` for profiling techniques.
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- Benchmark suite with Benchee (`mix weaviate.bench`)
- Batch and query performance benchmarks
- Pre-commit hooks configuration (`.pre-commit-config.yaml`)
- Profiling guide (`guides/profiling.md`)
- `mix weaviate.bench` task for running benchmarks
```

## Quality Gates

- [ ] Benchee dependency added and compiles
- [ ] `mix weaviate.bench` task works
- [ ] Pre-commit config valid: `pre-commit run --all-files`
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] README updated
- [ ] CONTRIBUTING.md updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `bench/` directory with batch and query benchmarks
2. `mix weaviate.bench` task implemented
3. `.pre-commit-config.yaml` created
4. Pre-commit hooks run format, compile, credo
5. `guides/profiling.md` created
6. Documentation updated
7. All quality gates pass
