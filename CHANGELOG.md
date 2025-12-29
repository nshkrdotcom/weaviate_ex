# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2025-12-28

### Added

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

#### Error Handling
- **RBAC-specific Errors** (`WeaviateEx.Error`):
  - `rbac_error/3` - Create RBAC error with category
  - `role_not_found/1` - Role not found error
  - `permission_denied/2` - Permission denied error
  - `user_not_found/1` - User not found error
  - `invalid_permission/1` - Invalid permission error

#### Main Module Convenience Functions
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
- **195+ new tests** for RBAC, Users, and Groups modules
- **881 tests passing** (up from 694)
- Full gRPC support for data operations
- Complete RBAC support matching Python client functionality
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
