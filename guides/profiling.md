# Profiling WeaviateEx

Elixir provides built-in profiling tools via the Erlang/OTP runtime. This guide shows how to use them with WeaviateEx to identify performance bottlenecks.

## fprof - Function Profiling

`fprof` provides detailed function call analysis including call counts and accumulated time. Best for understanding the full call graph.

```elixir
# Connect to Weaviate
config = WeaviateEx.Connect.to_local()
{:ok, client} = WeaviateEx.Client.connect(config)

# Generate a test vector
vector = for _ <- 1..128, do: :rand.uniform()

# Profile a query operation
:fprof.apply(fn ->
  WeaviateEx.Query.get("MyCollection")
  |> WeaviateEx.Query.near_vector(vector)
  |> WeaviateEx.Query.limit(10)
  |> WeaviateEx.Query.execute(client)
end, [])

# Generate analysis
:fprof.profile()
:fprof.analyse(dest: ~c"fprof.analysis")
```

The output file `fprof.analysis` contains detailed timing information for every function called.

## eprof - Time Profiling

`eprof` measures wall-clock time per function. Lighter weight than fprof, good for identifying slow functions.

```elixir
# Start the profiler
:eprof.start()
:eprof.start_profiling([self()])

# Run your operations
config = WeaviateEx.Connect.to_local()
{:ok, client} = WeaviateEx.Client.connect(config)

# Batch insert
objects = for i <- 1..100 do
  %{
    class: "TestCollection",
    properties: %{title: "Object #{i}"},
    vector: for(_ <- 1..128, do: :rand.uniform())
  }
end
WeaviateEx.Batch.create_objects(client, objects)

# Stop and analyze
:eprof.stop_profiling()
:eprof.analyze()
```

## cprof - Call Count Profiling

`cprof` counts function calls without timing overhead. Useful for finding hot spots.

```elixir
# Start counting
:cprof.start()

# Run operations
config = WeaviateEx.Connect.to_local()
{:ok, client} = WeaviateEx.Client.connect(config)
WeaviateEx.Collections.list(client)

# Get results
:cprof.pause()
:cprof.analyse()
```

## Profiling in IEx

You can run profiling interactively in IEx:

```elixir
# Start IEx with the project
iex -S mix

# Run a quick profile
:fprof.apply(&YourModule.your_function/0, [])
:fprof.profile()
:fprof.analyse(totals: true)
```

## Profiling Tips

### 1. Profile Representative Operations

Don't just profile a single query - profile the operations your application actually performs:

```elixir
# Profile a realistic workflow
:fprof.apply(fn ->
  # Your actual workflow here
  {:ok, client} = WeaviateEx.Client.connect(config)

  # Create objects
  WeaviateEx.Batch.create_objects(client, objects)

  # Query them
  WeaviateEx.Query.get("Collection")
  |> WeaviateEx.Query.bm25("search query")
  |> WeaviateEx.Query.execute(client)
end, [])
```

### 2. Warm Up Before Profiling

Run operations once before profiling to avoid measuring JIT compilation:

```elixir
# Warm up
WeaviateEx.Query.get("Collection") |> WeaviateEx.Query.execute(client)

# Now profile
:fprof.apply(fn ->
  WeaviateEx.Query.get("Collection") |> WeaviateEx.Query.execute(client)
end, [])
```

### 3. Focus on Your Code

Filter results to show only WeaviateEx modules:

```elixir
:fprof.analyse(
  dest: ~c"fprof.analysis",
  callers: true,
  sort: :own,
  totals: true
)
# Then grep the output for WeaviateEx
```

## Benchee for Performance Comparison

For comparing different approaches, use the benchmark suite:

```bash
# Run all benchmarks
mix weaviate.bench

# Run specific benchmark
mix weaviate.bench query
mix weaviate.bench batch
```

Results are saved to `bench/output/` as HTML files with detailed statistics and comparison charts.

See the `bench/` directory for benchmark examples you can adapt for your use case.

## Memory Profiling

Elixir processes can be inspected for memory usage:

```elixir
# Get process info
Process.info(self(), :memory)

# For GenServer state size
:sys.get_state(pid) |> :erts_debug.size()
```

## Tracing with :recon

For production-safe tracing, consider adding `recon` as a dependency:

```elixir
# mix.exs
{:recon, "~> 2.5", only: :dev}
```

Then use it for safe runtime tracing:

```elixir
# Trace calls to a specific function
:recon_trace.calls({WeaviateEx.Query, :execute, 2}, 10)

# Trace with return values
:recon_trace.calls({WeaviateEx.Query, :execute, :return_trace}, 10)
```

## Further Reading

- [Erlang Profiling Documentation](https://www.erlang.org/doc/efficiency_guide/profiling.html)
- [Erlang fprof Manual](https://www.erlang.org/doc/man/fprof.html)
- [Benchee Documentation](https://hexdocs.pm/benchee)
