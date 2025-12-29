# Cross-References Guide

This guide covers creating and managing cross-references between objects in Weaviate using WeaviateEx. Cross-references allow you to model relationships between objects, similar to foreign keys in relational databases.

## Overview

Weaviate supports two types of references:
- **Single-target references** - Reference to objects in one specific collection
- **Multi-target references** - Reference to objects across multiple collections

## Defining Reference Properties

First, define reference properties in your collection schema:

### Single-Target Reference

```elixir
# Create Author collection
{:ok, _} = WeaviateEx.Collections.create("Author", %{
  properties: [
    %{name: "name", dataType: ["text"]},
    %{name: "email", dataType: ["text"]}
  ]
})

# Create Article collection with reference to Author
{:ok, _} = WeaviateEx.Collections.create("Article", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]},
    # Single-target reference to Author
    %{name: "hasAuthor", dataType: ["Author"]}
  ]
})
```

### Multi-Target Reference

Multi-target references can point to objects in different collections:

```elixir
{:ok, _} = WeaviateEx.Collections.create("Article", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    # Multi-target reference - can point to Author, Editor, or Reviewer
    %{
      name: "contributors",
      dataType: ["Author", "Editor", "Reviewer"]
    }
  ]
})
```

## Adding References

Use `WeaviateEx.API.References` for reference operations:

### Add Single Reference

```elixir
alias WeaviateEx.API.References

# Create an author
{:ok, author} = WeaviateEx.Objects.create("Author", %{
  properties: %{name: "Jane Smith", email: "jane@example.com"}
})

# Create an article
{:ok, article} = WeaviateEx.Objects.create("Article", %{
  properties: %{title: "My Article", content: "Content here..."}
})

# Create a client
{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url())

# Add the reference
{:ok, _} = References.add(
  client,
  "Article",           # Source collection
  article["id"],       # Source object UUID
  "hasAuthor",         # Reference property name
  author["id"]         # Target object UUID
)
```

### Add Multi-Target Reference

For multi-target references, specify the target collection:

```elixir
{:ok, editor} = WeaviateEx.Objects.create("Editor", %{
  properties: %{name: "John Doe"}
})

# Add reference with target collection specified
{:ok, _} = References.add(
  client,
  "Article",
  article["id"],
  "contributors",
  %{target_collection: "Editor", uuids: editor["id"]}
)
```

### Add References During Object Creation

You can also add references when creating objects:

```elixir
# Create author first
{:ok, author} = WeaviateEx.Objects.create("Author", %{
  properties: %{name: "Jane Smith"}
})

# Create article with reference
{:ok, article} = WeaviateEx.Objects.create("Article", %{
  properties: %{
    title: "Article with Author",
    content: "Content...",
    hasAuthor: [%{"beacon" => "weaviate://localhost/Author/#{author["id"]}"}]
  }
})
```

## Deleting References

### Delete Single Reference

```elixir
{:ok, _} = References.delete(
  client,
  "Article",
  article["id"],
  "hasAuthor",
  author["id"]
)
```

### Delete Multi-Target Reference

```elixir
{:ok, _} = References.delete(
  client,
  "Article",
  article["id"],
  "contributors",
  %{target_collection: "Editor", uuids: editor["id"]}
)
```

## Replacing References

Replace all references on a property with new ones:

```elixir
# Create multiple authors
{:ok, author1} = WeaviateEx.Objects.create("Author", %{
  properties: %{name: "Author 1"}
})
{:ok, author2} = WeaviateEx.Objects.create("Author", %{
  properties: %{name: "Author 2"}
})

# Replace all authors on an article
{:ok, _} = References.replace(
  client,
  "Article",
  article["id"],
  "hasAuthors",  # Assuming this is a multi-valued reference
  [author1["id"], author2["id"]]
)
```

### Clear All References

To remove all references, replace with an empty list:

```elixir
{:ok, _} = References.replace(
  client,
  "Article",
  article["id"],
  "hasAuthors",
  []
)
```

## Batch Reference Operations

### Add Many References

Add multiple references in a single request:

```elixir
# Create multiple articles and authors
articles = for i <- 1..3 do
  {:ok, article} = WeaviateEx.Objects.create("Article", %{
    properties: %{title: "Article #{i}"}
  })
  article
end

authors = for i <- 1..3 do
  {:ok, author} = WeaviateEx.Objects.create("Author", %{
    properties: %{name: "Author #{i}"}
  })
  author
end

# Build reference list
references = Enum.zip(articles, authors)
  |> Enum.map(fn {article, author} ->
    %{
      from_uuid: article["id"],
      from_property: "hasAuthor",
      to_uuid: author["id"]
    }
  end)

# Add all references in batch
{:ok, _} = References.add_many(client, "Article", references)
```

### Batch Add with Legacy API

You can also use the batch API directly:

```elixir
references = [
  %{
    from: "weaviate://localhost/Article/#{article1_id}/hasAuthor",
    to: "weaviate://localhost/Author/#{author1_id}"
  },
  %{
    from: "weaviate://localhost/Article/#{article2_id}/hasAuthor",
    to: "weaviate://localhost/Author/#{author2_id}"
  }
]

{:ok, result} = WeaviateEx.Batch.add_references(references)
```

## Querying References

### Query with References

Retrieve objects with their referenced objects:

```elixir
# Using raw GraphQL for reference queries
query = """
{
  Get {
    Article(limit: 10) {
      title
      content
      hasAuthor {
        ... on Author {
          name
          email
        }
      }
    }
  }
}
"""

{:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url())
{:ok, response} = WeaviateEx.Client.request(client, :post, "/v1/graphql", %{query: query})

articles = response["data"]["Get"]["Article"]
Enum.each(articles, fn article ->
  IO.puts("#{article["title"]}")
  Enum.each(article["hasAuthor"] || [], fn author ->
    IO.puts("  Author: #{author["name"]}")
  end)
end)
```

### Query Multi-Target References

```elixir
query = """
{
  Get {
    Article(limit: 10) {
      title
      contributors {
        ... on Author {
          name
        }
        ... on Editor {
          name
          department
        }
        ... on Reviewer {
          name
          expertise
        }
      }
    }
  }
}
"""
```

### Filter by Reference Properties

```elixir
# Find articles by a specific author
query = """
{
  Get {
    Article(
      where: {
        path: ["hasAuthor", "Author", "name"],
        operator: Equal,
        valueText: "Jane Smith"
      }
      limit: 10
    ) {
      title
      hasAuthor {
        ... on Author {
          name
        }
      }
    }
  }
}
"""
```

## Reference Beacon Format

Weaviate uses "beacons" to identify referenced objects:

```
weaviate://localhost/{Collection}/{UUID}
```

For example:
```
weaviate://localhost/Author/550e8400-e29b-41d4-a716-446655440000
```

### Building Beacons

```elixir
defmodule BeaconHelper do
  def build_beacon(collection, uuid) do
    "weaviate://localhost/#{collection}/#{uuid}"
  end

  def build_beacon(uuid) do
    "weaviate://localhost/#{uuid}"
  end

  def build_reference(collection, uuid) do
    %{"beacon" => build_beacon(collection, uuid)}
  end
end

# Usage
beacon = BeaconHelper.build_beacon("Author", author_id)
reference = BeaconHelper.build_reference("Author", author_id)
```

## Complete Example

Here's a complete example modeling a blog with articles, authors, and categories:

```elixir
defmodule BlogSetup do
  alias WeaviateEx.API.References

  def setup do
    # Create collections
    create_collections()

    # Create sample data
    {:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url())

    # Create categories
    {:ok, tech} = WeaviateEx.Objects.create("Category", %{
      properties: %{name: "Technology", slug: "tech"}
    })

    {:ok, science} = WeaviateEx.Objects.create("Category", %{
      properties: %{name: "Science", slug: "science"}
    })

    # Create authors
    {:ok, jane} = WeaviateEx.Objects.create("Author", %{
      properties: %{name: "Jane Smith", bio: "Tech writer"}
    })

    {:ok, john} = WeaviateEx.Objects.create("Author", %{
      properties: %{name: "John Doe", bio: "Science correspondent"}
    })

    # Create articles with references
    {:ok, article1} = WeaviateEx.Objects.create("Article", %{
      properties: %{
        title: "Introduction to Elixir",
        content: "Elixir is a dynamic, functional language..."
      }
    })

    {:ok, article2} = WeaviateEx.Objects.create("Article", %{
      properties: %{
        title: "Quantum Computing Basics",
        content: "Quantum computers use quantum mechanics..."
      }
    })

    # Add references
    References.add(client, "Article", article1["id"], "hasAuthor", jane["id"])
    References.add(client, "Article", article1["id"], "hasCategory", tech["id"])

    References.add(client, "Article", article2["id"], "hasAuthor", john["id"])
    References.add(client, "Article", article2["id"], "hasCategory", science["id"])

    IO.puts("Blog setup complete!")
    {:ok, %{articles: [article1, article2], authors: [jane, john], categories: [tech, science]}}
  end

  defp create_collections do
    # Category collection
    WeaviateEx.Collections.create("Category", %{
      properties: [
        %{name: "name", dataType: ["text"]},
        %{name: "slug", dataType: ["text"]}
      ]
    })

    # Author collection
    WeaviateEx.Collections.create("Author", %{
      properties: [
        %{name: "name", dataType: ["text"]},
        %{name: "bio", dataType: ["text"]}
      ]
    })

    # Article collection with references
    WeaviateEx.Collections.create("Article", %{
      properties: [
        %{name: "title", dataType: ["text"]},
        %{name: "content", dataType: ["text"]},
        %{name: "hasAuthor", dataType: ["Author"]},
        %{name: "hasCategory", dataType: ["Category"]}
      ]
    })
  end

  def query_articles_with_refs do
    query = """
    {
      Get {
        Article(limit: 10) {
          title
          content
          hasAuthor {
            ... on Author {
              name
              bio
            }
          }
          hasCategory {
            ... on Category {
              name
              slug
            }
          }
        }
      }
    }
    """

    {:ok, client} = WeaviateEx.Client.new(base_url: WeaviateEx.base_url())
    WeaviateEx.Client.request(client, :post, "/v1/graphql", %{query: query})
  end

  def cleanup do
    WeaviateEx.Collections.delete("Article")
    WeaviateEx.Collections.delete("Author")
    WeaviateEx.Collections.delete("Category")
  end
end

# Run the example
{:ok, data} = BlogSetup.setup()
{:ok, results} = BlogSetup.query_articles_with_refs()
BlogSetup.cleanup()
```

## Next Steps

- [Collections Guide](collections.md) - Define reference properties
- [CRUD Operations](crud_operations.md) - Create objects with references
- [Queries Guide](queries.md) - Query referenced objects
