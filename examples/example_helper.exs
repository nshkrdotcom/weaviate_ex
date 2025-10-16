defmodule ExampleHelper do
  @moduledoc """
  Helper module for running examples with clean output formatting.
  """

  def check_weaviate! do
    case WeaviateEx.health_check() do
      {:ok, _} ->
        :ok

      {:error, _} ->
        IO.puts("\n#{red("✗")} #{bold("Weaviate is not running!")}\n")
        IO.puts("#{yellow("Please start Weaviate using one of these methods:")}\n")
        IO.puts("  #{cyan("Option 1:")} mix weaviate.start")
        IO.puts("  #{cyan("Option 2:")} docker compose up -d\n")
        IO.puts("#{dim("Then run this example again.")}\n")
        System.halt(1)
    end
  end

  def section(title) do
    IO.puts(
      "\n#{blue("━━━")} #{bold(title)} #{blue("━" <> String.duplicate("━", max(50 - String.length(title), 0)))}"
    )
  end

  def step(description) do
    IO.puts("\n#{green("▸")} #{description}")
  end

  def command(code) do
    IO.puts("#{dim("  >")} #{yellow(code)}")
  end

  def query(graphql) when is_binary(graphql) do
    formatted =
      graphql
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&"  #{dim("│")} #{&1}")
      |> Enum.join("\n")

    IO.puts("\n#{dim("  GraphQL Query:")}\n#{formatted}")
  end

  def result(label, data) do
    formatted = inspect(data, pretty: true, width: 80, limit: :infinity)

    lines =
      formatted
      |> String.split("\n")
      |> Enum.map(&"  #{&1}")
      |> Enum.join("\n")

    IO.puts("\n#{dim("  #{label}:")}\n#{cyan(lines)}")
  end

  def success(message) do
    IO.puts("  #{green("✓")} #{message}")
  end

  def error(message) do
    IO.puts("  #{red("✗")} #{message}")
  end

  def cleanup(client, collection_name) do
    IO.puts("\n#{dim("Cleaning up...")}")
    WeaviateEx.API.Collections.delete(client, collection_name)
  end

  # ANSI color helpers
  defp bold(text), do: "\e[1m#{text}\e[0m"
  defp dim(text), do: "\e[2m#{text}\e[0m"
  defp red(text), do: "\e[31m#{text}\e[0m"
  defp green(text), do: "\e[32m#{text}\e[0m"
  defp yellow(text), do: "\e[33m#{text}\e[0m"
  defp blue(text), do: "\e[34m#{text}\e[0m"
  defp cyan(text), do: "\e[36m#{text}\e[0m"
end
