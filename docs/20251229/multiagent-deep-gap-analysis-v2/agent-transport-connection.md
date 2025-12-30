# Agent Transport - Connection and Protocol Gap Analysis

## Scope and sources
- Python: `weaviate-python-client/weaviate/connect/helpers.py`, `weaviate-python-client/weaviate/connect/v4.py`, `weaviate-python-client/weaviate/config.py`, `weaviate-python-client/weaviate/connect/base.py`, `weaviate-python-client/weaviate/embedded.py`
- Elixir: `lib/weaviate_ex/connect.ex`, `lib/weaviate_ex/client.ex`, `lib/weaviate_ex/client/config.ex`, `lib/weaviate_ex/config/connection.ex`, `lib/weaviate_ex/config/proxy.ex`, `lib/weaviate_ex/protocol/http/client.ex`, `lib/weaviate_ex/application.ex`, `lib/weaviate_ex/grpc/channel.ex`, `lib/weaviate_ex/embedded.ex`, `lib/weaviate_ex/health.ex`

## Parity highlights
- Embedded server lifecycle and binary download exist in both (Python `weaviate/embedded.py`, Elixir `lib/weaviate_ex/embedded.ex`).
- Core HTTP + gRPC connection model exists (Python `connect/v4.py`, Elixir `client.ex`).
- HTTP retry and timeouts exist (Python `_Retry` in `weaviate/retry.py`, Elixir `lib/weaviate_ex/protocol/http/client.ex` and `lib/weaviate_ex/retry.ex`).

## Gap findings
1. WCS gRPC host derivation differs for `.weaviate.network`.
   - Impact: gRPC host may be wrong for WCS clusters using the newer `ident.grpc.<domain>` pattern; gRPC calls can fail while HTTP works.
   - Evidence (Python): `weaviate-python-client/weaviate/connect/helpers.py` function `__parse_weaviate_cloud_cluster_url` uses `ident.grpc.<domain>` when host ends with `.weaviate.network`.
   - Evidence (Elixir): `lib/weaviate_ex/connect.ex` always prefixes `grpc-` in `to_weaviate_cloud/1`.

2. AdditionalConfig and proxies are defined but not wired into the client.
   - Impact: no per-client pool tuning, proxy support, or trust_env behavior; production network requirements (HTTP/HTTPS/GRPC proxies, pool size, retries) must be handled outside the client.
   - Evidence (Python): `weaviate-python-client/weaviate/config.py` defines `AdditionalConfig` and `ConnectionConfig`; `weaviate-python-client/weaviate/connect/v4.py` applies proxies, trust_env, and pool settings.
   - Evidence (Elixir): `lib/weaviate_ex/config/connection.ex` and `lib/weaviate_ex/config/proxy.ex` exist but are not referenced by `lib/weaviate_ex/client.ex` or `lib/weaviate_ex/protocol/http/client.ex`; Finch pool is fixed in `lib/weaviate_ex/application.ex`.

3. OIDC auth is not integrated into the request pipeline.
   - Impact: users must manually run the TokenManager and inject headers on every request; no automatic refresh or OAuth2 session management; gRPC metadata only supports API keys by default.
   - Evidence (Python): `weaviate-python-client/weaviate/connect/v4.py` uses OAuth2 clients and auth secrets to populate headers and refresh tokens.
   - Evidence (Elixir): `lib/weaviate_ex/auth/token_manager.ex` exists, but `lib/weaviate_ex/client/config.ex` only supports `api_key`, and `lib/weaviate_ex/client.ex` builds gRPC metadata from that only.

4. Connection initialization checks and skip_init_checks are missing.
   - Impact: client can appear connected even when gRPC is unavailable or server version is unsupported; no guardrail for version compatibility.
   - Evidence (Python): `weaviate-python-client/weaviate/connect/v4.py` `ConnectionSync.connect()` performs meta/version checks and gRPC ping, gated by `skip_init_checks`.
   - Evidence (Elixir): `lib/weaviate_ex/client.ex` connects gRPC and returns without meta/version checks; health checks are separate (`lib/weaviate_ex/health.ex`).

5. Additional headers are not forwarded to gRPC metadata by default.
   - Impact: provider API keys (OpenAI, Cohere, etc.) added as `additional_headers` are present on HTTP requests but not on gRPC search/batch calls, which can break vectorization or generative operations via gRPC.
   - Evidence (Python): `weaviate-python-client/weaviate/connect/v4.py` builds gRPC metadata with `additional_headers`.
   - Evidence (Elixir): `lib/weaviate_ex/grpc/channel.ex` supports `additional_headers`, but `lib/weaviate_ex/client.ex` only passes `api_key` into `Channel.build_metadata/1`.

## Suggested closure
- Update WCS gRPC host derivation in `lib/weaviate_ex/connect.ex` to mirror Python `__parse_weaviate_cloud_cluster_url` logic.
- Introduce a per-client `AdditionalConfig` equivalent in `lib/weaviate_ex/client/config.ex` and wire it through Finch pool creation and gRPC options (or allow client-specific Finch pools).
- Integrate `WeaviateEx.Auth.TokenManager` into `WeaviateEx.Client` so OIDC can be configured once and refresh automatically, including gRPC metadata updates.
- Add optional init checks in `WeaviateEx.Client.connect/1` to validate `/v1/meta`, version compatibility, and gRPC health, with a `skip_init_checks` flag to match Python.
- Pass `additional_headers` into `Channel.build_metadata/1` by default in `lib/weaviate_ex/client.ex` and ensure gRPC service calls propagate them.
