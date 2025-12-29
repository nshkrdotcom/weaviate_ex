defmodule WeaviateEx.Config.ObjectTTL do
  @moduledoc """
  Object Time-To-Live (TTL) configuration for automatic object expiration.

  Weaviate 1.35+ supports automatic object expiration based on:
  - Object creation time
  - Object last update time
  - Custom date property values

  ## Usage

      # Delete objects 24 hours after last update
      ttl = WeaviateEx.Config.ObjectTTL.delete_by_update_time(86400)

      # Delete objects 1 hour after creation
      ttl = WeaviateEx.Config.ObjectTTL.delete_by_creation_time(3600)

      # Delete objects based on a custom expiry_date property
      ttl = WeaviateEx.Config.ObjectTTL.delete_by_date_property("expiry_date")

      # Include in collection creation
      WeaviateEx.Collections.create(client, "MyClass", %{
        properties: [...],
        object_ttl: ttl
      })
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          filter_expired_objects: boolean() | nil,
          delete_on: String.t() | nil,
          default_ttl: integer() | nil
        }

  defstruct [
    :enabled,
    :filter_expired_objects,
    :delete_on,
    :default_ttl
  ]

  @doc """
  Create TTL config that deletes objects based on their last update time.

  ## Parameters
    - `time_to_live` - TTL in seconds (positive integer)
    - `filter_expired_objects` - If true, exclude expired but not yet deleted
      objects from search results (optional)

  ## Examples

      # Objects expire 24 hours after last update
      WeaviateEx.Config.ObjectTTL.delete_by_update_time(86400)

      # With filtering of expired objects
      WeaviateEx.Config.ObjectTTL.delete_by_update_time(86400, true)
  """
  @spec delete_by_update_time(integer(), boolean() | nil) :: t()
  def delete_by_update_time(time_to_live, filter_expired_objects \\ nil)
      when is_integer(time_to_live) and time_to_live > 0 do
    %__MODULE__{
      enabled: true,
      delete_on: "_lastUpdateTimeUnix",
      filter_expired_objects: filter_expired_objects,
      default_ttl: time_to_live
    }
  end

  @doc """
  Create TTL config that deletes objects based on their creation time.

  ## Parameters
    - `time_to_live` - TTL in seconds (positive integer)
    - `filter_expired_objects` - If true, exclude expired but not yet deleted
      objects from search results (optional)

  ## Examples

      # Objects expire 1 hour after creation
      WeaviateEx.Config.ObjectTTL.delete_by_creation_time(3600)
  """
  @spec delete_by_creation_time(integer(), boolean() | nil) :: t()
  def delete_by_creation_time(time_to_live, filter_expired_objects \\ nil)
      when is_integer(time_to_live) and time_to_live > 0 do
    %__MODULE__{
      enabled: true,
      delete_on: "_creationTimeUnix",
      filter_expired_objects: filter_expired_objects,
      default_ttl: time_to_live
    }
  end

  @doc """
  Create TTL config that deletes objects based on a custom date property.

  This allows objects to expire based on any date property in the schema.

  ## Parameters
    - `property_name` - The name of the date property to use for expiration
    - `ttl_offset` - Optional offset in seconds relative to the property date.
      Can be negative for indicating objects should expire before the date.
      Defaults to 0.
    - `filter_expired_objects` - If true, exclude expired but not yet deleted
      objects from search results (optional)

  ## Examples

      # Delete when "expiry_date" property value is reached
      WeaviateEx.Config.ObjectTTL.delete_by_date_property("expiry_date")

      # Delete 1 hour after "event_date" property value
      WeaviateEx.Config.ObjectTTL.delete_by_date_property("event_date", 3600)

      # Delete 1 day before "deadline" property value
      WeaviateEx.Config.ObjectTTL.delete_by_date_property("deadline", -86400)
  """
  @spec delete_by_date_property(String.t(), integer() | nil, boolean() | nil) :: t()
  def delete_by_date_property(property_name, ttl_offset \\ nil, filter_expired_objects \\ nil)
      when is_binary(property_name) do
    offset = if is_nil(ttl_offset), do: 0, else: ttl_offset

    %__MODULE__{
      enabled: true,
      delete_on: property_name,
      filter_expired_objects: filter_expired_objects,
      default_ttl: offset
    }
  end

  @doc """
  Create a config to disable TTL for a collection.

  Use this when updating a collection to turn off automatic object expiration.

  ## Examples

      WeaviateEx.Collections.update("MyClass", %{
        object_ttl: WeaviateEx.Config.ObjectTTL.disable()
      })
  """
  @spec disable() :: t()
  def disable do
    %__MODULE__{enabled: false}
  end

  @doc """
  Convert a TTL config struct to a map for the Weaviate API.

  This function handles the conversion of Elixir-style keys to the
  camelCase format expected by the Weaviate REST API.

  ## Examples

      iex> config = WeaviateEx.Config.ObjectTTL.delete_by_update_time(3600)
      iex> WeaviateEx.Config.ObjectTTL.to_map(config)
      %{
        "enabled" => true,
        "deleteOn" => "_lastUpdateTimeUnix",
        "defaultTtl" => 3600
      }
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = config) do
    base = %{"enabled" => config.enabled}

    base
    |> maybe_put("filterExpiredObjects", config.filter_expired_objects)
    |> maybe_put("deleteOn", config.delete_on)
    |> maybe_put("defaultTtl", config.default_ttl)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @doc """
  Create a TTL config from a map (e.g., from API response).

  ## Examples

      iex> map = %{"enabled" => true, "deleteOn" => "_creationTimeUnix", "defaultTtl" => 3600}
      iex> WeaviateEx.Config.ObjectTTL.from_map(map)
      %WeaviateEx.Config.ObjectTTL{
        enabled: true,
        delete_on: "_creationTimeUnix",
        default_ttl: 3600,
        filter_expired_objects: nil
      }
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      enabled: Map.get(map, "enabled", false),
      filter_expired_objects: Map.get(map, "filterExpiredObjects"),
      delete_on: Map.get(map, "deleteOn"),
      default_ttl: Map.get(map, "defaultTtl")
    }
  end
end
