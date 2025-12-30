# Transport and Auth Implementation Plan

## Scope
Close parity gaps in connection helpers, proxy/pool configuration, auth integration, init checks, and gRPC metadata handling.

## Gap sources
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-transport-connection.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-auth-rbac.md`

## Tasks
1. WCS gRPC host derivation parity
   - Update `WeaviateEx.Connect.to_weaviate_cloud/1` to mirror Python `__parse_weaviate_cloud_cluster_url` logic, including `.weaviate.network` handling.

2. Wire connection config and proxies
   - Add a client option for connection and proxy config (or an `AdditionalConfig` equivalent).
   - Propagate proxy settings into Finch and gRPC channel options.
   - Align pool sizing and retry policy with existing Finch usage.

3. Integrate OIDC auth into client lifecycle
   - Accept `WeaviateEx.Auth` structs in `WeaviateEx.Client.connect/1`.
   - Start/attach `TokenManager` when OIDC is used and refresh tokens automatically.
   - Ensure HTTP and gRPC metadata include the current access token.

4. Init checks and skip flag
   - Add optional init checks (meta version, gRPC health) in `Client.connect/1`.
   - Implement `:skip_init_checks` option similar to Python.

5. gRPC metadata forwarding
   - Ensure `additional_headers` are included in gRPC metadata by default.

## Acceptance criteria
- Unit tests for host parsing, proxy propagation, OIDC header injection, and skip_init_checks.
- README and guides updated (getting_started, embedded_mode, auth sections).
- `CHANGELOG.md` 0.7.3 updated.
- Tests passing with no warnings/credo/dialyzer errors.
