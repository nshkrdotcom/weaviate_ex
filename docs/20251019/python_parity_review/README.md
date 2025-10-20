# Weaviate Python Parity Review – 2025-10-19

This document set captures the current state of the Elixir `weaviate_ex` client versus the reference Python client (`weaviate-python-client` v4). It combines source-level analysis with a roadmap for closing the outstanding feature gaps.

## Document Map

- [`implemented_features.md`](./implemented_features.md) — What the Elixir client already supports, mapped to the Python surface area.
- [`gaps_and_differences.md`](./gaps_and_differences.md) — Missing or partial implementations, organized by subsystem.
- [`roadmap.md`](./roadmap.md) — Suggested execution plan, milestones, and risk notes for achieving parity.
- [`appendix_source_refs.md`](./appendix_source_refs.md) — Direct pointers into the relevant source files in both repositories.

## Highlights

- Collections, object CRUD, batch basics, GraphQL query builders, generative APIs, and tenant management are all live in Elixir (see `lib/weaviate_ex/collections.ex`, `lib/weaviate_ex/api/data.ex`, `lib/weaviate_ex/batch.ex`, `lib/weaviate_ex/query.ex`, `lib/weaviate_ex/api/generative.ex`, `lib/weaviate_ex/api/tenants.ex`).
- The largest remaining gaps are around connection helpers, authentication breadth, gRPC support, batching ergonomics, RBAC, and auxiliary namespaces such as backup/cluster/debug.
- A multi-phase roadmap is proposed to layer gRPC transport, broaden auth and configuration, and add the missing namespaces while keeping backward compatibility.

Refer to the individual documents for full details and file-by-file references.
