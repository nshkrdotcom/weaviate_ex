defmodule WeaviateEx.Types.Vector do
  @moduledoc """
  Vector type with multi-dimensional support for ColBERT and other advanced models.

  Supports both standard 1D vectors and multi-dimensional vectors (2D arrays)
  used by models like ColBERT for late interaction retrieval.

  ## Standard Vectors

  Most embeddings are 1D vectors:

      vector = [0.1, 0.2, 0.3, 0.4]
      Vector.validate(vector)
      # => :ok

      Vector.shape(vector)
      # => {4}

  ## Multi-Dimensional Vectors

  Some models like ColBERT produce multi-dimensional vectors:

      multi_vector = [[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]]
      Vector.validate(multi_vector)
      # => :ok

      Vector.shape(multi_vector)
      # => {3, 2}
  """

  @type t :: list(float()) | list(list(float()))

  @doc """
  Validates a vector or multi-dimensional vector.

  ## Examples

      Vector.validate([0.1, 0.2, 0.3])
      # => :ok

      Vector.validate([[0.1, 0.2], [0.3, 0.4]])
      # => :ok

      Vector.validate([])
      # => {:error, "Vector cannot be empty"}

      Vector.validate([[0.1, 0.2], [0.3]])
      # => {:error, "Multi-dimensional vectors must have consistent inner dimensions"}
  """
  @spec validate(term()) :: :ok | {:error, String.t()}
  def validate(vector) when is_list(vector) do
    cond do
      vector == [] ->
        {:error, "Vector cannot be empty"}

      # 1D vector (standard)
      Enum.all?(vector, &is_number/1) ->
        :ok

      # 2D vector (multi-dimensional, e.g., ColBERT)
      all_lists?(vector) and all_numeric_lists?(vector) ->
        validate_multi_dimensional(vector)

      true ->
        {:error, "Invalid vector format: must be list of numbers or list of lists of numbers"}
    end
  end

  def validate(_), do: {:error, "Vector must be a list"}

  defp all_lists?(vector) do
    Enum.all?(vector, &is_list/1)
  end

  defp all_numeric_lists?(vector) do
    Enum.all?(vector, fn inner -> Enum.all?(inner, &is_number/1) end)
  end

  defp validate_multi_dimensional(vectors) do
    dimensions = Enum.map(vectors, &length/1)

    if Enum.uniq(dimensions) == [hd(dimensions)] do
      :ok
    else
      {:error, "Multi-dimensional vectors must have consistent inner dimensions"}
    end
  end

  @doc """
  Returns the shape of a vector.

  ## Examples

      Vector.shape([0.1, 0.2, 0.3, 0.4])
      # => {4}

      Vector.shape([[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]])
      # => {3, 2}
  """
  @spec shape(t()) :: {non_neg_integer()} | {non_neg_integer(), non_neg_integer()}
  def shape(vector) when is_list(vector) do
    case vector do
      [] ->
        {0}

      [first | _] when is_list(first) ->
        {length(vector), length(first)}

      _ ->
        {length(vector)}
    end
  end

  @doc """
  Checks if a vector is 1-dimensional.

  ## Examples

      Vector.one_dimensional?([0.1, 0.2, 0.3])
      # => true

      Vector.one_dimensional?([[0.1, 0.2], [0.3, 0.4]])
      # => false
  """
  @spec one_dimensional?(t()) :: boolean()
  def one_dimensional?([first | _]) when is_number(first), do: true
  def one_dimensional?([]), do: true
  def one_dimensional?(_), do: false

  @doc """
  Checks if a vector is multi-dimensional.

  ## Examples

      Vector.multi_dimensional?([[0.1, 0.2], [0.3, 0.4]])
      # => true

      Vector.multi_dimensional?([0.1, 0.2, 0.3])
      # => false
  """
  @spec multi_dimensional?(t()) :: boolean()
  def multi_dimensional?([first | _]) when is_list(first), do: true
  def multi_dimensional?(_), do: false

  @doc """
  Returns the dimensionality of a vector.

  For 1D vectors, returns the length.
  For multi-dimensional vectors, returns the inner dimension.

  ## Examples

      Vector.dimensionality([0.1, 0.2, 0.3])
      # => 3

      Vector.dimensionality([[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]])
      # => 2
  """
  @spec dimensionality(t()) :: non_neg_integer()
  def dimensionality([]), do: 0

  def dimensionality([first | _]) when is_list(first), do: length(first)

  def dimensionality(vector), do: length(vector)

  @doc """
  Normalizes a vector to unit length (L2 normalization).

  ## Examples

      Vector.normalize([3.0, 4.0])
      # => [0.6, 0.8]
  """
  @spec normalize(list(float())) :: list(float())
  def normalize(vector) when is_list(vector) do
    magnitude = :math.sqrt(Enum.reduce(vector, 0, fn x, acc -> acc + x * x end))

    if magnitude == 0 do
      vector
    else
      Enum.map(vector, &(&1 / magnitude))
    end
  end

  @doc """
  Computes the dot product of two vectors.

  ## Examples

      Vector.dot_product([1.0, 2.0], [3.0, 4.0])
      # => 11.0
  """
  @spec dot_product(list(float()), list(float())) :: float()
  def dot_product(v1, v2) when length(v1) == length(v2) do
    Enum.zip(v1, v2)
    |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
  end

  @doc """
  Computes the cosine similarity between two vectors.

  ## Examples

      Vector.cosine_similarity([1.0, 0.0], [0.0, 1.0])
      # => 0.0

      Vector.cosine_similarity([1.0, 0.0], [1.0, 0.0])
      # => 1.0
  """
  @spec cosine_similarity(list(float()), list(float())) :: float()
  def cosine_similarity(v1, v2) do
    dot = dot_product(v1, v2)
    mag1 = :math.sqrt(Enum.reduce(v1, 0, fn x, acc -> acc + x * x end))
    mag2 = :math.sqrt(Enum.reduce(v2, 0, fn x, acc -> acc + x * x end))

    if mag1 == 0 or mag2 == 0 do
      0.0
    else
      dot / (mag1 * mag2)
    end
  end
end
