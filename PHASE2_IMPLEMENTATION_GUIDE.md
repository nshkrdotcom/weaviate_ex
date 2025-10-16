# WeaviateEx Phase 2+ Implementation Guide

> Complete guide for implementing Phase 2 onwards with TDD approach

---

## 📚 Required Reading (IN ORDER - ~90 minutes)

Before implementing Phase 2, you MUST read these documents to understand the complete architecture and approach:

### 1. **DESIGN_SUMMARY.md** (START HERE - 10 minutes)
   - Executive overview of the entire v2.0 vision
   - Key architectural decisions
   - Quick navigation guide

### 2. **PROGRESS_REPORT.md** (CURRENT STATUS - 15 minutes)
   - What's already implemented (Phase 0 + 50% of Phase 1)
   - Current test statistics (158 tests passing)
   - Lessons learned from Phase 0 and Phase 1
   - **IMPORTANT**: See what patterns are already working

### 3. **FEATURE_PARITY_CHECKLIST.md** (REFERENCE - 20 minutes to skim)
   - All 500+ features needed for parity
   - Current status of each feature
   - Use as reference throughout implementation
   - Refer back often to ensure nothing is missed

### 4. **ARCHITECTURE.md** (DEEP DIVE - 30 minutes)
   - Complete directory structure
   - Module organization with code examples
   - Protocol layer design patterns
   - Error handling patterns
   - **This is your blueprint**

### 5. **TEST_DESIGN.md** (TESTING PATTERNS - 25 minutes)
   - TDD approach and test structure
   - Mox mocking strategy with examples
   - Complete test examples for each component
   - Stub implementation patterns
   - **Follow these patterns exactly**

### 6. **IMPLEMENTATION_ROADMAP.md** (PHASE BREAKDOWN - 15 minutes)
   - 22-week phase-by-phase plan
   - Feature breakdown per phase
   - Success criteria for each phase
   - **Your project timeline**

**Total Reading Time: ~115 minutes** (invest this time upfront!)

---

## ✅ What's Already Complete

### Phase 0: Foundation (100% DONE)
- ✅ Test Infrastructure (Mox, Factory, Fixtures)
- ✅ Core Client Structure (Protocol, Error, Config, Client)
- ✅ Protocol Behavior Layer
- ✅ HTTP Client Stub (ready for implementation)

### Phase 1: Core Features (50% DONE)
- ✅ **Collections API** (8/8 functions, 17 tests)
  - list, get, create, delete, delete_all, update, add_property, exists?
- ✅ **Filter System** (13 operators, 26 tests)
  - Constructors: by_property, by_id, by_ref
  - Operators: equal, comparison, like, contains, geo, null
  - Combinators: all_of, any_of, not_
  - GraphQL conversion
- ✅ **Data Operations** (7/7 functions, 17 tests)
  - insert, get_by_id, update, patch, delete_by_id, exists?, validate
  - UUID generation, vectors, multi-tenancy, consistency levels

### Phase 1: Remaining (50% TODO)
- ⏳ Query Builder Enhancement
- ⏳ Batch Operations Advanced Features
- ⏳ Authentication (Bearer, OAuth2)

---

## 🎯 Implementation Strategy for Phase 2+

### Core Principles (NEVER DEVIATE FROM THESE)

1. **TDD ALWAYS** - Write test first, stub implementation, then implement
2. **ONE FEATURE AT A TIME** - Small, focused commits
3. **MOX FOR EVERYTHING** - Mock all external dependencies
4. **MAKE TESTS FAIL FIRST** - Verify tests catch the issue
5. **WATCH TESTS TURN GREEN** - Implement minimal code to pass
6. **REFACTOR CONFIDENTLY** - Tests ensure correctness
7. **FOLLOW EXISTING PATTERNS** - Look at Collections, Filter, Data modules

### The TDD Cycle (Repeat for EVERY Function)

```
┌─────────────────────────────────────────┐
│  1. Write Test (RED)                    │
│     - Test describes expected behavior  │
│     - Test will fail initially          │
│     - Use Mox to mock dependencies      │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  2. Stub Implementation (RED)           │
│     - Create function signature         │
│     - Raise "NOT IMPLEMENTED" error     │
│     - Verify test fails correctly       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  3. Implement (GREEN)                   │
│     - Write minimal code to pass test   │
│     - Run test and watch it pass        │
│     - Follow patterns from existing code│
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  4. Refactor (GREEN)                    │
│     - Improve code quality              │
│     - Tests ensure correctness          │
│     - Add documentation                 │
└──────────────┬──────────────────────────┘
               │
               ▼
          Next Function
```

---

## 📋 Phase 2: Advanced Features - P1 (Weeks 7-10)

### Goal
Implement advanced query capabilities, aggregation, RAG, and multi-tenancy.

### 2.1 Advanced Queries (Week 7)

**Create:** `lib/weaviate_ex/api/query_advanced.ex`
**Test:** `test/weaviate_ex/api/query_advanced_test.exs`

**Functions to Implement:**
```elixir
# Near Image Search
@spec near_image(Client.t(), collection_name(), binary(), opts()) :: {:ok, map()} | {:error, Error.t()}
def near_image(client, collection_name, image_data, opts \\ [])

# Near Media Search
@spec near_media(Client.t(), collection_name(), media_type(), binary(), opts()) :: {:ok, map()} | {:error, Error.t()}
def near_media(client, collection_name, media_type, media_data, opts \\ [])

# Sort with multiple fields
@spec sort(query(), [{field :: String.t(), direction :: :asc | :desc}]) :: query()
def sort(query, sort_fields)

# Group By
@spec group_by(query(), property :: String.t(), opts()) :: query()
def group_by(query, property, opts \\ [])

# Autocut
@spec autocut(query(), integer()) :: query()
def autocut(query, max_results)
```

**TDD Steps:**
1. Create test file with comprehensive test cases
2. Create module with stubbed functions (NotImplementedError)
3. Run tests - verify they fail
4. Implement one function at a time
5. Watch tests turn green
6. Refactor and document

**Example Test Pattern (follow this):**
```elixir
defmodule WeaviateEx.API.QueryAdvancedTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.QueryAdvanced
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "near_image/4" do
    test "performs image similarity search", %{client: client} do
      image_data = <<...binary data...>>

      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/graphql"
        assert body["query"] =~ "nearImage"
        {:ok, %{"data" => %{"Get" => %{"Article" => []}}}}
      end)

      assert {:ok, results} = QueryAdvanced.near_image(client, "Article", image_data)
    end

    test "handles invalid image data", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :validation_error}}
      end)

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
        QueryAdvanced.near_image(client, "Article", "invalid")
    end
  end
end
```

### 2.2 Aggregation (Week 8)

**Create:** `lib/weaviate_ex/api/aggregate.ex`
**Test:** `test/weaviate_ex/api/aggregate_test.exs`

**Functions:**
```elixir
@spec over_all(Client.t(), collection_name(), opts()) :: {:ok, map()} | {:error, Error.t()}
def over_all(client, collection_name, opts \\ [])

@spec with_near_text(Client.t(), collection_name(), String.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
def with_near_text(client, collection_name, query, opts \\ [])

@spec with_metrics(query(), [metric()]) :: query()
def with_metrics(query, metrics)
# metrics: [:count, :sum, :mean, :median, :mode, :maximum, :minimum, :top_occurrences]

@spec group_by(query(), String.t(), opts()) :: query()
def group_by(query, property, opts \\ [])
```

**Key Points:**
- Aggregation uses GraphQL Aggregate API
- Returns aggregated statistics, not individual objects
- Support for groupBy aggregations
- Follow existing Query module patterns

### 2.3 Generative Search (RAG) (Week 9)

**Create:** `lib/weaviate_ex/api/generate.ex`
**Test:** `test/weaviate_ex/api/generate_test.exs`

**Modules for Each Provider:**
- `WeaviateEx.Config.Generative.Anthropic`
- `WeaviateEx.Config.Generative.OpenAI`
- `WeaviateEx.Config.Generative.AzureOpenAI`
- `WeaviateEx.Config.Generative.Cohere`
- (13+ total providers)

**Functions:**
```elixir
@spec generate_near_text(Client.t(), collection_name(), String.t(), String.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
def generate_near_text(client, collection_name, search_query, prompt, opts \\ [])

@spec generate_near_vector(Client.t(), collection_name(), [float()], String.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
def generate_near_vector(client, collection_name, vector, prompt, opts \\ [])

# Single prompt vs grouped task
@spec with_single_prompt(query(), String.t()) :: query()
def with_single_prompt(query, prompt)

@spec with_grouped_task(query(), String.t()) :: query()
def with_grouped_task(query, task)
```

**Important:**
- RAG combines search + generation
- Each provider has different config options
- Test with mocked responses (don't call real LLMs in tests)
- Support runtime parameters (temperature, max_tokens, etc.)

### 2.4 Vector Configuration (Week 9)

**Create Module Structure:**
```
lib/weaviate_ex/config/
├── vector_index/
│   ├── hnsw.ex
│   ├── flat.ex
│   └── dynamic.ex
├── vectorizer/
│   ├── text2vec_openai.ex
│   ├── text2vec_cohere.ex
│   ├── multi2vec_clip.ex
│   └── ... (25+ vectorizers)
└── quantization/
    ├── pq.ex
    ├── bq.ex
    └── sq.ex
```

**Pattern for Each Vectorizer:**
```elixir
defmodule WeaviateEx.Config.Vectorizer.Text2VecOpenAI do
  @moduledoc """
  Configuration for text2vec-openai vectorizer.
  """

  @type t :: %__MODULE__{
    model: String.t(),
    model_version: String.t() | nil,
    type: String.t() | nil,
    base_url: String.t() | nil
  }

  defstruct [
    model: "ada",
    model_version: nil,
    type: "text",
    base_url: nil
  ]

  @spec new(opts :: keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = config) do
    # Convert to Weaviate API format
  end
end
```

### 2.5 Multi-Tenancy (Week 10)

**Enhance:** `lib/weaviate_ex/api/tenants.ex` (already exists, enhance it)
**Test:** `test/weaviate_ex/api/tenants_test.exs`

**Functions to Complete:**
```elixir
@spec get(Client.t(), collection_name(), tenant_name :: String.t()) :: {:ok, map()} | {:error, Error.t()}
def get(client, collection_name, tenant_name)

@spec update(Client.t(), collection_name(), tenant_name :: String.t(), updates :: map()) :: {:ok, map()} | {:error, Error.t()}
def update(client, collection_name, tenant_name, updates)

@spec update_activity_status(Client.t(), collection_name(), tenant_name :: String.t(), status :: atom()) :: {:ok, map()} | {:error, Error.t()}
def update_activity_status(client, collection_name, tenant_name, status)
# status: :active | :inactive | :hot | :cold
```

### 2.6 Backups (Week 10)

**Create:** `lib/weaviate_ex/api/backup.ex`
**Test:** `test/weaviate_ex/api/backup_test.exs`

**Functions:**
```elixir
@spec create(Client.t(), backup_id :: String.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
def create(client, backup_id, opts \\ [])

@spec restore(Client.t(), backup_id :: String.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
def restore(client, backup_id, opts \\ [])

@spec get_create_status(Client.t(), backend :: String.t(), backup_id :: String.t()) :: {:ok, map()} | {:error, Error.t()}
def get_create_status(client, backend, backup_id)

@spec get_restore_status(Client.t(), backend :: String.t(), backup_id :: String.t()) :: {:ok, map()} | {:error, Error.t()}
def get_restore_status(client, backend, backup_id)

@spec cancel(Client.t(), backend :: String.t(), backup_id :: String.t()) :: {:ok, map()} | {:error, Error.t()}
def cancel(client, backend, backup_id)
```

**Backends to Support:**
- Filesystem
- S3 (AWS)
- GCS (Google Cloud)
- Azure

---

## 📝 Daily Workflow (Follow This Every Day)

### Morning Checklist
```bash
# 1. Pull latest changes (if working in team)
git pull

# 2. Run all tests
mix test

# 3. Check code quality
mix format --check-formatted
mix credo

# 4. Check types
mix dialyzer
```

### Development Cycle (Repeat for Each Function)
```bash
# 1. Create feature branch
git checkout -b feature/aggregation-api

# 2. Write test for ONE function
# Edit: test/weaviate_ex/api/aggregate_test.exs
# Add ONE test for ONE function

# 3. Run test (should fail)
mix test test/weaviate_ex/api/aggregate_test.exs:42

# 4. Create stub or implement function
# Edit: lib/weaviate_ex/api/aggregate.ex

# 5. Run test (should pass)
mix test test/weaviate_ex/api/aggregate_test.exs:42

# 6. Run all tests (ensure no regressions)
mix test

# 7. Format code
mix format

# 8. Commit (small, focused commit)
git add .
git commit -m "feat: implement Aggregate.over_all/3 with tests"

# 9. Repeat for next function
```

### End of Day
```bash
# 1. Run full test suite
mix test

# 2. Check coverage
mix test --cover

# 3. Format code
mix format

# 4. Push changes
git push origin feature/aggregation-api

# 5. Update PROGRESS_REPORT.md
# Add: "Completed Aggregation.over_all/3 - 5 tests passing"
```

---

## 🎯 Success Criteria for Each Phase

### Phase 2 Complete When:
- [ ] All advanced query types implemented (near_image, near_media, sort, group_by, autocut)
- [ ] Complete aggregation API (over_all, with metrics, group_by)
- [ ] RAG/Generative search for all 13+ providers
- [ ] All 25+ vectorizer configurations
- [ ] Complete multi-tenancy (CRUD + status management)
- [ ] Backup operations for all backends (filesystem, S3, GCS, Azure)
- [ ] All RBAC and user management functions
- [ ] ~300+ tests passing total

### Ongoing Quality Checks
- [ ] `mix test` - all tests passing
- [ ] `mix test --cover` - coverage > 95%
- [ ] `mix dialyzer` - no errors
- [ ] `mix credo` - no warnings
- [ ] `mix format --check-formatted` - code formatted
- [ ] All functions have `@doc` with examples
- [ ] All functions have `@spec` type specifications

---

## 🚨 CRITICAL Rules (Never Break These)

### ALWAYS:
1. **Write the test first** - No exceptions, ever
2. **Make it fail** - Verify test catches the problem
3. **Make it pass** - Minimal implementation to pass
4. **Make it right** - Refactor with confidence
5. **Commit often** - Small, focused commits
6. **Follow patterns** - Look at Collections, Filter, Data modules
7. **Document everything** - `@doc`, `@spec`, examples

### NEVER:
1. **Skip tests** - Every function needs tests
2. **Implement without test** - No cowboy coding
3. **Push failing tests** - All tests must pass
4. **Ignore Dialyzer** - Fix type issues immediately
5. **Leave NotImplementedError** - Complete what you start
6. **Commit without formatting** - Always run `mix format`
7. **Deviate from architecture** - Follow ARCHITECTURE.md

---

## 📖 Code Examples & Patterns

### Pattern 1: Simple API Function with Mox Test

**Test:**
```elixir
describe "get_metadata/2" do
  test "retrieves cluster metadata", %{client: client} do
    Mox.expect(Mock, :request, fn _client, :get, "/v1/meta", nil, _opts ->
      {:ok, %{"version" => "1.28.1", "modules" => %{}}}
    end)

    assert {:ok, meta} = Module.get_metadata(client)
    assert meta["version"] == "1.28.1"
  end

  test "handles connection errors", %{client: client} do
    Mox.expect(Mock, :request, fn _client, :get, "/v1/meta", nil, _opts ->
      {:error, %WeaviateEx.Error{type: :connection_error}}
    end)

    assert {:error, %WeaviateEx.Error{type: :connection_error}} =
      Module.get_metadata(client)
  end
end
```

**Implementation:**
```elixir
@doc """
Get cluster metadata.

## Examples

    {:ok, meta} = Module.get_metadata(client)

## Returns
  * `{:ok, map()}` - Cluster metadata
  * `{:error, Error.t()}` - Error if request fails
"""
@spec get_metadata(Client.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
def get_metadata(client, opts \\ []) do
  Client.request(client, :get, "/v1/meta", nil, opts)
end
```

### Pattern 2: Complex Query Builder

**Test:**
```elixir
test "builds complex query with multiple modifiers" do
  query = Query.new("Article")
    |> Query.with_near_text("AI", certainty: 0.7)
    |> Query.with_where(Filter.greater_than("views", 100))
    |> Query.with_limit(10)
    |> Query.with_fields(["title", "content"])
    |> Query.with_additional(["certainty"])

  graphql = Query.to_graphql(query)

  assert graphql =~ "nearText"
  assert graphql =~ "where"
  assert graphql =~ "limit: 10"
end
```

**Implementation:**
```elixir
defstruct [:collection_name, :near_text, :where, :limit, :fields, :additional]

@spec with_near_text(t(), String.t(), opts()) :: t()
def with_near_text(%__MODULE__{} = query, text, opts \\ []) do
  %{query | near_text: {text, opts}}
end

@spec to_graphql(t()) :: String.t()
def to_graphql(%__MODULE__{} = query) do
  # Build GraphQL query string
end
```

### Pattern 3: Configuration Builder

**Test:**
```elixir
test "builds HNSW configuration" do
  config = HNSW.new(
    distance_metric: :cosine,
    ef: 100,
    ef_construction: 128,
    max_connections: 64
  )

  assert config.distance_metric == :cosine
  assert config.ef == 100

  map = HNSW.to_map(config)
  assert map["distance"] == "cosine"
  assert map["ef"] == 100
end
```

**Implementation:**
```elixir
defstruct [
  distance_metric: :cosine,
  ef: 100,
  ef_construction: 128,
  max_connections: 64
]

@spec new(opts()) :: t()
def new(opts \\ []) do
  struct(__MODULE__, opts)
end

@spec to_map(t()) :: map()
def to_map(%__MODULE__{} = config) do
  %{
    "distance" => distance_to_string(config.distance_metric),
    "ef" => config.ef,
    "efConstruction" => config.ef_construction,
    "maxConnections" => config.max_connections
  }
end
```

---

## 🎬 START IMPLEMENTING

Ready to begin Phase 2? Follow these steps:

### Step 1: Review Existing Code (30 minutes)
Study these completed modules to understand patterns:
- `lib/weaviate_ex/api/collections.ex`
- `lib/weaviate_ex/filter.ex`
- `lib/weaviate_ex/api/data.ex`
- Their corresponding test files

### Step 2: Choose Your Starting Point
Pick ONE module from Phase 2 to start:
- Advanced Queries (if you like search features)
- Aggregation (if you like analytics)
- RAG/Generative (if you like AI features)
- Multi-Tenancy (if you like infrastructure)
- Backups (if you like operational features)

### Step 3: Create Branch
```bash
git checkout -b feature/phase2-[module-name]
```

### Step 4: Start TDD Cycle
1. Create test file
2. Write ONE test for ONE function
3. Run test (watch it fail)
4. Create stub implementation
5. Run test (still fails)
6. Implement function
7. Run test (watch it pass!)
8. Refactor
9. Commit
10. Repeat for next function

### Step 5: Track Progress
Update `PROGRESS_REPORT.md` after each completed module.

---

## 🆘 Need Help?

If you get stuck:
1. **Re-read TEST_DESIGN.md** for testing patterns
2. **Re-read ARCHITECTURE.md** for design guidance
3. **Look at existing modules** (Collections, Filter, Data)
4. **Check FEATURE_PARITY_CHECKLIST.md** for requirements
5. **Review weaviate-python-client source code** on GitHub
6. **Ask for clarification** on specific implementation details

---

## 🎉 Let's Continue Building!

You have:
- ✅ Solid foundation (Phase 0 complete)
- ✅ 50% of Phase 1 done (158 tests passing)
- ✅ Proven TDD approach
- ✅ Clear patterns to follow
- ✅ Complete documentation

**Start with Phase 2, Section 2.1 (Advanced Queries). Write tests first. Make them fail. Make them pass. Repeat.**

Good luck! 🚀
