defmodule WeaviateEx.API.Collections do
  @moduledoc """
  Collection (schema) management API.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @doc """
  List all collections.

  ## Examples

      {:ok, collections} = WeaviateEx.API.Collections.list(client)
      ["Article", "Author"]

  ## Returns

    * `{:ok, [String.t()]}` - List of collection names
    * `{:error, Error.t()}` - Error if request fails
  """
  @spec list(Client.t()) :: {:ok, [String.t()]} | {:error, Error.t()}
  def list(client) do
    case Client.request(client, :get, "/v1/schema", nil, []) do
      {:ok, %{"classes" => classes}} when is_list(classes) ->
        names = Enum.map(classes, & &1["class"])
        {:ok, names}

      {:ok, %{"classes" => _}} ->
        {:ok, []}

      {:ok, _} ->
        {:ok, []}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get a specific collection configuration.

  ## Examples

      {:ok, config} = WeaviateEx.API.Collections.get(client, "Article")

  ## Returns

    * `{:ok, map()}` - Collection configuration
    * `{:error, Error.t()}` - Error if not found
  """
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, collection_name) do
    Client.request(client, :get, "/v1/schema/#{collection_name}", nil, [])
  end

  @doc """
  Create a new collection.

  ## Examples

      config = %{
        "class" => "Article",
        "vectorizer" => "text2vec-openai",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]}
        ]
      }
      {:ok, created} = WeaviateEx.API.Collections.create(client, config)

  ## Returns

    * `{:ok, map()}` - Created collection config
    * `{:error, Error.t()}` - Error if validation fails or exists
  """
  @spec create(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, config) do
    Client.request(client, :post, "/v1/schema", config, [])
  end

  @doc "Delete a collection"
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, collection_name) do
    Client.request(client, :delete, "/v1/schema/#{collection_name}", nil, [])
  end

  @doc "Update a collection"
  @spec update(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, collection_name, updates) do
    Client.request(client, :put, "/v1/schema/#{collection_name}", updates, [])
  end

  @doc "Add property to collection"
  @spec add_property(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def add_property(client, collection_name, property) do
    Client.request(client, :post, "/v1/schema/#{collection_name}/properties", property, [])
  end

  @doc "Check if collection exists"
  @spec exists?(Client.t(), String.t()) :: {:ok, boolean()}
  def exists?(client, collection_name) do
    case get(client, collection_name) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{type: :not_found}} -> {:ok, false}
      {:error, _} -> {:ok, false}
    end
  end
end
