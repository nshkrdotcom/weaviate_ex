# WeaviateEx

A modern Elixir client for [Weaviate](https://weaviate.io) vector database (v2.0).

WeaviateEx provides a clean, idiomatic Elixir interface with:
- ✅ **Auto Health Checks** - Validates connection on startup
- ✅ **Friendly Error Messages** - Helpful guidance for missing configuration
- ✅ **Easy Setup** - One-command Docker installation
- 🚧 **Collections API** - Create and manage vector collections (coming soon)
- 🚧 **Objects API** - CRUD operations with vectors (coming soon)
- 🚧 **Batch Operations** - Efficient bulk imports (coming soon)
- 🚧 **GraphQL Queries** - Complex searches and filters (coming soon)

## Quick Start

### 1. Install Weaviate

Run the installation script to set up Weaviate with Docker:

```bash
./install.sh
```

This will:
- Install Docker (if needed)
- Create a `.env` file with configuration
- Start Weaviate in Docker
- Verify the connection

For detailed installation instructions, see [INSTALL.md](INSTALL.md).

### 2. Add to Your Project

Add `weaviate_ex` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:weaviate_ex, "~> 2.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

### 3. Configure

The library automatically reads configuration from environment variables (loaded from `.env`):

```bash
# .env file (created by install.sh)
WEAVIATE_URL=http://localhost:8080
WEAVIATE_API_KEY=  # Optional, for authenticated instances
```

Alternatively, configure in `config/config.exs`:

```elixir
config :weaviate_ex,
  url: "http://localhost:8080",
  api_key: nil  # Optional
```

### 4. Test the Connection

The library automatically performs a health check on startup. You'll see:

```
[WeaviateEx] Successfully connected to Weaviate
  URL: http://localhost:8080
  Version: 1.28.1
```

If configuration is missing, you'll get friendly error messages:

```
╔════════════════════════════════════════════════════════════════╗
║                  WeaviateEx Configuration Error                 ║
╠════════════════════════════════════════════════════════════════╣
║  Missing required configuration: WEAVIATE_URL                    ║
║                                                                  ║
║  Please set the Weaviate URL using one of these methods:        ║
║  1. Environment variable: export WEAVIATE_URL=http://localhost:8080
║  2. Application configuration (config/config.exs)                ║
║  3. Runtime configuration (config/runtime.exs)                   ║
╚════════════════════════════════════════════════════════════════╝
```

## Usage

### Health Check

```elixir
# Check if Weaviate is accessible
{:ok, meta} = WeaviateEx.health_check()
# => %{"version" => "1.28.1", "modules" => %{}}

# Check readiness
{:ok, true} = WeaviateEx.ready?()

# Check liveness
{:ok, true} = WeaviateEx.alive?()
```

### Collections (Coming Soon)

```elixir
# Create a collection
{:ok, collection} = WeaviateEx.Collections.create("Article", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ]
})

# List all collections
{:ok, collections} = WeaviateEx.Collections.list()
```

### Objects (Coming Soon)

```elixir
# Create an object
{:ok, object} = WeaviateEx.Objects.create("Article", %{
  properties: %{
    title: "Hello Weaviate",
    content: "This is a test article"
  },
  vector: [0.1, 0.2, 0.3, ...]  # Optional
})

# Get an object
{:ok, object} = WeaviateEx.Objects.get("Article", uuid)

# List objects
{:ok, objects} = WeaviateEx.Objects.list("Article", limit: 10)
```

## Development

```bash
# Get dependencies
mix deps.get

# Compile
mix compile

# Run tests
mix test

# Generate documentation
mix docs

# Run code analysis
mix credo
```

## Managing Weaviate

```bash
# Start Weaviate
docker compose up -d

# Stop Weaviate
docker compose down

# View logs
docker compose logs -f weaviate

# Check status
docker compose ps

# Fresh start (removes all data)
docker compose down -v
docker compose up -d
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WEAVIATE_URL` | Yes | - | Full URL to Weaviate (e.g., `http://localhost:8080`) |
| `WEAVIATE_API_KEY` | No | - | API key for authentication |

## Documentation

- [Installation Guide](INSTALL.md) - Detailed setup instructions
- [API Documentation](https://hexdocs.pm/weaviate_ex) - Full API reference (coming soon)
- [Weaviate Docs](https://docs.weaviate.io) - Official Weaviate documentation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Apache 2.0 License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built for [Weaviate](https://weaviate.io) vector database
- Inspired by official Python and TypeScript clients

