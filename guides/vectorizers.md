# Vectorizers Guide

This guide covers configuring vectorizers in Weaviate using WeaviateEx. Vectorizers automatically convert your data into vector embeddings for semantic search.

## Overview

Weaviate supports multiple vectorizer types:
- **Text vectorizers** - Convert text to vectors (text2vec-*)
- **Image vectorizers** - Convert images to vectors (img2vec-*, multi2vec-*)
- **Multimodal vectorizers** - Handle multiple data types (multi2vec-*)
- **No vectorizer** - Provide your own vectors

## Provider API Keys

Most vectorizers require API keys. Use `WeaviateEx.Integrations` to set them:

```elixir
headers = WeaviateEx.Integrations.openai(api_key: "sk-...")

{:ok, client} = WeaviateEx.Client.new(
  base_url: WeaviateEx.base_url(),
  headers: headers
)
```

Or set via environment variables in Weaviate's configuration.

## OpenAI (text2vec-openai)

### Basic Configuration

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-openai"
})
```

### Advanced Configuration

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-openai",
  moduleConfig: %{
    "text2vec-openai" => %{
      model: "text-embedding-3-small",    # or text-embedding-3-large, text-embedding-ada-002
      modelVersion: "3",
      type: "text",
      baseURL: nil,                        # Custom endpoint
      dimensions: 1536,                    # Output dimensions
      vectorizeClassName: true             # Include class name in embedding
    }
  }
})
```

### Per-Property Configuration

```elixir
{:ok, _} = WeaviateEx.Collections.create("Article", %{
  properties: [
    %{
      name: "title",
      dataType: ["text"],
      moduleConfig: %{
        "text2vec-openai" => %{skip: false}
      }
    },
    %{
      name: "internalId",
      dataType: ["text"],
      moduleConfig: %{
        "text2vec-openai" => %{skip: true}  # Don't vectorize this property
      }
    }
  ],
  vectorizer: "text2vec-openai"
})
```

## Cohere (text2vec-cohere)

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-cohere",
  moduleConfig: %{
    "text2vec-cohere" => %{
      model: "embed-english-v3.0",     # or embed-multilingual-v3.0
      truncate: "END",                  # END, START, NONE
      vectorizeClassName: true
    }
  }
})
```

## HuggingFace (text2vec-huggingface)

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "text", dataType: ["text"]}
  ],
  vectorizer: "text2vec-huggingface",
  moduleConfig: %{
    "text2vec-huggingface" => %{
      model: "sentence-transformers/all-MiniLM-L6-v2",
      options: %{
        waitForModel: true
      }
    }
  }
})
```

## VoyageAI (text2vec-voyageai)

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-voyageai",
  moduleConfig: %{
    "text2vec-voyageai" => %{
      model: "voyage-2",               # or voyage-large-2, voyage-code-2
      truncate: true
    }
  }
})
```

## JinaAI (text2vec-jinaai)

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-jinaai",
  moduleConfig: %{
    "text2vec-jinaai" => %{
      model: "jina-embeddings-v2-base-en"  # or jina-embeddings-v2-small-en
    }
  }
})
```

## Mistral (text2vec-mistral)

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-mistral",
  moduleConfig: %{
    "text2vec-mistral" => %{
      model: "mistral-embed"
    }
  }
})
```

## AWS Bedrock (text2vec-aws)

```elixir
# Set AWS credentials
headers = WeaviateEx.Integrations.aws(
  access_key: "AKIA...",
  secret_key: "secret"
)

{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-aws",
  moduleConfig: %{
    "text2vec-aws" => %{
      service: "bedrock",
      region: "us-east-1",
      model: "amazon.titan-embed-text-v1"
    }
  }
})
```

## Google (text2vec-palm / text2vec-google)

### Vertex AI

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-google",
  moduleConfig: %{
    "text2vec-google" => %{
      projectId: "my-gcp-project",
      modelId: "textembedding-gecko@001",
      apiEndpoint: "us-central1-aiplatform.googleapis.com"
    }
  }
})
```

### Google AI (Gemini)

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-google",
  moduleConfig: %{
    "text2vec-google" => %{
      modelId: "text-embedding-004"
    }
  }
})
```

## Azure OpenAI (text2vec-azure-openai)

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-azure-openai",
  moduleConfig: %{
    "text2vec-azure-openai" => %{
      resourceName: "my-azure-resource",
      deploymentId: "my-embedding-deployment",
      baseURL: "https://my-azure-resource.openai.azure.com"
    }
  }
})
```

## Ollama (text2vec-ollama)

For local models:

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-ollama",
  moduleConfig: %{
    "text2vec-ollama" => %{
      model: "nomic-embed-text",
      apiEndpoint: "http://localhost:11434"
    }
  }
})
```

## NVIDIA NIM (text2vec-nvidia)

```elixir
{:ok, _} = WeaviateEx.Collections.create("Document", %{
  properties: [
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-nvidia",
  moduleConfig: %{
    "text2vec-nvidia" => %{
      model: "nvidia/embed-qa-4",
      baseURL: nil  # Uses default NVIDIA API
    }
  }
})
```

## No Vectorizer (Bring Your Own Vectors)

When you want to provide vectors yourself:

```elixir
{:ok, _} = WeaviateEx.Collections.create("CustomVectors", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "none"
})

# Insert with your own vector
{:ok, _} = WeaviateEx.Objects.create("CustomVectors", %{
  properties: %{
    title: "Pre-vectorized document",
    content: "Content here..."
  },
  vector: [0.1, 0.2, 0.3, 0.4, 0.5, ...]  # Your embedding
})
```

## Named Vectors

Configure multiple vector spaces per collection:

```elixir
{:ok, _} = WeaviateEx.Collections.create("MultiVectorDoc", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]},
    %{name: "summary", dataType: ["text"]}
  ],
  vectorConfig: %{
    # Vector for title (small, fast)
    "title_vector" => %{
      vectorizer: %{
        "text2vec-openai" => %{
          model: "text-embedding-3-small",
          sourceProperties: ["title"]
        }
      },
      vectorIndexType: "hnsw",
      vectorIndexConfig: %{
        distance: "cosine"
      }
    },
    # Vector for content (larger, more detailed)
    "content_vector" => %{
      vectorizer: %{
        "text2vec-openai" => %{
          model: "text-embedding-3-large",
          sourceProperties: ["content", "summary"]
        }
      },
      vectorIndexType: "hnsw",
      vectorIndexConfig: %{
        distance: "cosine"
      }
    }
  }
})

# Query specific vector space
query = """
{
  Get {
    MultiVectorDoc(
      nearText: {
        concepts: ["machine learning"]
        targetVectors: ["title_vector"]
      }
      limit: 5
    ) {
      title
      content
    }
  }
}
"""
```

## Image Vectorizers

### img2vec-neural

```elixir
{:ok, _} = WeaviateEx.Collections.create("Image", %{
  properties: [
    %{name: "image", dataType: ["blob"]},
    %{name: "description", dataType: ["text"]}
  ],
  vectorizer: "img2vec-neural",
  moduleConfig: %{
    "img2vec-neural" => %{
      imageFields: ["image"]
    }
  }
})
```

### multi2vec-clip

Multimodal vectorization (text + images):

```elixir
{:ok, _} = WeaviateEx.Collections.create("Media", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "image", dataType: ["blob"]}
  ],
  vectorizer: "multi2vec-clip",
  moduleConfig: %{
    "multi2vec-clip" => %{
      textFields: ["title"],
      imageFields: ["image"],
      weights: %{
        textFields: [0.5],
        imageFields: [0.5]
      }
    }
  }
})
```

## Combining Vectorizers with Modules

Configure both vectorization and generative AI:

```elixir
{:ok, _} = WeaviateEx.Collections.create("SmartDocument", %{
  properties: [
    %{name: "title", dataType: ["text"]},
    %{name: "content", dataType: ["text"]}
  ],
  vectorizer: "text2vec-openai",
  moduleConfig: %{
    # Vectorizer config
    "text2vec-openai" => %{
      model: "text-embedding-3-small",
      vectorizeClassName: false
    },
    # Generative AI config
    "generative-openai" => %{
      model: "gpt-4o-mini"
    },
    # Reranker config
    "reranker-cohere" => %{
      model: "rerank-english-v3.0"
    }
  }
})
```

## Setting API Keys

### Via Headers (Recommended)

```elixir
# Single provider
headers = WeaviateEx.Integrations.openai(api_key: "sk-...")

# Multiple providers
headers = WeaviateEx.Integrations.merge([
  WeaviateEx.Integrations.openai(api_key: "sk-..."),
  WeaviateEx.Integrations.cohere(api_key: "cohere-key"),
  WeaviateEx.Integrations.anthropic(api_key: "anthropic-key")
])

{:ok, client} = WeaviateEx.Client.new(
  base_url: WeaviateEx.base_url(),
  headers: headers
)
```

### Via Environment Variables

Set in Weaviate's environment (Docker Compose or embedded mode):

```elixir
{:ok, _} = WeaviateEx.start_embedded(
  environment_variables: %{
    "OPENAI_APIKEY" => System.get_env("OPENAI_API_KEY"),
    "COHERE_APIKEY" => System.get_env("COHERE_API_KEY"),
    "HUGGINGFACE_APIKEY" => System.get_env("HF_API_KEY")
  }
)
```

## Best Practices

1. **Choose the right model size**
   - Smaller models: Faster, cheaper, good for prototyping
   - Larger models: Better quality, higher cost

2. **Skip non-semantic properties**
   ```elixir
   %{
     name: "internalId",
     dataType: ["text"],
     moduleConfig: %{"text2vec-openai" => %{skip: true}}
   }
   ```

3. **Use named vectors for different search needs**
   - Fast title search with small embeddings
   - Detailed content search with large embeddings

4. **Batch inserts for efficiency**
   - Vectorization adds latency per object
   - Batch operations amortize this cost

5. **Monitor token usage**
   - Text embedding APIs charge per token
   - Consider text length limits

## Next Steps

- [Collections Guide](collections.md) - Full collection configuration
- [Queries Guide](queries.md) - Semantic search with vectors
- [Generative Search](generative_search.md) - RAG with AI providers
