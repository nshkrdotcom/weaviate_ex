# WeaviateEx Examples

Comprehensive examples demonstrating all WeaviateEx functionality.

## Prerequisites

Weaviate must be running and reachable at `WEAVIATE_URL`:

```bash
# 1. Start the full stack (same compose files as the Python client)
mix weaviate.start --version latest
# or use the helper script with a menu
./scripts/weaviate-stack.sh start --version latest

# 2. Verify the services are healthy (optional)
mix weaviate.status

# 3. Configure the client endpoint for the examples
export WEAVIATE_URL=http://localhost:8080
# export WEAVIATE_API_KEY=...  # if your instance requires auth

# When finished, tear everything down
mix weaviate.stop --version latest
# or use the helper
./scripts/weaviate-stack.sh stop --version latest
```

## Running Examples

Each example is self-contained and can be run with `mix run`:

```bash
mix run examples/01_collections.exs
mix run examples/02_data.exs
mix run examples/03_filter.exs
mix run examples/04_aggregate.exs
mix run examples/05_vector_config.exs
mix run examples/06_tenants.exs
mix run examples/07_batch.exs
mix run examples/08_query.exs
```

## Examples Overview

### 01_collections.exs - Collections API
- List collections
- Create collection with schema
- Get collection details
- Add properties
- Check existence
- Delete collection

### 02_data.exs - Data Operations (CRUD)
- Insert objects
- Get by ID
- Update (patch/put)
- Check existence
- Delete objects
- UUID handling

### 03_filter.exs - Filter System
- Equality filters
- Numeric comparisons
- Pattern matching (LIKE)
- Array filters (contains_any/all)
- Geospatial filters
- Combining filters (AND/OR/NOT)
- GraphQL conversion

### 04_aggregate.exs - Aggregation API
- Count objects
- Numeric statistics (mean, sum, max, min)
- Top occurrences
- Group by aggregation
- Boolean percentages

### 05_vector_config.exs - Vector Configuration
- Generate schemas with the fluent `VectorConfig` builder
- Custom HNSW parameters (distance, ef, max connections)
- Product Quantization (PQ) toggles and settings
- Flat index configuration for exact search

### 06_tenants.exs - Multi-Tenancy
- Create tenants
- List/Get/Delete tenants
- Activate/Deactivate (HOT/COLD)
- Check existence
- Count tenants
- Filter by activity status

### 07_batch.exs - Batch API
- Create multiple objects with one request
- Inspect structured summaries (success/failed counts)
- Delete objects using match filters
- Verify results with the query builder

### 08_query.exs - GraphQL Query Builder
- BM25 keyword search
- Filtered queries using the `Filter` DSL
- Near-vector similarity search with `_additional` metadata
- Flexible field selection and pagination

## Output Format

Each example provides clean, formatted output showing:
- **Commands**: The Elixir code being executed
- **GraphQL Queries**: When applicable (formatted)
- **Results**: Response data (pretty-printed)
- **Success/Error**: Status indicators

## Troubleshooting

### Weaviate Not Running

If you see:
```
✗ Weaviate is not running!
```

Start Weaviate:
```bash
mix weaviate.start
# or
docker compose up -d
```

### Port Already in Use

Stop existing Weaviate:
```bash
mix weaviate.stop
# or
docker compose down
```

### Connection Errors

Check Weaviate is accessible:
```bash
curl http://localhost:8080/v1/meta
```

## Learn More

- **Documentation**: [README.md](../README.md)
- **Quick Start**: [QUICK_START_GUIDE.md](../QUICK_START_GUIDE.md)
- **API Reference**: Run `mix docs` and open `doc/index.html`
- **Test Suite**: See `test/` directory for comprehensive test examples
