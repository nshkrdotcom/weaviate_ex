defmodule Mix.Tasks.Weaviate.Bench do
  @moduledoc """
  Runs WeaviateEx benchmarks.

  ## Usage

      mix weaviate.bench           # Run all benchmarks
      mix weaviate.bench batch     # Run batch benchmark
      mix weaviate.bench query     # Run query benchmark

  ## Requirements

  Requires a running Weaviate instance on localhost:8080.

  Start Weaviate first:

      mix weaviate.start

  ## Output

  Results are saved to `bench/output/` as HTML files for detailed analysis.
  Console output provides quick summary statistics.

  ## Available Benchmarks

  - `batch` - Benchmark batch insert operations with various object counts
  - `query` - Benchmark query operations (near_vector, BM25, hybrid)

  ## Examples

      # Run all benchmarks
      mix weaviate.bench

      # Run only batch benchmarks
      mix weaviate.bench batch

      # Run only query benchmarks
      mix weaviate.bench query
  """

  use Mix.Task

  @shortdoc "Run WeaviateEx benchmarks"

  @impl Mix.Task
  def run(args) do
    # Ensure application is started
    Mix.Task.run("app.start")

    # Ensure output directory exists
    File.mkdir_p!("bench/output")

    bench_files =
      case args do
        [] ->
          Path.wildcard("bench/*_bench.exs")

        [name] ->
          file = Path.join("bench", "#{name}_bench.exs")

          if File.exists?(file) do
            [file]
          else
            print_benchmark_not_found(file)
            []
          end

        _ ->
          Mix.shell().error("Usage: mix weaviate.bench [benchmark_name]")
          []
      end

    if Enum.empty?(bench_files) do
      if args == [] do
        Mix.shell().info("No benchmarks found in bench/ directory.")
        Mix.shell().info("Create benchmark files matching bench/*_bench.exs pattern.")
      end
    else
      Enum.each(bench_files, fn file ->
        Mix.shell().info("\n" <> String.duplicate("=", 60))
        Mix.shell().info("Running #{file}")
        Mix.shell().info(String.duplicate("=", 60) <> "\n")
        Code.eval_file(file)
      end)

      Mix.shell().info("\n" <> String.duplicate("=", 60))
      Mix.shell().info("All benchmarks complete!")
      Mix.shell().info("HTML reports available in bench/output/")
      Mix.shell().info(String.duplicate("=", 60))
    end
  end

  defp print_benchmark_not_found(file) do
    Mix.shell().error("Benchmark file not found: #{file}")
    Mix.shell().info("\nAvailable benchmarks:")

    Path.wildcard("bench/*_bench.exs")
    |> Enum.each(fn f ->
      name = f |> Path.basename() |> String.replace("_bench.exs", "")
      Mix.shell().info("  - #{name}")
    end)
  end
end
