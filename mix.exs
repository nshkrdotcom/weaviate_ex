defmodule WeaviateEx.MixProject do
  use Mix.Project

  @version "0.7.4"
  @source_url "https://github.com/nshkrdotcom/weaviate_ex"

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
      dialyzer: dialyzer(),
      name: "WeaviateEx",
      source_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env()),
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :crypto, :public_key],
      mod: {WeaviateEx.Application, []}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp deps do
    [
      # HTTP client - retained for schema operations (no gRPC schema support in Weaviate)
      {:finch, "~> 0.18"},

      # JSON encoding/decoding - for config and schema operations
      {:jason, "~> 1.4"},

      # UUID generation
      {:uniq, "~> 0.6"},

      # gRPC support for data operations, queries, batch, etc.
      {:grpc, "~> 0.9"},
      {:protobuf, "~> 0.13"},

      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:supertester, "~> 0.4.0", only: :test},

      # Benchmarking
      {:benchee, "~> 1.3", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},

      # Journey test dependencies (Phoenix/Plug web framework integration)
      {:phoenix, "~> 1.7", only: :test},
      {:phoenix_html, "~> 4.0", only: :test},
      {:bandit, "~> 1.0", only: :test},
      {:plug, "~> 1.15", only: :test}
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
        "LICENSE",
        # Guides
        "guides/getting_started.md",
        "guides/collections.md",
        "guides/crud_operations.md",
        "guides/queries.md",
        "guides/references.md",
        "guides/generative_search.md",
        "guides/multi_tenancy.md",
        "guides/embedded_mode.md",
        "guides/vectorizers.md",
        "guides/profiling.md"
      ],
      groups_for_extras: [
        Introduction: ["README.md", "INSTALL.md"],
        Guides: [
          "guides/getting_started.md",
          "guides/collections.md",
          "guides/crud_operations.md",
          "guides/queries.md",
          "guides/references.md",
          "guides/generative_search.md",
          "guides/multi_tenancy.md",
          "guides/embedded_mode.md",
          "guides/vectorizers.md",
          "guides/profiling.md"
        ],
        "Release Notes": ["CHANGELOG.md"]
      ],
      groups_for_modules: [
        "Core API": [
          WeaviateEx,
          WeaviateEx.Collections,
          WeaviateEx.Objects,
          WeaviateEx.Query,
          WeaviateEx.Batch
        ],
        "Advanced API": [
          WeaviateEx.API.Generative,
          WeaviateEx.API.References,
          WeaviateEx.API.Tenants,
          WeaviateEx.API.Cluster,
          WeaviateEx.API.VectorConfig
        ],
        "Query Features": [
          WeaviateEx.Query.Rerank,
          WeaviateEx.Query.GroupBy
        ],
        "Batch Features": [
          WeaviateEx.Batch.FixedSize,
          WeaviateEx.Batch.Dynamic,
          WeaviateEx.Batch.RateLimited,
          WeaviateEx.Batch.DeleteResult
        ],
        "Cluster Types": [
          WeaviateEx.Cluster.Node,
          WeaviateEx.Cluster.Shard,
          WeaviateEx.Cluster.Replication
        ],
        Infrastructure: [
          WeaviateEx.Client,
          WeaviateEx.Embedded,
          WeaviateEx.Integrations,
          WeaviateEx.Error
        ],
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
