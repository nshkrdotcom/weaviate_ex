#!/bin/bash

set -e

echo "=========================================="
echo "Weaviate Development Environment Setup"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

# Check if running on Ubuntu/Debian
if ! command -v apt-get &> /dev/null; then
    print_error "This script is designed for Ubuntu/Debian systems"
    exit 1
fi

print_info "Detected Ubuntu/Debian system"
echo ""

# Check if Docker is installed
print_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_info "Docker not found. Installing Docker..."

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
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker $USER

    print_success "Docker installed successfully"
    print_info "You may need to log out and back in for group membership to take effect"
else
    print_success "Docker is already installed"
fi

# Verify Docker is running
if ! sudo systemctl is-active --quiet docker; then
    print_info "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
fi

print_success "Docker service is running"
echo ""

# Check Docker Compose
print_info "Checking Docker Compose..."
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose plugin not found"
    exit 1
fi

print_success "Docker Compose is available"
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    print_info "Creating .env file with default configuration..."
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
    print_success "Created .env file"
else
    print_info ".env file already exists"
fi

echo ""

# Stop any running containers
print_info "Stopping any existing Weaviate containers..."
docker compose down 2>/dev/null || true

# Pull latest images
print_info "Pulling Weaviate Docker images..."
docker compose pull

# Start Weaviate
print_info "Starting Weaviate..."
docker compose up -d

echo ""
print_info "Waiting for Weaviate to be healthy (this may take 30-60 seconds)..."

# Wait for health check
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker compose ps | grep -q "healthy"; then
        print_success "Weaviate is healthy and ready!"
        break
    fi

    if [ $attempt -eq $((max_attempts - 1)) ]; then
        print_error "Weaviate did not become healthy in time"
        print_info "Check logs with: docker compose logs weaviate"
        exit 1
    fi

    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
done

echo ""
echo ""

# Test connection
print_info "Testing Weaviate connection..."
if curl -s http://localhost:8080/v1/meta > /dev/null; then
    print_success "Weaviate is accessible at http://localhost:8080"
else
    print_error "Could not connect to Weaviate"
    exit 1
fi

echo ""
echo "=========================================="
print_success "Installation Complete!"
echo "=========================================="
echo ""
echo "Weaviate is running at:"
echo "  HTTP API:  http://localhost:8080"
echo "  gRPC API:  localhost:50051"
echo ""
echo "Useful commands:"
echo "  Start:     docker compose up -d"
echo "  Stop:      docker compose down"
echo "  Logs:      docker compose logs -f weaviate"
echo "  Status:    docker compose ps"
echo ""
echo "Environment variables are configured in .env file"
echo ""
