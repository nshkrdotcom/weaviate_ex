# Prompt - Transport and Auth Parity

## Objective
Implement transport/auth parity gaps: WCS gRPC host parsing, proxy/pool wiring, OIDC integration, init checks, and gRPC metadata forwarding.

## Required reading (docs)
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-transport-connection.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-auth-rbac.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/implementation-plan/01_transport_auth.md`
- `README.md`
- `guides/getting_started.md`
- `guides/embedded_mode.md`
- `CHANGELOG.md`

## Required reading (src/tests)
- `lib/weaviate_ex/connect.ex`
- `lib/weaviate_ex/client.ex`
- `lib/weaviate_ex/client/config.ex`
- `lib/weaviate_ex/config/connection.ex`
- `lib/weaviate_ex/config/proxy.ex`
- `lib/weaviate_ex/protocol/http/client.ex`
- `lib/weaviate_ex/grpc/channel.ex`
- `lib/weaviate_ex/auth.ex`
- `lib/weaviate_ex/auth/token_manager.ex`
- `lib/weaviate_ex/application.ex`
- `lib/weaviate_ex/health.ex`
- `test/weaviate_ex/auth/*`
- `test/weaviate_ex/client/*`

## Context
- Elixir always prefixes gRPC host with `grpc-` for WCS, but Python switches to `ident.grpc.<domain>` for `.weaviate.network` clusters.
- Proxy and connection pool config modules exist but are not wired into Finch or gRPC channel creation.
- OIDC TokenManager exists but is not integrated into client request lifecycle; gRPC metadata only uses API keys.
- There is no init check pipeline (meta/version/gRPC) or skip_init_checks flag in `WeaviateEx.Client.connect/1`.

## Implementation instructions (TDD required)
1. WCS gRPC host parsing
   - Update `WeaviateEx.Connect.to_weaviate_cloud/1` to follow Python WCS parsing rules, including `.weaviate.network` handling.
   - Add unit tests that cover both `.weaviate.network` and other WCS hostnames.

2. Connection config and proxies
   - Introduce a client option (or `AdditionalConfig` equivalent) to pass pool + proxy settings.
   - Wire proxy options into Finch (`Finch.build/4` options) and gRPC channel options.
   - Ensure defaults preserve current behavior when config is omitted.

3. OIDC integration
   - Allow `WeaviateEx.Client.connect/1` to accept `WeaviateEx.Auth` structs.
   - Start/attach `TokenManager` on OIDC configs and inject refreshed access tokens into HTTP headers and gRPC metadata.
   - Ensure `additional_headers` are merged into gRPC metadata by default.

4. Init checks
   - Add `:skip_init_checks` option similar to Python.
   - When enabled, skip meta/version/gRPC health checks; otherwise validate minimum server version and gRPC availability.
   - Use existing `WeaviateEx.Version` and `WeaviateEx.Health` where appropriate.

## Docs updates
- Update `README.md` with new auth/config usage.
- Update `guides/getting_started.md` and `guides/embedded_mode.md` if new options or behavior affect setup.

## Changelog
- Add entries under `## [0.7.3] - 2025-12-29` in `CHANGELOG.md` describing transport/auth changes.

## Quality gates
- TDD: add/adjust tests first, then implement.
- All tests passing.
- No warnings, credo issues, or dialyzer errors.
