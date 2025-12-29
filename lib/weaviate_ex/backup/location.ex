defmodule WeaviateEx.Backup.Location do
  @moduledoc """
  Backup storage location configurations.

  Provides location configuration structs for each supported storage backend.

  ## Examples

      # Local filesystem
      Location.filesystem("/var/backups")

      # Amazon S3
      Location.s3("my-bucket", "/backups",
        endpoint: "s3.us-west-2.amazonaws.com",
        region: "us-west-2"
      )

      # Google Cloud Storage
      Location.gcs("my-bucket", "/backups",
        credentials: %{...}
      )

      # Azure Blob Storage
      Location.azure("my-container", "/backups",
        connection_string: "..."
      )
  """

  defmodule Filesystem do
    @moduledoc "Local filesystem backup location"

    @type t :: %__MODULE__{
            path: String.t()
          }

    defstruct [:path]

    @doc "Create new filesystem location"
    @spec new(String.t()) :: t()
    def new(path), do: %__MODULE__{path: path}

    @doc "Convert to API format"
    @spec to_api(t()) :: map()
    def to_api(%__MODULE__{path: path}), do: %{path: path}
  end

  defmodule S3 do
    @moduledoc "Amazon S3 backup location"

    @type t :: %__MODULE__{
            bucket: String.t(),
            path: String.t(),
            endpoint: String.t() | nil,
            region: String.t() | nil,
            access_key_id: String.t() | nil,
            secret_access_key: String.t() | nil,
            use_ssl: boolean()
          }

    defstruct [
      :bucket,
      :path,
      :endpoint,
      :region,
      :access_key_id,
      :secret_access_key,
      use_ssl: true
    ]

    @doc "Create new S3 location"
    @spec new(String.t(), String.t(), keyword()) :: t()
    def new(bucket, path, opts \\ []) do
      %__MODULE__{
        bucket: bucket,
        path: path,
        endpoint: Keyword.get(opts, :endpoint),
        region: Keyword.get(opts, :region),
        access_key_id: Keyword.get(opts, :access_key_id),
        secret_access_key: Keyword.get(opts, :secret_access_key),
        use_ssl: Keyword.get(opts, :use_ssl, true)
      }
    end

    @doc "Convert to API format"
    @spec to_api(t()) :: map()
    def to_api(%__MODULE__{} = loc) do
      %{bucket: loc.bucket, path: loc.path}
      |> maybe_put(:endpoint, loc.endpoint)
      |> maybe_put(:region, loc.region)
      |> maybe_put(:accessKeyId, loc.access_key_id)
      |> maybe_put(:secretAccessKey, loc.secret_access_key)
      |> Map.put(:useSSL, loc.use_ssl)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule GCS do
    @moduledoc "Google Cloud Storage backup location"

    @type t :: %__MODULE__{
            bucket: String.t(),
            path: String.t(),
            project_id: String.t() | nil,
            credentials: map() | nil
          }

    defstruct [:bucket, :path, :project_id, :credentials]

    @doc "Create new GCS location"
    @spec new(String.t(), String.t(), keyword()) :: t()
    def new(bucket, path, opts \\ []) do
      %__MODULE__{
        bucket: bucket,
        path: path,
        project_id: Keyword.get(opts, :project_id),
        credentials: Keyword.get(opts, :credentials)
      }
    end

    @doc "Convert to API format"
    @spec to_api(t()) :: map()
    def to_api(%__MODULE__{} = loc) do
      %{bucket: loc.bucket, path: loc.path}
      |> maybe_put(:projectId, loc.project_id)
      |> maybe_put(:credentials, loc.credentials)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule Azure do
    @moduledoc "Azure Blob Storage backup location"

    @type t :: %__MODULE__{
            container: String.t(),
            path: String.t(),
            connection_string: String.t() | nil
          }

    defstruct [:container, :path, :connection_string]

    @doc "Create new Azure location"
    @spec new(String.t(), String.t(), keyword()) :: t()
    def new(container, path, opts \\ []) do
      %__MODULE__{
        container: container,
        path: path,
        connection_string: Keyword.get(opts, :connection_string)
      }
    end

    @doc "Convert to API format"
    @spec to_api(t()) :: map()
    def to_api(%__MODULE__{} = loc) do
      %{container: loc.container, path: loc.path}
      |> maybe_put(:connectionString, loc.connection_string)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  @type t :: Filesystem.t() | S3.t() | GCS.t() | Azure.t()

  @doc """
  Create filesystem location.

  ## Examples

      iex> Location.filesystem("/var/backups")
      %Location.Filesystem{path: "/var/backups"}
  """
  @spec filesystem(String.t()) :: Filesystem.t()
  def filesystem(path), do: Filesystem.new(path)

  @doc """
  Create S3 location.

  ## Options

  - `:endpoint` - S3 endpoint URL
  - `:region` - AWS region
  - `:access_key_id` - AWS access key ID
  - `:secret_access_key` - AWS secret access key
  - `:use_ssl` - Use SSL (default: true)

  ## Examples

      iex> Location.s3("my-bucket", "/backups")
      %Location.S3{bucket: "my-bucket", path: "/backups", use_ssl: true}

      iex> Location.s3("my-bucket", "/backups", region: "us-west-2")
      %Location.S3{bucket: "my-bucket", path: "/backups", region: "us-west-2", use_ssl: true}
  """
  @spec s3(String.t(), String.t(), keyword()) :: S3.t()
  def s3(bucket, path, opts \\ []), do: S3.new(bucket, path, opts)

  @doc """
  Create GCS location.

  ## Options

  - `:project_id` - GCP project ID
  - `:credentials` - Service account credentials map

  ## Examples

      iex> Location.gcs("my-bucket", "/backups")
      %Location.GCS{bucket: "my-bucket", path: "/backups"}

      iex> Location.gcs("my-bucket", "/backups", project_id: "my-project")
      %Location.GCS{bucket: "my-bucket", path: "/backups", project_id: "my-project"}
  """
  @spec gcs(String.t(), String.t(), keyword()) :: GCS.t()
  def gcs(bucket, path, opts \\ []), do: GCS.new(bucket, path, opts)

  @doc """
  Create Azure location.

  ## Options

  - `:connection_string` - Azure connection string

  ## Examples

      iex> Location.azure("my-container", "/backups")
      %Location.Azure{container: "my-container", path: "/backups"}
  """
  @spec azure(String.t(), String.t(), keyword()) :: Azure.t()
  def azure(container, path, opts \\ []), do: Azure.new(container, path, opts)

  @doc """
  Get storage backend type from location.

  ## Examples

      iex> Location.backend(Location.filesystem("/backups"))
      :filesystem

      iex> Location.backend(Location.s3("bucket", "/path"))
      :s3
  """
  @spec backend(t()) :: atom()
  def backend(%Filesystem{}), do: :filesystem
  def backend(%S3{}), do: :s3
  def backend(%GCS{}), do: :gcs
  def backend(%Azure{}), do: :azure

  @doc """
  Convert location to API format.

  ## Examples

      iex> Location.to_api(Location.filesystem("/backups"))
      %{path: "/backups"}

      iex> Location.to_api(Location.s3("bucket", "/path"))
      %{bucket: "bucket", path: "/path", useSSL: true}
  """
  @spec to_api(t()) :: map()
  def to_api(%Filesystem{} = loc), do: Filesystem.to_api(loc)
  def to_api(%S3{} = loc), do: S3.to_api(loc)
  def to_api(%GCS{} = loc), do: GCS.to_api(loc)
  def to_api(%Azure{} = loc), do: Azure.to_api(loc)
end
