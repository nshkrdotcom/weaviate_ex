# Implementation Roadmap: Closing Integration Test Gaps

This document provides a prioritized roadmap for achieving full parity with the canonical Python client's integration testing infrastructure.

---

## Priority Legend

| Priority | Meaning | Action Timeline |
|----------|---------|-----------------|
| P0 | Critical for parity claim | Immediate |
| P1 | Important for quality | Next sprint |
| P2 | Nice to have | Backlog |
| P3 | Optional | As time permits |

---

## Phase 1: P0 - Critical Gaps

### 1.1 Journey Tests

**Status**: Not Started
**Effort**: 15 hours
**Document**: [01-journey-tests-gap.md](./01-journey-tests-gap.md)

#### Tasks

- [ ] Create `test/journey/` directory structure
- [ ] Implement shared journey scenarios module
- [ ] Create Phoenix integration test
- [ ] Create Plug integration test
- [ ] Add journey test tag and configuration
- [ ] Document in README.md

#### Deliverables

```
test/journey/
├── journeys.ex
├── phoenix_test.exs
└── plug_test.exs
```

#### Verification

```bash
WEAVIATE_INTEGRATION=true mix test --include journey
```

---

## Phase 2: P1 - Important Gaps

### 2.1 Version Matrix Expansion

**Status**: Not Started
**Effort**: 1 hour
**Document**: [02-version-matrix-gap.md](./02-version-matrix-gap.md)

#### Tasks

- [ ] Update `.github/workflows/ci.yml` matrix to include 1.31-1.35
- [ ] Update `ci/start_weaviate.sh` default version to 1.35.0
- [ ] Add version compatibility table to README.md

#### Deliverables

```yaml
# ci.yml matrix
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

#### Verification

All CI matrix jobs pass.

---

### 2.2 Code Coverage in CI

**Status**: Not Started
**Effort**: 2 hours
**Document**: [03-tooling-gaps.md](./03-tooling-gaps.md)

#### Tasks

- [ ] Add `excoveralls` dependency
- [ ] Configure `coveralls.json`
- [ ] Update CI workflow to upload coverage
- [ ] Add Codecov badge to README

#### Deliverables

- `mix.exs` with excoveralls
- `coveralls.json`
- `codecov.yml`
- Coverage badge in README

#### Verification

Coverage reports visible on Codecov.

---

## Phase 3: P2 - Nice to Have

### 3.1 Pre-commit Hooks

**Status**: Not Started
**Effort**: 1 hour
**Document**: [03-tooling-gaps.md](./03-tooling-gaps.md)

#### Tasks

- [ ] Create `.pre-commit-config.yaml`
- [ ] Document installation in CONTRIBUTING.md

#### Deliverables

- `.pre-commit-config.yaml`
- Updated CONTRIBUTING.md

---

### 3.2 Benchmark Suite

**Status**: Not Started
**Effort**: 4 hours
**Document**: [03-tooling-gaps.md](./03-tooling-gaps.md)

#### Tasks

- [ ] Add `benchee` dependency
- [ ] Create `bench/` directory with benchmarks
- [ ] Add `mix weaviate.bench` task

#### Deliverables

```
bench/
├── batch_bench.exs
├── query_bench.exs
└── connection_bench.exs
```

---

### 3.3 Profiling Documentation

**Status**: Not Started
**Effort**: 2 hours
**Document**: [03-tooling-gaps.md](./03-tooling-gaps.md)

#### Tasks

- [ ] Create `mix weaviate.profile` task
- [ ] Document profiling workflow in README

---

## Phase 4: P3 - Optional

### 4.1 gRPC Version Matrix

**Status**: Deprioritized
**Effort**: 4 hours

Test against multiple `grpc` and `protobuf` library versions. Lower priority for Elixir ecosystem.

---

## Timeline Overview

```
Phase 1 (P0): Journey Tests
├── Week 1: Core implementation
└── Week 2: Documentation and CI

Phase 2 (P1): Quality Improvements
├── Week 3: Version matrix + Coverage
└── Week 4: Verification and polish

Phase 3 (P2): Polish
├── Week 5+: Pre-commit, benchmarks, profiling
```

---

## Total Effort Summary

| Phase | Items | Total Effort |
|-------|-------|--------------|
| Phase 1 (P0) | Journey Tests | 15 hours |
| Phase 2 (P1) | Version Matrix + Coverage | 3 hours |
| Phase 3 (P2) | Pre-commit + Benchmarks + Profiling | 7 hours |
| Phase 4 (P3) | gRPC Matrix | 4 hours |
| **Total** | | **29 hours** |

---

## Success Criteria

### Full Parity Achieved When:

1. [ ] Journey tests exist and pass for Phoenix and Plug
2. [ ] CI tests against all 9 Weaviate versions (1.27-1.35)
3. [ ] Code coverage reports uploaded to Codecov
4. [ ] Pre-commit hooks configured
5. [ ] Benchmark suite available

### Minimum Viable Parity (P0 + P1):

1. [ ] Journey tests implemented
2. [ ] Version matrix expanded to 9 versions
3. [ ] Code coverage in CI

---

## Progress Tracking

Use this checklist to track implementation progress:

```markdown
## Implementation Progress

### P0 - Critical
- [ ] Journey tests (01-journey-tests-gap.md)
  - [ ] Directory structure created
  - [ ] Shared scenarios implemented
  - [ ] Phoenix test passing
  - [ ] Plug test passing
  - [ ] Documentation updated

### P1 - Important
- [ ] Version matrix (02-version-matrix-gap.md)
  - [ ] CI workflow updated
  - [ ] All versions passing
- [ ] Code coverage (03-tooling-gaps.md)
  - [ ] excoveralls integrated
  - [ ] Codecov configured
  - [ ] Badge in README

### P2 - Nice to Have
- [ ] Pre-commit hooks
- [ ] Benchmark suite
- [ ] Profiling tools

### P3 - Optional
- [ ] gRPC version matrix
```

---

## References

- [00-overview.md](./00-overview.md) - Executive summary
- [01-journey-tests-gap.md](./01-journey-tests-gap.md) - Journey tests details
- [02-version-matrix-gap.md](./02-version-matrix-gap.md) - Version matrix details
- [03-tooling-gaps.md](./03-tooling-gaps.md) - Tooling details
- [04-infrastructure-comparison.md](./04-infrastructure-comparison.md) - Infrastructure reference
- [05-quick-start-guide.md](./05-quick-start-guide.md) - Running tests guide
