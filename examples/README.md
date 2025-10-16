# WeaviateEx Examples

Comprehensive examples demonstrating all WeaviateEx functionality.

## Prerequisites

Weaviate must be running:

```bash
# Option 1: Using mix task
mix weaviate.start

# Option 2: Using Docker Compose
docker compose up -d

# Check status
mix weaviate.status
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
- 11 vectorizer configurations
- HNSW index settings
- Product Quantization (PQ)
- Binary/Scalar Quantization
- Multi-modal (CLIP)
- Named vectors

### 06_tenants.exs - Multi-Tenancy
- Create tenants
- List/Get/Delete tenants
- Activate/Deactivate (HOT/COLD)
- Check existence
- Count tenants
- Filter by activity status

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
