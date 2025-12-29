# Embedded Mode Guide

This guide covers running Weaviate in embedded mode using WeaviateEx. Embedded mode allows you to run a local Weaviate instance without managing external containers or services.

## Overview

Embedded Weaviate:
- Downloads the official Weaviate binary automatically
- Runs as a subprocess managed by your Elixir application
- Persists data locally
- Ideal for development, testing, and edge deployments

## Requirements

- **Operating System**: Linux or macOS (Windows is not supported)
- **Architecture**: x86_64 (amd64) or arm64 (aarch64)
- **Network**: Internet connection for initial binary download

## Quick Start

```elixir
# Start an embedded instance
{:ok, instance} = WeaviateEx.start_embedded()

# Verify it's running
{:ok, true} = WeaviateEx.ready?()
{:ok, meta} = WeaviateEx.health_check()
IO.puts("Running Weaviate #{meta["version"]}")

# Use Weaviate normally...
{:ok, _} = WeaviateEx.Collections.create("Test", %{
  properties: [%{name: "data", dataType: ["text"]}]
})

# Stop when done
:ok = WeaviateEx.stop_embedded(instance)
```

## Configuration Options

### All Options

```elixir
{:ok, instance} = WeaviateEx.start_embedded(
  version: "1.30.5",                     # Weaviate version
  hostname: "127.0.0.1",                 # Bind address
  port: 8079,                            # HTTP port
  grpc_port: 50060,                      # gRPC port
  binary_path: "~/.cache/weaviate-embedded",  # Binary cache location
  persistence_data_path: "~/.local/share/weaviate",  # Data storage
  environment_variables: %{},            # Additional env vars
  ready_timeout: 30_000                  # Startup timeout in ms
)
```

### Version Selection

```elixir
# Specific version
{:ok, instance} = WeaviateEx.start_embedded(version: "1.30.5")

# Latest version
{:ok, instance} = WeaviateEx.start_embedded(version: "latest")

# Version without 'v' prefix
{:ok, instance} = WeaviateEx.start_embedded(version: "1.30.5")

# With 'v' prefix
{:ok, instance} = WeaviateEx.start_embedded(version: "v1.30.5")

# Direct download URL
{:ok, instance} = WeaviateEx.start_embedded(
  version: "https://github.com/weaviate/weaviate/releases/download/v1.30.5/weaviate-v1.30.5-Linux-amd64.tar.gz"
)
```

### Custom Ports

```elixir
{:ok, instance} = WeaviateEx.start_embedded(
  port: 8090,
  grpc_port: 50061
)

# Update your client configuration
Application.put_env(:weaviate_ex, :url, "http://127.0.0.1:8090")
```

### Custom Data Path

```elixir
{:ok, instance} = WeaviateEx.start_embedded(
  persistence_data_path: "/path/to/my/weaviate/data"
)
```

### Environment Variables

Configure Weaviate through environment variables:

```elixir
{:ok, instance} = WeaviateEx.start_embedded(
  environment_variables: %{
    "QUERY_DEFAULTS_LIMIT" => "50",
    "AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED" => "true",
    "ENABLE_MODULES" => "text2vec-openai,generative-openai",
    "DEFAULT_VECTORIZER_MODULE" => "text2vec-openai",
    "OPENAI_APIKEY" => System.get_env("OPENAI_API_KEY")
  }
)
```

## Direct Usage via Embedded Module

For more control, use `WeaviateEx.Embedded` directly:

```elixir
alias WeaviateEx.Embedded

# Start with all options
{:ok, instance} = Embedded.start(
  version: "1.30.5",
  port: 8079
)

# Get instance information
IO.inspect(instance.options)     # Configuration used
IO.inspect(instance.executable)  # Path to binary
IO.inspect(instance.os_pid)      # OS process ID

# Stop the instance
:ok = Embedded.stop(instance)
```

## Default Modules

By default, embedded Weaviate enables these modules:

- `text2vec-openai` - OpenAI embeddings
- `text2vec-cohere` - Cohere embeddings
- `text2vec-huggingface` - HuggingFace embeddings
- `ref2vec-centroid` - Reference vector aggregation
- `generative-openai` - OpenAI generative AI
- `qna-openai` - OpenAI Q&A
- `reranker-cohere` - Cohere reranker

To customize:

```elixir
{:ok, instance} = WeaviateEx.start_embedded(
  environment_variables: %{
    "ENABLE_MODULES" => "text2vec-openai,text2vec-cohere,generative-openai,generative-anthropic"
  }
)
```

## Binary Caching

WeaviateEx caches downloaded binaries to avoid re-downloading:

- **Default location**: `~/.cache/weaviate-embedded/` (or `$XDG_CACHE_HOME/weaviate-embedded/`)
- **Binary naming**: `weaviate-{version}-{hash}`

Each version is stored with a unique hash to support multiple versions.

### Clear Cache

```elixir
# Get the default cache path
cache_path = Path.join(System.user_home!(), ".cache/weaviate-embedded")

# Remove all cached binaries
File.rm_rf!(cache_path)
```

## Data Persistence

Data is persisted locally:

- **Default location**: `~/.local/share/weaviate/` (or `$XDG_DATA_HOME/weaviate/`)
- Data persists across restarts
- Each instance uses the configured path

### Clear Data

```elixir
data_path = Path.join(System.user_home!(), ".local/share/weaviate")
File.rm_rf!(data_path)
```

## Multiple Instances

Run multiple embedded instances on different ports:

```elixir
# Instance 1
{:ok, instance1} = WeaviateEx.start_embedded(
  port: 8081,
  grpc_port: 50061,
  persistence_data_path: "/tmp/weaviate-1"
)

# Instance 2
{:ok, instance2} = WeaviateEx.start_embedded(
  port: 8082,
  grpc_port: 50062,
  persistence_data_path: "/tmp/weaviate-2"
)

# Use each instance
client1 = WeaviateEx.Client.new!(base_url: "http://127.0.0.1:8081")
client2 = WeaviateEx.Client.new!(base_url: "http://127.0.0.1:8082")

# Stop both
WeaviateEx.stop_embedded(instance1)
WeaviateEx.stop_embedded(instance2)
```

## Testing with Embedded Weaviate

Use embedded mode in your test setup:

```elixir
# test/test_helper.exs
{:ok, _instance} = WeaviateEx.start_embedded(port: 8099)
Application.put_env(:weaviate_ex, :url, "http://127.0.0.1:8099")
ExUnit.start()
```

Or in a test module:

```elixir
defmodule MyApp.WeaviateTest do
  use ExUnit.Case

  setup_all do
    {:ok, instance} = WeaviateEx.start_embedded(
      port: 8099,
      persistence_data_path: "/tmp/weaviate-test-#{System.unique_integer()}"
    )

    Application.put_env(:weaviate_ex, :url, "http://127.0.0.1:8099")

    on_exit(fn ->
      WeaviateEx.stop_embedded(instance)
    end)

    {:ok, instance: instance}
  end

  test "can create collection" do
    {:ok, _} = WeaviateEx.Collections.create("TestCollection", %{
      properties: [%{name: "data", dataType: ["text"]}]
    })

    {:ok, true} = WeaviateEx.Collections.exists?("TestCollection")
  end
end
```

## Development Workflow

A typical development setup:

```elixir
defmodule MyApp.DevServer do
  @moduledoc "Development Weaviate server manager"

  def start do
    case WeaviateEx.start_embedded(
      version: "1.30.5",
      port: 8080,
      environment_variables: %{
        "ENABLE_MODULES" => "text2vec-openai,generative-openai",
        "OPENAI_APIKEY" => System.get_env("OPENAI_API_KEY")
      }
    ) do
      {:ok, instance} ->
        IO.puts("Weaviate started on http://127.0.0.1:8080")
        {:ok, instance}

      {:error, reason} ->
        IO.puts("Failed to start Weaviate: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def stop(instance) do
    WeaviateEx.stop_embedded(instance)
    IO.puts("Weaviate stopped")
  end
end

# Usage in IEx
{:ok, instance} = MyApp.DevServer.start()
# ... do development work ...
MyApp.DevServer.stop(instance)
```

## GenServer Wrapper

For long-running applications, wrap in a GenServer:

```elixir
defmodule MyApp.WeaviateServer do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  @impl true
  def init(opts) do
    case WeaviateEx.start_embedded(opts) do
      {:ok, instance} ->
        {:ok, %{instance: instance}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:stop, _from, %{instance: instance} = state) do
    WeaviateEx.stop_embedded(instance)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def terminate(_reason, %{instance: instance}) do
    WeaviateEx.stop_embedded(instance)
  end
end

# Add to your supervision tree
children = [
  {MyApp.WeaviateServer, [version: "1.30.5", port: 8080]}
]
```

## Error Handling

```elixir
case WeaviateEx.start_embedded(version: "1.30.5") do
  {:ok, instance} ->
    # Success
    instance

  {:error, "Embedded Weaviate is not supported on Windows"} ->
    IO.puts("Please use Docker on Windows")
    :error

  {:error, "Embedded Weaviate did not become ready on " <> url} ->
    IO.puts("Startup timeout - check logs")
    :error

  {:error, reason} ->
    IO.puts("Failed: #{inspect(reason)}")
    :error
end
```

## Comparison with Docker

| Aspect | Embedded | Docker |
|--------|----------|--------|
| Setup | Automatic download | Requires Docker installation |
| Resource usage | Lower | Higher (container overhead) |
| Platform support | Linux, macOS | All platforms |
| Configuration | Environment variables | Docker Compose |
| Data persistence | Local filesystem | Docker volumes |
| Clustering | Not supported | Supported |
| Production use | Edge/development | Recommended |

## Limitations

1. **Single node only** - No clustering support in embedded mode
2. **Platform restrictions** - Linux and macOS only
3. **Resource constraints** - Shares resources with host process
4. **No hot reload** - Requires restart for configuration changes

## Next Steps

- [Getting Started](getting_started.md) - Basic WeaviateEx usage
- [Collections Guide](collections.md) - Create and configure collections
- [Vectorizers Guide](vectorizers.md) - Configure AI vectorizers
