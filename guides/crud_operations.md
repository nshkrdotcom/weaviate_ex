# CRUD Operations Guide

This guide covers creating, reading, updating, and deleting objects in Weaviate collections using WeaviateEx.

## Overview

WeaviateEx provides two main modules for data operations:
- `WeaviateEx.Objects` - Individual object operations
- `WeaviateEx.Batch` - Bulk operations for efficiency

## Creating Objects

### Insert a Single Object

```elixir
{:ok, object} = WeaviateEx.Objects.create("Article", %{
  properties: %{
    title: "Introduction to Vector Databases",
    content: "Vector databases are specialized systems...",
    author: "Jane Smith",
    publishedAt: "2024-01-15T10:30:00Z"
  }
})

IO.puts("Created object with ID: #{object["id"]}")
```

### Insert with Custom UUID

```elixir
{:ok, object} = WeaviateEx.Objects.create("Article", %{
  id: "550e8400-e29b-41d4-a716-446655440000",
  properties: %{
    title: "My Article",
    content: "Content here..."
  }
})
```

### Insert with Vector

When using `vectorizer: "none"`, provide vectors manually:

```elixir
{:ok, object} = WeaviateEx.Objects.create("Article", %{
  properties: %{
    title: "Pre-vectorized Content",
    content: "This content has a pre-computed vector"
  },
  vector: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
})
```

### Insert with Named Vectors

For collections with multiple vector spaces:

```elixir
{:ok, object} = WeaviateEx.Objects.create("MultiVectorDoc", %{
  properties: %{
    title: "Document with multiple vectors",
    summary: "A brief summary",
    content: "Full content here..."
  },
  vectors: %{
    "title_vector" => [0.1, 0.2, 0.3],
    "content_vector" => [0.4, 0.5, 0.6]
  }
})
```

### Insert with References

Create objects with cross-references:

```elixir
# First, create the referenced object
{:ok, author} = WeaviateEx.Objects.create("Author", %{
  properties: %{name: "Jane Smith"}
})

# Then create an object with a reference
{:ok, article} = WeaviateEx.Objects.create("Article", %{
  properties: %{
    title: "My Article",
    # Reference using beacon format
    hasAuthor: [%{"beacon" => "weaviate://localhost/Author/#{author["id"]}"}]
  }
})
```

### Insert with Tenant

For multi-tenant collections:

```elixir
{:ok, object} = WeaviateEx.Objects.create("Article", %{
  properties: %{
    title: "Tenant-specific article"
  }
}, tenant: "tenant-a")
```

## Batch Operations

For inserting many objects, batch operations are much more efficient.

### Batch Insert

```elixir
objects = [
  %{class: "Article", properties: %{title: "Article 1", content: "Content 1"}},
  %{class: "Article", properties: %{title: "Article 2", content: "Content 2"}},
  %{class: "Article", properties: %{title: "Article 3", content: "Content 3"}}
]

{:ok, result} = WeaviateEx.Batch.create_objects(objects)

# Check for errors
Enum.each(result.errors, fn {index, error} ->
  IO.puts("Failed at index #{index}: #{inspect(error)}")
end)

IO.puts("Successfully created #{length(result.successes)} objects")
```

### Batch Insert with Vectors

```elixir
objects = [
  %{
    class: "Article",
    properties: %{title: "Article 1"},
    vector: [0.1, 0.2, 0.3]
  },
  %{
    class: "Article",
    properties: %{title: "Article 2"},
    vector: [0.4, 0.5, 0.6]
  }
]

{:ok, result} = WeaviateEx.Batch.create_objects(objects)
```

### Batch Insert with Custom UUIDs

```elixir
objects = [
  %{
    class: "Article",
    id: "11111111-1111-1111-1111-111111111111",
    properties: %{title: "Article 1"}
  },
  %{
    class: "Article",
    id: "22222222-2222-2222-2222-222222222222",
    properties: %{title: "Article 2"}
  }
]

{:ok, result} = WeaviateEx.Batch.create_objects(objects)
```

### Batch Summary

Get a summary of batch operations:

```elixir
{:ok, result} = WeaviateEx.Batch.create_objects(objects, return_summary: true)

IO.puts("Total: #{result.statistics.total}")
IO.puts("Successful: #{result.statistics.successful}")
IO.puts("Failed: #{result.statistics.failed}")
```

## Reading Objects

### Get by ID

```elixir
{:ok, object} = WeaviateEx.Objects.get("Article", "550e8400-e29b-41d4-a716-446655440000")

IO.puts("Title: #{object["properties"]["title"]}")
```

### Get with Vector

Include the object's vector in the response:

```elixir
{:ok, object} = WeaviateEx.Objects.get("Article", uuid, include: "vector")

IO.inspect(object["vector"])
```

### Get with Additional Metadata

```elixir
{:ok, object} = WeaviateEx.Objects.get("Article", uuid,
  include: ["vector", "creationTimeUnix", "lastUpdateTimeUnix"]
)
```

### Fetch by IDs

Fetch a specific set of objects while preserving the input ID order:

```elixir
ids = [
  "550e8400-e29b-41d4-a716-446655440001",
  "550e8400-e29b-41d4-a716-446655440002"
]

{:ok, objects} = WeaviateEx.Objects.fetch_objects_by_ids("Article", ids,
  return_properties: ["title", "content"]
)
```

### List Objects

List objects with pagination:

```elixir
# Get first 10 objects
{:ok, result} = WeaviateEx.Objects.list("Article", limit: 10)

Enum.each(result["objects"], fn obj ->
  IO.puts("- #{obj["properties"]["title"]}")
end)

# Pagination with offset
{:ok, page2} = WeaviateEx.Objects.list("Article", limit: 10, offset: 10)

# Cursor-based pagination (recommended for large datasets)
{:ok, page1} = WeaviateEx.Objects.list("Article", limit: 10)
last_id = List.last(page1["objects"])["id"]
{:ok, page2} = WeaviateEx.Objects.list("Article", limit: 10, after: last_id)
```

### List with Sorting

```elixir
{:ok, result} = WeaviateEx.Objects.list("Article",
  limit: 10,
  sort: "title",
  order: "asc"
)
```

### List Objects in a Tenant

```elixir
{:ok, result} = WeaviateEx.Objects.list("Article",
  tenant: "tenant-a",
  limit: 10
)
```

### Check if Object Exists

```elixir
case WeaviateEx.Objects.exists?("Article", uuid) do
  {:ok, true} -> IO.puts("Object exists")
  {:ok, false} -> IO.puts("Object not found")
  {:error, _} -> IO.puts("Error checking existence")
end
```

## Updating Objects

### Full Update (Replace)

Replace an entire object (PUT operation):

```elixir
{:ok, updated} = WeaviateEx.Objects.update("Article", uuid, %{
  properties: %{
    title: "Updated Title",
    content: "Completely new content",
    author: "New Author"
  }
})
```

### Partial Update (Patch)

Update only specific properties (PATCH operation):

```elixir
{:ok, patched} = WeaviateEx.Objects.patch("Article", uuid, %{
  properties: %{
    title: "Just Updated the Title"
    # Other properties remain unchanged
  }
})
```

### Update with New Vector

```elixir
{:ok, updated} = WeaviateEx.Objects.update("Article", uuid, %{
  properties: %{
    title: "Updated Content",
    content: "New content requiring new vector"
  },
  vector: [0.9, 0.8, 0.7, 0.6, 0.5]
})
```

Note: PATCH operations do not support updating vectors. Use full update (PUT) for vector changes.

### Update in Tenant

```elixir
{:ok, updated} = WeaviateEx.Objects.update("Article", uuid, %{
  properties: %{title: "Updated"}
}, tenant: "tenant-a")
```

## Deleting Objects

### Delete by ID

```elixir
{:ok, _} = WeaviateEx.Objects.delete("Article", uuid)
```

### Delete with Tenant

```elixir
{:ok, _} = WeaviateEx.Objects.delete("Article", uuid, tenant: "tenant-a")
```

### Batch Delete with Filter

Delete multiple objects matching a filter:

```elixir
{:ok, result} = WeaviateEx.Batch.delete_objects(%{
  class: "Article",
  where: %{
    path: ["author"],
    operator: "Equal",
    valueText: "John Doe"
  }
})

IO.puts("Deleted #{result["results"]["matches"]} objects")
```

### Batch Delete with Dry Run

Preview what would be deleted without actually deleting:

```elixir
{:ok, result} = WeaviateEx.Batch.delete_objects(%{
  class: "Article",
  where: %{
    path: ["status"],
    operator: "Equal",
    valueText: "draft"
  },
  dryRun: true,
  output: "verbose"
})

IO.puts("Would delete #{result["results"]["matches"]} objects")
Enum.each(result["results"]["objects"], fn obj ->
  IO.puts("- #{obj["id"]}")
end)
```

### Complex Filter for Batch Delete

```elixir
{:ok, result} = WeaviateEx.Batch.delete_objects(%{
  class: "Article",
  where: %{
    operator: "And",
    operands: [
      %{
        path: ["publishedAt"],
        operator: "LessThan",
        valueDate: "2023-01-01T00:00:00Z"
      },
      %{
        path: ["status"],
        operator: "Equal",
        valueText: "archived"
      }
    ]
  }
})
```

## Validation

WeaviateEx performs basic client-side validation before sending data:

- `properties` is required for insert and update operations
- `id` and `vector` are reserved property names and raise `ArgumentError`

Validate object data without creating it:

```elixir
case WeaviateEx.Objects.validate("Article", %{
  properties: %{
    title: "Test Article",
    invalidProperty: "This doesn't exist"
  }
}) do
  {:ok, _} -> IO.puts("Valid!")
  {:error, error} -> IO.puts("Invalid: #{inspect(error)}")
end
```

## Error Handling

Handle common errors:

```elixir
case WeaviateEx.Objects.create("Article", %{properties: %{title: "Test"}}) do
  {:ok, object} ->
    IO.puts("Created: #{object["id"]}")

  {:error, %WeaviateEx.Error{type: :validation_error, message: msg}} ->
    IO.puts("Validation failed: #{msg}")

  {:error, %WeaviateEx.Error{type: :conflict, message: msg}} ->
    IO.puts("Object already exists: #{msg}")

  {:error, %WeaviateEx.Error{type: :not_found}} ->
    IO.puts("Collection not found")

  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

## Complete Example

Here's a complete CRUD workflow:

```elixir
# Setup: Create collection
{:ok, _} = WeaviateEx.Collections.create("Task", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "description", dataType: ["text"]},
    %{name: "status", dataType: ["text"]},
    %{name: "priority", dataType: ["int"]}
  ],
  vectorizer: "none"
})

# CREATE: Add tasks
{:ok, task1} = WeaviateEx.Objects.create("Task", %{
  properties: %{
    title: "Complete project",
    description: "Finish the WeaviateEx guide",
    status: "in_progress",
    priority: 1
  },
  vector: [0.1, 0.2, 0.3, 0.4]
})

# READ: Get the task
{:ok, fetched} = WeaviateEx.Objects.get("Task", task1["id"])
IO.puts("Task: #{fetched["properties"]["title"]}")

# UPDATE: Change status
{:ok, _} = WeaviateEx.Objects.patch("Task", task1["id"], %{
  properties: %{status: "completed"}
})

# READ: Verify update
{:ok, updated} = WeaviateEx.Objects.get("Task", task1["id"])
IO.puts("Status: #{updated["properties"]["status"]}")

# DELETE: Remove the task
{:ok, _} = WeaviateEx.Objects.delete("Task", task1["id"])

# Cleanup: Delete collection
{:ok, _} = WeaviateEx.Collections.delete("Task")
```

## Next Steps

- [Queries Guide](queries.md) - Search your data
- [Batch Operations](#batch-operations) - Efficient bulk imports
- [References Guide](references.md) - Cross-references between objects
- [Multi-tenancy Guide](multi_tenancy.md) - Tenant-scoped operations
