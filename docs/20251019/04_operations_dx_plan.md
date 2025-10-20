# Pillar Plan: Operational Reliability & Developer Experience

**Date:** 2025‑10‑19  
**Owners:** Platform reliability & DX  
**Objective:** Ensure the essential client delivers predictable operations, clear errors, and great onboarding without implementing full enterprise tooling.

---

## 1. Functional Scope

1. **Connection Management**
   - Finch-based HTTP protocol with configurable pool size, request timeout, and retry policy.
   - Health check endpoint wrapper (`/.well-known/ready`, `/v1/.well-known/ready` fallback).
   - Optional startup probe to verify connectivity during application boot.
2. **Error Taxonomy**
   - Extend `WeaviateEx.Error` with typed reasons (`:connection_error`, `:timeout`, `:validation_error`, `:not_found`, `:conflict`, `:graphql_error`, `:unauthorized`).
   - Include `status_code`, `message`, `details` (raw body) for logging.
3. **Observability Hooks**
   - Telemetry events for request lifecycle (`[:weaviate_ex, :request, :start|:stop|:exception]`) with timings and result metadata.
   - Allow custom metadata injection (correlation IDs) via request options.
4. **Raw Request API**
   - `WeaviateEx.Raw.request/5` to call arbitrary REST paths with same error handling.
   - Document warnings around stability but provide fallback for advanced teams.
5. **Documentation & Onboarding**
   - Update quick start, architecture, and troubleshooting docs.
   - Provide migration notes for teams coming from Python client.
   - Example mix project demonstrating essential flow (schema → ingest → query).

---

## 2. Technical Design

### 2.1 Protocol Enhancements

- Introduce `WeaviateEx.Protocol.HTTP.Request` struct to capture method/path/body/opts.  
- Implement middleware pipeline for retries (simple exponential backoff with jitter, max 3 attempts, idempotent only).  
- Configure Finch pool via client config (pool count, max connections).  
- Surface instrumentation by wrapping `Finch.request/3` with telemetry events.

### 2.2 Configuration Layer

- `WeaviateEx.Client.Config` to accept:  
  - `base_url` (required), `api_key`, `timeout`, `pool_size`, `retry` (enabled/disabled + max attempts).  
  - `telemetry_prefix` (default `[:weaviate_ex]`).  
  - `default_headers` (optional list of tuples).
- Validate config at client creation; raise informative error if missing `base_url`.

### 2.3 Telemetry & Logging

- Emit events with metadata: `%{method, path, status, duration_ms, attempt, error?}`.  
- Provide `WeaviateEx.Logger` helper to plug into Logger backend for easy debugging.  
- Document how to integrate with OpenTelemetry or PromEx.

### 2.4 Health & Diagnostics

- `WeaviateEx.Health.ready?/1` and `WeaviateEx.Health.live?/1` wrappers to check readiness/liveness endpoints with timeout fallback.  
- Provide `mix weaviate_ex.doctor` task (optional) to ping, fetch version, and print cluster info using essential APIs (no advanced debug endpoints).

---

## 3. Implementation Milestones

| Sprint | Deliverable | Key Tasks | Acceptance |
| --- | --- | --- | --- |
| **S1** | Config & Protocol upgrades | Extend client config, implement request struct, add retries/timeouts, telemetry instrumentation. | Unit tests for backoff, config validation, telemetry events; integration test verifying retry on transient 502. |
| **S2** | Error taxonomy & health checks | Expand `WeaviateEx.Error`, implement health endpoints, ensure consistent error mapping across APIs. | Integration tests hitting readiness endpoint, mocks verifying error typing. |
| **S3** | Raw API + docs | Add `WeaviateEx.Raw.request/5`, update docs, provide cookbook. | DX review with two internal consumers; docs merged. |
| **S4** | Observability polish | Provide Logger helper, sample PromEx dashboard config, finalize telemetry docs. | Telemetry validated in sample app; documentation walkthrough complete. |

---

## 4. Testing & QA

- **Unit:**  
  - Retry logic with deterministic jitter seeds.  
  - Telemetry events via `:telemetry_test.attach_many`.  
  - Config validation for missing fields / invalid values.
- **Integration:**  
  - Simulate transient errors using local proxy to confirm retry + backoff.  
  - Health readiness check against running Weaviate container.  
  - Raw request to unsupported endpoint returns structured error.
- **Performance:**  
  - Load test 10 concurrent writers using essential APIs with telemetry capturing throughput.  
  - Ensure Finch pool configuration prevents connection exhaustion.

---

## 5. Documentation Checklist

- Update `QUICK_START_GUIDE.md` with config table and telemetry example.  
- Add `docs/telemetry.md` reference linking to this plan.  
- Create troubleshooting entries for common errors (timeout, unauthorized, validation).  
- Migration note comparing Python client’s `client.backup` etc. with new `Raw.request/5`.

---

## 6. Risks & Mitigations

- **Retry Complexity:** Avoid re-sending non-idempotent POST with bodies unless flagged. Mitigation: only retry GET/HEAD/DELETE by default; allow opt-in per request.  
- **Telemetry Overhead:** Keep events lightweight, provide guidance to sample only in high-load systems.  
- **Doc Drift:** Assign DX writer to quarterly review; link documents in main README to increase visibility.

---

## 7. Open Questions

1. Should we auto-detect API key from env (`WEAVIATE_API_KEY`) or leave to caller?  
2. Do we provide default logging middleware or rely on host app instrumentation?  
3. Is `mix weaviate_ex.doctor` necessary for v2.0 or can we push to v2.1 once core stability metrics are confirmed?

