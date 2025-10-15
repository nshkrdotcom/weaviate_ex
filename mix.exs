defmodule WeaviateEx.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/yourusername/weaviate_ex"

  def project do
    [
      app: :weaviate_ex,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "WeaviateEx",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {WeaviateEx.Application, []}
    ]
  end

  defp deps do
    [
      # HTTP client with HTTP/2 and connection pooling
      {:finch, "~> 0.18"},

      # JSON encoding/decoding
      {:jason, "~> 1.4"},

      # Optional: gRPC support (for future enhancement)
      # {:grpc, "~> 0.7", optional: true},

      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    A modern Elixir client for Weaviate vector database with support for
    collections, objects, batch operations, GraphQL queries, and vector search.
    Includes health checks and friendly error messages for missing configuration.
    """
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Weaviate" => "https://weaviate.io"
      },
      maintainers: ["Your Name"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "INSTALL.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
