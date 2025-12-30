# Prompt - Multi-Modal Search APIs

## Objective

Implement high-level APIs for multi-modal search: `near_image`, `near_audio`, `near_video`, `near_thermal`, `near_depth`, and `near_imu`. These enable searching with non-text modalities.

## Priority

P1 - High (Feature completeness)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/02-grpc-services.md`
- `README.md` (search section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/query.ex` - Main query module
- `lib/weaviate_ex/query/near_image.ex` - Existing near_image (if exists)
- `lib/weaviate_ex/query/near_media.ex` - Existing near_media
- `lib/weaviate_ex/grpc/services/search.ex` - gRPC search
- `lib/weaviate_ex/api/vectorizers/multi2vec_*.ex` - Multi-modal vectorizers
- `test/weaviate_ex/query_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/queries/near_media.py`
- `../weaviate-python-client/weaviate/collections/classes/internal.py` - MediaType enum

## Context

### Current State
- `near_text` and `near_vector` fully implemented
- `near_media` exists but may not have convenience wrappers
- Multi-modal vectorizers configured but search APIs incomplete

### Gap
Python provides dedicated methods for each modality:
```python
collection.query.near_image(image_path_or_base64)
collection.query.near_audio(audio_path_or_base64)
collection.query.near_video(video_path_or_base64)
```

### Media Types Supported
- `image` - JPEG, PNG, GIF, WebP
- `audio` - WAV, MP3, FLAC
- `video` - MP4, WebM
- `thermal` - Thermal imaging data
- `depth` - Depth map data
- `imu` - IMU sensor data

## Implementation Instructions (TDD Required)

### Step 1: Create Media Type Module

Create `lib/weaviate_ex/types/media_type.ex`:

```elixir
defmodule WeaviateEx.Types.MediaType do
  @moduledoc """
  Supported media types for multi-modal search.
  """

  @type t :: :image | :audio | :video | :thermal | :depth | :imu

  @media_types [:image, :audio, :video, :thermal, :depth, :imu]

  def valid?(type), do: type in @media_types

  def all, do: @media_types

  def to_grpc_field(:image), do: :image
  def to_grpc_field(:audio), do: :audio
  def to_grpc_field(:video), do: :video
  def to_grpc_field(:thermal), do: :thermal
  def to_grpc_field(:depth), do: :depth
  def to_grpc_field(:imu), do: :imu
end
```

### Step 2: Create Media Input Handler

Create `lib/weaviate_ex/types/media_input.ex`:

```elixir
defmodule WeaviateEx.Types.MediaInput do
  @moduledoc """
  Handles media input for multi-modal search.
  Accepts file paths, base64 strings, or raw binary data.
  """

  @type input :: String.t() | binary()

  @doc """
  Prepares media input for API request.

  ## Examples

      # From file path
      MediaInput.prepare("/path/to/image.jpg")

      # From base64 string
      MediaInput.prepare("data:image/jpeg;base64,/9j/4AAQ...")

      # From raw binary
      MediaInput.prepare(<<0xFF, 0xD8, 0xFF, ...>>)
  """
  @spec prepare(input()) :: {:ok, String.t()} | {:error, term()}
  def prepare(input) when is_binary(input) do
    cond do
      File.exists?(input) -> read_and_encode(input)
      base64?(input) -> {:ok, strip_data_uri(input)}
      true -> {:ok, Base.encode64(input)}
    end
  end

  defp read_and_encode(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, Base.encode64(data)}
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  defp base64?(str), do: String.starts_with?(str, "data:") or valid_base64?(str)

  defp valid_base64?(str) do
    case Base.decode64(str) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp strip_data_uri(str) do
    case String.split(str, ",", parts: 2) do
      [_, data] -> data
      [data] -> data
    end
  end
end
```

### Step 3: Add Convenience Methods to Query

Update `lib/weaviate_ex/query.ex`:

```elixir
defmodule WeaviateEx.Query do
  alias WeaviateEx.Types.{MediaType, MediaInput}

  @doc """
  Searches by image similarity.

  ## Examples

      Query.get("Products")
      |> Query.near_image("/path/to/image.jpg")
      |> Query.limit(10)
      |> Query.execute(client)
  """
  @spec near_image(t(), String.t() | binary(), keyword()) :: t()
  def near_image(query, image, opts \\ []) do
    near_media(query, :image, image, opts)
  end

  @doc """
  Searches by audio similarity.
  """
  @spec near_audio(t(), String.t() | binary(), keyword()) :: t()
  def near_audio(query, audio, opts \\ []) do
    near_media(query, :audio, audio, opts)
  end

  @doc """
  Searches by video similarity.
  """
  @spec near_video(t(), String.t() | binary(), keyword()) :: t()
  def near_video(query, video, opts \\ []) do
    near_media(query, :video, video, opts)
  end

  @doc """
  Searches by thermal image similarity.
  """
  @spec near_thermal(t(), String.t() | binary(), keyword()) :: t()
  def near_thermal(query, thermal, opts \\ []) do
    near_media(query, :thermal, thermal, opts)
  end

  @doc """
  Searches by depth map similarity.
  """
  @spec near_depth(t(), String.t() | binary(), keyword()) :: t()
  def near_depth(query, depth, opts \\ []) do
    near_media(query, :depth, depth, opts)
  end

  @doc """
  Searches by IMU data similarity.
  """
  @spec near_imu(t(), String.t() | binary(), keyword()) :: t()
  def near_imu(query, imu, opts \\ []) do
    near_media(query, :imu, imu, opts)
  end

  @doc """
  Generic multi-modal search.
  """
  @spec near_media(t(), MediaType.t(), String.t() | binary(), keyword()) :: t()
  def near_media(query, media_type, media, opts \\ []) do
    with true <- MediaType.valid?(media_type),
         {:ok, encoded} <- MediaInput.prepare(media) do
      %{query |
        near_media: %{
          type: media_type,
          data: encoded,
          certainty: opts[:certainty],
          distance: opts[:distance],
          target_vectors: opts[:target_vectors]
        }
      }
    else
      false -> raise ArgumentError, "Invalid media type: #{media_type}"
      {:error, reason} -> raise ArgumentError, "Failed to prepare media: #{inspect(reason)}"
    end
  end
end
```

### Step 4: Update gRPC Search

Update `lib/weaviate_ex/grpc/services/search.ex`:

```elixir
defp build_near_media(%{type: type, data: data} = config) do
  field = MediaType.to_grpc_field(type)

  %NearMedia{
    media: data,
    type: field,
    certainty: config[:certainty],
    distance: config[:distance],
    target_vectors: config[:target_vectors]
  }
end
```

### Step 5: Add HTTP Fallback

For servers without gRPC, add HTTP support:

```elixir
defmodule WeaviateEx.API.Search do
  def near_media(client, collection, media_type, media_data, opts) do
    body = %{
      "nearMedia" => %{
        media_type => media_data,
        "certainty" => opts[:certainty],
        "distance" => opts[:distance]
      }
    }
    # ... execute HTTP request
  end
end
```

## Tests to Write

### MediaInput Tests (`test/weaviate_ex/types/media_input_test.exs`)

```elixir
describe "prepare/1" do
  test "reads and encodes file path"
  test "strips data URI prefix from base64"
  test "encodes raw binary to base64"
  test "returns error for non-existent file"
  test "handles already-encoded base64"
end
```

### Query Multi-Modal Tests (`test/weaviate_ex/query_test.exs`)

```elixir
describe "near_image/3" do
  test "builds query with image data"
  test "accepts file path"
  test "accepts base64 string"
  test "accepts raw binary"
  test "passes certainty option"
  test "passes target_vectors option"
end

describe "near_audio/3" do
  test "builds query with audio data"
end

describe "near_video/3" do
  test "builds query with video data"
end

describe "near_media/4" do
  test "rejects invalid media type"
  test "handles file read errors gracefully"
end
```

### Integration Tests

```elixir
@tag :integration
@tag :multimodal
describe "multi-modal search" do
  setup do
    # Create collection with multi2vec-clip vectorizer
  end

  test "near_image returns similar images"
  test "near_audio returns similar audio"
  test "near_video returns similar video"
end
```

## Docs Updates

### README.md

Add multi-modal search section:

```markdown
### Multi-Modal Search

Search by image, audio, video, and other media types:

\`\`\`elixir
# Search by image (file path)
{:ok, results} = WeaviateEx.Query.get("Products")
|> WeaviateEx.Query.near_image("/path/to/query.jpg")
|> WeaviateEx.Query.limit(10)
|> WeaviateEx.Query.execute(client)

# Search by image (base64)
{:ok, results} = WeaviateEx.Query.get("Products")
|> WeaviateEx.Query.near_image(base64_image_data)
|> WeaviateEx.Query.execute(client)

# Search by audio
{:ok, results} = WeaviateEx.Query.get("Podcasts")
|> WeaviateEx.Query.near_audio("/path/to/clip.mp3")
|> WeaviateEx.Query.execute(client)

# Search by video
{:ok, results} = WeaviateEx.Query.get("Videos")
|> WeaviateEx.Query.near_video("/path/to/clip.mp4")
|> WeaviateEx.Query.execute(client)

# With options
{:ok, results} = WeaviateEx.Query.get("Products")
|> WeaviateEx.Query.near_image(image, certainty: 0.8, target_vectors: ["image_vector"])
|> WeaviateEx.Query.execute(client)
\`\`\`

**Supported modalities:** image, audio, video, thermal, depth, imu

**Note:** Requires a multi-modal vectorizer (e.g., `multi2vec-clip`).
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- `Query.near_image/3` for image similarity search
- `Query.near_audio/3` for audio similarity search
- `Query.near_video/3` for video similarity search
- `Query.near_thermal/3` for thermal image search
- `Query.near_depth/3` for depth map search
- `Query.near_imu/3` for IMU data search
- `WeaviateEx.Types.MediaInput` for flexible media input handling
- `WeaviateEx.Types.MediaType` for media type validation

### Changed
- `Query.near_media/4` now accepts file paths, base64, and raw binary
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New multi-modal tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `near_image/3`, `near_audio/3`, `near_video/3` methods exist
2. `near_thermal/3`, `near_depth/3`, `near_imu/3` methods exist
3. File paths automatically read and encoded
4. Base64 strings properly handled
5. Raw binary data encoded
6. Options (certainty, distance, target_vectors) passed correctly
7. All quality gates pass
