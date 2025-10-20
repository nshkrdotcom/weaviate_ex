defmodule WeaviateEx.API.Batch do
  @moduledoc """
  Low-level batch API helpers for Weaviate.

  This module powers the public `WeaviateEx.Batch` wrapper while providing
  structured summaries for batch create/delete operations.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  defmodule Result do
    @moduledoc """
    Structured summary for batch operations.
    """

    @enforce_keys [:successful, :errors, :statistics]
    defstruct successful: [],
              errors: [],
              statistics: %{processed: 0, successful: 0, failed: 0}

    @typedoc """
    Summary returned when `summary: true` is passed to batch operations.
    """
    @type t :: %__MODULE__{
            successful: list(),
            errors: list(),
            statistics: %{
              processed: non_neg_integer(),
              successful: non_neg_integer(),
              failed: non_neg_integer()
            }
          }
  end

  @type t :: Result.t()

  @type opts :: keyword()
  @type objects_payload :: list(map())
  @type delete_payload :: map()

  @doc """
  Create objects in batch.

  Pass `summary: true` to receive a `%WeaviateEx.API.Batch{}` summary instead of the raw payload.
  """
  @spec create_objects(Client.t(), objects_payload(), opts()) ::
          {:ok, map() | Result.t()} | {:error, Error.t()}
  def create_objects(client, objects, opts \\ []) when is_list(objects) do
    summary? = Keyword.get(opts, :summary, false)
    request_opts = Keyword.drop(opts, [:summary])

    path =
      "/v1/batch/objects" <>
        build_query(request_opts, [:tenant, :consistency_level, :wait_for_completion])

    body = %{"objects" => objects}

    with {:ok, response} <- Client.request(client, :post, path, body, request_opts) do
      if summary? do
        {:ok, build_summary(response)}
      else
        {:ok, normalize_batch_response(response)}
      end
    end
  end

  @doc """
  Delete objects in batch using match criteria.
  """
  @spec delete_objects(Client.t(), delete_payload(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete_objects(client, criteria, opts \\ []) when is_map(criteria) do
    path =
      "/v1/batch/objects" <>
        build_query(opts, [:tenant, :consistency_level, :wait_for_completion])

    body = %{"match" => criteria}
    Client.request(client, :delete, path, body, opts)
  end

  defp build_summary(response) do
    objects = extract_objects(response)

    {successful, failed} =
      Enum.split_with(objects, fn item ->
        case Map.get(item, "status") do
          nil -> false
          status -> String.upcase(status) == "SUCCESS"
        end
      end)

    errors =
      failed
      |> Enum.map(&build_error/1)
      |> Enum.reject(&is_nil/1)

    %Result{
      successful: successful,
      errors: errors,
      statistics: %{
        processed: length(objects),
        successful: length(successful),
        failed: length(errors)
      }
    }
  end

  defp extract_objects(%{"results" => %{"objects" => objects}}) when is_list(objects), do: objects
  defp extract_objects(%{"results" => objects}) when is_list(objects), do: objects
  defp extract_objects(objects) when is_list(objects), do: objects
  defp extract_objects(_), do: []

  defp build_error(item) do
    messages =
      item
      |> Map.get("result", %{})
      |> Map.get("errors", [])
      |> List.wrap()
      |> Enum.map(fn
        %{"message" => message} -> message
        %{"error" => message} -> message
        other when is_binary(other) -> other
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    %{
      id: item["id"],
      class: item["class"],
      status: item["status"],
      messages: messages,
      raw: item
    }
  end

  defp normalize_batch_response(%{"results" => results}) when is_list(results) do
    %{"results" => results}
  end

  defp normalize_batch_response(results) when is_list(results) do
    %{"results" => results}
  end

  defp normalize_batch_response(response), do: response

  defp build_query(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _} -> key in allowed_keys end)
      |> Enum.map(fn {key, value} -> "#{key}=#{encode_value(value)}" end)
      |> Enum.join("&")

    if params == "", do: "", else: "?" <> params
  end

  defp encode_value(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.join(",")
    |> URI.encode_www_form()
  end

  defp encode_value(value) do
    value
    |> to_string()
    |> URI.encode_www_form()
  end
end
