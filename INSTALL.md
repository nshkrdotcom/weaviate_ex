# Weaviate Installation Guide

This guide provides step-by-step instructions for setting up Weaviate vector database for development with the WeaviateEx Elixir library.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Installation](#manual-installation)
- [Configuration](#configuration)
- [Verification](#verification)
- [Managing Weaviate](#managing-weaviate)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- **Operating System**: Ubuntu 24.04 or compatible Linux distribution
- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **curl**: For testing HTTP endpoints
- **sudo access**: Required for Docker installation

## Quick Start

The easiest way to set up Weaviate is using the provided installation script:

```bash
./install.sh
```

This script will:
1. Check if Docker is installed (and install it if missing)
2. Create a `.env` file with default configuration
3. Pull the Weaviate Docker image
4. Start Weaviate with docker-compose
5. Wait for Weaviate to be healthy
6. Verify the connection

After successful installation, Weaviate will be running at:
- **HTTP API**: http://localhost:8080
- **gRPC API**: localhost:50051

## Manual Installation

If you prefer to install manually, follow these steps:

### Step 1: Install Docker

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

**Note**: After adding yourself to the docker group, you may need to log out and back in for the changes to take effect.

### Step 2: Verify Docker Installation

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Verify Docker is running
sudo systemctl status docker
```

### Step 3: Create Environment Configuration

Create a `.env` file in the project root:

```bash
cat > .env << 'EOF'
# Weaviate Configuration
WEAVIATE_HOST=localhost
WEAVIATE_PORT=8080
WEAVIATE_GRPC_PORT=50051
WEAVIATE_SCHEME=http

# Weaviate URL (used by Elixir client)
WEAVIATE_URL=http://localhost:8080

# Optional: Authentication (set to 'true' to enable)
WEAVIATE_AUTH_ENABLED=false
WEAVIATE_API_KEY=

# Optional: Vectorizer settings
# DEFAULT_VECTORIZER_MODULE=text2vec-openai
# OPENAI_API_KEY=your_key_here
EOF
```

### Step 4: Start Weaviate

```bash
# Pull the Weaviate image
docker compose pull

# Start Weaviate in detached mode
docker compose up -d

# Wait for Weaviate to be healthy (takes 30-60 seconds)
# You can check the status with:
docker compose ps
```

### Step 5: Verify Installation

```bash
# Test the HTTP endpoint
curl http://localhost:8080/v1/meta

# You should see JSON output with Weaviate version and configuration
```

## Configuration

### Environment Variables

The WeaviateEx library requires the following environment variables:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WEAVIATE_URL` | Yes | - | Full URL to Weaviate instance (e.g., `http://localhost:8080`) |
| `WEAVIATE_HOST` | No | localhost | Weaviate host |
| `WEAVIATE_PORT` | No | 8080 | Weaviate HTTP port |
| `WEAVIATE_GRPC_PORT` | No | 50051 | Weaviate gRPC port |
| `WEAVIATE_SCHEME` | No | http | HTTP scheme (http or https) |
| `WEAVIATE_API_KEY` | No | - | API key for authentication (if enabled) |
| `WEAVIATE_AUTH_ENABLED` | No | false | Enable authentication |

### Elixir Configuration

Add to your `config/config.exs`:

```elixir
config :weaviate_ex,
  url: System.get_env("WEAVIATE_URL") || "http://localhost:8080",
  api_key: System.get_env("WEAVIATE_API_KEY"),
  # Optional: gRPC configuration
  grpc_host: System.get_env("WEAVIATE_HOST") || "localhost",
  grpc_port: System.get_env("WEAVIATE_GRPC_PORT") || "50051"
```

## Verification

### Check Weaviate Health

```bash
# Using curl
curl http://localhost:8080/v1/.well-known/ready

# Using docker
docker compose ps

# Check logs
docker compose logs -f weaviate
```

### Test with Elixir

```elixir
# Start your Elixir application
iex -S mix

# The WeaviateEx library will automatically check connection on startup
# If configuration is missing, you'll see friendly error messages
```

## Managing Weaviate

### Start Weaviate

```bash
docker compose up -d
```

### Stop Weaviate

```bash
docker compose down
```

### Restart Weaviate

```bash
docker compose restart
```

### View Logs

```bash
# Follow logs
docker compose logs -f weaviate

# View last 100 lines
docker compose logs --tail=100 weaviate
```

### Check Status

```bash
docker compose ps
```

### Remove All Data (Fresh Start)

```bash
# Stop and remove containers, networks, and volumes
docker compose down -v

# Start fresh
docker compose up -d
```

## Troubleshooting

### Docker Permission Denied

If you get permission denied errors:

```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker
```

### Port Already in Use

If port 8080 or 50051 is already in use:

1. Edit `docker-compose.yml` and change the port mappings:
```yaml
ports:
  - "8081:8080"  # Changed from 8080:8080
  - "50052:50051"  # Changed from 50051:50051
```

2. Update your `.env` file:
```bash
WEAVIATE_PORT=8081
WEAVIATE_GRPC_PORT=50052
WEAVIATE_URL=http://localhost:8081
```

### Weaviate Not Starting

Check the logs for errors:

```bash
docker compose logs weaviate
```

Common issues:
- Insufficient memory (Weaviate needs at least 1GB RAM)
- Disk space full
- Corrupted data volume (try `docker compose down -v` to reset)

### Connection Refused from Elixir

1. Verify Weaviate is running:
```bash
docker compose ps
curl http://localhost:8080/v1/meta
```

2. Check your `.env` file has the correct URL

3. Ensure the `WEAVIATE_URL` environment variable is loaded in your Elixir app

### Weaviate Container Exits Immediately

Check logs for the specific error:

```bash
docker compose logs weaviate
```

Try removing old volumes and restarting:

```bash
docker compose down -v
docker compose up -d
```

## Additional Resources

- [Weaviate Documentation](https://docs.weaviate.io/)
- [Weaviate Docker Installation Guide](https://docs.weaviate.io/deploy/installation-guides/docker-installation)
- [WeaviateEx GitHub Repository](#) (coming soon)

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Weaviate logs: `docker compose logs weaviate`
3. Verify environment variables are set correctly
4. Ensure Docker and Docker Compose are up to date
