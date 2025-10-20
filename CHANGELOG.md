# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- **Mix Tasks Refactored**: Cleaner implementation using `WeaviateEx.DevSupport.Compose` module for shared logic
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
