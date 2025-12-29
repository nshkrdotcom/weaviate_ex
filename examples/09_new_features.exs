# New Features Example (Dec 2025 Python Client Sync)
# Run: mix run examples/09_new_features.exs
#
# This example demonstrates the new features added to weaviate_ex to sync with
# the Python client updates from October 2025 onwards.

unless Code.ensure_loaded?(WeaviateEx) do
  Mix.install([{:weaviate_ex, path: "."}])
end

Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.VectorConfig
alias WeaviateEx.Config.ObjectTTL

ExampleHelper.section("New Features - Dec 2025 Python Client Sync")

# ============================================================================
# 1. Object TTL Configuration
# ============================================================================
ExampleHelper.step("Object TTL (Time-To-Live) Configuration")

# Create TTL config for objects to expire 24 hours after last update
ttl_by_update = ObjectTTL.delete_by_update_time(86400)
ExampleHelper.command("ObjectTTL.delete_by_update_time(86400)")
ExampleHelper.result("TTL Config", ObjectTTL.to_map(ttl_by_update))

# Create TTL config for objects to expire based on creation time
ttl_by_creation = ObjectTTL.delete_by_creation_time(3600, true)
ExampleHelper.command("ObjectTTL.delete_by_creation_time(3600, true)")
ExampleHelper.result("TTL Config with filtering", ObjectTTL.to_map(ttl_by_creation))

# Create TTL config based on a custom date property
ttl_by_date = ObjectTTL.delete_by_date_property("expiry_date", 1800)
ExampleHelper.command("ObjectTTL.delete_by_date_property(\"expiry_date\", 1800)")
ExampleHelper.result("TTL by Date Property", ObjectTTL.to_map(ttl_by_date))

# Disable TTL
disabled_ttl = ObjectTTL.disable()
ExampleHelper.command("ObjectTTL.disable()")
ExampleHelper.result("Disabled TTL", ObjectTTL.to_map(disabled_ttl))

ExampleHelper.success("Object TTL configurations created successfully")

# ============================================================================
# 2. AWS Service-Specific Vectorizer Methods
# ============================================================================
ExampleHelper.step("AWS Service-Specific Vectorizer Methods")

# AWS Bedrock configuration (requires AWS credentials)
bedrock_config =
  VectorConfig.text2vec_aws_bedrock(
    model: "amazon.titan-embed-text-v1",
    region: "us-east-1"
  )

ExampleHelper.command("VectorConfig.text2vec_aws_bedrock(model: ..., region: ...)")
ExampleHelper.result("AWS Bedrock Config", bedrock_config["moduleConfig"])

# AWS SageMaker configuration
sagemaker_config =
  VectorConfig.text2vec_aws_sagemaker(
    endpoint: "my-embedding-endpoint",
    region: "us-west-2",
    target_model: "embedding-model-v1",
    target_variant: "AllTraffic"
  )

ExampleHelper.command("VectorConfig.text2vec_aws_sagemaker(endpoint: ..., region: ...)")
ExampleHelper.result("AWS SageMaker Config", sagemaker_config["moduleConfig"])

ExampleHelper.success("AWS vectorizer configurations created")

# ============================================================================
# 3. Google Service-Specific Vectorizer Methods
# ============================================================================
ExampleHelper.step("Google Service-Specific Vectorizer Methods")

# Google Vertex AI configuration
vertex_config =
  VectorConfig.text2vec_google_vertex(
    project_id: "my-gcp-project",
    model: "textembedding-gecko@001",
    dimensions: 768
  )

ExampleHelper.command("VectorConfig.text2vec_google_vertex(project_id: ..., model: ...)")
ExampleHelper.result("Google Vertex Config", vertex_config["moduleConfig"])

# Google Gemini (AI Studio) configuration
gemini_config =
  VectorConfig.text2vec_google_gemini(
    model: "text-embedding-004",
    dimensions: 512
  )

ExampleHelper.command("VectorConfig.text2vec_google_gemini(model: ...)")
ExampleHelper.result("Google Gemini Config", gemini_config["moduleConfig"])

ExampleHelper.success("Google vectorizer configurations created")

# ============================================================================
# 4. New Vectorizers
# ============================================================================
ExampleHelper.step("New Vectorizers Added Dec 2025")

# VoyageAI with new models
voyage_config =
  VectorConfig.text2vec_voyageai(
    # New model
    model: "voyage-3.5"
  )

ExampleHelper.command("VectorConfig.text2vec_voyageai(model: \"voyage-3.5\")")
ExampleHelper.result("VoyageAI Config", voyage_config)

# text2vec-morph
morph_config =
  VectorConfig.text2vec_morph(
    model: "morph-base",
    base_url: "http://localhost:8000"
  )

ExampleHelper.command("VectorConfig.text2vec_morph(model: ...)")
ExampleHelper.result("Morph Config", morph_config)

# text2vec-model2vec
model2vec_config = VectorConfig.text2vec_model2vec(inference_url: "http://localhost:8001")
ExampleHelper.command("VectorConfig.text2vec_model2vec(inference_url: ...)")
ExampleHelper.result("Model2Vec Config", model2vec_config)

# text2colbert-jinaai (multi-vector)
colbert_config =
  VectorConfig.text2colbert_jinaai(
    model: "jina-colbert-v2",
    dimensions: 128
  )

ExampleHelper.command("VectorConfig.text2colbert_jinaai(model: ..., dimensions: ...)")
ExampleHelper.result("ColBERT Jina Config", colbert_config)

# multi2multivec-jinaai
multi_jina_config =
  VectorConfig.multi2multivec_jinaai(
    model: "jina-clip-v1",
    image_fields: ["image"],
    text_fields: ["title", "description"]
  )

ExampleHelper.command("VectorConfig.multi2multivec_jinaai(model: ..., image_fields: ...)")
ExampleHelper.result("Multi2MultiVec Jina Config", multi_jina_config)

ExampleHelper.success("New vectorizer configurations created")

# ============================================================================
# 5. Cohere Improvements
# ============================================================================
ExampleHelper.step("Cohere Improvements")

# Cohere with new dimensions parameter
cohere_config =
  VectorConfig.text2vec_cohere(
    model: "embed-english-v3.0",
    # New parameter
    dimensions: 1024,
    base_url: "https://api.cohere.ai"
  )

ExampleHelper.command("VectorConfig.text2vec_cohere(model: ..., dimensions: 1024)")
ExampleHelper.result("Cohere with Dimensions", cohere_config["moduleConfig"])

# Cohere reranker with baseURL
reranker_config =
  VectorConfig.reranker_cohere(
    model: "rerank-english-v3.0",
    base_url: "https://api.cohere.ai"
  )

ExampleHelper.command("VectorConfig.reranker_cohere(model: ..., base_url: ...)")
ExampleHelper.result("Cohere Reranker Config", reranker_config)

ExampleHelper.success("Cohere configurations with new parameters created")

# ============================================================================
# 6. New Generative AI Providers
# ============================================================================
ExampleHelper.step("New Generative AI Providers")

IO.puts("\n  New providers available for generative search:")
IO.puts("  - :xai - XAI (Grok) with topP support")
IO.puts("  - :contextualai - ContextualAI with system_prompt, avoid_commentary, max_new_tokens")
IO.puts("  - :google_vertex - Google Vertex AI")
IO.puts("  - :google_gemini - Google Gemini")
IO.puts("  - :aws_sagemaker - AWS SageMaker")
IO.puts("")
IO.puts("  OpenAI O1/O3 reasoning models now support:")
IO.puts("  - :verbosity - low/medium/high")
IO.puts("  - :reasoning_effort - minimal/low/medium/high")

ExampleHelper.success("Generative providers documented")

# ============================================================================
# Summary
# ============================================================================
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("#{ExampleHelper.green("SUMMARY: New Features from Python Client Sync")}")
IO.puts(String.duplicate("=", 60))

IO.puts("""

1. Object TTL Configuration
   - delete_by_update_time/2 - Expire by last update
   - delete_by_creation_time/2 - Expire by creation
   - delete_by_date_property/3 - Expire by custom date property
   - disable/0 - Disable TTL

2. AWS Service-Specific Methods
   - text2vec_aws_bedrock/1 - AWS Bedrock embeddings
   - text2vec_aws_sagemaker/1 - AWS SageMaker endpoints

3. Google Service-Specific Methods
   - text2vec_google_vertex/1 - Google Vertex AI
   - text2vec_google_gemini/1 - Google AI Studio (Gemini)

4. New Vectorizers
   - text2vec_voyageai/1 - VoyageAI (new models: voyage-3.5, voyage-3-large)
   - text2vec_morph/1 - Morph embeddings
   - text2vec_model2vec/1 - Model2Vec embeddings
   - text2colbert_jinaai/1 - ColBERT multi-vector
   - multi2multivec_jinaai/1 - Jina multi-modal

5. Enhanced Parameters
   - Cohere: dimensions parameter
   - Cohere Reranker: baseURL parameter
   - OpenAI: verbosity, reasoning_effort (O1/O3 models)

6. New Generative Providers
   - :xai - XAI (Grok)
   - :contextualai - ContextualAI
   - :google_vertex - Google Vertex AI
   - :google_gemini - Google Gemini
   - :aws_sagemaker - AWS SageMaker
""")

IO.puts("\n#{ExampleHelper.green("✓")} All new features demonstrated!\n")
