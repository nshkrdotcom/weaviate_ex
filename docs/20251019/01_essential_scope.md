# WeaviateEx Essential Feature Set – Scope Blueprint

**Date:** 2025‑10‑19  
**Authors:** Platform DX  
**Audience:** Elixir maintainers, product, solution architects  
**Status:** Draft for sign‑off

---

## 1. Purpose

The parity wish list for the Python client exceeds 500 endpoints and config flags. This blueprint narrows WeaviateEx v2.0 to the core features that 90% of customer workloads rely on: define schema, ingest objects, search with filters/vectors, and surface rollups. Everything else becomes modular extensions or future phases.

---

## 2. Essential Pillars

| Pillar | Goal | Included Capabilities | Deferred / Out of Scope |
| --- | --- | --- | --- |
| **Connection & Auth** | Reliable HTTP access with minimal setup. | HTTP transport, API key header, health check, configurable timeouts/retries. | OAuth/OIDC, proxy support, gRPC, embedded mode, custom header builder. |
| **Schema Lifecycle** | Create/update/delete classes quickly. | CRUD on collections, property add, vector & inverted index minimal config, multi-tenancy flag, shard/tenant inspection. | Config builders for every index knob, vectorizer catalog, generative module injection, replication tuning UI. |
| **Data Ingestion** | Insert/update/delete objects safely. | Single-object insert/update/patch/delete, tenant + consistency options, validation, heads-up existence check, lightweight batch create/delete with error summary. | Auto-flush batching, gRPC streaming, per-object retry policies, reference mutation utilities, advanced batch stats. |
| **Query & Aggregation** | Fetch results across keyword/vector search. | GraphQL Get builder with filters, near_text/vector/object, BM25, hybrid, pagination/modifiers, `_additional` metadata, rollup aggregations (over_all, where, near_text/vector, group_by). | near_image/media, multi-vector targeting, cursor pagination (`after`), GraphQL explain fields, generative responses, cross-collection joins. |
| **DX Quality** | Make the "happy path" obvious and testable. | Consistent error struct, docs, examples, integration tests with live Weaviate, raw request escape hatch. | ORM wrapper, async client, macros for DSL, CLI tooling, full admin APIs. |

---

## 3. Release Structure

- **v2.0 Essential (Q4 2025):** Delivers all pillars above with documented module boundaries and test suites.  
- **v2.1 Extensibility (Q1 2026):** Evaluate add-ons requested by design partners (references API, richer batch).  
- **v2.x Advanced (later):** Authentication expansion, gRPC, admin namespaces, RAG providers.

---

## 4. KPIs for Sign-Off

1. **Scenario Coverage:** Can define schema, load 100k objects, run production searches, and fetch aggregations without hitting raw HTTP.  
2. **DX Feedback:** 3 internal adopters confirm API clarity versus Python client sprawl.  
3. **Quality Bar:** ≥95% unit/integration coverage on essential modules; soak test stable for 24h ingest/search loop.  
4. **Documentation:** Quick start + pillar guides stored in `docs/20251019` plus inline moduledocs.  
5. **Sustainability:** Non-essential endpoints exposed via explicit escape hatch (e.g., `WeaviateEx.Raw.request/5`) so power users are not blocked.

---

## 5. Dependencies & Risks

- **Upstream Compatibility:** Targets Weaviate v1.23.6+ REST API; features behind experimental server flags stay deferred.  
- **Team Alignment:** Requires agreement from product and customer success to postpone enterprise tooling (RBAC/backup).  
- **Test Infrastructure:** Live Weaviate environment must be part of CI to validate ingestion/query loops.  
- **Docs Maintenance:** Essential scope docs need quarterly review to avoid slow creep toward full parity.

---

## 6. Next Actions

1. Ratify this scope with stakeholders (product, solutions, support).  
2. Use pillar docs (`02_`, `03_`, `04_`) to plan implementation sprints.  
3. Update roadmap to replace “500 feature parity” with essential milestone KPIs.  
4. Publish summary to engineering blog/internal memo for awareness.

