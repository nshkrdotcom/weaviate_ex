defmodule WeaviateEx.Collection do
  @moduledoc """
  Collection handle with default tenant and consistency settings.

  Use this when you want to reuse tenant/consistency defaults across data operations.

  ## Examples

      collection =
        WeaviateEx.Collection.new(client, "Article",
          tenant: "tenant-a",
          consistency_level: "QUORUM"
        )

      {:ok, _} = WeaviateEx.Collection.insert(collection, %{properties: %{title: "Hello"}})
  """

  alias WeaviateEx.API.Data
  alias WeaviateEx.Client

  @type t :: %__MODULE__{
          client: Client.t(),
          name: String.t(),
          tenant: String.t() | nil,
          consistency_level: String.t() | atom() | nil
        }

  defstruct [:client, :name, :tenant, :consistency_level]

  @spec new(Client.t(), String.t(), keyword()) :: t()
  def new(%Client{} = client, name, opts \\ []) when is_binary(name) do
    %__MODULE__{
      client: client,
      name: name,
      tenant: Keyword.get(opts, :tenant),
      consistency_level: Keyword.get(opts, :consistency_level)
    }
  end

  @spec with_tenant(t(), String.t() | nil) :: t()
  def with_tenant(%__MODULE__{} = collection, tenant) do
    %{collection | tenant: tenant}
  end

  @spec with_consistency(t(), String.t() | atom() | nil) :: t()
  def with_consistency(%__MODULE__{} = collection, consistency_level) do
    %{collection | consistency_level: consistency_level}
  end

  @spec insert(t(), map(), keyword()) :: {:ok, map()} | {:error, WeaviateEx.Error.t()}
  def insert(%__MODULE__{} = collection, data, opts \\ []) do
    Data.insert(collection.client, collection.name, data, merge_defaults(collection, opts))
  end

  @spec get(t(), String.t(), keyword()) :: {:ok, map()} | {:error, WeaviateEx.Error.t()}
  def get(%__MODULE__{} = collection, id, opts \\ []) do
    Data.get_by_id(collection.client, collection.name, id, merge_defaults(collection, opts))
  end

  @spec update(t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, WeaviateEx.Error.t()}
  def update(%__MODULE__{} = collection, id, data, opts \\ []) do
    Data.update(collection.client, collection.name, id, data, merge_defaults(collection, opts))
  end

  @spec replace(t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, WeaviateEx.Error.t()}
  def replace(%__MODULE__{} = collection, id, data, opts \\ []) do
    Data.replace(collection.client, collection.name, id, data, merge_defaults(collection, opts))
  end

  @spec patch(t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, WeaviateEx.Error.t()}
  def patch(%__MODULE__{} = collection, id, data, opts \\ []) do
    Data.patch(collection.client, collection.name, id, data, merge_defaults(collection, opts))
  end

  @spec delete(t(), String.t(), keyword()) :: {:ok, map()} | {:error, WeaviateEx.Error.t()}
  def delete(%__MODULE__{} = collection, id, opts \\ []) do
    Data.delete_by_id(collection.client, collection.name, id, merge_defaults(collection, opts))
  end

  @spec exists?(t(), String.t(), keyword()) :: {:ok, boolean()} | {:error, WeaviateEx.Error.t()}
  def exists?(%__MODULE__{} = collection, id, opts \\ []) do
    Data.exists?(collection.client, collection.name, id, merge_defaults(collection, opts))
  end

  @spec validate(t(), map(), keyword()) :: {:ok, map()} | {:error, WeaviateEx.Error.t()}
  def validate(%__MODULE__{} = collection, data, opts \\ []) do
    Data.validate(collection.client, collection.name, data, merge_defaults(collection, opts))
  end

  defp merge_defaults(%__MODULE__{} = collection, opts) do
    opts
    |> maybe_put_new(:tenant, collection.tenant)
    |> maybe_put_new(:consistency_level, collection.consistency_level)
  end

  defp maybe_put_new(opts, _key, nil), do: opts
  defp maybe_put_new(opts, key, value), do: Keyword.put_new(opts, key, value)
end
