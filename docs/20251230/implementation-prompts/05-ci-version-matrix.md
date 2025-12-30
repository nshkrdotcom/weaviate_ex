# Prompt - CI Version Matrix Expansion + Codecov

## Objective

Expand CI version matrix from 4 to 9 Weaviate versions and integrate Codecov for code coverage reporting. This ensures compatibility across the full range of supported Weaviate versions.

## Priority

P1 - High (Quality assurance)

## Required Reading (Docs)

- `docs/20251230/integration-test-gaps/02-version-matrix-gap.md`
- `docs/20251230/integration-test-gaps/03-tooling-gaps.md`
- `.github/workflows/ci.yml` - Current CI configuration
- `README.md`
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `mix.exs` - Project configuration
- `test/test_helper.exs` - Test configuration
- `ci/start_weaviate.sh` - Docker script (default version)

## Required Reading (Python Reference)

- `../weaviate-python-client/.github/workflows/main.yaml` - Python CI with 9 versions

## Context

### Current State
- CI tests against 4 Weaviate versions: 1.27.27, 1.28.14, 1.29.11, 1.30.22
- Python tests against 9 versions: 1.27.27 through 1.35.0
- No code coverage integration (Codecov)
- Local coverage via `mix test --cover`

### Gap
- Missing versions 1.31.x through 1.35.x in CI
- No Codecov badge or coverage reporting
- Default local test version is 1.28.14 (outdated)

## Implementation Instructions

### Step 1: Update CI Workflow Version Matrix

Update `.github/workflows/ci.yml`:

```yaml
env:
  MIX_ENV: test
  ELIXIR_VERSION: "1.18.4"
  OTP_VERSION: "28"
  # Weaviate version constants (match Python)
  WEAVIATE_127: "1.27.27"
  WEAVIATE_128: "1.28.14"
  WEAVIATE_129: "1.29.11"
  WEAVIATE_130: "1.30.22"
  WEAVIATE_131: "1.31.4"
  WEAVIATE_132: "1.32.4"
  WEAVIATE_133: "1.33.2"
  WEAVIATE_134: "1.34.1"
  WEAVIATE_135: "1.35.0"

# Update integration-matrix job:
integration-matrix:
  name: Integration (Weaviate ${{ matrix.weaviate-version }})
  runs-on: ubuntu-latest
  needs: unit-tests
  if: github.ref == 'refs/heads/master' || startsWith(github.ref, 'refs/tags/')

  strategy:
    fail-fast: false
    matrix:
      weaviate-version:
        - "1.27.27"
        - "1.28.14"
        - "1.29.11"
        - "1.30.22"
        - "1.31.4"
        - "1.32.4"
        - "1.33.2"
        - "1.34.1"
        - "1.35.0"
```

### Step 2: Add Code Coverage to Unit Tests Job

Update `.github/workflows/ci.yml` unit-tests job:

```yaml
unit-tests:
  name: Unit Tests
  runs-on: ubuntu-latest

  steps:
    # ... existing steps ...

    - name: Run tests with coverage
      run: mix test --cover --export-coverage default
      env:
        MIX_ENV: test

    - name: Create coverage report
      run: mix test.coverage

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v4
      with:
        token: ${{ secrets.CODECOV_TOKEN }}
        files: cover/excoveralls.json
        fail_ci_if_error: false
        verbose: true
```

### Step 3: Add excoveralls Dependency

Update `mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps
    {:excoveralls, "~> 0.18", only: :test}
  ]
end

def project do
  [
    # ... existing config
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      "coveralls.github": :test
    ]
  ]
end
```

### Step 4: Create Codecov Configuration

Create `codecov.yml`:

```yaml
codecov:
  require_ci_to_pass: yes

coverage:
  precision: 2
  round: down
  range: "70...100"

  status:
    project:
      default:
        target: 80%
        threshold: 2%
    patch:
      default:
        target: 80%

ignore:
  - "lib/weaviate_ex/grpc/generated/**/*"
  - "lib/weaviate_ex/proto/**/*"
  - "test/**/*"
  - "bench/**/*"

comment:
  layout: "reach,diff,flags,tree,betaprofiling"
  behavior: default
  require_changes: true
```

### Step 5: Create coveralls.json

Create `coveralls.json`:

```json
{
  "coverage_options": {
    "treat_no_relevant_lines_as_covered": true,
    "minimum_coverage": 80
  },
  "skip_files": [
    "lib/weaviate_ex/grpc/generated/",
    "lib/weaviate_ex/proto/",
    "test/"
  ]
}
```

### Step 6: Update Default Weaviate Version

Update `ci/start_weaviate.sh`:

```bash
#!/bin/bash
# Change default from 1.28.14 to latest
WEAVIATE_VERSION="${1:-1.35.0}"
```

### Step 7: Add Coverage Badge to README

Update `README.md` (near top):

```markdown
[![Coverage](https://codecov.io/gh/YOUR_ORG/weaviate_ex/branch/master/graph/badge.svg)](https://codecov.io/gh/YOUR_ORG/weaviate_ex)
```

### Step 8: Add Supported Versions Table to README

Add to README.md:

```markdown
## Supported Weaviate Versions

| Weaviate Version | Status | Notes |
|------------------|--------|-------|
| 1.35.x | Fully Supported | Latest |
| 1.34.x | Fully Supported | gRPC streaming |
| 1.33.x | Fully Supported | |
| 1.32.x | Fully Supported | |
| 1.31.x | Fully Supported | |
| 1.30.x | Fully Supported | |
| 1.29.x | Fully Supported | |
| 1.28.x | Fully Supported | |
| 1.27.x | Fully Supported | Minimum |
| < 1.27 | Not Tested | |

Testing is performed against all supported versions in CI.
```

## Tests to Verify

No new tests required, but verify:

1. All existing tests pass with excoveralls
2. Coverage report generates correctly
3. CI workflow syntax is valid

```bash
# Verify locally
mix deps.get
mix test --cover
mix coveralls.html
open cover/excoveralls.html
```

## Docs Updates

### README.md

1. Add Codecov badge
2. Add supported versions table
3. Update testing section to mention coverage

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- CI testing against Weaviate versions 1.31.x through 1.35.x (9 total versions)
- Code coverage reporting via Codecov
- Coverage badge in README
- Supported Weaviate versions table in README

### Changed
- Default local test Weaviate version updated to 1.35.0
- Unit tests now generate coverage reports
```

## Quality Gates

- [ ] CI workflow syntax valid: `act -n` or GitHub Actions linter
- [ ] All existing tests pass: `mix test`
- [ ] Coverage report generates: `mix test --cover`
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] README updated with badge and versions table
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. CI matrix tests 9 Weaviate versions (1.27-1.35)
2. Codecov integration configured
3. Coverage badge in README
4. Supported versions table in README
5. Default local test version is 1.35.0
6. All CI jobs pass
