defmodule WeaviateEx.API.Aliases do
  @moduledoc """
  Collection aliases API for Weaviate.

  Aliases allow you to create alternative names for collections, enabling
  zero-downtime collection updates and blue-green deployments.

  **Requires Weaviate v1.32.0 or later.**

  ## Use Cases

  - **Zero-downtime updates**: Create a new collection, populate it, then
    update the alias to point to the new collection
  - **Blue-green deployments**: Switch between "blue" and "green" collections
    instantly
  - **Semantic naming**: Use descriptive alias names while keeping collection
    names versioned

  ## Examples

      # Create an alias
      {:ok, _} = Aliases.create(client, "articles", "Article_v1")

      # List all aliases
      {:ok, aliases} = Aliases.list(client)

      # Update alias to point to new collection
      {:ok, _} = Aliases.update(client, "articles", "Article_v2")

      # Check if alias exists
      {:ok, true} = Aliases.exists?(client, "articles")

      # Get alias details
      {:ok, alias_info} = Aliases.get(client, "articles")
      # => %Alias{alias: "articles", collection: "Article_v2"}

      # Delete alias (collection remains)
      {:ok, true} = Aliases.delete(client, "articles")
  """

  alias WeaviateEx.Client

  @minimum_version "1.32.0"

  defmodule Alias do
    @moduledoc """
    Represents a collection alias.
    """

    @type t :: %__MODULE__{
            alias: String.t(),
            collection: String.t()
          }

    defstruct [:alias, :collection]

    @doc """
    Create an Alias struct from API response.
    """
    @spec from_api(map()) :: t()
    def from_api(%{"alias" => alias_name, "class" => collection}) do
      %__MODULE__{
        alias: alias_name,
        collection: collection
      }
    end
  end

  @doc """
  Get the minimum Weaviate version required for aliases.

  ## Examples

      Aliases.minimum_version()
      # => "1.32.0"
  """
  @spec minimum_version() :: String.t()
  def minimum_version, do: @minimum_version

  @doc """
  Create a new alias for a collection.

  ## Parameters

  - `client` - WeaviateEx client
  - `alias_name` - Name for the alias
  - `target_collection` - Name of the collection to alias

  ## Examples

      {:ok, _} = Aliases.create(client, "articles", "Article")

      # With options
      {:ok, _} = Aliases.create(client, "articles", "Article", timeout: 30_000)
  """
  @spec create(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create(client, alias_name, target_collection, opts \\ []) do
    body = %{
      "class" => target_collection,
      "alias" => alias_name
    }

    Client.request(client, :post, "/v1/aliases", body, opts)
  end

  @doc """
  Delete an alias.

  The underlying collection is not affected.

  ## Parameters

  - `client` - WeaviateEx client
  - `alias_name` - Name of the alias to delete

  ## Returns

  - `{:ok, true}` - Alias was deleted
  - `{:ok, false}` - Alias did not exist

  ## Examples

      {:ok, true} = Aliases.delete(client, "articles")
  """
  @spec delete(Client.t(), String.t(), keyword()) ::
          {:ok, boolean()} | {:error, term()}
  def delete(client, alias_name, opts \\ []) do
    case Client.request(client, :delete, "/v1/aliases/#{alias_name}", nil, opts) do
      {:ok, _} -> {:ok, true}
      {:error, %{type: :not_found}} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Update an alias to point to a different collection.

  ## Parameters

  - `client` - WeaviateEx client
  - `alias_name` - Name of the alias to update
  - `new_target_collection` - Name of the new target collection

  ## Returns

  - `{:ok, true}` - Alias was updated
  - `{:ok, false}` - Alias did not exist

  ## Examples

      {:ok, true} = Aliases.update(client, "articles", "Article_v2")
  """
  @spec update(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, boolean()} | {:error, term()}
  def update(client, alias_name, new_target_collection, opts \\ []) do
    body = %{"class" => new_target_collection}

    case Client.request(client, :put, "/v1/aliases/#{alias_name}", body, opts) do
      {:ok, _} -> {:ok, true}
      {:error, %{type: :not_found}} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get an alias by name.

  ## Parameters

  - `client` - WeaviateEx client
  - `alias_name` - Name of the alias to get

  ## Returns

  - `{:ok, %Alias{}}` - Alias found
  - `{:ok, nil}` - Alias not found

  ## Examples

      {:ok, alias_info} = Aliases.get(client, "articles")
      # => %Alias{alias: "articles", collection: "Article"}
  """
  @spec get(Client.t(), String.t(), keyword()) ::
          {:ok, Alias.t() | nil} | {:error, term()}
  def get(client, alias_name, opts \\ []) do
    case Client.request(client, :get, "/v1/aliases/#{alias_name}", nil, opts) do
      {:ok, response} when is_map(response) ->
        {:ok, Alias.from_api(response)}

      {:error, %{type: :not_found}} ->
        {:ok, nil}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  List all aliases.

  ## Parameters

  - `client` - WeaviateEx client
  - `opts` - Options
    - `:collection` - Filter by collection name

  ## Returns

  - `{:ok, [%Alias{}]}` - List of aliases

  ## Examples

      # List all aliases
      {:ok, aliases} = Aliases.list(client)

      # List aliases for a specific collection
      {:ok, aliases} = Aliases.list(client, collection: "Article")
  """
  @spec list(Client.t(), keyword()) ::
          {:ok, [Alias.t()]} | {:error, term()}
  def list(client, opts \\ []) do
    path =
      case Keyword.get(opts, :collection) do
        nil -> "/v1/aliases"
        collection -> "/v1/aliases?class=#{collection}"
      end

    case Client.request(client, :get, path, nil, opts) do
      {:ok, %{"aliases" => aliases}} when is_list(aliases) ->
        {:ok, Enum.map(aliases, &Alias.from_api/1)}

      {:ok, %{"aliases" => nil}} ->
        {:ok, []}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Check if an alias exists.

  ## Parameters

  - `client` - WeaviateEx client
  - `alias_name` - Name of the alias to check

  ## Returns

  - `{:ok, true}` - Alias exists
  - `{:ok, false}` - Alias does not exist

  ## Examples

      {:ok, true} = Aliases.exists?(client, "articles")
  """
  @spec exists?(Client.t(), String.t(), keyword()) ::
          {:ok, boolean()} | {:error, term()}
  def exists?(client, alias_name, opts \\ []) do
    case Client.request(client, :get, "/v1/aliases/#{alias_name}", nil, opts) do
      {:ok, _} -> {:ok, true}
      {:error, %{type: :not_found}} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end
end
