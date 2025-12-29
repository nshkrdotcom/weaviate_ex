defmodule WeaviateEx.Generative.Parameters do
  @moduledoc """
  Parameters for generative queries with multimodal support.

  Use these structs to create typed generation parameters including
  support for images and advanced options like metadata and debug.

  ## Examples

      # Basic single prompt
      param = Parameters.single_prompt("Summarize: {content}")

      # With metadata and debug
      param = Parameters.single_prompt("Summarize: {content}",
        metadata: true,
        debug: true
      )

      # Multimodal with external images
      param = Parameters.single_prompt("Describe this image",
        images: [base64_image_data]
      )

      # Use image properties from objects
      param = Parameters.grouped_task("Compare products",
        image_properties: ["product_image"],
        non_blob_properties: ["name", "price"]
      )
  """

  # Single prompt parameters
  defmodule SinglePrompt do
    @moduledoc "Parameters for single prompt generation"

    defstruct [
      :prompt,
      :images,
      :image_properties,
      :non_blob_properties,
      metadata: false,
      debug: false
    ]

    @type t :: %__MODULE__{
            prompt: String.t(),
            images: [String.t()] | nil,
            image_properties: [String.t()] | nil,
            non_blob_properties: [String.t()] | nil,
            metadata: boolean(),
            debug: boolean()
          }
  end

  # Grouped task parameters
  defmodule GroupedTask do
    @moduledoc "Parameters for grouped task generation"

    defstruct [
      :prompt,
      :images,
      :image_properties,
      :non_blob_properties,
      metadata: false
    ]

    @type t :: %__MODULE__{
            prompt: String.t(),
            images: [String.t()] | nil,
            image_properties: [String.t()] | nil,
            non_blob_properties: [String.t()] | nil,
            metadata: boolean()
          }
  end

  @type params :: SinglePrompt.t() | GroupedTask.t()

  @doc """
  Create a single prompt parameter object.

  ## Parameters

    - `prompt` - The generation prompt with optional {property} interpolation
    - `opts` - Options:
      - `:images` - List of base64-encoded images or file paths
      - `:image_properties` - Object properties containing images
      - `:non_blob_properties` - Properties to include (excluding blobs)
      - `:metadata` - Return generation metadata (default: false)
      - `:debug` - Return debug info including full prompt (default: false)

  ## Examples

      # Basic prompt
      param = Parameters.single_prompt("Summarize: {content}")

      # With options
      param = Parameters.single_prompt("Describe this",
        images: ["base64data..."],
        metadata: true,
        debug: true
      )
  """
  @spec single_prompt(String.t(), keyword()) :: SinglePrompt.t()
  def single_prompt(prompt, opts \\ []) do
    %SinglePrompt{
      prompt: prompt,
      images: Keyword.get(opts, :images),
      image_properties: Keyword.get(opts, :image_properties),
      non_blob_properties: Keyword.get(opts, :non_blob_properties),
      metadata: Keyword.get(opts, :metadata, false),
      debug: Keyword.get(opts, :debug, false)
    }
  end

  @doc """
  Create a grouped task parameter object.

  ## Parameters

    - `prompt` - The generation prompt
    - `opts` - Options (same as single_prompt, except no debug option)

  ## Examples

      param = Parameters.grouped_task("Compare these articles about {title}")
  """
  @spec grouped_task(String.t(), keyword()) :: GroupedTask.t()
  def grouped_task(prompt, opts \\ []) do
    %GroupedTask{
      prompt: prompt,
      images: Keyword.get(opts, :images),
      image_properties: Keyword.get(opts, :image_properties),
      non_blob_properties: Keyword.get(opts, :non_blob_properties),
      metadata: Keyword.get(opts, :metadata, false)
    }
  end

  @doc """
  Convert parameters to GraphQL generate clause.

  ## Examples

      param = Parameters.single_prompt("Summarize {title}")
      clause = Parameters.to_graphql_clause(param)
      # => "singleResult: { prompt: \"\"\"Summarize {title}\"\"\" }"
  """
  @spec to_graphql_clause(params()) :: String.t()
  def to_graphql_clause(%SinglePrompt{} = param) do
    build_clause("singleResult", param.prompt, param)
  end

  def to_graphql_clause(%GroupedTask{} = param) do
    build_clause("groupedResult", param.prompt, param)
  end

  @doc """
  Extract query options from parameters.

  Returns keyword list of options that should be passed to the query.
  """
  @spec to_query_options(params()) :: keyword()
  def to_query_options(%SinglePrompt{} = param) do
    []
    |> maybe_add(:metadata, param.metadata, false)
    |> maybe_add(:debug, param.debug, false)
    |> maybe_add(:image_properties, param.image_properties, nil)
    |> maybe_add(:non_blob_properties, param.non_blob_properties, nil)
  end

  def to_query_options(%GroupedTask{} = param) do
    []
    |> maybe_add(:metadata, param.metadata, false)
    |> maybe_add(:image_properties, param.image_properties, nil)
    |> maybe_add(:non_blob_properties, param.non_blob_properties, nil)
  end

  # Private helpers

  defp build_clause(result_type, prompt, param) do
    parts = [~s(prompt: """#{prompt}""")]

    parts =
      if param.images do
        images_str = Enum.map_join(param.images, ", ", &~s("#{&1}"))
        parts ++ ["images: [#{images_str}]"]
      else
        parts
      end

    parts =
      if param.image_properties do
        props_str = Enum.map_join(param.image_properties, ", ", &~s("#{&1}"))
        parts ++ ["imageProperties: [#{props_str}]"]
      else
        parts
      end

    parts =
      if param.non_blob_properties do
        props_str = Enum.map_join(param.non_blob_properties, ", ", &~s("#{&1}"))
        parts ++ ["nonBlobProperties: [#{props_str}]"]
      else
        parts
      end

    "#{result_type}: { #{Enum.join(parts, ", ")} }"
  end

  defp maybe_add(opts, _key, value, skip_value) when value == skip_value, do: opts
  defp maybe_add(opts, key, value, _skip_value), do: Keyword.put(opts, key, value)
end
