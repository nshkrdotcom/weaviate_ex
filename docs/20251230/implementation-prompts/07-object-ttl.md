# Prompt - Object TTL Configuration

## Objective

Implement Object TTL (Time-To-Live) configuration for automatic data expiration. This allows objects to be automatically deleted after a specified duration.

## Priority

P1 - High (Data lifecycle management)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/03-schema-collections.md`
- `README.md`
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/config/object_ttl.ex` - Existing TTL config (if exists)
- `lib/weaviate_ex/collections.ex` - Collection creation
- `lib/weaviate_ex/api/collections.ex` - Collection API
- `test/weaviate_ex/config/object_ttl_test.exs` (if exists)
- `test/weaviate_ex/collections_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/classes/config.py` - ObjectTTLConfig

## Context

### Current State
- Basic TTL config may exist but isn't fully integrated
- Collection creation doesn't support TTL configuration
- No validation of TTL values

### Python Implementation
```python
# From config.py
class ObjectTTLConfig:
    enabled: bool = False
    ttl_seconds: Optional[int] = None

# Usage
client.collections.create(
    name="Events",
    object_ttl_config=ObjectTTLConfig(enabled=True, ttl_seconds=86400)  # 24 hours
)
```

### Weaviate API
```json
{
  "class": "Events",
  "objectTTLConfig": {
    "enabled": true,
    "ttlSeconds": 86400
  }
}
```

## Implementation Instructions (TDD Required)

### Step 1: Create/Update ObjectTTL Module

Create or update `lib/weaviate_ex/config/object_ttl.ex`:

```elixir
defmodule WeaviateEx.Config.ObjectTTL do
  @moduledoc """
  Configuration for automatic object expiration (TTL).

  Objects will be automatically deleted after the specified TTL period
  from their creation or last update time.
  """

  @type t :: %__MODULE__{
    enabled: boolean(),
    ttl_seconds: non_neg_integer() | nil
  }

  defstruct enabled: false, ttl_seconds: nil

  @doc """
  Creates a new ObjectTTL configuration.

  ## Examples

      # Enable TTL with 24-hour expiration
      ObjectTTL.new(enabled: true, ttl_seconds: 86400)

      # Disable TTL
      ObjectTTL.new(enabled: false)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, false),
      ttl_seconds: Keyword.get(opts, :ttl_seconds)
    }
  end

  @doc """
  Creates TTL config from duration.

  ## Examples

      ObjectTTL.from_duration(hours: 24)
      ObjectTTL.from_duration(days: 7)
      ObjectTTL.from_duration(minutes: 30)
  """
  @spec from_duration(keyword()) :: t()
  def from_duration(duration) do
    seconds = duration_to_seconds(duration)
    %__MODULE__{enabled: true, ttl_seconds: seconds}
  end

  defp duration_to_seconds(duration) do
    days = Keyword.get(duration, :days, 0)
    hours = Keyword.get(duration, :hours, 0)
    minutes = Keyword.get(duration, :minutes, 0)
    seconds = Keyword.get(duration, :seconds, 0)

    days * 86400 + hours * 3600 + minutes * 60 + seconds
  end

  @doc """
  Converts to Weaviate API format.
  """
  @spec to_api_format(t()) :: map()
  def to_api_format(%__MODULE__{enabled: enabled, ttl_seconds: ttl}) do
    %{
      "enabled" => enabled,
      "ttlSeconds" => ttl
    }
  end

  @doc """
  Parses from Weaviate API response.
  """
  @spec from_api_response(map() | nil) :: t() | nil
  def from_api_response(nil), do: nil
  def from_api_response(%{"enabled" => enabled, "ttlSeconds" => ttl}) do
    %__MODULE__{enabled: enabled, ttl_seconds: ttl}
  end
end
```

### Step 2: Integrate into Collections

Update `lib/weaviate_ex/collections.ex`:

```elixir
defmodule WeaviateEx.Collections do
  alias WeaviateEx.Config.ObjectTTL

  @doc """
  Creates a new collection with optional TTL configuration.

  ## Options

  - `:object_ttl` - ObjectTTL struct for automatic expiration

  ## Examples

      # Collection with 24-hour TTL
      Collections.create(client, "Events",
        object_ttl: ObjectTTL.from_duration(hours: 24)
      )
  """
  def create(client, name, opts \\ []) do
    params = build_create_params(name, opts)
    # ... create collection
  end

  defp build_create_params(name, opts) do
    base = %{"class" => name}

    base
    |> maybe_add_ttl(opts[:object_ttl])
    |> maybe_add_vectorizer(opts[:vectorizer])
    # ... other options
  end

  defp maybe_add_ttl(params, nil), do: params
  defp maybe_add_ttl(params, %ObjectTTL{} = ttl) do
    Map.put(params, "objectTTLConfig", ObjectTTL.to_api_format(ttl))
  end
end
```

### Step 3: Add TTL to Collection Config Response

Update collection parsing to include TTL:

```elixir
defmodule WeaviateEx.Collection do
  defstruct [:name, :properties, :vectorizer, :object_ttl, ...]

  def from_api_response(response) do
    %__MODULE__{
      name: response["class"],
      # ... other fields
      object_ttl: ObjectTTL.from_api_response(response["objectTTLConfig"])
    }
  end
end
```

### Step 4: Add Update Support

Allow updating TTL on existing collections:

```elixir
def update_ttl(client, collection_name, %ObjectTTL{} = ttl) do
  API.Collections.update(client, collection_name, %{
    "objectTTLConfig" => ObjectTTL.to_api_format(ttl)
  })
end
```

## Tests to Write

### ObjectTTL Module Tests (`test/weaviate_ex/config/object_ttl_test.exs`)

```elixir
describe "new/1" do
  test "creates disabled TTL by default"
  test "creates enabled TTL with seconds"
  test "validates ttl_seconds is non-negative"
end

describe "from_duration/1" do
  test "converts days to seconds"
  test "converts hours to seconds"
  test "converts minutes to seconds"
  test "combines multiple duration units"
end

describe "to_api_format/1" do
  test "converts to Weaviate API format"
  test "handles nil ttl_seconds"
end

describe "from_api_response/1" do
  test "parses Weaviate response"
  test "returns nil for nil input"
end
```

### Collections Integration Tests

```elixir
@tag :integration
describe "collections with TTL" do
  test "creates collection with TTL enabled"
  test "retrieves collection with TTL config"
  test "updates collection TTL"
  test "objects expire after TTL period" do
    # Create collection with short TTL
    # Insert object
    # Wait for TTL
    # Verify object is deleted
  end
end
```

## Docs Updates

### README.md

Add Object TTL section:

```markdown
### Object TTL (Time-To-Live)

Automatically expire objects after a specified duration:

\`\`\`elixir
alias WeaviateEx.Config.ObjectTTL

# Create collection with 24-hour TTL
{:ok, _} = WeaviateEx.Collections.create(client, "Events",
  object_ttl: ObjectTTL.from_duration(hours: 24)
)

# Or specify exact seconds
{:ok, _} = WeaviateEx.Collections.create(client, "Sessions",
  object_ttl: ObjectTTL.new(enabled: true, ttl_seconds: 3600)
)

# Update existing collection TTL
{:ok, _} = WeaviateEx.Collections.update_ttl(client, "Events",
  ObjectTTL.from_duration(days: 7)
)

# Disable TTL
{:ok, _} = WeaviateEx.Collections.update_ttl(client, "Events",
  ObjectTTL.new(enabled: false)
)
\`\`\`

**Note:** Objects are deleted based on their creation time, not last update time.
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- `WeaviateEx.Config.ObjectTTL` module for automatic object expiration
- `ObjectTTL.from_duration/1` for human-readable TTL configuration
- Collection creation with TTL support
- `Collections.update_ttl/3` for updating existing collection TTL

### Changed
- Collection struct now includes `object_ttl` field
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New ObjectTTL tests pass
- [ ] Integration tests pass: `WEAVIATE_INTEGRATION=true mix test --include integration`
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `ObjectTTL` module with `new/1`, `from_duration/1`
2. Collection creation accepts `:object_ttl` option
3. Collection response includes TTL config
4. `update_ttl/3` function for existing collections
5. Integration test verifies object expiration
6. All quality gates pass
