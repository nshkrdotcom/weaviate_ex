defmodule WeaviateEx.Objects.Payload do
  @moduledoc """
  Utilities for preparing object payloads for Weaviate requests.

  These helpers keep UUID generation, key normalization, and class assignments
  consistent between the high-level `WeaviateEx.Objects` module and the lower-level
  `WeaviateEx.API.Data` module.
  """

  @type data :: map()
  @type opts :: keyword()

  @doc """
  Normalizes a payload by converting atom keys to strings and recursively normalizing
  nested maps or lists.
  """
  @spec normalize_keys(data()) :: data()
  def normalize_keys(data) when is_map(data) do
    Map.new(data, fn
      {key, value} when is_map(value) ->
        {normalize_key(key), normalize_keys(value)}

      {key, value} when is_list(value) ->
        {normalize_key(key), Enum.map(value, &normalize_nested/1)}

      {key, value} ->
        {normalize_key(key), value}
    end)
  end

  def normalize_keys(other), do: other

  @doc """
  Ensures a UUID is present on the payload. By default a new UUID is generated
  using `Uniq.UUID`. Use `auto_generate_id: false` to skip automatic generation.
  """
  @spec ensure_id(data(), opts()) :: data()
  def ensure_id(data, opts \\ []) when is_map(data) do
    cond do
      Map.has_key?(data, "id") -> data
      Map.has_key?(data, :id) -> data
      Keyword.get(opts, :auto_generate_id, true) -> Map.put(data, "id", Uniq.UUID.uuid4())
      true -> data
    end
  end

  @doc """
  Removes any existing class markers and sets the provided class on the payload.
  """
  @spec ensure_class(data(), String.t()) :: data()
  def ensure_class(data, class_name) when is_map(data) do
    data
    |> Map.delete(:class)
    |> Map.delete("class")
    |> Map.put("class", class_name)
  end

  @doc """
  Removes any existing id markers and sets the provided id on the payload.
  """
  @spec ensure_id_value(data(), String.t()) :: data()
  def ensure_id_value(data, id) when is_map(data) do
    data
    |> Map.delete(:id)
    |> Map.delete("id")
    |> Map.put("id", id)
  end

  @doc """
  Prepares a payload for insertion by normalizing keys, generating an id when
  necessary, and applying the collection class.
  """
  @spec prepare_for_insert(data(), String.t(), opts()) :: data()
  def prepare_for_insert(data, class_name, opts \\ []) do
    data
    |> normalize_keys()
    |> ensure_id(opts)
    |> ensure_class(class_name)
  end

  @doc """
  Prepares a payload for update requests by normalizing keys, forcing the id, and
  applying the collection class.
  """
  @spec prepare_for_update(data(), String.t(), String.t(), opts()) :: data()
  def prepare_for_update(data, class_name, id, opts \\ []) do
    data
    |> normalize_keys()
    |> ensure_id_value(id)
    |> ensure_class(class_name)
    |> maybe_preserve_vector(opts)
  end

  @doc """
  Normalizes a payload for patch operations (class/id handled by the server).
  """
  @spec prepare_for_patch(data()) :: data()
  def prepare_for_patch(data) do
    data
    |> normalize_keys()
    |> Map.delete("class")
    |> Map.delete("id")
  end

  defp normalize_nested(value) when is_map(value), do: normalize_keys(value)
  defp normalize_nested(value), do: value

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: key

  defp maybe_preserve_vector(data, opts) do
    case Keyword.get(opts, :keep_vector, true) do
      true -> data
      false -> Map.delete(data, "vector")
    end
  end
end
