# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
