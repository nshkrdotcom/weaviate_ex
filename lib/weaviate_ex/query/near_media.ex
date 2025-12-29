defmodule WeaviateEx.Query.NearMedia do
  @moduledoc """
  Media-based vector search for multimodal collections.

  Supports audio, video, thermal, depth, and IMU data types for
  multi2vec-bind and similar multimodal vectorizers.

  ## Supported Media Types

    * `:audio` - Audio files (wav, mp3, etc.)
    * `:video` - Video files (mp4, avi, etc.)
    * `:thermal` - Thermal imaging data
    * `:depth` - Depth sensor data
    * `:imu` - Inertial measurement unit data

  ## Examples

      # Search by audio
      NearMedia.new(:audio, media: base64_audio)
      |> Query.execute(client, "MediaCollection")

      # Search by video file
      NearMedia.new(:video, media_file: "/path/to/video.mp4", certainty: 0.8)

      # Using the Query builder
      Query.get("MediaCollection")
      |> Query.near_media(:audio, media: base64_audio, certainty: 0.7)
      |> Query.fields(["name", "description"])
      |> Query.execute(client)
  """

  @media_types [:audio, :video, :thermal, :depth, :imu]

  @type media_type :: :audio | :video | :thermal | :depth | :imu

  @type t :: %__MODULE__{
          type: media_type(),
          media: String.t() | nil,
          media_file: String.t() | nil,
          certainty: float() | nil,
          distance: float() | nil,
          target_vectors: [String.t()] | nil
        }

  @enforce_keys [:type]
  defstruct [:type, :media, :media_file, :certainty, :distance, :target_vectors]

  @doc """
  Returns the list of supported media types.

  ## Examples

      NearMedia.media_types()
      # => [:audio, :video, :thermal, :depth, :imu]
  """
  @spec media_types() :: [media_type()]
  def media_types, do: @media_types

  @doc """
  Create a new near_media search configuration.

  ## Arguments

    * `type` - Media type: `:audio`, `:video`, `:thermal`, `:depth`, or `:imu`
    * `opts` - Keyword options

  ## Options

    * `:media` - Base64-encoded media data
    * `:media_file` - Path to media file (will be read and base64 encoded)
    * `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    * `:distance` - Maximum distance threshold
    * `:target_vectors` - List of named vectors to target

  Either `:media` or `:media_file` must be provided, but not both.

  ## Examples

      NearMedia.new(:audio, media: base64_audio)
      NearMedia.new(:video, media_file: "/path/to/video.mp4", certainty: 0.8)
      NearMedia.new(:thermal, media: data, target_vectors: ["thermal_vector"])
  """
  @spec new(media_type(), keyword()) :: t()
  def new(type, opts) when type in @media_types do
    media = Keyword.get(opts, :media)
    media_file = Keyword.get(opts, :media_file)

    cond do
      is_nil(media) and is_nil(media_file) ->
        raise ArgumentError, "must provide either :media or :media_file option"

      not is_nil(media) and not is_nil(media_file) ->
        raise ArgumentError, "cannot provide both :media and :media_file options"

      true ->
        %__MODULE__{
          type: type,
          media: media,
          media_file: media_file,
          certainty: Keyword.get(opts, :certainty),
          distance: Keyword.get(opts, :distance),
          target_vectors: Keyword.get(opts, :target_vectors)
        }
    end
  end

  def new(type, _opts) do
    raise ArgumentError,
          "invalid media type: #{inspect(type)}. Must be one of: #{inspect(@media_types)}"
  end

  @doc """
  Encode a media file to base64.

  ## Examples

      NearMedia.encode_media_file("/path/to/audio.wav")
      # => "UklGRi4A..." (WAV header as base64)
  """
  @spec encode_media_file(String.t()) :: String.t()
  def encode_media_file(path) do
    path
    |> File.read!()
    |> Base.encode64()
  end

  @doc """
  Get the base64-encoded media data, reading from file if necessary.

  If the struct was created with `:media`, returns it as-is.
  If the struct was created with `:media_file`, reads and encodes the file.

  ## Examples

      near_media = NearMedia.new(:audio, media: "base64data")
      NearMedia.get_encoded_media(near_media)
      # => "base64data"

      near_media = NearMedia.new(:audio, media_file: "/path/to/audio.wav")
      NearMedia.get_encoded_media(near_media)
      # => "UklGRi4A..." (file contents as base64)
  """
  @spec get_encoded_media(t()) :: String.t()
  def get_encoded_media(%__MODULE__{media: media}) when not is_nil(media), do: media
  def get_encoded_media(%__MODULE__{media_file: path}), do: encode_media_file(path)

  @grpc_type_map %{
    audio: :MEDIA_TYPE_AUDIO,
    video: :MEDIA_TYPE_VIDEO,
    thermal: :MEDIA_TYPE_THERMAL,
    depth: :MEDIA_TYPE_DEPTH,
    imu: :MEDIA_TYPE_IMU
  }

  @doc """
  Convert to gRPC NearMediaSearch format.

  Returns a map suitable for use with the gRPC search API.
  The media type is converted to the gRPC enum format (e.g., `:MEDIA_TYPE_AUDIO`).
  Nil values are excluded from the result.

  ## Examples

      near_media = NearMedia.new(:thermal, media: "data", certainty: 0.8)
      NearMedia.to_grpc(near_media)
      # => %{media: "data", type: :MEDIA_TYPE_THERMAL, certainty: 0.8}
  """
  @spec to_grpc(t()) :: map()
  def to_grpc(%__MODULE__{} = near_media) do
    %{
      media: get_encoded_media(near_media),
      type: Map.fetch!(@grpc_type_map, near_media.type),
      certainty: near_media.certainty,
      distance: near_media.distance,
      target_vectors: near_media.target_vectors
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc """
  Convert to GraphQL query format.

  Returns a map with string keys suitable for GraphQL nearMedia queries.
  The media type is converted to a lowercase string (e.g., "audio").
  Nil values are excluded from the result.

  ## Examples

      near_media = NearMedia.new(:depth, media: "data", distance: 0.2)
      NearMedia.to_graphql(near_media)
      # => %{"media" => "data", "type" => "depth", "distance" => 0.2}
  """
  @spec to_graphql(t()) :: map()
  def to_graphql(%__MODULE__{} = near_media) do
    %{
      "media" => get_encoded_media(near_media),
      "type" => Atom.to_string(near_media.type),
      "certainty" => near_media.certainty,
      "distance" => near_media.distance,
      "targetVectors" => near_media.target_vectors
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
