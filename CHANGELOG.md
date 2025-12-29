# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Object TTL Configuration** (`WeaviateEx.Config.ObjectTTL`)
  - `delete_by_update_time/2` - Expire objects by last update time
  - `delete_by_creation_time/2` - Expire objects by creation time
  - `delete_by_date_property/3` - Expire objects by custom date property
  - `disable/0` - Disable TTL
- **New Generative Providers**:
  - ContextualAI with `system_prompt`, `avoid_commentary`, `max_new_tokens`
  - XAI (Grok) with `top_p` support
  - Google Vertex AI and Google Gemini
  - AWS SageMaker
- **AWS Service-Specific Vectorizers**:
  - `text2vec_aws_bedrock/1` - AWS Bedrock embeddings
  - `text2vec_aws_sagemaker/1` - AWS SageMaker endpoints
- **Google Service-Specific Vectorizers**:
  - `text2vec_google_vertex/1` - Google Vertex AI
  - `text2vec_google_gemini/1` - Google AI Studio (Gemini)
- **New Vectorizers** (Dec 2025 Python client sync):
  - `text2vec_voyageai/1` - VoyageAI (voyage-3.5, voyage-3-large, voyage-context-3)
  - `text2vec_morph/1` - Morph embeddings
  - `text2vec_model2vec/1` - Model2Vec embeddings
  - `text2colbert_jinaai/1` - ColBERT multi-vector
  - `multi2multivec_jinaai/1` - Jina multi-modal
  - `reranker_cohere/1` - Cohere reranker with baseURL
- **OpenAI O1/O3 Support**: `verbosity` and `reasoning_effort` parameters
- **Cohere Enhancements**: `dimensions` parameter for embeddings
- **CI Infrastructure**: Full GitHub Actions workflow (lint, dialyzer, unit tests, integration tests, publishing)
- **Documentation**: CONTRIBUTING.md, RELEASING.md, updated CHANGELOG.md

### Changed
- Updated Docker Compose to Weaviate 1.28.14
- Copied full CI infrastructure from Python client (`ci/` directory)
- Added default version to CI start/stop scripts
- Removed obsolete `version:` from Docker Compose files

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
