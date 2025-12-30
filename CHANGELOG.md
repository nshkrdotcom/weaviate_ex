# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.1] - 2025-12-29

### Added

#### Custom Headers Support
- **Additional Headers Configuration** (`WeaviateEx.Client.Config`):
  - `additional_headers` option for custom HTTP headers (e.g., `X-OpenAI-Api-Key`, `X-Cohere-Api-Key`)
  - Applied to all HTTP requests via Finch
  - Applied as gRPC metadata with lowercased keys
  - Validation prevents nil header values

#### Named Vectors in Data Operations
- **Named Vectors Support** (`WeaviateEx.Objects.Payload`):
  - `vectors` parameter for multiple named vectors (e.g., `%{"title_vector" => [0.1, 0.2]}`)
  - Mutual exclusivity validation between `vector` (single) and `vectors` (named)
  - Supported in `insert/4`, `update/4`, and `replace/4` operations

#### References During Insert
- **Inline References** (`WeaviateEx.Objects.Payload`):
  - `references` parameter in Data.insert/4 for inline reference creation
  - Single UUID: `%{"hasAuthor" => "uuid-123"}`
  - Multiple UUIDs: `%{"hasAuthors" => ["uuid-1", "uuid-2"]}`
  - Multi-target: `%{"relatedTo" => %{target_collection: "Category", uuids: "cat-uuid"}}`
  - Automatic beacon format conversion and properties merge

#### gRPC Exponential Backoff Retry
- **Retry Module** (`WeaviateEx.GRPC.Retry`):
  - `with_retry/2` - Execute function with automatic retry on transient errors
  - `calculate_backoff/1` - Calculate exponential backoff (capped at 32 seconds)
  - `retryable?/1` - Check if error is retryable
  - `retryable_status?/1` - Check if gRPC status code is retryable
  - Retryable status codes: UNAVAILABLE (14), RESOURCE_EXHAUSTED (8), ABORTED (10), DEADLINE_EXCEEDED (4)
  - Configurable `max_retries` (default: 4) and `base_delay_ms` (default: 1000)

### Changed
- gRPC services now automatically retry on transient failures:
  - `WeaviateEx.GRPC.Services.Search` - All search operations
  - `WeaviateEx.GRPC.Services.Batch` - Batch insert, references, delete
  - `WeaviateEx.GRPC.Services.Aggregate` - Aggregation queries
  - `WeaviateEx.GRPC.Services.Tenants` - Tenant operations
  - `WeaviateEx.GRPC.Services.Health` - Health checks (with reduced retry count)

## [0.7.0] - 2025-12-29

### Added

#### Multimodal Search Support
- **NearImage Search** (`WeaviateEx.Query.NearImage`) - Image-based vector search for multimodal collections:
  - `new/1` - Create near_image search with base64 data or file path
  - Supports `multi2vec-clip`, `multi2vec-bind`, and other image vectorizers
  - Options: `:image`, `:image_file`, `:certainty`, `:distance`, `:target_vectors`
  - `encode_image_file/1` - Base64 encode image files
  - `to_grpc/1`, `to_graphql/1` - Protocol conversion utilities
- **NearMedia Search** (`WeaviateEx.Query.NearMedia`) - Media-based vector search for multimodal collections:
  - `new/2` - Create near_media search with type and media data
  - Supports 5 media types: `:audio`, `:video`, `:thermal`, `:depth`, `:imu`
  - Options: `:media`, `:media_file`, `:certainty`, `:distance`, `:target_vectors`
  - `media_types/0` - List all supported media types
  - `to_grpc/1`, `to_graphql/1` - Protocol conversion utilities
- **Query Builder Integration**:
  - `Query.near_image/2` - Add image-based search to query
  - `Query.near_media/3` - Add media-based search to query
  - Full GraphQL and gRPC support for multimodal queries

#### gRPC Health Checking
- **gRPC Health Ping** (`WeaviateEx.GRPC.Services.Health`):
  - `ping/2` - Lightweight connectivity check returning `:ok` or `{:error, reason}`
  - Quick connection verification for startup and heartbeat checks
  - Returns `{:error, :no_channel}` for nil channels

#### Server Version Detection
- **Version Module** (`WeaviateEx.Version`) - Parse and validate Weaviate server versions:
  - `parse/1` - Parse version strings (handles "v" prefix, prereleases, build metadata)
  - `meets_minimum?/2` - Check if version meets minimum requirement
  - `get_server_version/1` - Extract version from meta endpoint response
  - `validate_server/1` - Validate against minimum supported version (1.27.0)
  - `minimum_version/0`, `minimum_version_string/0` - Get minimum version info
  - `format_version/1` - Format version tuple to string

#### Kubernetes Health Endpoints
- **K8s Probe Support** (`WeaviateEx.Health`):
  - `alive?/0`, `alive?/1` - Liveness probe via `/.well-known/live` endpoint
  - `ready?/0`, `ready?/1` - Readiness probe via `/.well-known/ready` endpoint
  - Client and no-client variants for flexibility
  - Returns `{:ok, true}` or `{:ok, false}` for consistent handling

#### Background Batch Processing (Phase 2)
- **Background Batcher** (`WeaviateEx.Batch.Background`) - Process-based async batching:
  - `start_link/1` - Start background batcher with configuration
  - `add_object/3` - Queue object for background processing
  - `add_reference/5` - Queue reference with UUID tracking
  - `flush/1` - Trigger immediate flush
  - `get_results/1` - Get accumulated results
  - `stop/2` - Stop with optional final flush
  - Automatic flushing based on batch size or time interval
  - Concurrent request management with configurable limits
  - UUID tracking for reference ordering
  - Error tracking and callback support
- **Batch Module Integration**:
  - `Batch.background/3` - Convenience function to start background batcher

#### Named Vector Query Integration (Phase 2)
- **TargetVectors Enhancements** (`WeaviateEx.Query.TargetVectors`):
  - `combine/2` - Create combined target vectors with method (`:sum`, `:average`, `:minimum`)
  - `weighted/1` - Create manually weighted target vectors
  - `normalize/1` - Normalize various input formats to Config struct
  - `to_grpc/1` - Convert to gRPC format
  - `Config` struct for structured target vector configuration
- **Query Builder Integration**:
  - `Query.near_vector/3` now accepts `:target_vectors` option
  - `Query.near_text/3` now accepts `:target_vectors` option
  - `Query.near_object/3` now accepts `:target_vectors` option

#### Advanced Hybrid Search (Phase 2)
- **HybridVector Enhancements** (`WeaviateEx.Query.HybridVector`):
  - `near_text/2` - Text-based vector search with Move operations
  - `near_vector/2` - Vector-based search with target vectors
  - `to_grpc/1` - Convert to gRPC format for query execution
  - Support for `:move_to`, `:move_away_from`, `:target_vectors` options
  - `query` field for better naming consistency
- **Query.hybrid/3** Enhancements:
  - `:vector` option accepts HybridVector configuration
  - `:properties` option for BM25 component
  - `:target_vectors` option for multi-vector collections

#### Connection Pool Configuration (Phase 2)
- **Connection Config** (`WeaviateEx.Config.Connection`) - Fine-tune connection settings:
  - `new/1` - Create pool config with size, max connections, timeouts
  - `to_finch_opts/1` - Convert to Finch HTTP client options
  - `to_grpc_opts/1` - Convert to gRPC channel options
  - Options: `:pool_size`, `:max_connections`, `:pool_timeout`, `:max_idle_time`

#### Azure OIDC Support (Phase 2)
- **Azure Authentication** (`WeaviateEx.Auth.Azure`) - Azure-specific OIDC handling:
  - `azure_endpoint?/1` - Detect Azure/Microsoft token endpoints
  - `default_scopes/1` - Generate Azure-style `.default` scopes
  - `apply_azure_defaults/1` - Auto-configure Azure authentication
  - `detect_version/1` - Detect Azure v1/v2 endpoint version
  - `build_token_params/2` - Build Azure-specific token parameters

#### Dynamic gRPC Message Size (Phase 2)
- **Version Module** (`WeaviateEx.Version`):
  - `get_grpc_max_message_size/1` - Extract gRPC max message size from server meta

#### Filter Enhancements (Phase 4)
- **Property Length Filtering** (`WeaviateEx.Filter`):
  - `by_property_length/3` - Filter by string or array length
  - `len/1` - Create length path helper (e.g., `len("title")`)
  - Operators: `:equal`, `:not_equal`, `:greater_than`, `:greater_or_equal`, `:less_than`, `:less_or_equal`
  - Use for filtering empty strings, minimum content length, array element counts

- **Reference Path Traversal** (`WeaviateEx.Filter.RefPath`):
  - `through/2`, `through/3` - Build multi-level reference paths
  - `property/4` - Terminate path with property filter
  - `build_path/2` - Build path list from segments
  - `to_path/1` - Get path without final property
  - `depth/1` - Get number of hops in reference path
  - Enables deep filtering: `RefPath.through("hasAuthor", "Author") |> RefPath.through("worksAt", "Company") |> RefPath.property("industry", :equal, "Tech")`

- **Multi-Target Reference Filters** (`WeaviateEx.Filter.MultiTargetRef`):
  - `new/2` - Create multi-target reference filter builder
  - `where/4` - Add property filter on specific target collection
  - `deep_where/2` - Deep path filtering with RefPath
  - `as_ref_path/1` - Convert to RefPath for chaining
  - Filter different target collections: `MultiTargetRef.new("relatedTo", "Article") |> MultiTargetRef.where("title", :like, "Tech*")`

- **Filter Module Integration**:
  - `by_ref_path/4` - Create filter from RefPath
  - `by_ref_multi_target/5` - Create multi-target reference filter

#### Query Reference Enhancements (Phase 4)
- **Multi-Target References** (`WeaviateEx.Query.QueryReference`):
  - `multi_target/3` - Create query for specific target collection
  - `multi_target?/1` - Check if reference is multi-target
  - Query different targets: `QueryReference.multi_target("relatedTo", "Article", return_properties: ["title"])`

- **Return Metadata Option**:
  - `return_metadata` option for references
  - Accepts `:full`, `:common`, or list of atoms (`:uuid`, `:distance`, `:certainty`, `:creation_time`, etc.)
  - Include metadata in referenced objects: `QueryReference.new("hasAuthor", return_metadata: [:uuid, :distance])`

#### Named Vector Config Updates (Phase 4)
- **Update Configuration** (`WeaviateEx.API.NamedVectors`):
  - `update_config/2` - Create update config for existing named vector
  - `update_to_api/1` - Convert update to API format
  - `build_update_config/1` - Build combined update for multiple vectors
  - Vector index options: `:ef`, `:dynamic_ef_min`, `:dynamic_ef_max`, `:dynamic_ef_factor`, `:flat_search_cutoff`
  - Quantizer options: `:type` (`:pq`, `:bq`, `:sq`), `:segments`, `:centroids`, `:training_limit`, `:rescore_limit`
  - Example: `NamedVectors.update_config("title_vector", vector_index: [ef: 200], quantizer: [type: :pq, segments: 128])`

#### Custom Provider Configurations (Phase 4)
- **Custom Generative Providers** (`WeaviateEx.API.GenerativeConfig`):
  - `custom/2` - Create config for unlisted generative AI providers
  - Automatic snake_case to camelCase conversion
  - Pass any options: api_endpoint, model, api_key_header, temperature, max_tokens, etc.
  - Example: `GenerativeConfig.custom("my-llm", api_endpoint: "https://llm.example.com", model: "custom-gpt")`

- **Reranker Configuration Module** (`WeaviateEx.API.RerankerConfig`):
  - `cohere/2` - Cohere Rerank configuration
  - `transformers/1` - Local transformers reranker
  - `voyageai/2` - Voyage AI reranker
  - `jinaai/2` - Jina AI reranker
  - `custom/2` - Custom/unlisted reranker providers
  - `none/0` - Disable reranking
  - All providers support `:base_url` option for custom endpoints

### Changed
- Updated Query struct to include `near_image` and `near_media` fields
- Enhanced GraphQL query building with nearImage and nearMedia support

### Test Infrastructure

#### Supertester Integration
- **Added `supertester ~> 0.4.0`** as test dependency for robust, async-safe testing
- **Eliminated all Process.sleep calls** from unit tests using supertester-style patterns:
  - `token_manager_test.exs`: Replaced 8 sleep calls with deterministic state polling
  - `dynamic_test.exs`: Replaced 1 sleep call with state-based synchronization
  - `state_test.exs`: Replaced 1 sleep call with explicit time-wait pattern
- **New Test Helpers** (`WeaviateEx.TestHelpers`):
  - `wait_until/2` - Polls until condition is met with configurable timeout/interval
  - `wait_for_genserver_state/3` - Waits for GenServer state to match a condition
  - `trigger_and_wait/4` - Sends message and waits for state change
- All 2151 tests pass with full async execution support

### Stats
- Phase 1-4: 20+ new feature modules/functions
- Phase 4: 6 new modules (RefPath, MultiTargetRef, RerankerConfig) + major enhancements
- Full test coverage for all new features
- Backward compatible with v0.6.0
- Test suite now fully async-safe with zero timing-based synchronization

## [0.6.0] - 2025-12-29

### Added

#### Quantizer Support
- **Quantizer Module** (`WeaviateEx.API.Quantizer`) - Typed structs for vector quantization:
  - `PQConfig` - Product Quantization with segments, centroids, encoder configuration
  - `BQConfig` - Binary Quantization with cache and rescore options
  - `SQConfig` - Scalar Quantization with training limit configuration
  - `RQConfig` - Rotational Quantization with configurable bit depth
  - Each config provides `new/1`, `to_api/1`, `from_api/1` for serialization round-trips
  - Convenience aliases: `Quantizer.pq/1`, `Quantizer.bq/1`, `Quantizer.sq/1`, `Quantizer.rq/1`
  - `detect_type/1` - Auto-detect quantizer type from API response
  - `from_api/1` - Parse any quantizer from API response

#### Core Vectorizer Modules
- **Text2VecAWS** (`WeaviateEx.API.Vectorizers.Text2VecAWS`) - AWS vectorizer support:
  - Bedrock service with model selection (Titan, Cohere, etc.)
  - SageMaker service with endpoint, target model, and variant options
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Text2VecGoogle** (`WeaviateEx.API.Vectorizers.Text2VecGoogle`) - Google vectorizer support:
  - Vertex AI service with project ID and region
  - Gemini service (Google AI Studio) with auto-configured endpoint
  - Task type, title property, and dimensions configuration
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Text2VecWeaviate** (`WeaviateEx.API.Vectorizers.Text2VecWeaviate`) - Weaviate-hosted embeddings:
  - Model selection for Weaviate-managed embedding service
  - Base URL configuration for custom deployments
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Img2VecNeural** (`WeaviateEx.API.Vectorizers.Img2VecNeural`) - Neural image vectorizer:
  - Image fields configuration for multi-image objects
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`

#### OIDC Token Management
- **OIDC Module** (`WeaviateEx.Auth.OIDC`) - OpenID Connect support:
  - `discover/1` - OIDC configuration discovery from issuer URL
  - `get_token/2` - Token exchange for client_credentials and password grants
  - `refresh_token/2` - Token refresh using refresh tokens
  - `OIDC.Config` struct for provider configuration
  - `OIDC.TokenResponse` struct with expiration helpers:
    - `expires_at/1` - Calculate expiration timestamp
    - `expired?/1` - Check if token is expired
    - `expiring_soon?/2` - Check if token expires within buffer time
- **TokenManager GenServer** (`WeaviateEx.Auth.TokenManager`) - Automatic token management:
  - `start_link/1` - Start with OIDC config or issuer URL
  - `get_token/1` - Get current valid token
  - `get_access_token/1` - Get just the access token string
  - `force_refresh/1` - Force immediate token refresh
  - Automatic background token refresh before expiration
  - Configurable refresh buffer (default: 60 seconds before expiry)
  - `child_spec/1` - Easy integration with supervision trees
- **Auth Module Extensions**:
  - `get_oidc_headers/1` - Get authorization headers from TokenManager
  - `oidc_config/1` - Create OIDC configuration for TokenManager

#### Generative Search Integration
- **Query.Generate Module** (`WeaviateEx.Query.Generate`) - Combine search with AI generation:
  - `new/1` - Create generative query for collection
  - `near_text/3`, `near_vector/3`, `near_object/3` - Vector similarity with generation
  - `bm25/3`, `hybrid/3` - Keyword and hybrid search with generation
  - `single/2` - Single-object generation (generate per result)
  - `grouped/2` - Grouped generation (generate once for all results)
  - `return_properties/2`, `where/2`, `limit/2`, `offset/2`, `tenant/2`
  - `additional/2` - Request additional metadata fields
  - `to_graphql/1` - Convert to GraphQL query string
  - `execute/2` - Execute query and parse results
  - `parse_response/2` - Parse API response to GenerativeResult
- **GenerativeResult Struct** (`WeaviateEx.Query.GenerativeResult`):
  - `objects` - List of result objects with properties
  - `generated` - Grouped generation result
  - `generated_per_object` - List of per-object generation results
- **Query Module Integration**:
  - `Query.generate/4` - Convert Query struct to Generate query

#### Nested Properties Support
- **Property.Nested Module** (`WeaviateEx.Property.Nested`) - Nested object schema support:
  - `new/1` - Create nested property with name, data_type, nested_properties
  - `to_api/1` - Serialize to Weaviate API format
  - `from_api/1` - Parse from API response (supports recursive nesting)
  - `valid?/1` - Validate nested property configuration
  - `object_type?/1` - Check if property is object or object_array type
- **Property Module Integration**:
  - `Property.object/3` - Create object property with nested properties
  - `Property.object_array/3` - Create object array property with nested properties
- **DataType Module**:
  - `:object` and `:object_array` data types for nested structures

#### Batch Improvements
- **Concurrent Batch Operations** (`WeaviateEx.Batch.Concurrent`):
  - `insert_many/4` - Parallel batch insertion using Task.async_stream
  - Configurable: `max_concurrency`, `batch_size`, `ordered`, `timeout`
  - `split_into_batches/2` - Split objects into batches
  - `aggregate_results/2` - Combine results from parallel batches
  - `retryable_error?/1` - Detect retryable errors
  - `Result` struct with `all_successful?/1`, `has_failures?/1`, `summary/1`
- **Batch Queue** (`WeaviateEx.Batch.Queue`) - FIFO queue for failure tracking:
  - `new/0` - Create empty queue
  - `enqueue/2` - Add object to pending queue
  - `dequeue_batch/2` - Get batch of objects for processing
  - `mark_failed/3` - Move object to failed queue with reason
  - `requeue_failed/2` - Move failed objects back to pending (respects max_retries)
  - `pending_count/1`, `failed_count/1`, `empty?/1`
  - `FailedObject` struct with retry count and failure timestamp
- **Rate Limit Detection** (`WeaviateEx.Batch.RateLimit`):
  - `detect/1` - Detect rate limiting from HTTP response
  - `rate_limited?/1` - Check if error indicates rate limiting
  - `calculate_backoff/1` - Calculate exponential backoff with jitter
  - `extract_retry_after/1` - Extract retry-after from headers
  - Provider-specific patterns: OpenAI (429), Cohere (rate limit errors)
- **Server Queue Monitoring** (`WeaviateEx.API.Cluster`):
  - `batch_stats/1` - Get cluster batch statistics (queue_length, rate_per_second, failed_count)
  - Aggregates stats from all nodes for dynamic batch sizing
- **Dynamic Batch Sizing** (`WeaviateEx.Batch.Dynamic`):
  - `:monitor_server_stats` option - Enable server queue monitoring
  - `:poll_interval` option - Configure stats polling frequency
  - `get_server_batch_stats/1` - Get current server stats from GenServer

#### gRPC Batch Streaming (Weaviate 1.34+)
- **Batch Stream Service** (`WeaviateEx.GRPC.Services.BatchStream`) - Low-level gRPC streaming:
  - `open/2` - Open bidirectional gRPC stream
  - `send_objects/2` - Send batch objects over stream
  - `send_references/2` - Send cross-references over stream
  - `receive_results/2` - Receive batch results with timeout
  - `close/1` - Close stream and clean up resources
  - `start_message/1`, `stop_message/0`, `data_message/2` - Protocol message builders
- **High-Level Batch Stream** (`WeaviateEx.Batch.Stream`) - Client-side buffered streaming:
  - `new/3` - Create stream session with buffer configuration
  - `add/2` - Add object to buffer (auto-flush when full)
  - `flush/1` - Manually flush buffer to server
  - `close/1` - Close stream and return all results
  - Configurable: `buffer_size`, `flush_interval_ms`, `auto_flush`, `auto_reconnect`
  - Automatic connection management and error recovery

#### RBAC Enhancements
- **Scope Permissions** (`WeaviateEx.API.RBAC.Scope`) - Fine-grained access control:
  - `all_collections/0` - Create scope for all collections
  - `collection/1` - Create scope for specific collection
  - `collections/1` - Create scope for list of collections
  - `with_tenants/2` - Add tenant restrictions to scope
  - `with_shards/2` - Add shard restrictions to scope
  - `to_api/1`, `from_api/1` - API serialization
- **Permission Builder** (`WeaviateEx.API.RBAC.Permission`) - Permission construction:
  - `new/3` - Create permission with resource, action, and scope
  - `read_collection/1`, `manage_data/1` - Common permission shortcuts
  - `admin/0` - Full administrative permissions
  - `viewer/0` - Read-only permissions
  - `to_api/1`, `from_api/1` - API serialization
- **Database User Management** (`WeaviateEx.API.Users.DB`) - DB-backed users:
  - `create/3` - Create DB user (returns API key)
  - `get/3` - Get DB user details
  - `list/2` - List all DB users
  - `delete/3` - Delete DB user
  - `rotate_api_key/3` - Rotate user's API key
  - `assign_roles/4`, `revoke_roles/4` - Role management
- **OIDC User Management** (`WeaviateEx.API.Users.OIDC`) - OIDC-backed users:
  - `get/3` - Get OIDC user details
  - `list/2` - List OIDC users
  - `assign_roles/4`, `revoke_roles/4` - Role management
  - Note: OIDC users cannot be created/deleted via API

#### Additional Vectorizers
- **Text2VecTransformers** (`WeaviateEx.API.Vectorizers.Text2VecTransformers`) - Local transformer models:
  - Pooling strategy configuration (`:masked_mean`, `:cls`)
  - Separate passage/query inference URLs for asymmetric search
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Text2VecOllama** (`WeaviateEx.API.Vectorizers.Text2VecOllama`) - Ollama embeddings:
  - Model selection (nomic-embed-text, mxbai-embed-large, etc.)
  - Custom API endpoint configuration
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Text2VecJinaAI** (`WeaviateEx.API.Vectorizers.Text2VecJinaAI`) - Jina AI embeddings:
  - Model selection with dimensions support
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Text2VecVoyageAI** (`WeaviateEx.API.Vectorizers.Text2VecVoyageAI`) - VoyageAI embeddings:
  - Truncation support for long inputs
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Text2VecPalm** (`WeaviateEx.API.Vectorizers.Text2VecPalm`) - Google PaLM/Vertex AI:
  - Project ID and model ID configuration
  - Custom API endpoint support
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Text2VecAzureOpenAI** (`WeaviateEx.API.Vectorizers.Text2VecAzureOpenAI`) - Azure OpenAI:
  - Resource name and deployment ID configuration
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Multi2VecClip** (`WeaviateEx.API.Vectorizers.Multi2VecClip`) - CLIP multimodal:
  - Image and text field configuration with weights
  - Custom inference URL support
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Multi2VecGoogle** (`WeaviateEx.API.Vectorizers.Multi2VecGoogle`) - Google multimodal:
  - Image, text, and video field support
  - Project ID, location, model ID, dimensions configuration
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Multi2VecCohere** (`WeaviateEx.API.Vectorizers.Multi2VecCohere`) - Cohere multimodal:
  - Image and text field configuration
  - Truncation strategy support (NONE, START, END)
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Multi2VecVoyageAI** (`WeaviateEx.API.Vectorizers.Multi2VecVoyageAI`) - VoyageAI multimodal:
  - Image and text field configuration with weights
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`
- **Ref2VecCentroid** (`WeaviateEx.API.Vectorizers.Ref2VecCentroid`) - Reference centroid:
  - Reference properties configuration
  - Centroid calculation method (mean)
  - `new/1`, `to_api/1`, `from_api/1`, `vectorizer_name/0`

#### Debug Module
- **Debug API** (`WeaviateEx.Debug`) - Protocol comparison and troubleshooting:
  - `get_object_rest/4` - Fetch object via REST/HTTP protocol
  - `get_object_grpc/4` - Fetch object via gRPC protocol
  - `compare_protocols/4` - Compare REST and gRPC responses with detailed diff
  - `connection_info/1` - Get HTTP and gRPC connection diagnostics
- **ObjectCompare** (`WeaviateEx.Debug.ObjectCompare`) - Deep object comparison:
  - `compare/2` - Compare two objects and detect differences
  - `diff/2` - Generate list of differences between objects
  - `format_diff/1` - Format differences as human-readable report
- **RequestLogger** (`WeaviateEx.Debug.RequestLogger`) - Request logging GenServer:
  - `start_link/1` - Start logger with optional name
  - `enable/1`, `disable/1` - Toggle request logging
  - `log_request/2` - Log HTTP/gRPC request details
  - `get_logs/2` - Retrieve logs with optional filters (protocol, min_duration_ms)
  - `export_logs/3` - Export logs to file (JSON or text format)
  - `clear_logs/1` - Clear all logged requests
- **Main Module Integration**:
  - `WeaviateEx.debug_get_rest/4` - Convenience delegate to Debug.get_object_rest
  - `WeaviateEx.debug_compare/4` - Convenience delegate to Debug.compare_protocols

#### Backup Enhancements
- **RBAC Restore Options** (`WeaviateEx.API.Backup`):
  - `roles_restore` option - Restore role definitions from backup
  - `users_restore` option - Restore user role assignments from backup
  - `overwrite_alias` option - Overwrite existing collection aliases during restore
- **Location Struct Support** (`WeaviateEx.API.Backup`):
  - `create/4` now accepts Location structs (Filesystem, S3, GCS, Azure) directly
  - `restore/4` now accepts Location structs directly
  - Dynamic location configuration for programmatic backend selection
- **Backup Config Enhancement** (`WeaviateEx.Backup.Config.Create`):
  - Added `chunk_size` option - Configure backup chunk size in megabytes

#### Connection Management
- **Pool Configuration** (`WeaviateEx.Client.Pool`) - Connection pool settings:
  - `new/1` - Create pool config with size, overflow, strategy, timeouts
  - `default/0` - Default pool configuration
  - `default_http/0` - HTTP-optimized pool (larger pool for parallel requests)
  - `default_grpc/0` - gRPC-optimized pool (smaller pool due to multiplexing)
  - `to_finch_opts/1` - Convert to Finch HTTP client options
  - `to_grpc_opts/1` - Convert to gRPC channel options
  - Configurable: size, overflow, strategy (:fifo/:lifo), timeout, idle_timeout, max_age
- **Client State Tracking** (`WeaviateEx.Client.State`) - Lifecycle state management:
  - `new/0` - Create initial state with timestamps
  - `connected/1`, `disconnected/2`, `closed/1` - State transitions
  - `record_request/1` - Track successful requests
  - `record_error/2` - Track errors with details
  - Status tracking: `:initializing`, `:connected`, `:disconnected`, `:closed`
  - Statistics: request_count, error_count, created_at, last_used_at, last_error
- **Client Lifecycle** (`WeaviateEx.Client`):
  - `close/1` - Close client and release all connections
  - `closed?/1` - Check if client has been closed
  - `status/1` - Get current client status
  - `stats/1` - Get client statistics (request/error counts, timestamps)
  - `with_client/2` - Execute function with auto-managed client lifecycle
  - Added `state` field to client struct for tracking lifecycle
- **ClosedClientError** (`WeaviateEx.Error.ClosedClientError`) - Exception for closed client:
  - Raised when operations are attempted on a closed client
  - Includes `closed_at` timestamp for debugging

## [0.5.0] - 2025-12-28

### Added

#### Proxy Support
- **Proxy Configuration** (`WeaviateEx.Config.Proxy`) - HTTP, HTTPS, and gRPC proxy support:
  - `new/1` - Create proxy config with explicit options
  - `from_env/0` - Read from environment variables (HTTP_PROXY, HTTPS_PROXY, GRPC_PROXY)
  - `configured?/1` - Check if any proxy is configured
  - `http_proxy_for/2` - Get appropriate proxy for a URL scheme
  - `to_finch_opts/1` - Convert to Finch HTTP client options
  - `to_grpc_opts/1` - Convert to gRPC channel options
- Environment variable reading with case-insensitive support (uppercase takes precedence)
- Automatic fallback from HTTPS to HTTP proxy when HTTPS not configured

#### Inverted Index Configuration
- **Inverted Index Config** (`WeaviateEx.API.InvertedIndexConfig`) - Collection index configuration:
  - `bm25/1` - BM25 algorithm configuration with `b` and `k1` parameters
  - `stopwords/1` - Stopwords configuration with preset, additions, and removals
  - `index_timestamps/1` - Enable/disable timestamp indexing
  - `index_property_length/1` - Enable/disable property length indexing
  - `index_null_state/1` - Enable/disable null state indexing
  - `cleanup_interval_seconds/1` - Set cleanup interval
  - `build/1` - Build complete inverted index configuration
  - `merge/2` - Merge two configurations
  - `validate/1` - Validate configuration values
- Supported stopwords presets: `en`, `none`
- BM25 parameter validation (b: 0-1, k1: positive)

#### Generative Search Configuration
- **Generative Config** (`WeaviateEx.API.GenerativeConfig`) - 13+ provider configurations:
  - `openai/1` - OpenAI GPT models
  - `azure_openai/1` - Azure OpenAI deployments
  - `cohere/1` - Cohere Command models
  - `anthropic/1` - Anthropic Claude models
  - `mistral/1` - Mistral AI models
  - `google/1` - Google Gemini/PaLM models
  - `aws/1` - AWS Bedrock/SageMaker models
  - `ollama/1` - Ollama local models
  - `databricks/1` - Databricks endpoints
  - `nvidia/1` - NVIDIA NIM models
  - `friendliai/1` - FriendliAI models
  - `xai/1` - XAI Grok models
  - `anyscale/1` - Anyscale models
  - `contextualai/1` - ContextualAI models
- `providers/0` - List all supported providers
- `provider_module/1` - Get Weaviate module name for provider
- Full parameter support: model, temperature, maxTokens, baseURL, topK, topP

#### Collection Aliases API
- **Aliases API** (`WeaviateEx.API.Aliases`) - Zero-downtime collection management (requires Weaviate v1.32.0+):
  - `create/3` - Create an alias for a collection
  - `delete/2` - Delete an alias
  - `update/3` - Update alias to point to different collection
  - `get/2` - Get alias details
  - `list/2` - List all aliases (optionally filter by collection)
  - `exists?/2` - Check if alias exists
  - `minimum_version/0` - Get minimum required Weaviate version
- **Alias Struct** (`WeaviateEx.API.Aliases.Alias`):
  - `from_api/1` - Parse API response to struct
  - Fields: `alias`, `collection`

#### ZSTD Compression Options
- **Extended Compression** (`WeaviateEx.Backup.Compression`) - Additional compression algorithms:
  - `:zstd_default` - Balanced ZSTD compression
  - `:zstd_best_speed` - Fast ZSTD compression
  - `:zstd_best_compression` - Maximum ZSTD compression
  - `:no_compression` - Disable compression
  - `gzip?/1` - Check if compression level uses GZIP
  - `zstd?/1` - Check if compression level uses ZSTD
- ZSTD provides faster compression with better ratios than GZIP

#### Query Move Integration
- **Move in near_text** (`WeaviateEx.Query`) - Semantic direction control:
  - `near_text/3` now supports `:move_to` and `:move_away` options
  - Move concepts toward or away from specific terms
  - Accepts `WeaviateEx.Query.Move` structs or keyword options
  - Proper GraphQL generation for move parameters
- Example: `Query.near_text("technology", move_to: [concepts: ["AI"], force: 0.8])`

### Changed
- Updated test count to 1575 tests
- Enhanced Query module with Move struct integration
- Extended Backup.Compression with ZSTD support while maintaining backward compatibility

### Stats
- 6 new feature modules
- Full test coverage for all new features
- Backward compatible with v0.4.0

## [0.4.0] - 2025-12-28

### Added

#### Cluster Management
- **Cluster API** (`WeaviateEx.API.Cluster`) - Complete cluster management:
  - `nodes/2` - Get cluster node information with optional verbose output
  - `shards/2` - Get shards for a collection
  - `statistics/1` - Get cluster-wide statistics
  - `replicate/4` - Trigger shard replication between nodes
  - `list_replications/2` - List ongoing replication operations
  - `get_replication/3` - Get replication operation status
  - `cancel_replication/2` - Cancel an ongoing replication
  - `delete_replication/2` - Delete a replication operation record
  - `wait_for_replications/2` - Wait for all replications to complete
- **Cluster Type Structs**:
  - `WeaviateEx.Cluster.Node` - Node with status, version, shards, stats
  - `WeaviateEx.Cluster.Shard` - Shard with status, vector indexing, object count
  - `WeaviateEx.Cluster.Replication` - Replication operation with progress tracking
  - `WeaviateEx.Cluster.Replication.Operation` - Individual replication operation

#### Query Rerank & GroupBy Integration
- **Query.Rerank** enhancements:
  - `to_map/1` - Convert to map format for gRPC
  - `valid?/1` - Validate rerank configuration
  - Improved `to_graphql/1` with proper string escaping
- **Query.GroupBy** enhancements:
  - Support for list paths (nested properties)
  - `to_map/1` - Convert to map format for gRPC
  - `valid?/1` - Validate group_by configuration
- **Query Builder Integration**:
  - `Query.rerank/2` - Add rerank to query
  - `Query.group_by/2` - Add group_by to query
  - Works with all query types: near_text, near_vector, hybrid, bm25

#### Batch Advanced Features
- **wait_for_vector_indexing** (`WeaviateEx.Batch`):
  - Poll until all vectors are indexed
  - Configurable timeout, poll interval, max failures
  - Optional shard filtering
- **Auto UUID Generation** (`WeaviateEx.Batch.FixedSize`):
  - `add_object/4` auto-generates UUID if not provided
  - Uses `WeaviateEx.Types.UUID.generate/0`
- **Multi-Target References** (`WeaviateEx.Batch.FixedSize`):
  - `add_reference/6` now supports list of targets
  - Each target specifies collection and uuid
- **DeleteResult Struct** (`WeaviateEx.Batch.DeleteResult`):
  - Typed result for batch delete operations
  - `from_api/1` - Parse API response
  - `all_successful?/1`, `has_failures?/1`
  - `failed_objects/1`, `successful_objects/1`
  - `summary/1` - Human-readable summary
  - `DeletedObject` submodule for individual objects

#### Reranker Configurations
- **6 Reranker Types** in `WeaviateEx.API.VectorConfig`:
  - `reranker_cohere/1` - Cohere reranker (existing)
  - `reranker_transformers/1` - Local transformers reranker
  - `reranker_voyageai/1` - VoyageAI reranker
  - `reranker_jinaai/1` - Jina AI reranker
  - `reranker_nvidia/1` - NVIDIA reranker
  - `reranker_contextualai/1` - Contextual AI reranker
- **Builder Function**: `with_reranker/3` - Add reranker to collection config

#### Backup & Restore Module
- **Backup API** (`WeaviateEx.API.Backup`) - Complete backup and restore functionality:
  - `create/4` - Create backup with include/exclude collections, config, wait_for_completion
  - `restore/4` - Restore backup with include/exclude collections, config, wait_for_completion
  - `get_create_status/3` - Get backup creation status
  - `get_restore_status/3` - Get restore operation status
  - `list/2` - List all backups for a storage backend
  - `cancel/3` - Cancel in-progress backup
  - `wait_for_completion/5` - Poll until operation completes with configurable timeout
- **Storage Backend Enum** (`WeaviateEx.Backup.Storage`) - 4 supported backends:
  - `:filesystem` - Local filesystem storage
  - `:s3` - Amazon S3 or S3-compatible storage
  - `:gcs` - Google Cloud Storage
  - `:azure` - Azure Blob Storage
  - Helper functions: `all/0`, `valid?/1`, `to_api_path/1`, `from_api/1`
- **Compression Level Enum** (`WeaviateEx.Backup.Compression`):
  - `:default` - Balanced compression
  - `:best_speed` - Faster compression, larger files
  - `:best_compression` - Slower compression, smaller files
- **Backup Status Types** (`WeaviateEx.Backup.Status`):
  - Status values: `:started`, `:transferring`, `:transferred`, `:success`, `:failed`, `:canceled`
  - Response structs: `CreateResponse`, `RestoreResponse`, `BackupInfo`
  - Helper functions: `completed?/1`, `success?/1`, `in_progress?/1`
- **Backup Configuration** (`WeaviateEx.Backup.Config`):
  - `Create` struct with `cpu_percentage` and `compression` options
  - `Restore` struct with `cpu_percentage` option
  - Factory functions: `create/1`, `restore/1`
- **Storage Location Structs** (`WeaviateEx.Backup.Location`):
  - `Filesystem` - Local path configuration
  - `S3` - Bucket, path, endpoint, region, credentials, SSL
  - `GCS` - Bucket, path, project ID, credentials
  - `Azure` - Container, path, connection string
  - Factory functions: `filesystem/1`, `s3/3`, `gcs/3`, `azure/3`
- **Backup Error Types** (`WeaviateEx.Error`):
  - `backup_not_found/2`, `backup_already_exists/2`, `backup_failed/2`
  - `restore_failed/2`, `backup_timeout/2`, `invalid_backend/1`
- **Main Module Backup Functions**:
  - `create_backup/4`, `restore_backup/4`, `list_backups/2`
  - `cancel_backup/3`, `get_backup_status/3`, `get_restore_status/3`

#### Role-Based Access Control (RBAC)
- **RBAC Module** (`WeaviateEx.RBAC`) - Complete role-based access control support:
  - `Actions` - Action type definitions and conversions for all 11 permission types
  - `Permission` - Permission struct with encoding/decoding for API communication
  - `Permissions` - Builder API for constructing permissions fluently
  - `Role` - Role struct with permission management
- **RBAC API** (`WeaviateEx.API.RBAC`) - Role CRUD operations:
  - `list_roles/1` - List all roles
  - `get_role/2` - Get role by name
  - `create_role/3` - Create role with permissions
  - `delete_role/2` - Delete a role
  - `add_permissions/3` - Add permissions to role
  - `remove_permissions/3` - Remove permissions from role
  - `has_permissions?/3` - Check if role has permissions
  - `get_users_for_role/2` - Get users assigned to role
  - `get_groups_for_role/2` - Get groups assigned to role
  - `exists?/2` - Check if role exists
- **11 Permission Types**: collections, data, tenants, roles, users, groups, cluster, nodes, backups, replicate, alias
- **Type-safe Permissions Builder** (`WeaviateEx.RBAC.Permissions`):
  - `collections/2` - Collection schema permissions
  - `data/3` - Data CRUD permissions with tenant/object filters
  - `tenants/3` - Tenant management permissions
  - `roles/2` - Role management permissions
  - `users/2` - User management permissions
  - `groups/2` - OIDC group permissions
  - `cluster/1` - Cluster info permissions
  - `nodes/1` - Node info permissions (minimal/verbose)
  - `backups/1` - Backup management permissions
  - `replicate/2` - Replication permissions
  - `alias_permission/2` - Collection alias permissions

#### User Management
- **User Structs** (`WeaviateEx.Users.User`):
  - `User.DB` - Database-managed users with API key
  - `User.OIDC` - OIDC-managed users with groups
  - `User.Own` - Current authenticated user info
- **Users API** (`WeaviateEx.API.Users`) - User lifecycle management:
  - `create/2` - Create DB user (returns API key)
  - `get/2` - Get user by ID
  - `list_all/1` - List all users
  - `delete/2` - Delete user
  - `activate/2` - Activate user
  - `deactivate/2` - Deactivate user
  - `rotate_key/2` - Rotate API key
  - `assign_roles/3` - Assign roles to user
  - `revoke_roles/3` - Revoke roles from user
  - `get_assigned_roles/2` - Get user's roles
  - `get_my_user/1` - Get current user info

#### Group Management
- **Group Struct** (`WeaviateEx.Groups.Group`) - OIDC group representation
- **Groups API** (`WeaviateEx.API.Groups`) - OIDC group operations:
  - `list_known/1` - List known OIDC groups
  - `get_assigned_roles/2` - Get roles assigned to group
  - `assign_roles/3` - Assign roles to group
  - `revoke_roles/3` - Revoke roles from group

#### Error Types
- **Cluster Errors** (`WeaviateEx.Error`):
  - `node_not_found/1` - Node not found in cluster
  - `shard_not_found/2` - Shard not found in collection
  - `replication_failed/2` - Replication operation failed
  - `replication_timeout/1` - Replication timed out
  - `cluster_not_ready/0` - Cluster not ready
  - `vector_indexing_timeout/1` - Vector indexing timed out
- **RBAC-specific Errors** (`WeaviateEx.Error`):
  - `rbac_error/3` - Create RBAC error with category
  - `role_not_found/1` - Role not found error
  - `permission_denied/2` - Permission denied error
  - `user_not_found/1` - User not found error
  - `invalid_permission/1` - Invalid permission error

#### Main Module Delegations
- Cluster convenience functions: `cluster_nodes/2`, `cluster_shards/2`, `cluster_statistics/1`
- Replication functions: `replicate_shard/4`, `list_replications/2`, `get_replication/3`
- Replication control: `cancel_replication/2`, `delete_replication/2`, `wait_for_replications/2`
- `list_roles/1`, `get_role/2`, `create_role/3`, `delete_role/2`
- `create_user/2`, `get_user/2`, `list_users/1`, `delete_user/2`, `get_my_user/1`
- `list_groups/1`, `assign_group_roles/3`, `revoke_group_roles/3`

#### gRPC Protocol Support
- **gRPC Channel Management** (`WeaviateEx.GRPC.Channel`) - Persistent connection management:
  - `connect/3` - Establish gRPC channel with TLS support
  - `disconnect/1` - Clean channel shutdown
  - `build_metadata/1` - Auth metadata for gRPC calls
  - Automatic reconnection handling
- **gRPC Services** - High-performance data operations:
  - `WeaviateEx.GRPC.Services.Search` - Vector similarity search (near_vector, near_text, near_object, bm25, hybrid)
  - `WeaviateEx.GRPC.Services.Batch` - Batch insert, delete, and reference operations
  - `WeaviateEx.GRPC.Services.Aggregate` - Count and group_by aggregations
  - `WeaviateEx.GRPC.Services.Tenants` - Multi-tenancy operations
  - `WeaviateEx.GRPC.Services.Health` - gRPC health checks
- **Protocol Buffer Definitions** - Generated from Weaviate v1 protos:
  - 11 proto files in `priv/protos/v1/`
  - Generated Elixir modules in `lib/weaviate_ex/grpc/generated/v1/`
- **gRPC Error Handling** (`WeaviateEx.Error`):
  - `from_grpc_status/3` - Map gRPC status codes to error types
  - `from_grpc_error/1` - Convert gRPC errors to WeaviateEx.Error
  - `grpc_retryable?/1` - Identify retryable gRPC errors
- **gRPC Retry Logic** (`WeaviateEx.Retry`):
  - Retry on UNAVAILABLE, RESOURCE_EXHAUSTED, ABORTED status codes
  - Exponential backoff with jitter
- **Client Configuration** (`WeaviateEx.Client.Config`):
  - `grpc_host` - gRPC endpoint hostname
  - `grpc_port` - gRPC port (default: 50051)
  - `grpc_max_message_size` - Maximum message size for gRPC calls
  - `use_tls?/1` - TLS detection for gRPC connections

### Changed
- Updated documentation with new module groups
- Improved test coverage for all new features
- **Hybrid Architecture**: gRPC for data operations (queries, batch, aggregations), HTTP retained for schema operations (Weaviate gRPC API doesn't support schema management)
- **Client Connection** (`WeaviateEx.Client`):
  - `connect/1` now establishes both HTTP (Finch) and gRPC channels
  - New `grpc_channel` field in client struct
  - Automatic gRPC fallback to HTTP when channel unavailable
- **Query Execution** (`WeaviateEx.Query`):
  - `execute/2` with client uses gRPC when available
  - `execute/1` without client uses HTTP (backwards compatible)
- **Batch Operations** (`WeaviateEx.API.Batch`):
  - `create_objects/3` uses gRPC when client has gRPC channel
  - `delete_objects/2` uses gRPC for batch deletes
- **Aggregations** (`WeaviateEx.API.Aggregate`):
  - Simple count/group_by use gRPC
  - Complex aggregations (multiple properties) use GraphQL
- **Tenants** (`WeaviateEx.API.Tenants`):
  - `list/2`, `get/3`, `exists?/3` use gRPC
  - Create/update/delete remain HTTP (not in gRPC API)

### Dependencies
- Added `{:grpc, "~> 0.9"}` - Elixir gRPC client
- Added `{:protobuf, "~> 0.13"}` - Protocol Buffer support
- Retained `{:finch, "~> 0.18"}` - For schema operations and HTTP fallback

### Stats
- Full gRPC support for data operations
- Complete Backup & Restore support with 4 storage backends
- Complete RBAC support matching Python client functionality
- Complete Cluster management with replication support
- Backwards compatible - existing code continues to work

## [0.3.0] - 2025-12-28

### Added

#### Query Enhancements
- **Move Configuration** (`WeaviateEx.Query.Move`) - Move to/away from concepts in near_text queries
- **Rerank Configuration** (`WeaviateEx.Query.Rerank`) - Reranking for search results
- **Target Vectors** (`WeaviateEx.Query.TargetVectors`) - Named vector targeting with combination strategies (sum, average, minimum, manual weights, relative score)
- **BM25 Operator** (`WeaviateEx.Query.BM25Operator`) - AND/OR operators with minimum_should_match
- **Hybrid Vector** (`WeaviateEx.Query.HybridVector`) - Vector sub-search for hybrid queries
- **GroupBy** (`WeaviateEx.Query.GroupBy`) - Result grouping configuration
- **Metadata Helpers** (`WeaviateEx.Query.Metadata`) - Metadata field selection utilities
- **Query Reference** (`WeaviateEx.Query.QueryReference`) - Cross-reference query configuration

#### Reference Operations
- **References API** (`WeaviateEx.API.References`) - Full cross-reference CRUD:
  - `add/6` - Add single reference
  - `delete/6` - Delete reference
  - `replace/6` - Replace all references on a property
  - `add_many/4` - Batch add references
- **ReferenceToMulti** (`WeaviateEx.Data.ReferenceToMulti`) - Multi-target reference type with `to_beacons/1`

#### Generative AI Enhancements
- **Typed Provider Configs** (`WeaviateEx.Generative.Config`) - Full configuration structs for 14 providers:
  - OpenAI, Azure OpenAI, Anthropic, Cohere
  - AWS Bedrock/SageMaker, Google Vertex/Gemini
  - Mistral, Ollama, XAI, ContextualAI, Anyscale
  - **NEW**: NVIDIA NIM, Databricks, FriendliAI
- **Generative Results** (`WeaviateEx.Generative.Result`) - Typed result structures:
  - `Single` - Single prompt result with metadata and debug
  - `Grouped` - Grouped task result
  - `GenerativeObject` - Object with generative result
  - `ResponseParser` - Parse API responses to typed structs
- **Generative Parameters** (`WeaviateEx.Generative.Parameters`) - Multimodal support:
  - `SinglePrompt` / `GroupedTask` with image support
  - `image_properties`, `non_blob_properties` options
  - `metadata` and `debug` options
- **20+ AI Providers** - Added nvidia, databricks, friendliai to supported providers

#### Batch Operations
- **Error Tracking** (`WeaviateEx.Batch.ErrorTracking`) - Detailed error tracking:
  - `ErrorObject` - Failed object details with retry count
  - `ErrorReference` - Failed reference details
  - `Results` - Aggregated results with helpers
- **Batch Retry** (`WeaviateEx.Batch.BatchRetry`) - Smart retry logic:
  - Rate limit detection
  - Exponential backoff calculation
  - `with_retry/2` wrapper function
- **Fixed Size Batcher** (`WeaviateEx.Batch.FixedSize`) - Fixed-size batch processor

#### Tenant Extensions
- `freeze/3` - Set tenant to FROZEN state
- `offload/3` - Set tenant to OFFLOADED state

#### Multi-Vector Support
- **Multi-Vector API** (`WeaviateEx.API.MultiVector`) - ColBERT-style embeddings:
  - `muvera_encoding/1` - Muvera encoding configuration
  - `multi_vector_config/1` - Multi-vector index configuration
  - `self_provided/1` - Self-provided multi-vectors
  - `text2colbert_jinaai/1` - Jina ColBERT vectorizer
  - `multi2multivec_jinaai/1` - Jina multi-modal vectorizer

#### Vectorizers
- **New Vectorizers** (Dec 2025 Python client sync):
  - `text2vec_voyageai/1` - VoyageAI (voyage-3.5, voyage-3-large, voyage-context-3)
  - `text2vec_morph/1` - Morph embeddings
  - `text2vec_model2vec/1` - Model2Vec embeddings
  - `text2vec_aws_bedrock/1` - AWS Bedrock embeddings
  - `text2vec_aws_sagemaker/1` - AWS SageMaker endpoints
  - `text2vec_google_vertex/1` - Google Vertex AI
  - `text2vec_google_gemini/1` - Google AI Studio (Gemini)
  - `reranker_cohere/1` - Cohere reranker with baseURL

#### Other
- **Object TTL Configuration** (`WeaviateEx.Config.ObjectTTL`)
- **OpenAI O1/O3 Support**: `verbosity` and `reasoning_effort` parameters
- **Cohere Enhancements**: `dimensions` parameter for embeddings
- **CI Infrastructure**: Full GitHub Actions workflow

### Changed
- Updated Docker Compose to Weaviate 1.28.14
- Copied full CI infrastructure from Python client (`ci/` directory)
- Added default version to CI start/stop scripts

### Stats
- **694 tests passing** (up from 536)
- Full Python client feature parity for core operations

## [0.2.0] - 2025-10-19

### Added
- **Embedded Mode**: Download and manage Weaviate embedded binary lifecycle with `WeaviateEx.start_embedded/1` and `WeaviateEx.stop_embedded/1`
- **Comprehensive Docker Environment**: Full Docker Compose profiles from Python client (single node, modules, RBAC, async, cluster, proxy, backup, WCS, Okta)
- **Mix Tasks for Docker Management**:
  - `mix weaviate.start` - Start Weaviate stack with version and profile selection
  - `mix weaviate.stop` - Stop running containers with optional volume removal
  - `mix weaviate.status` - Display container status and exposed ports
  - `mix weaviate.logs` - View and follow logs from specific compose files
- **Batch API Enhancements**: Comprehensive batch operations with detailed summaries, error tracking, and statistics
- **Enhanced Examples**: Added `07_batch.exs` and `08_query.exs` with comprehensive batch and query demonstrations
- **Objects API Payload Builder**: Type-safe payload construction in `WeaviateEx.Objects.Payload`
- **Collections API Extensions**: Multi-tenancy support with `set_multi_tenancy/2`, improved tenant management
- **Development Scripts**: `scripts/weaviate-stack.sh` wrapper for unified stack management
- **CI/Weaviate Infrastructure**: Complete Docker Compose setup under `ci/weaviate/` with helper scripts
- **Documentation**: Extensive planning docs in `docs/20251019/` covering essential scope, schema, queries, operations

### Changed
- **Examples Overhaul**: All 8 examples updated with improved error handling, cleaner output, and better demonstrations
- **README Improvements**: Expanded documentation with embedded mode, Mix tasks, Docker management, and comprehensive usage guides
- **Mix Tasks Refactored**: Cleaner implementation using WeaviateEx.DevSupport.Compose module for shared logic
- **Test Coverage**: Added tests for batch operations, collections API, and data operations

### Fixed
- Example helper module visibility and formatting
- Collections API tenant operations
- Batch summary statistics and error reporting

## [0.1.1] - 2025-10-16

### Changed
- Refactored HTTP client implementation into Protocol.HTTP.Client for better protocol-based architecture
- Removed old HTTPClient and HTTPClient.Finch modules in favor of protocol-based implementation
- Updated all examples to use cleaner ExampleHelper patterns with proper module qualification
- Enhanced example output formatting and error handling
- Fixed docker-compose port mapping (40051:50051 for gRPC)
- Improved test cleanup and formatting across all test files

### Added
- Added vector support to data examples
- Enhanced Protocol.HTTP.Client with comprehensive error handling
- Added better response parsing and authentication header support

### Fixed
- Fixed example helper function visibility (made ANSI color helpers public)
- Fixed client initialization to properly use protocol implementation
- Improved error messages and debugging output

## [0.1.0] - 2025-10-16

### Added
- Initial release
