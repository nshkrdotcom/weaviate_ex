defmodule WeaviateEx.MixProject do
  use Mix.Project

  @version "0.2.0"
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
      source_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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

      # UUID generation
      {:uniq, "~> 0.6"},

      # Optional: gRPC support (for future enhancement)
      # {:grpc, "~> 0.7", optional: true},

      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.1", only: :test},
      {:bypass, "~> 2.1", only: :test}
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
      name: "weaviate_ex",
      description: description(),
      files: ~w(lib mix.exs README.md INSTALL.md CHANGELOG.md LICENSE assets),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Online documentation" => "https://hexdocs.pm/weaviate_ex",
        "Weaviate" => "https://weaviate.io"
      },
      maintainers: ["nshkrdotcom"],
      exclude_patterns: [
        "priv/plts",
        ".DS_Store"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "WeaviateEx",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      assets: %{"assets" => "assets"},
      logo: "assets/weaviate_ex.svg",
      extras: [
        "README.md",
        "INSTALL.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Guides: ["README.md", "INSTALL.md"],
        "Release Notes": ["CHANGELOG.md"]
      ],
      groups_for_modules: [
        "Core API": [WeaviateEx],
        Application: [WeaviateEx.Application]
      ],
      before_closing_head_tag: fn
        :html ->
          """
          <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
          <script>
            let initialized = false;

            window.addEventListener("exdoc:loaded", () => {
              if (!initialized) {
                mermaid.initialize({
                  startOnLoad: false,
                  theme: document.body.className.includes("dark") ? "dark" : "default"
                });
                initialized = true;
              }

              let id = 0;
              for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
                const preEl = codeEl.parentElement;
                const graphDefinition = codeEl.textContent;
                const graphEl = document.createElement("div");
                const graphId = "mermaid-graph-" + id++;
                mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
                  graphEl.innerHTML = svg;
                  bindFunctions?.(graphEl);
                  preEl.insertAdjacentElement("afterend", graphEl);
                  preEl.remove();
                });
              }
            });
          </script>
          """

        _ ->
          ""
      end
    ]
  end
end
