defmodule WeaviateEx.Query.NearImage do
  @moduledoc """
  Image-based vector search for multimodal collections.

  Supports multi2vec-clip, multi2vec-bind, and other image vectorizers.

  ## Examples

      # Search by base64 encoded image
      NearImage.new(image: base64_data)
      |> Query.execute(client, "ImageCollection")

      # Search by file path
      NearImage.new(image_file: "/path/to/image.png", certainty: 0.8)
      |> Query.execute(client, "ImageCollection")

      # With named vectors
      NearImage.new(image: data, target_vectors: ["image_vector"])

      # Using the Query builder
      Query.get("ImageCollection")
      |> Query.near_image(image: base64_data, certainty: 0.8)
      |> Query.fields(["name", "description"])
      |> Query.execute(client)
  """

  @type t :: %__MODULE__{
          image: String.t() | nil,
          image_file: String.t() | nil,
          certainty: float() | nil,
          distance: float() | nil,
          target_vectors: [String.t()] | nil
        }

  @enforce_keys []
  defstruct [:image, :image_file, :certainty, :distance, :target_vectors]

  @doc """
  Create a new near_image search configuration.

  ## Options

    * `:image` - Base64-encoded image data
    * `:image_file` - Path to image file (will be read and base64 encoded)
    * `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    * `:distance` - Maximum distance threshold
    * `:target_vectors` - List of named vectors to target

  Either `:image` or `:image_file` must be provided, but not both.

  ## Examples

      NearImage.new(image: "base64encodeddata==")
      NearImage.new(image_file: "/path/to/image.png", certainty: 0.8)
      NearImage.new(image: data, target_vectors: ["image_vector"])
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    image = Keyword.get(opts, :image)
    image_file = Keyword.get(opts, :image_file)

    cond do
      is_nil(image) and is_nil(image_file) ->
        raise ArgumentError, "must provide either :image or :image_file option"

      not is_nil(image) and not is_nil(image_file) ->
        raise ArgumentError, "cannot provide both :image and :image_file options"

      true ->
        %__MODULE__{
          image: image,
          image_file: image_file,
          certainty: Keyword.get(opts, :certainty),
          distance: Keyword.get(opts, :distance),
          target_vectors: Keyword.get(opts, :target_vectors)
        }
    end
  end

  @doc """
  Encode an image file to base64.

  ## Examples

      NearImage.encode_image_file("/path/to/image.png")
      # => "iVBORw0KGgo..."
  """
  @spec encode_image_file(String.t()) :: String.t()
  def encode_image_file(path) do
    path
    |> File.read!()
    |> Base.encode64()
  end

  @doc """
  Get the base64-encoded image data, reading from file if necessary.

  If the struct was created with `:image`, returns it as-is.
  If the struct was created with `:image_file`, reads and encodes the file.

  ## Examples

      near_image = NearImage.new(image: "base64data")
      NearImage.get_encoded_image(near_image)
      # => "base64data"

      near_image = NearImage.new(image_file: "/path/to/image.png")
      NearImage.get_encoded_image(near_image)
      # => "iVBORw0KGgo..." (file contents as base64)
  """
  @spec get_encoded_image(t()) :: String.t()
  def get_encoded_image(%__MODULE__{image: image}) when not is_nil(image), do: image
  def get_encoded_image(%__MODULE__{image_file: path}), do: encode_image_file(path)

  @doc """
  Convert to gRPC NearImageSearch format.

  Returns a map suitable for use with the gRPC search API.
  Nil values are excluded from the result.

  ## Examples

      near_image = NearImage.new(image: "data", certainty: 0.8)
      NearImage.to_grpc(near_image)
      # => %{image: "data", certainty: 0.8}
  """
  @spec to_grpc(t()) :: map()
  def to_grpc(%__MODULE__{} = near_image) do
    %{
      image: get_encoded_image(near_image),
      certainty: near_image.certainty,
      distance: near_image.distance,
      target_vectors: near_image.target_vectors
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc """
  Convert to GraphQL query format.

  Returns a map with string keys suitable for GraphQL nearImage queries.
  Nil values are excluded from the result.

  ## Examples

      near_image = NearImage.new(image: "data", distance: 0.2)
      NearImage.to_graphql(near_image)
      # => %{"image" => "data", "distance" => 0.2}
  """
  @spec to_graphql(t()) :: map()
  def to_graphql(%__MODULE__{} = near_image) do
    %{
      "image" => get_encoded_image(near_image),
      "certainty" => near_image.certainty,
      "distance" => near_image.distance,
      "targetVectors" => near_image.target_vectors
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
