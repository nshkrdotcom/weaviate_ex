# Agent Auth - Authentication, Users, and RBAC Gap Analysis

## Scope and sources
- Python: `weaviate-python-client/weaviate/auth.py`, `weaviate-python-client/weaviate/connect/v4.py`, `weaviate-python-client/weaviate/users/base.py`, `weaviate-python-client/weaviate/rbac/models.py`
- Elixir: `lib/weaviate_ex/auth.ex`, `lib/weaviate_ex/auth/token_manager.ex`, `lib/weaviate_ex/client/config.ex`, `lib/weaviate_ex/client.ex`, `lib/weaviate_ex/api/users.ex`, `lib/weaviate_ex/api/users/db.ex`, `lib/weaviate_ex/api/users/oidc.ex`, `lib/weaviate_ex/api/rbac.ex`, `lib/weaviate_ex/rbac/*`

## Parity highlights
- Elixir provides full RBAC role CRUD, permission builders, and group role assignment APIs (`lib/weaviate_ex/api/rbac.ex`, `lib/weaviate_ex/api/groups.ex`).
- OIDC flows exist in Elixir via `TokenManager` with refresh behavior (`lib/weaviate_ex/auth/token_manager.ex`).

## Gap findings
1. OIDC auth is not integrated into the client lifecycle.
   - Impact: users must manually fetch and refresh tokens and inject headers per request; no automatic refresh or OAuth2 session handling for HTTP or gRPC.
   - Evidence (Python): `weaviate-python-client/weaviate/connect/v4.py` uses OAuth2 clients and manages tokens in the connection class.
   - Evidence (Elixir): `lib/weaviate_ex/client/config.ex` only supports `api_key`; `TokenManager` is separate and not wired into `Client.connect/1` or `Protocol.HTTP.Client`.

2. User role retrieval lacks full permission details.
   - Impact: Elixir can only return role names for users; Python can return full `Role` objects including permissions when `include_permissions` is set.
   - Evidence (Python): `weaviate-python-client/weaviate/users/base.py` `_get_roles_of_user` supports `include_permissions` and returns `Role` objects.
   - Evidence (Elixir): `lib/weaviate_ex/api/users.ex` `get_assigned_roles/3` returns a list of strings; no `include_permissions` option exists.

3. Missing unified client sub-namespace for user types.
   - Impact: Python exposes `client.users.db` and `client.users.oidc` for clear separation; Elixir exposes modules but does not provide an equivalent client-bound namespace with shared defaults (tenant, consistency, auth).
   - Evidence (Python): `weaviate-python-client/weaviate/users/sync.py` builds `.db` and `.oidc` subclients.
   - Evidence (Elixir): user operations are in `lib/weaviate_ex/api/users.ex`, `lib/weaviate_ex/api/users/db.ex`, and `lib/weaviate_ex/api/users/oidc.ex` without a client wrapper.

## Suggested closure
- Add a first-class auth option to `WeaviateEx.Client` that accepts `WeaviateEx.Auth` structs and automatically manages tokens via `TokenManager`.
- Extend user role retrieval to support `include_permissions` and return full `Role` structures, matching Python output.
- Provide a client-scoped Users namespace (for db and oidc) that mirrors Python ergonomics and centralizes auth and default options.
