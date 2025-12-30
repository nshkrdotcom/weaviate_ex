# Agent Query - Search and Generative Gap Analysis

## Scope and sources
- Python: `weaviate-python-client/weaviate/collections/queries/near_image/query/executor.py`, `weaviate-python-client/weaviate/collections/queries/fetch_objects_by_ids`, `weaviate-python-client/weaviate/collections/classes/generative.py`
- Elixir: `lib/weaviate_ex/query.ex`, `lib/weaviate_ex/query/near_image.ex`, `lib/weaviate_ex/query/near_media.ex`, `lib/weaviate_ex/query/group_by.ex`, `lib/weaviate_ex/grpc/services/search.ex`, `lib/weaviate_ex/api/generative.ex`, `lib/weaviate_ex/generative/config.ex`, `lib/weaviate_ex/generative/parameters.ex`

## Parity highlights
- GraphQL query builder covers near_text, near_vector, near_image, near_media, hybrid, BM25, rerank, and generative clauses (`lib/weaviate_ex/query.ex`).
- Generative parameters support multimodal image inputs and metadata flags (`lib/weaviate_ex/generative/parameters.ex`).

## Gap findings
1. gRPC query coverage is incomplete and silently drops advanced options.
   - Impact: when a gRPC channel is present, `WeaviateEx.Query.execute/3` selects gRPC, but gRPC requests do not include filters, target_vectors, or group_by, and do not implement near_image or near_media. This can lead to incorrect results without explicit errors.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/queries/near_image/query/executor.py` uses gRPC search with `target_vector`, filters, group_by, and references.
   - Evidence (Elixir): `lib/weaviate_ex/query.ex` chooses gRPC when a channel exists; `lib/weaviate_ex/grpc/services/search.ex` builds `SearchRequest` without filters, group_by, or target vectors, and only exposes near_text, near_vector, near_object, bm25, hybrid.

2. gRPC search cannot return references or vectors.
   - Impact: Python can return nested references and vectors from gRPC search; Elixir gRPC search only returns non-reference properties and metadata, forcing GraphQL for parity.
   - Evidence (Python): gRPC query APIs accept `return_references` and `include_vector` (see near_image executor overloads).
   - Evidence (Elixir): `lib/weaviate_ex/grpc/services/search.ex` `build_properties_request/1` only sets `non_ref_properties` and does not include references or vector fields.

3. Generative provider parameters are missing for some advanced options.
   - Impact: users cannot pass provider-specific parameters like `log_probs`, `top_log_probs`, or `n` for OpenAI/Databricks that are supported in the Python client.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/classes/generative.py` includes `log_probs`, `top_log_probs`, and `n` for Databricks and other providers.
   - Evidence (Elixir): `lib/weaviate_ex/generative/config.ex` Databricks config includes only `model`, `temperature`, `max_tokens`, `top_p`, `endpoint`.

4. gRPC generative execution is not implemented.
   - Impact: generative search uses GraphQL only; no gRPC execution path, so performance and feature parity with Python gRPC generate flows are lower.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/classes/generative.py` builds gRPC `GenerativeProvider` payloads used by gRPC search.
   - Evidence (Elixir): `lib/weaviate_ex/api/generative.ex` constructs GraphQL queries; no gRPC generative service is used.

5. Missing fetch-by-IDs query helper.
   - Impact: Python provides `fetch_objects_by_ids` and `generate.fetch_objects_by_ids`; Elixir lacks a direct equivalent and requires manual filters or multiple requests.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/queries/fetch_objects_by_ids`.
   - Evidence (Elixir): no dedicated module or function for ID lists in `lib/weaviate_ex/query.ex` or `lib/weaviate_ex/api/data.ex`.

## Suggested closure
- Gate gRPC usage in `WeaviateEx.Query.execute/3` based on feature support; fall back to GraphQL when filters, target vectors, group_by, or media search are used.
- Extend `WeaviateEx.GRPC.Services.Search` to include filters, target_vectors, and reference/vector return data; add near_image and near_media gRPC paths.
- Expand `WeaviateEx.Generative.Config` with missing provider fields (log_probs, top_log_probs, n, frequency_penalty variants) to match Python.
- Add a gRPC generative path or an explicit GraphQL-only marker in the API to avoid silent behavior differences.
- Implement `fetch_objects_by_ids` and optionally `generate.fetch_objects_by_ids` helpers for parity with Python collection queries.
