# Agent Data - Objects, References, and Batch Gap Analysis

## Scope and sources
- Python: `weaviate-python-client/weaviate/collections/data/executor.py`, `weaviate-python-client/weaviate/collections/batch/grpc_batch.py`, `weaviate-python-client/weaviate/collections/queries/fetch_objects_by_ids`
- Elixir: `lib/weaviate_ex/api/data.ex`, `lib/weaviate_ex/objects/payload.ex`, `lib/weaviate_ex/api/references.ex`, `lib/weaviate_ex/batch.ex`, `lib/weaviate_ex/batch/stream.ex`, `lib/weaviate_ex/validation/property.ex`

## Parity highlights
- CRUD, references, and batch insert/delete exist in Elixir with named vector support (`lib/weaviate_ex/api/data.ex`, `lib/weaviate_ex/api/references.ex`, `lib/weaviate_ex/objects/payload.ex`).
- Batch modes (fixed, dynamic, rate-limited) and gRPC streaming are implemented (`lib/weaviate_ex/batch/*`).

## Gap findings
1. Missing fetch-by-IDs convenience for data retrieval.
   - Impact: users must build filters or multiple requests for ID lists; Python offers direct API.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/queries/fetch_objects_by_ids`.
   - Evidence (Elixir): no direct API in `lib/weaviate_ex/api/data.ex` or `lib/weaviate_ex/objects.ex`.

2. Minimal data input validation compared to Python.
   - Impact: invalid payloads are caught later by the server; Python validates reserved property names and types client-side.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/data/executor.py` uses `_validate_input` and enforces reserved names; typed `DataObject` inputs.
   - Evidence (Elixir): `lib/weaviate_ex/api/data.ex` and `lib/weaviate_ex/objects/payload.ex` accept maps with no reserved-name checks; validation modules only cover schema (`lib/weaviate_ex/validation/property.ex`).

3. Batch error handling semantics diverge from Python.
   - Impact: Python raises explicit errors when all objects fail; Elixir returns error tracking results without a matching exception, which can hide failures in pipelines.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/batch/grpc_batch.py` raises `WeaviateInsertManyAllFailedError` when all fail.
   - Evidence (Elixir): `lib/weaviate_ex/batch.ex` returns result structs/maps; no equivalent exception path is documented.

4. gRPC batch stream backoff signals are not applied.
   - Impact: server backoff is treated as success without throttling or buffer adjustment, risking rate-limit or resource contention.
   - Evidence (Python): gRPC batch stream protocol carries backoff information (see `weaviate-python-client/weaviate/collections/batch/grpc_batch.py`).
   - Evidence (Elixir): `lib/weaviate_ex/batch/stream.ex` parses `{:backoff, ...}` but does not adjust pacing or batch size.

## Suggested closure
- Add `fetch_objects_by_ids` in `WeaviateEx.API.Data` and a GraphQL-based fallback for HTTP-only environments.
- Introduce basic payload validation (reserved property names, required keys) in `WeaviateEx.Objects.Payload` and/or `WeaviateEx.API.Data` to mirror Python preflight checks.
- Define batch error contracts (success/partial/all-fail) and optionally raise on all-fail to match Python semantics.
- Apply server backoff signals in `WeaviateEx.Batch.Stream` by delaying sends or reducing buffer size dynamically.
