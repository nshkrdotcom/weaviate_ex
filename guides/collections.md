# Collections Guide

Collections in Weaviate define the structure and configuration of your data. This guide covers creating, configuring, and managing collections with WeaviateEx.

## Overview

A collection (called a "class" in Weaviate's REST API) defines:
- Properties and their data types
- Vectorizer configuration
- Index settings (HNSW, inverted index)
- Multi-tenancy settings
- Replication configuration

## Creating Collections

### Basic Collection

Create a simple collection with text properties:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("Article", %{
  description: "A collection for news articles",
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]},
    %{name: "publishedAt", dataType: ["date"]}
  ]
})
```

### Collection with Vectorizer

Configure automatic vectorization with an AI provider:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("Document", %{
  description: "Documents with automatic vectorization",
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "body", dataType: ["text"]}
  ],
  vectorizer: "text2vec-openai",
  moduleConfig: %{
    "text2vec-openai" => %{
      model: "text-embedding-3-small",
      vectorizeClassName: true
    }
  }
})
```

### Collection without Vectorization

For collections where you'll provide vectors manually:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("CustomVectors", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "none"
})
```

## Property Data Types

Weaviate supports various data types for properties:

| Data Type | Elixir Example | Description |
|-----------|----------------|-------------|
| `text` | `"hello"` | Text with full-text search |
| `text[]` | `["a", "b"]` | Array of text values |
| `int` | `42` | Integer number |
| `int[]` | `[1, 2, 3]` | Array of integers |
| `number` | `3.14` | Floating point number |
| `number[]` | `[1.0, 2.5]` | Array of numbers |
| `boolean` | `true` | Boolean value |
| `boolean[]` | `[true, false]` | Array of booleans |
| `date` | `"2024-01-15T10:30:00Z"` | RFC3339 date string |
| `date[]` | `["2024-01-15", "2024-01-16"]` | Array of dates |
| `uuid` | `"550e8400-e29b-41d4-a716-446655440000"` | UUID string |
| `uuid[]` | `[uuid1, uuid2]` | Array of UUIDs |
| `geoCoordinates` | `%{latitude: 52.52, longitude: 13.405}` | Geographic coordinates |
| `phoneNumber` | `%{input: "+1234567890"}` | Phone number |
| `blob` | `"base64data..."` | Base64-encoded binary |
| `object` | `%{nested: "value"}` | Nested object |
| `object[]` | `[%{a: 1}, %{b: 2}]` | Array of objects |

### Property Configuration Example

```elixir
{:ok, collection} = WeaviateEx.Collections.create("Product", %{
  properties: [
    # Text with specific tokenization
    %{
      name: "name",
      dataType: ["text"],
      tokenization: "word",
      indexFilterable: true,
      indexSearchable: true
    },
    # Numeric property
    %{
      name: "price",
      dataType: ["number"],
      indexFilterable: true,
      indexRangeFilters: true
    },
    # Date property
    %{
      name: "createdAt",
      dataType: ["date"]
    },
    # Nested object
    %{
      name: "metadata",
      dataType: ["object"],
      nestedProperties: [
        %{name: "source", dataType: ["text"]},
        %{name: "version", dataType: ["int"]}
      ]
    },
    # Cross-reference to another collection
    %{
      name: "belongsToCategory",
      dataType: ["Category"]  # Reference to Category collection
    }
  ],
  vectorizer: "none"
})
```

## Vector Index Configuration

### HNSW Index (Default)

Configure the HNSW vector index for similarity search:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("Vectors", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorIndexType: "hnsw",
  vectorIndexConfig: %{
    # Distance metric: cosine, l2-squared, dot, hamming, manhattan
    distance: "cosine",
    # HNSW parameters
    efConstruction: 128,  # Build-time quality (higher = better, slower)
    maxConnections: 64,   # Max connections per node
    ef: -1,               # Search-time parameter (-1 = dynamic)
    # Quantization for memory efficiency
    pq: %{
      enabled: false,
      trainingLimit: 100000,
      segments: 0
    }
  }
})
```

### Flat Index

For small collections where exact search is preferred:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("SmallCollection", %{
  properties: [
    %{name: "data", dataType: ["text"]}
  ],
  vectorIndexType: "flat",
  vectorIndexConfig: %{
    distance: "cosine"
  }
})
```

## Inverted Index Configuration

Configure text search and filtering:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("Searchable", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "body", dataType: ["text"]}
  ],
  invertedIndexConfig: %{
    bm25: %{
      b: 0.75,    # Length normalization
      k1: 1.2     # Term frequency saturation
    },
    stopwords: %{
      preset: "en",
      additions: ["custom", "words"],
      removals: []
    },
    indexTimestamps: true,      # Enable filtering by creation/update time
    indexNullState: true,       # Enable filtering by null values
    indexPropertyLength: true   # Enable filtering by property length
  }
})
```

## Object TTL Configuration

Automatically expire objects using the object TTL config:

```elixir
alias WeaviateEx.Config.ObjectTTL

ttl = ObjectTTL.delete_by_update_time(86_400, true)

{:ok, _} = WeaviateEx.Collections.create("Session", %{
  properties: [
    %{name: "token", dataType: ["text"]}
  ],
  object_ttl: ttl
})

# Disable TTL later if needed
{:ok, _} = WeaviateEx.Collections.update("Session", %{
  object_ttl: ObjectTTL.disable()
})
```

## Multi-tenancy Configuration

Enable multi-tenancy for data isolation:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("TenantData", %{
  properties: [
    %{name: "data", dataType: ["text"]}
  ],
  multiTenancyConfig: %{
    enabled: true,
    autoTenantCreation: false,   # Auto-create tenants on insert
    autoTenantActivation: true   # Auto-activate inactive tenants
  }
})
```

### Typed Multi-tenancy Helpers

```elixir
alias WeaviateEx.Config.AutoTenant
alias WeaviateEx.Schema.MultiTenancyConfig

{:ok, _} = WeaviateEx.Collections.create("TenantData", %{
  properties: [
    %{name: "data", dataType: ["text"]}
  ],
  multi_tenancy_config: MultiTenancyConfig.new(enabled: true, auto_tenant_creation: true),
  auto_tenant: AutoTenant.enable(auto_delete_timeout: 3_600)
})
```

See the [Multi-tenancy Guide](multi_tenancy.md) for tenant operations.

## Replication Configuration

Configure data replication for high availability:

```elixir
{:ok, collection} = WeaviateEx.Collections.create("Replicated", %{
  properties: [
    %{name: "data", dataType: ["text"]}
  ],
  replicationConfig: %{
    factor: 3,            # Number of replicas
    asyncEnabled: false   # Sync vs async replication
  }
})
```

## Reading Collections

### Get All Collections

```elixir
{:ok, schema} = WeaviateEx.Collections.list()
classes = schema["classes"]

Enum.each(classes, fn class ->
  IO.puts("Collection: #{class["class"]}")
end)
```

### Get a Specific Collection

```elixir
{:ok, collection} = WeaviateEx.Collections.get("Article")
IO.inspect(collection["properties"])
```

### Check if Collection Exists

```elixir
case WeaviateEx.Collections.exists?("Article") do
  {:ok, true} -> IO.puts("Collection exists")
  {:ok, false} -> IO.puts("Collection does not exist")
  {:error, error} -> IO.puts("Error: #{inspect(error)}")
end
```

## Updating Collections

### Update Collection Configuration

Note: Not all fields can be updated after creation. Check Weaviate documentation for updateable fields.

```elixir
{:ok, updated} = WeaviateEx.Collections.update("Article", %{
  description: "Updated description",
  invertedIndexConfig: %{
    bm25: %{k1: 1.5}
  }
})
```

### Add a Property

Add a new property to an existing collection:

```elixir
{:ok, property} = WeaviateEx.Collections.add_property("Article", %{
  name: "author",
  dataType: ["text"],
  description: "The article author",
  indexFilterable: true,
  indexSearchable: true
})
```

## Deleting Collections

Delete a collection and all its data:

```elixir
{:ok, _} = WeaviateEx.Collections.delete("Article")
```

**Warning**: This is irreversible and deletes all objects in the collection.

## Shard Management

For distributed setups, manage collection shards:

```elixir
# Get shard status
{:ok, shards} = WeaviateEx.Collections.get_shards("Article")

Enum.each(shards, fn shard ->
  IO.puts("Shard: #{shard["name"]}, Status: #{shard["status"]}")
end)

# Update shard status
{:ok, _} = WeaviateEx.Collections.update_shard("Article", "shard-1", "READONLY")
```

## Complete Example

Here's a complete example creating a well-configured collection:

```elixir
# Create a production-ready collection
{:ok, collection} = WeaviateEx.Collections.create("BlogPost", %{
  description: "Blog posts with semantic search",

  properties: [
    %{
      name: "title",
      dataType: ["text"],
      description: "Post title",
      tokenization: "word",
      indexFilterable: true,
      indexSearchable: true
    },
    %{
      name: "content",
      dataType: ["text"],
      description: "Post content",
      tokenization: "word",
      indexFilterable: false,
      indexSearchable: true
    },
    %{
      name: "author",
      dataType: ["text"],
      indexFilterable: true
    },
    %{
      name: "tags",
      dataType: ["text[]"],
      indexFilterable: true
    },
    %{
      name: "publishedAt",
      dataType: ["date"],
      indexFilterable: true
    },
    %{
      name: "viewCount",
      dataType: ["int"],
      indexFilterable: true
    }
  ],

  # Use OpenAI for vectorization
  vectorizer: "text2vec-openai",
  moduleConfig: %{
    "text2vec-openai" => %{
      model: "text-embedding-3-small",
      vectorizeClassName: false
    },
    # Enable generative module
    "generative-openai" => %{
      model: "gpt-4o-mini"
    }
  },

  # Vector index configuration
  vectorIndexType: "hnsw",
  vectorIndexConfig: %{
    distance: "cosine",
    efConstruction: 128,
    maxConnections: 64
  },

  # Inverted index for BM25
  invertedIndexConfig: %{
    bm25: %{b: 0.75, k1: 1.2},
    stopwords: %{preset: "en"},
    indexTimestamps: true
  }
})

IO.puts("Created collection: #{collection["class"]}")
```

## Next Steps

- [CRUD Operations](crud_operations.md) - Add and manage objects in collections
- [Queries](queries.md) - Search your collections
- [Vectorizers](vectorizers.md) - Configure AI vectorization
- [Multi-tenancy](multi_tenancy.md) - Tenant management
