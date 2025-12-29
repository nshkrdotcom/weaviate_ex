# Contributing to weaviate_ex

Thank you for your interest in contributing to the Elixir client for Weaviate!

## Setup

### Prerequisites

- Elixir 1.16+
- Erlang/OTP 26+
- Docker (for integration tests)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/nshkrdotcom/weaviate_ex.git
   cd weaviate_ex
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Compile:
   ```bash
   mix compile
   ```

### Development Installation

To use a development version in your project, add as a path dependency:

```elixir
# mix.exs
defp deps do
  [
    {:weaviate_ex, path: "/path/to/weaviate_ex"}
  ]
end
```

## Testing

### Test Requirements

```bash
mix deps.get
```

### Types of Tests

1. **Unit Tests** - Test individual components with mocks
2. **Integration Tests** - Test against running Weaviate instance
3. **Property Tests** - Property-based testing (optional)

### Running Unit Tests

```bash
mix test
```

### Running Integration Tests

1. Start Weaviate:
   ```bash
   ./ci/start_weaviate.sh
   # Or for a specific version:
   ./ci/start_weaviate.sh 1.32.23
   ```

2. Run tests:
   ```bash
   WEAVIATE_INTEGRATION=true mix test
   ```

3. Stop Weaviate:
   ```bash
   ./ci/stop_weaviate.sh
   ```

### Running Specific Test Files

```bash
mix test test/weaviate_ex/collections_test.exs
mix test test/integration/
```

## Linting & Formatting

We use the following tools to ensure code quality:

### Format Check
```bash
mix format --check-formatted
```

### Auto-format
```bash
mix format
```

### Credo (Linting)
```bash
mix credo --strict
```

### Dialyzer (Type Checking)
```bash
mix dialyzer
```

**Note:** We strongly recommend running all checks before committing:
```bash
mix format && mix credo --strict && mix test
```

## Creating a Pull Request

1. The `master` branch is the main development branch
2. Create a feature branch: `feature/your-feature-name`
3. Make your changes with tests
4. Ensure all checks pass:
   ```bash
   mix format --check-formatted
   mix credo --strict
   mix test
   ```
5. Push and create a Pull Request to `master`
6. The `master` branch is protected and requires review

## Code Style

- Follow standard Elixir conventions
- Use `mix format` for consistent formatting
- Write documentation for public functions
- Add typespecs where appropriate
- Keep functions small and focused

## Commit Messages

Follow conventional commit format:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `test:` Adding tests
- `refactor:` Code refactoring
- `chore:` Maintenance tasks

Example:
```
feat: add Object TTL configuration module

- Add WeaviateEx.Config.ObjectTTL module
- Support delete_by_update_time, delete_by_creation_time
- Add comprehensive tests
```

## Documentation

- Document all public modules and functions
- Use `@moduledoc` and `@doc` attributes
- Include examples in documentation
- Run `mix docs` to verify documentation builds

## Contributor License Agreement

Contributions to weaviate_ex must be accompanied by agreement to the project's license terms. By submitting a pull request, you agree that your contributions will be licensed under the MIT License.
