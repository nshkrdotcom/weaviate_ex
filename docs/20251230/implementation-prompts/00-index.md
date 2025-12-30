# Implementation Prompts Index

**Date:** 2025-12-30
**Purpose:** Standalone prompts for achieving full Python client parity

Each prompt file is self-contained with all context needed for a fresh agent session.

---

## Execution Order

### P0 - Critical (Complete First)

| # | Prompt File | Description | Effort |
|---|------------|-------------|--------|
| 01 | [01-journey-tests.md](./01-journey-tests.md) | Phoenix/Plug integration tests | 4-6 hours |
| 02 | [02-http-retry-timeouts.md](./02-http-retry-timeouts.md) | HTTP transport retry + per-op timeouts | 3-4 hours |
| 03 | [03-batch-safety.md](./03-batch-safety.md) | MAX_STORED_RESULTS + auto re-queue | 2-3 hours |
| 04 | [04-property-serialization.md](./04-property-serialization.md) | Property value serialization fixes | 2-3 hours |

### P1 - High Priority (Feature Completeness)

| # | Prompt File | Description | Effort |
|---|------------|-------------|--------|
| 05 | [05-ci-version-matrix.md](./05-ci-version-matrix.md) | CI version expansion + Codecov | 1-2 hours |
| 06 | [06-grpc-generative.md](./06-grpc-generative.md) | gRPC generative search (RAG) | 4-6 hours |
| 07 | [07-object-ttl.md](./07-object-ttl.md) | Object TTL configuration | 2-3 hours |
| 08 | [08-multimodal-search.md](./08-multimodal-search.md) | near_image/audio/video high-level APIs | 3-4 hours |
| 09 | [09-fluent-tenant-api.md](./09-fluent-tenant-api.md) | Fluent with_tenant API | 3-4 hours |
| 10 | [10-aggregate-variants.md](./10-aggregate-variants.md) | Aggregate near_object/hybrid | 2-3 hours |
| 11 | [11-wcs-compatibility.md](./11-wcs-compatibility.md) | WCS headers + version checks | 2-3 hours |

### P2 - Medium Priority (Polish)

| # | Prompt File | Description | Effort |
|---|------------|-------------|--------|
| 12 | [12-testing-tooling.md](./12-testing-tooling.md) | Benchmarks, profiling, pre-commit | 3-4 hours |
| 13 | [13-grpc-rerank.md](./13-grpc-rerank.md) | gRPC rerank integration | 2-3 hours |
| 14 | [14-multi-target-refs.md](./14-multi-target-refs.md) | Multi-target references | 2-3 hours |
| 15 | [15-auto-tenant.md](./15-auto-tenant.md) | Auto-tenant creation/activation | 2-3 hours |

---

## How to Use These Prompts

1. Each prompt is designed to be run by a fresh Claude Code agent
2. Copy the entire prompt file content into a new conversation
3. The agent will read all required files, implement using TDD, and update docs
4. Each prompt appends to the existing CHANGELOG.md entry

---

## Total Estimated Effort

| Priority | Prompts | Hours |
|----------|---------|-------|
| P0 | 4 | 11-16 hours |
| P1 | 7 | 17-25 hours |
| P2 | 4 | 9-13 hours |
| **Total** | **15** | **37-54 hours** |

---

## Quality Gates (All Prompts)

Every prompt includes these quality requirements:
- TDD: Write tests first, then implement
- All tests passing: `mix test`
- No warnings: `mix compile --warnings-as-errors`
- No Credo issues: `mix credo --strict`
- No Dialyzer errors: `mix dialyzer`
- Docs updated: README.md, guides as needed
- CHANGELOG updated: Append to 0.7.3 entry
