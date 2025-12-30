# Prompt - WCS Compatibility (Headers + Version Checks)

## Objective

Implement Weaviate Cloud Service (WCS) compatibility features: automatic header detection, proper gRPC host parsing for `.weaviate.network` clusters, and server version compatibility checks.

## Priority

P1 - High (Cloud compatibility)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/06-auth-connection.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-transport-connection.md`
- `README.md`
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/connect.ex` - Connection helpers
- `lib/weaviate_ex/client.ex` - Client initialization
- `lib/weaviate_ex/client/config.ex` - Client configuration
- `lib/weaviate_ex/health.ex` - Health checks
- `lib/weaviate_ex/version.ex` - Version handling
- `test/weaviate_ex/connect_test.exs`
- `test/weaviate_ex/client_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/connect/helpers.py` - Connection helpers
- `../weaviate-python-client/weaviate/connect/v4.py` - WCS handling

## Context

### Current State
- `connect_to_wcs` or `connect_to_weaviate_cloud` helpers may exist
- gRPC host always prefixed with `grpc-`
- No automatic `X-Weaviate-Cluster-URL` header
- No minimum server version validation

### Gap 1: WCS gRPC Host Parsing
Python handles `.weaviate.network` clusters differently:
```python
# For .weaviate.network clusters
# Python uses: ident.grpc.<domain>
# Not: grpc-ident.<domain>

# Example:
# HTTP: my-cluster.weaviate.network
# gRPC: my-cluster.grpc.weaviate.network  (NOT grpc-my-cluster.weaviate.network)
```

### Gap 2: WCS Headers
Python automatically adds cluster URL header:
```python
headers = {
    "X-Weaviate-Cluster-URL": f"https://{cluster_url}"
}
```

### Gap 3: Version Checks
Python validates server version on connect:
```python
if server_version < MIN_REQUIRED_VERSION:
    raise WeaviateUnsupportedVersionError(...)
```

## Implementation Instructions (TDD Required)

### Step 1: Update WCS Host Parsing

Update `lib/weaviate_ex/connect.ex`:

```elixir
defmodule WeaviateEx.Connect do
  @weaviate_network_suffix ".weaviate.network"
  @min_supported_version "1.27.0"

  @doc """
  Connects to Weaviate Cloud Service.

  ## Examples

      # Standard WCS cluster
      {:ok, client} = Connect.to_weaviate_cloud("my-cluster.weaviate.network", api_key)

      # With custom options
      {:ok, client} = Connect.to_weaviate_cloud(url, api_key,
        skip_init_checks: false,
        additional_headers: [{"X-Custom", "value"}]
      )
  """
  @spec to_weaviate_cloud(String.t(), String.t(), keyword()) ::
    {:ok, Client.t()} | {:error, term()}
  def to_weaviate_cloud(cluster_url, api_key, opts \\ []) do
    http_url = normalize_wcs_url(cluster_url)
    grpc_host = build_wcs_grpc_host(cluster_url)

    headers = build_wcs_headers(cluster_url, opts[:additional_headers])

    Client.connect(http_url,
      api_key: api_key,
      grpc_host: grpc_host,
      additional_headers: headers,
      skip_init_checks: opts[:skip_init_checks] || false
    )
  end

  defp normalize_wcs_url(url) do
    url = String.trim_trailing(url, "/")

    cond do
      String.starts_with?(url, "https://") -> url
      String.starts_with?(url, "http://") -> String.replace(url, "http://", "https://")
      true -> "https://#{url}"
    end
  end

  defp build_wcs_grpc_host(cluster_url) do
    # Extract hostname without protocol
    host = cluster_url
    |> String.replace(~r{^https?://}, "")
    |> String.split("/")
    |> hd()

    cond do
      # .weaviate.network uses ident.grpc.domain pattern
      String.ends_with?(host, @weaviate_network_suffix) ->
        # my-cluster.weaviate.network -> my-cluster.grpc.weaviate.network
        base = String.replace(host, @weaviate_network_suffix, "")
        "#{base}.grpc#{@weaviate_network_suffix}"

      # Other WCS clusters use grpc-ident.domain pattern
      true ->
        "grpc-#{host}"
    end
  end

  defp build_wcs_headers(cluster_url, additional) do
    base_headers = [{"X-Weaviate-Cluster-URL", normalize_wcs_url(cluster_url)}]

    case additional do
      nil -> base_headers
      headers -> base_headers ++ headers
    end
  end
end
```

### Step 2: Add Version Compatibility Check

Update `lib/weaviate_ex/client.ex`:

```elixir
defmodule WeaviateEx.Client do
  @min_supported_version "1.27.0"

  def connect(url, opts \\ []) do
    skip_init_checks = Keyword.get(opts, :skip_init_checks, false)

    with {:ok, client} <- do_connect(url, opts),
         :ok <- maybe_run_init_checks(client, skip_init_checks) do
      {:ok, client}
    end
  end

  defp maybe_run_init_checks(_client, true), do: :ok
  defp maybe_run_init_checks(client, false) do
    with :ok <- check_server_version(client),
         :ok <- check_grpc_availability(client) do
      :ok
    end
  end

  defp check_server_version(client) do
    case WeaviateEx.Version.get_server_version(client) do
      {:ok, version} ->
        if version_supported?(version) do
          :ok
        else
          {:error, {:unsupported_version, version, @min_supported_version}}
        end

      {:error, _} = error ->
        error
    end
  end

  defp version_supported?(server_version) do
    case Version.compare(normalize_version(server_version), @min_supported_version) do
      :lt -> false
      _ -> true
    end
  end

  defp normalize_version(version) do
    # Handle versions like "1.28.14" or "1.28.14-rc.1"
    version
    |> String.split("-")
    |> hd()
  end

  defp check_grpc_availability(client) do
    case WeaviateEx.Health.grpc_ready?(client) do
      true -> :ok
      false -> {:error, :grpc_unavailable}
    end
  end
end
```

### Step 3: Add skip_init_checks Option

Ensure the option is documented and passed through:

```elixir
@type connect_opts :: [
  api_key: String.t(),
  grpc_host: String.t(),
  grpc_port: integer(),
  additional_headers: [{String.t(), String.t()}],
  skip_init_checks: boolean(),
  timeout: WeaviateEx.Config.Timeout.t()
]
```

### Step 4: Add Helpful Error Messages

Create `lib/weaviate_ex/errors/version_error.ex`:

```elixir
defmodule WeaviateEx.Errors.VersionError do
  defexception [:server_version, :min_version, :message]

  @impl true
  def message(%{server_version: server, min_version: min}) do
    """
    Weaviate server version #{server} is not supported.
    Minimum required version: #{min}

    Please upgrade your Weaviate server or use skip_init_checks: true
    if you want to proceed anyway (not recommended).
    """
  end
end
```

## Tests to Write

### WCS Host Parsing Tests (`test/weaviate_ex/connect_test.exs`)

```elixir
describe "build_wcs_grpc_host/1" do
  test "handles .weaviate.network clusters" do
    assert build_wcs_grpc_host("my-cluster.weaviate.network") ==
      "my-cluster.grpc.weaviate.network"
  end

  test "handles other WCS clusters" do
    assert build_wcs_grpc_host("my-cluster.aws.weaviate.cloud") ==
      "grpc-my-cluster.aws.weaviate.cloud"
  end

  test "handles URL with protocol" do
    assert build_wcs_grpc_host("https://my-cluster.weaviate.network") ==
      "my-cluster.grpc.weaviate.network"
  end
end

describe "build_wcs_headers/2" do
  test "adds X-Weaviate-Cluster-URL header"
  test "merges with additional headers"
end
```

### Version Check Tests (`test/weaviate_ex/client_test.exs`)

```elixir
describe "version compatibility" do
  test "connects successfully with supported version"
  test "returns error for unsupported version"
  test "skips check when skip_init_checks: true"
end

describe "gRPC availability check" do
  test "succeeds when gRPC is available"
  test "returns error when gRPC unavailable"
  test "skips check when skip_init_checks: true"
end
```

### Integration Tests

```elixir
@tag :integration
describe "WCS connection" do
  @tag :skip  # Requires real WCS cluster
  test "connects to .weaviate.network cluster"

  test "local connection runs version check"
  test "skip_init_checks bypasses version check"
end
```

## Docs Updates

### README.md

Update connection section:

```markdown
### Connecting to Weaviate Cloud

\`\`\`elixir
# Connect to Weaviate Cloud Service
{:ok, client} = WeaviateEx.Connect.to_weaviate_cloud(
  "my-cluster.weaviate.network",
  "your-api-key"
)

# With options
{:ok, client} = WeaviateEx.Connect.to_weaviate_cloud(
  "my-cluster.weaviate.network",
  "your-api-key",
  skip_init_checks: false,  # Validates server version (default)
  additional_headers: [{"X-Custom", "value"}]
)
\`\`\`

### Server Version Requirements

WeaviateEx requires Weaviate server version 1.27.0 or higher.
The client validates the server version on connection by default.

To bypass version checks (not recommended):

\`\`\`elixir
{:ok, client} = WeaviateEx.Client.connect(url,
  skip_init_checks: true
)
\`\`\`
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- Proper WCS gRPC host parsing for `.weaviate.network` clusters
- Automatic `X-Weaviate-Cluster-URL` header for WCS connections
- Server version compatibility check on connect (requires 1.27.0+)
- gRPC availability check on connect
- `skip_init_checks` option to bypass version/gRPC validation
- `WeaviateEx.Errors.VersionError` for clear version mismatch errors

### Fixed
- gRPC connections to `.weaviate.network` clusters now use correct host format
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New WCS/version tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `.weaviate.network` gRPC hosts use `ident.grpc.domain` format
2. Other WCS hosts use `grpc-ident.domain` format
3. `X-Weaviate-Cluster-URL` header automatically added
4. Server version validated on connect (>= 1.27.0)
5. gRPC availability checked on connect
6. `skip_init_checks: true` bypasses all init checks
7. Clear error messages for version mismatches
8. All quality gates pass
