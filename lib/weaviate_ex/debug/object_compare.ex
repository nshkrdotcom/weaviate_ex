defmodule WeaviateEx.Debug.ObjectCompare do
  @moduledoc """
  Object comparison utilities for debugging REST vs gRPC responses.

  Provides deep comparison of objects retrieved via different protocols,
  helping to identify discrepancies between REST and gRPC implementations.

  ## Example

      {:ok, rest_obj} = Debug.get_object_rest(client, "Article", uuid)
      {:ok, grpc_obj} = Debug.get_object_grpc(client, "Article", uuid)

      result = ObjectCompare.compare(rest_obj, grpc_obj)

      if result.match do
        IO.puts("Objects are identical")
      else
        IO.puts(ObjectCompare.format_diff(result.differences))
      end
  """

  @type difference :: %{
          path: [String.t()],
          rest_value: term(),
          grpc_value: term()
        }

  @type comparison_result :: %{
          match: boolean(),
          rest_object: map(),
          grpc_object: map(),
          differences: [difference()]
        }

  @doc """
  Compare two objects and return detailed comparison result.

  ## Parameters

    * `rest_object` - Object retrieved via REST API
    * `grpc_object` - Object retrieved via gRPC API

  ## Returns

  A comparison result map containing:
    * `:match` - boolean indicating if objects are identical
    * `:rest_object` - the original REST object
    * `:grpc_object` - the original gRPC object
    * `:differences` - list of differences found

  ## Example

      result = ObjectCompare.compare(rest_obj, grpc_obj)
      if result.match, do: :ok, else: handle_differences(result.differences)
  """
  @spec compare(rest_object :: map(), grpc_object :: map()) :: comparison_result()
  def compare(rest_object, grpc_object) do
    differences = diff(rest_object, grpc_object)

    %{
      match: differences == [],
      rest_object: rest_object,
      grpc_object: grpc_object,
      differences: differences
    }
  end

  @doc """
  Calculate differences between two objects.

  Returns a list of difference maps, each containing:
    * `:path` - list of keys showing where the difference is located
    * `:rest_value` - value from REST object (or `:missing`)
    * `:grpc_value` - value from gRPC object (or `:missing`)

  ## Example

      diffs = ObjectCompare.diff(rest_obj, grpc_obj)
      Enum.each(diffs, fn d ->
        IO.puts("Difference at \#{Enum.join(d.path, ".")}")
      end)
  """
  @spec diff(map(), map()) :: [difference()]
  def diff(rest_object, grpc_object) do
    diff_recursive(rest_object, grpc_object, [])
  end

  @doc """
  Format differences as a human-readable string.

  ## Example

      diffs = ObjectCompare.diff(rest_obj, grpc_obj)
      IO.puts(ObjectCompare.format_diff(diffs))
  """
  @spec format_diff([difference()]) :: String.t()
  def format_diff([]) do
    "No differences found - objects are identical"
  end

  def format_diff(differences) do
    header = "Found #{length(differences)} difference(s):\n"

    body =
      differences
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {diff, index} ->
        path = Enum.join(diff.path, ".")
        rest_val = format_value(diff.rest_value)
        grpc_val = format_value(diff.grpc_value)

        "  #{index}. #{path}\n     REST:  #{rest_val}\n     gRPC:  #{grpc_val}"
      end)

    header <> body
  end

  # Private functions

  defp diff_recursive(rest, grpc, path) when is_map(rest) and is_map(grpc) do
    all_keys = MapSet.union(MapSet.new(Map.keys(rest)), MapSet.new(Map.keys(grpc)))

    all_keys
    |> Enum.flat_map(fn key ->
      rest_val = Map.get(rest, key, :missing)
      grpc_val = Map.get(grpc, key, :missing)
      new_path = path ++ [to_string(key)]

      cond do
        rest_val == :missing and grpc_val != :missing ->
          [%{path: new_path, rest_value: :missing, grpc_value: grpc_val}]

        rest_val != :missing and grpc_val == :missing ->
          [%{path: new_path, rest_value: rest_val, grpc_value: :missing}]

        true ->
          diff_values(rest_val, grpc_val, new_path)
      end
    end)
  end

  defp diff_recursive(rest, grpc, path) do
    if rest == grpc do
      []
    else
      [%{path: path, rest_value: rest, grpc_value: grpc}]
    end
  end

  defp diff_values(rest_val, grpc_val, path) do
    cond do
      is_map(rest_val) and is_map(grpc_val) ->
        diff_recursive(rest_val, grpc_val, path)

      is_list(rest_val) and is_list(grpc_val) ->
        if rest_val == grpc_val do
          []
        else
          [%{path: path, rest_value: rest_val, grpc_value: grpc_val}]
        end

      rest_val == grpc_val ->
        []

      true ->
        [%{path: path, rest_value: rest_val, grpc_value: grpc_val}]
    end
  end

  defp format_value(:missing), do: "(missing)"
  defp format_value(val) when is_binary(val), do: inspect(val)
  defp format_value(val) when is_list(val), do: "[#{length(val)} items]"
  defp format_value(val) when is_map(val), do: "{...}"
  defp format_value(val), do: inspect(val)
end
