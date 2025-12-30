# Gap Analysis: CI Version Matrix

**Priority**: P1 - Important
**Effort**: Low
**Status**: Partial Implementation

---

## Current State

### Python Client Version Matrix

The canonical Python client tests against **9 Weaviate versions**:

```yaml
# From weaviate-python-client/.github/workflows/main.yaml
env:
  WEAVIATE_127: "1.27.27"
  WEAVIATE_128: "1.28.14"
  WEAVIATE_129: "1.29.11"
  WEAVIATE_130: "1.30.22"
  WEAVIATE_131: "1.31.4"
  WEAVIATE_132: "1.32.4"
  WEAVIATE_133: "1.33.2"
  WEAVIATE_134: "1.34.1"
  WEAVIATE_135: "1.35.0"
```

### Elixir Client Version Matrix

The `weaviate_ex` client currently tests against **4 Weaviate versions**:

```yaml
# From .github/workflows/ci.yml
matrix:
  weaviate-version:
    - "1.27.27"
    - "1.28.14"
    - "1.29.11"
    - "1.30.22"
```

---

## Gap Analysis

| Version | Python | Elixir | Status |
|---------|--------|--------|--------|
| 1.27.27 | Yes | Yes | Covered |
| 1.28.14 | Yes | Yes | Covered |
| 1.29.11 | Yes | Yes | Covered |
| 1.30.22 | Yes | Yes | Covered |
| 1.31.x | Yes | **No** | **Gap** |
| 1.32.x | Yes | **No** | **Gap** |
| 1.33.x | Yes | **No** | **Gap** |
| 1.34.x | Yes | **No** | **Gap** |
| 1.35.x | Yes | **No** | **Gap** |

**Coverage**: 4/9 versions = **44%**

---

## Why This Matters

### Breaking Changes Detection

Newer Weaviate versions may introduce:

1. **API Changes**: New endpoints, deprecated features, modified responses
2. **gRPC Schema Updates**: Protocol buffer changes requiring regeneration
3. **Behavioral Changes**: Different default values, validation rules
4. **New Features**: Features that should be exposed in the client

### Specific Version Concerns

| Version | Notable Changes |
|---------|-----------------|
| 1.31.x | Async indexing improvements |
| 1.32.x | Multi-tenancy enhancements |
| 1.33.x | Vector quantization updates |
| 1.34.x | HNSW index improvements |
| 1.35.x | Latest stable release |

---

## Recommended Changes

### Option 1: Match Python Matrix (Recommended)

Update `.github/workflows/ci.yml`:

```yaml
env:
  MIX_ENV: test
  ELIXIR_VERSION: "1.18.4"
  OTP_VERSION: "28"
  # Add version constants like Python
  WEAVIATE_127: "1.27.27"
  WEAVIATE_128: "1.28.14"
  WEAVIATE_129: "1.29.11"
  WEAVIATE_130: "1.30.22"
  WEAVIATE_131: "1.31.4"
  WEAVIATE_132: "1.32.4"
  WEAVIATE_133: "1.33.2"
  WEAVIATE_134: "1.34.1"
  WEAVIATE_135: "1.35.0"

# ...

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

### Option 2: Test Latest + LTS Only (Resource-Conscious)

If CI time/resources are a concern, test a subset:

```yaml
matrix:
  weaviate-version:
    - "1.27.27"  # Oldest supported
    - "1.30.22"  # Mid-range stable
    - "1.35.0"   # Latest
```

### Option 3: Nightly Extended Matrix

Run full matrix only on nightly builds:

```yaml
# Main CI - runs on every push/PR
integration-tests:
  # Test against single stable version
  services:
    weaviate:
      image: cr.weaviate.io/semitechnologies/weaviate:1.30.22

# Nightly CI - runs on schedule
integration-matrix-nightly:
  if: github.event_name == 'schedule'
  strategy:
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

Add schedule trigger:

```yaml
on:
  push:
    branches: [master]
    tags: ["v*"]
  pull_request:
    branches: [master]
  schedule:
    - cron: '0 2 * * *'  # Run at 2 AM UTC daily
```

---

## Implementation Steps

### Step 1: Update Version Matrix

```diff
# .github/workflows/ci.yml

  strategy:
    fail-fast: false
    matrix:
      weaviate-version:
        - "1.27.27"
        - "1.28.14"
        - "1.29.11"
        - "1.30.22"
+       - "1.31.4"
+       - "1.32.4"
+       - "1.33.2"
+       - "1.34.1"
+       - "1.35.0"
```

### Step 2: Update Local Test Scripts

Update `ci/start_weaviate.sh` default version:

```bash
# Change default from 1.28.14 to latest
WEAVIATE_VERSION="${1:-1.35.0}"
```

### Step 3: Update README

Document supported versions in README.md:

```markdown
## Supported Weaviate Versions

| Weaviate Version | Status |
|------------------|--------|
| 1.35.x | Fully Supported |
| 1.34.x | Fully Supported |
| 1.33.x | Fully Supported |
| 1.32.x | Fully Supported |
| 1.31.x | Fully Supported |
| 1.30.x | Fully Supported |
| 1.29.x | Fully Supported |
| 1.28.x | Fully Supported |
| 1.27.x | Fully Supported |
| < 1.27 | Not Tested |
```

### Step 4: Add Version Compatibility Tests (Optional)

Create version-specific test tags for features only available in certain versions:

```elixir
# test/integration/new_feature_test.exs
@moduletag :integration
@moduletag min_version: "1.32.0"

test "new feature from 1.32" do
  # This test only runs on Weaviate >= 1.32
end
```

Add to test helper:

```elixir
# test/test_helper.exs
defmodule WeaviateEx.VersionFilter do
  def filter_by_version(tags) do
    case tags[:min_version] do
      nil -> true
      min_version ->
        current = get_weaviate_version()
        Version.compare(current, min_version) != :lt
    end
  end
end

ExUnit.configure(
  exclude: [:integration, :property, :performance],
  include: [],
  filter: &WeaviateEx.VersionFilter.filter_by_version/1
)
```

---

## CI Time Impact

| Configuration | Versions | Estimated CI Time |
|--------------|----------|-------------------|
| Current | 4 | ~8 minutes |
| Full Matrix | 9 | ~18 minutes |
| LTS + Latest | 3 | ~6 minutes |

The additional CI time is minimal and the coverage benefit is significant.

---

## Acceptance Criteria

1. [ ] CI tests against all 9 Weaviate versions (1.27-1.35)
2. [ ] Default local test version updated to latest (1.35.x)
3. [ ] README documents supported versions
4. [ ] All tests pass on all supported versions

---

## Effort Estimate

| Task | Effort |
|------|--------|
| Update CI workflow | 15 minutes |
| Update shell scripts | 5 minutes |
| Update README | 10 minutes |
| Verify all tests pass | 30 minutes |
| **Total** | **~1 hour** |

---

## References

- Python CI workflow: `weaviate-python-client/.github/workflows/main.yaml`
- Current Elixir CI: `.github/workflows/ci.yml`
- Weaviate releases: https://github.com/weaviate/weaviate/releases
