# Weaviate Server Lifecycle Reference (Python Client)

This note captures how the official `weaviate-python-client` stands up and manages real Weaviate instances for testing and local development. We can mirror the same patterns inside WeaviateEx.

## Docker-Based Workflow

- **Launch script** – `ci/start_weaviate.sh` accepts a `WEAVIATE_VERSION` tag, tears down any running stack, wipes the `weaviate-data` folder, then boots every compose profile in `ci/` before blocking on readiness checks (`weaviate-python-client/ci/start_weaviate.sh:1` and `weaviate-python-client/ci/compose.sh:1`).
- **Compose orchestration** – `ci/compose.sh` lists every `docker-compose*.yml` file, runs `docker compose … up -d`, and polls `/v1/.well-known/ready` on all exposed ports (`8080`, `8082`, `8083`, `8075`, `8085`, `8086`, `8087`, `8088`, `8089`, `8090`, `8092`, `8093`) until each instance reports HTTP 200. The `compose_down_all` helper reverses the process.
- **Profile coverage** – Each compose file pins `semitechnologies/weaviate:${WEAVIATE_VERSION}` and enables scenario-specific settings:
  - `docker-compose.yml` – baseline single-node instance plus a `contextionary` sidecar with default modules.
  - `docker-compose-modules.yml` – module-heavy node on port `8086` with OpenAI/Cohere/Jina providers exposed.
  - `docker-compose-async.yml` – async-indexing build on port `8090`, used for “journey” tests.
  - `docker-compose-cluster.yml` – three-node Raft cluster (HTTP ports `8087/8088/8089`, gRPC `50058/50059/50060`) plus shared contextionary.
  - `docker-compose-backup.yml` – RBAC-enabled instance at `8093` with filesystem backups.
  - `docker-compose-rbac.yml`, `docker-compose-okta-cc.yml`, `docker-compose-okta-users.yml`, `docker-compose-wcs.yml` – authentication variants (API key, OIDC, Okta, WCS).
  - `docker-compose-proxy.yml` – Envoy proxy fronting a Weaviate node at `8075`.
- **Teardown** – `ci/stop_weaviate.sh` mirrors startup: `docker compose … down --remove-orphans` for every profile, then removes `weaviate-data`.
- **Async shortcut** – `ci/start_weaviate_jt.sh` only brings up `docker-compose-async.yml` for journey tests that need the async indexer.

## How Tests Connect

- The pytest fixtures open clients against the localhost ports booted above. `integration/conftest.py` exposes a `client_factory` that calls `weaviate.connect_to_local(headers=…, port=PORT, grpc_port=GRPC)` and reuses the handle per test module.
- Individual integration suites target the matching profile: e.g. RBAC tests hit `localhost:8092`, backup tests use `8093`, proxy tests talk to the Envoy on `10000`, etc.
- Developers follow the same path when running tests locally: run `./ci/start_weaviate.sh <tag>`, execute the desired pytest suites, then stop the stack.

## Embedded Weaviate Path

- `weaviate.connect_to_embedded` wraps an on-disk server: it builds an `EmbeddedOptions` struct, ensures binaries live under `~/.cache/weaviate-embedded` (or `binary_path`), downloads the requested release from GitHub if missing, and spawns the process (`weaviate-python-client/weaviate/connect/helpers.py:206` and `weaviate-python-client/weaviate/embedded.py:18`).
- Startup logic seeds default environment variables: anonymous access, module enablement, randomly assigned gossip/data/Raft ports, gRPC port binding, and optional overrides via `environment_variables`.
- The helper waits for both HTTP and gRPC listeners before handing control back, and it stops the subprocess when the client object is closed.
- `integration_embedded/test_client.py` demonstrates the flow by pointing the client at temp directories supplied by `pytest tmp_path_factory`, verifying readiness, and making sure cleanup works.

## Implications for WeaviateEx

1. **Replicate the Docker harness** – ship mix tasks or scripts that mirror `start_weaviate.sh`/`stop_weaviate.sh`, enumerate compose profiles, and gate tests on `/v1/.well-known/ready`.
2. **Provide profile parity** – maintain dedicated compose files for modules, async indexers, clusters, RBAC/OIDC, proxy, and backups so each integration suite has a predictable endpoint.
3. **Wire fixtures to ports** – expose helpers in Elixir test support that align with the same port map, letting each test module grab the right configuration with minimal boilerplate.
4. **Offer embedded mode** – add an `connect_to_embedded/1` variant that downloads the Weaviate binary, caches it, manages lifecycle, and mirrors the Python client’s environment defaults for parity.
5. **Expose developer tooling** – surface `mix weaviate.start`, `mix weaviate.stop`, `mix weaviate.logs`, and `mix weaviate.status` so contributors can manage the stack from Elixir, and wrap the embedded lifecycle behind `WeaviateEx.start_embedded/1` and `WeaviateEx.stop_embedded/1`.
