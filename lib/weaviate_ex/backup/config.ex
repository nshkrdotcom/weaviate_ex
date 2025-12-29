defmodule WeaviateEx.Backup.Config do
  @moduledoc """
  Configuration options for backup operations.

  ## Create Configuration

  Configure how backups are created:

      config = Config.create(
        cpu_percentage: 50,
        compression: :best_compression
      )

  ## Restore Configuration

  Configure how backups are restored:

      config = Config.restore(cpu_percentage: 80)

  ## Options

  ### Create Options

  - `:cpu_percentage` - Maximum CPU percentage to use (1-100)
  - `:compression` - Compression level (`:default`, `:best_speed`, `:best_compression`)

  ### Restore Options

  - `:cpu_percentage` - Maximum CPU percentage to use (1-100)
  """

  alias WeaviateEx.Backup.Compression

  defmodule Create do
    @moduledoc "Configuration for backup creation"

    @type t :: %__MODULE__{
            cpu_percentage: pos_integer() | nil,
            compression: Compression.t() | nil
          }

    defstruct [:cpu_percentage, :compression]

    @doc """
    Create new backup create config.

    ## Examples

        iex> Config.Create.new(cpu_percentage: 50, compression: :best_speed)
        %Config.Create{cpu_percentage: 50, compression: :best_speed}

        iex> Config.Create.new()
        %Config.Create{cpu_percentage: nil, compression: nil}
    """
    @spec new(keyword()) :: t()
    def new(opts \\ []) do
      %__MODULE__{
        cpu_percentage: Keyword.get(opts, :cpu_percentage),
        compression: Keyword.get(opts, :compression)
      }
    end

    @doc """
    Convert to API format.

    Excludes nil values from the resulting map.

    ## Examples

        iex> Config.Create.to_api(%Config.Create{cpu_percentage: 50, compression: :best_speed})
        %{CPUPercentage: 50, CompressionLevel: "BestSpeed"}

        iex> Config.Create.to_api(%Config.Create{})
        %{}
    """
    @spec to_api(t()) :: map()
    def to_api(%__MODULE__{} = config) do
      %{}
      |> maybe_put(:CPUPercentage, config.cpu_percentage)
      |> maybe_put(
        :CompressionLevel,
        config.compression && Compression.to_api(config.compression)
      )
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule Restore do
    @moduledoc "Configuration for backup restoration"

    @type t :: %__MODULE__{
            cpu_percentage: pos_integer() | nil
          }

    defstruct [:cpu_percentage]

    @doc """
    Create new backup restore config.

    ## Examples

        iex> Config.Restore.new(cpu_percentage: 80)
        %Config.Restore{cpu_percentage: 80}

        iex> Config.Restore.new()
        %Config.Restore{cpu_percentage: nil}
    """
    @spec new(keyword()) :: t()
    def new(opts \\ []) do
      %__MODULE__{
        cpu_percentage: Keyword.get(opts, :cpu_percentage)
      }
    end

    @doc """
    Convert to API format.

    ## Examples

        iex> Config.Restore.to_api(%Config.Restore{cpu_percentage: 80})
        %{CPUPercentage: 80}

        iex> Config.Restore.to_api(%Config.Restore{cpu_percentage: nil})
        %{}
    """
    @spec to_api(t()) :: map()
    def to_api(%__MODULE__{cpu_percentage: nil}), do: %{}
    def to_api(%__MODULE__{cpu_percentage: pct}), do: %{CPUPercentage: pct}
  end

  @doc """
  Create backup creation config.

  ## Options

  - `:cpu_percentage` - Maximum CPU percentage to use (1-100)
  - `:compression` - Compression level (`:default`, `:best_speed`, `:best_compression`)

  ## Examples

      iex> Config.create(cpu_percentage: 50, compression: :best_compression)
      %Config.Create{cpu_percentage: 50, compression: :best_compression}

      iex> Config.create()
      %Config.Create{cpu_percentage: nil, compression: nil}
  """
  @spec create(keyword()) :: Create.t()
  def create(opts \\ []), do: Create.new(opts)

  @doc """
  Create backup restoration config.

  ## Options

  - `:cpu_percentage` - Maximum CPU percentage to use (1-100)

  ## Examples

      iex> Config.restore(cpu_percentage: 80)
      %Config.Restore{cpu_percentage: 80}

      iex> Config.restore()
      %Config.Restore{cpu_percentage: nil}
  """
  @spec restore(keyword()) :: Restore.t()
  def restore(opts \\ []), do: Restore.new(opts)
end
