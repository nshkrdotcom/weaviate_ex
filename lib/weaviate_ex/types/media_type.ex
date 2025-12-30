defmodule WeaviateEx.Types.MediaType do
  @moduledoc """
  Supported media types for multi-modal search.

  Weaviate supports multiple modalities for vector search including:
  - Image (JPEG, PNG, GIF, WebP)
  - Audio (WAV, MP3, FLAC)
  - Video (MP4, WebM)
  - Thermal imaging data
  - Depth map data
  - IMU (Inertial Measurement Unit) sensor data

  ## Examples

      MediaType.valid?(:image)  # => true
      MediaType.valid?(:audio)  # => true
      MediaType.valid?(:invalid)  # => false

      MediaType.all()  # => [:image, :audio, :video, :thermal, :depth, :imu]
  """

  @type t :: :image | :audio | :video | :thermal | :depth | :imu

  @media_types [:image, :audio, :video, :thermal, :depth, :imu]

  @doc """
  Checks if a media type is valid.

  ## Examples

      iex> WeaviateEx.Types.MediaType.valid?(:image)
      true

      iex> WeaviateEx.Types.MediaType.valid?(:audio)
      true

      iex> WeaviateEx.Types.MediaType.valid?(:invalid)
      false
  """
  @spec valid?(atom()) :: boolean()
  def valid?(type), do: type in @media_types

  @doc """
  Returns all supported media types.

  ## Examples

      iex> WeaviateEx.Types.MediaType.all()
      [:image, :audio, :video, :thermal, :depth, :imu]
  """
  @spec all() :: [t()]
  def all, do: @media_types

  @doc """
  Converts a media type to the corresponding gRPC field name.

  ## Examples

      iex> WeaviateEx.Types.MediaType.to_grpc_field(:image)
      :image

      iex> WeaviateEx.Types.MediaType.to_grpc_field(:audio)
      :audio
  """
  @spec to_grpc_field(t()) :: atom()
  def to_grpc_field(:image), do: :image
  def to_grpc_field(:audio), do: :audio
  def to_grpc_field(:video), do: :video
  def to_grpc_field(:thermal), do: :thermal
  def to_grpc_field(:depth), do: :depth
  def to_grpc_field(:imu), do: :imu
end
