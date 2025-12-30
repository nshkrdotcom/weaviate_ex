# Prompt - Multi-Target References

## Objective

Implement multi-target reference support for cross-references that can point to objects in multiple collections.

## Priority

P2 - Medium (Graph modeling)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/09-data-types-objects.md`
- `README.md` (references section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/api/references.ex` - Reference operations
- `lib/weaviate_ex/types/reference.ex` - Reference type
- `lib/weaviate_ex/data/reference_to_multi.ex` - Multi-target conversion
- `lib/weaviate_ex/filter/multi_target_ref.ex` - Multi-target filtering
- `lib/weaviate_ex/property.ex` - Property definitions
- `test/weaviate_ex/api/references_test.exs`
- `test/weaviate_ex/data/reference_to_multi_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/classes/data.py` - Reference handling
- `../weaviate-python-client/weaviate/collections/classes/config.py` - Multi-target config

## Context

### Current State
- Single-target references work
- Multi-target reference type may exist
- Creating multi-target reference properties may not be fully supported
- Reference operations may not handle multi-target correctly

### Gap
Python supports multi-target references:
```python
# Define property that can reference multiple collections
client.collections.create(
    name="Article",
    references=[
        ReferenceProperty(
            name="hasAuthor",
            target_collection=["Person", "Organization"]  # Multi-target
        )
    ]
)

# Add reference to specific target
article.references.add(
    from_property="hasAuthor",
    to=Reference(
        target_collection="Person",
        uuids=["uuid1"]
    )
)
```

### Multi-Target vs Single-Target
- **Single-target**: Reference property points to one collection
- **Multi-target**: Reference property can point to objects in multiple collections

## Implementation Instructions (TDD Required)

### Step 1: Update Reference Property Definition

Update `lib/weaviate_ex/property.ex`:

```elixir
defmodule WeaviateEx.Property do
  @doc """
  Creates a reference property definition.

  ## Single-target reference

      Property.reference("hasAuthor", "Person")

  ## Multi-target reference

      Property.reference("hasAuthor", ["Person", "Organization"])
  """
  @spec reference(String.t(), String.t() | [String.t()]) :: map()
  def reference(name, target) when is_binary(target) do
    %{
      "name" => name,
      "dataType" => ["#{target}"]
    }
  end

  def reference(name, targets) when is_list(targets) do
    %{
      "name" => name,
      "dataType" => Enum.map(targets, &"#{&1}")
    }
  end
end
```

### Step 2: Create Multi-Target Reference Struct

Create/update `lib/weaviate_ex/types/multi_target_reference.ex`:

```elixir
defmodule WeaviateEx.Types.MultiTargetReference do
  @moduledoc """
  A reference that specifies the target collection.
  Used for multi-target reference properties.
  """

  @type t :: %__MODULE__{
    target_collection: String.t(),
    uuids: [String.t()]
  }

  @enforce_keys [:target_collection, :uuids]
  defstruct [:target_collection, :uuids]

  @doc """
  Creates a multi-target reference.

  ## Examples

      MultiTargetReference.new("Person", ["uuid1", "uuid2"])
      MultiTargetReference.new("Organization", "single-uuid")
  """
  @spec new(String.t(), String.t() | [String.t()]) :: t()
  def new(target_collection, uuid) when is_binary(uuid) do
    %__MODULE__{target_collection: target_collection, uuids: [uuid]}
  end

  def new(target_collection, uuids) when is_list(uuids) do
    %__MODULE__{target_collection: target_collection, uuids: uuids}
  end

  @doc """
  Converts to Weaviate beacon format.
  """
  @spec to_beacons(t()) :: [map()]
  def to_beacons(%__MODULE__{target_collection: collection, uuids: uuids}) do
    Enum.map(uuids, fn uuid ->
      %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
    end)
  end
end
```

### Step 3: Update Reference Operations

Update `lib/weaviate_ex/api/references.ex`:

```elixir
defmodule WeaviateEx.API.References do
  alias WeaviateEx.Types.MultiTargetReference

  @doc """
  Adds a reference, supporting both single and multi-target.

  ## Single-target reference

      References.add(client, "Article", article_uuid, "hasAuthor", author_uuid)

  ## Multi-target reference

      References.add(client, "Article", article_uuid, "hasAuthor",
        MultiTargetReference.new("Person", author_uuid)
      )
  """
  @spec add(Client.t(), String.t(), String.t(), String.t(), String.t() | MultiTargetReference.t()) ::
    :ok | {:error, term()}
  def add(client, collection, from_uuid, property, to_uuid) when is_binary(to_uuid) do
    # Single-target: use existing implementation
    do_add_reference(client, collection, from_uuid, property, [
      %{"beacon" => "weaviate://localhost/#{to_uuid}"}
    ])
  end

  def add(client, collection, from_uuid, property, %MultiTargetReference{} = ref) do
    # Multi-target: include collection in beacon
    do_add_reference(client, collection, from_uuid, property,
      MultiTargetReference.to_beacons(ref)
    )
  end

  @doc """
  Adds multiple references to a multi-target property.

  ## Example

      References.add_many(client, "Article", article_uuid, "hasAuthor", [
        MultiTargetReference.new("Person", person_uuid),
        MultiTargetReference.new("Organization", org_uuid)
      ])
  """
  @spec add_many(Client.t(), String.t(), String.t(), String.t(), [MultiTargetReference.t()]) ::
    :ok | {:error, term()}
  def add_many(client, collection, from_uuid, property, refs) do
    beacons = Enum.flat_map(refs, &MultiTargetReference.to_beacons/1)
    do_add_reference(client, collection, from_uuid, property, beacons)
  end
end
```

### Step 4: Update Beacon Parsing

Update parsing to extract collection from beacon:

```elixir
defmodule WeaviateEx.Types.Beacon do
  @doc """
  Parses a Weaviate beacon URL.

  ## Examples

      parse("weaviate://localhost/Person/uuid")
      # => %{collection: "Person", uuid: "uuid"}

      parse("weaviate://localhost/uuid")
      # => %{collection: nil, uuid: "uuid"}
  """
  @spec parse(String.t()) :: %{collection: String.t() | nil, uuid: String.t()}
  def parse(beacon) do
    case String.split(beacon, "/") do
      ["weaviate:", "", _host, collection, uuid] ->
        %{collection: collection, uuid: uuid}

      ["weaviate:", "", _host, uuid] ->
        %{collection: nil, uuid: uuid}

      _ ->
        %{collection: nil, uuid: beacon}
    end
  end
end
```

### Step 5: Handle Multi-Target in Responses

Update object parsing to include target collection:

```elixir
defp parse_references(refs) when is_list(refs) do
  Enum.map(refs, fn ref ->
    beacon = ref["beacon"]
    parsed = Beacon.parse(beacon)

    %{
      collection: parsed.collection,
      uuid: parsed.uuid,
      beacon: beacon
    }
  end)
end
```

## Tests to Write

### MultiTargetReference Tests (`test/weaviate_ex/types/multi_target_reference_test.exs`)

```elixir
describe "new/2" do
  test "creates reference with single UUID"
  test "creates reference with multiple UUIDs"
end

describe "to_beacons/1" do
  test "converts to beacon format with collection"
  test "handles multiple UUIDs"
end
```

### Property Tests (`test/weaviate_ex/property_test.exs`)

```elixir
describe "reference/2" do
  test "creates single-target reference property"
  test "creates multi-target reference property with list"
end
```

### Reference Operation Tests (`test/weaviate_ex/api/references_test.exs`)

```elixir
describe "add/5 with multi-target" do
  test "adds reference with MultiTargetReference"
  test "includes collection in beacon"
end

describe "add_many/5" do
  test "adds references to multiple collections"
end
```

### Beacon Tests (`test/weaviate_ex/types/beacon_test.exs`)

```elixir
describe "parse/1" do
  test "parses beacon with collection"
  test "parses beacon without collection"
  test "handles invalid format gracefully"
end
```

### Integration Tests

```elixir
@tag :integration
describe "multi-target references" do
  setup do
    # Create Person collection
    # Create Organization collection
    # Create Article collection with multi-target hasAuthor
  end

  test "creates multi-target reference property"
  test "adds reference to Person"
  test "adds reference to Organization"
  test "retrieves references with target collection"
  test "filters by multi-target reference"
end
```

## Docs Updates

### README.md

Add multi-target reference section:

```markdown
### Multi-Target References

Create reference properties that can point to multiple collections:

\`\`\`elixir
alias WeaviateEx.{Collections, Property, Types.MultiTargetReference}

# Create collection with multi-target reference
{:ok, _} = Collections.create(client, "Article",
  properties: [
    Property.text("title"),
    Property.reference("hasAuthor", ["Person", "Organization"])
  ]
)

# Add reference to Person
{:ok, _} = WeaviateEx.API.References.add(client, "Article", article_uuid, "hasAuthor",
  MultiTargetReference.new("Person", person_uuid)
)

# Add reference to Organization
{:ok, _} = WeaviateEx.API.References.add(client, "Article", article_uuid, "hasAuthor",
  MultiTargetReference.new("Organization", org_uuid)
)

# Add multiple references at once
{:ok, _} = WeaviateEx.API.References.add_many(client, "Article", article_uuid, "hasAuthor", [
  MultiTargetReference.new("Person", person1_uuid),
  MultiTargetReference.new("Person", person2_uuid),
  MultiTargetReference.new("Organization", org_uuid)
])
\`\`\`
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- `WeaviateEx.Types.MultiTargetReference` for multi-target reference operations
- `Property.reference/2` supports list of target collections
- `References.add/5` accepts `MultiTargetReference` struct
- `References.add_many/5` for batch multi-target reference additions
- `WeaviateEx.Types.Beacon` for parsing beacon URLs
- Target collection included in reference responses
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New multi-target tests pass
- [ ] Integration tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `MultiTargetReference` struct implemented
2. `Property.reference/2` accepts list of collections
3. Reference operations handle `MultiTargetReference`
4. Beacon parsing extracts target collection
5. Reference responses include target collection
6. Integration tests verify end-to-end functionality
7. All quality gates pass
