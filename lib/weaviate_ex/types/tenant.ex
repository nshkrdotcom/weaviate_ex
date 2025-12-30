defmodule WeaviateEx.Types.Tenant do
  @moduledoc """
  Tenant struct with typed activity status.

  Represents a tenant in a multi-tenant collection with full type safety
  for activity status values.

  ## Activity Status Types

  - `:active` - Tenant is active (alias for hot)
  - `:inactive` - Tenant is inactive (alias for cold)
  - `:hot` - Tenant data is in memory, ready for queries
  - `:cold` - Tenant is temporarily deactivated
  - `:frozen` - Tenant data is persisted but not in memory
  - `:offloaded` - Tenant data moved to cold storage

  ## Examples

      tenant = Tenant.new("customer_123")
      tenant = Tenant.new("customer_456", activity_status: :cold)

      # Convert to API format
      api_map = Tenant.to_map(tenant)
      # => %{"name" => "customer_456", "activityStatus" => "COLD"}

      # Parse from API response
      tenant = Tenant.from_map(%{"name" => "customer_789", "activityStatus" => "FROZEN"})
      # => %Tenant{name: "customer_789", activity_status: :frozen}
  """

  @type activity_status :: :active | :inactive | :hot | :cold | :frozen | :offloaded

  @type t :: %__MODULE__{
          name: String.t(),
          activity_status: activity_status()
        }

  defstruct [:name, activity_status: :active]

  @valid_statuses ~w(active inactive hot cold frozen offloaded)a

  @doc """
  Creates a new Tenant struct.

  ## Options

  - `:activity_status` - Initial activity status (default: `:active`)

  ## Examples

      tenant = Tenant.new("customer_123")
      tenant = Tenant.new("customer_456", activity_status: :cold)
  """
  @spec new(String.t(), keyword()) :: t()
  def new(name, opts \\ []) when is_binary(name) do
    status = Keyword.get(opts, :activity_status, :active)
    validate_status!(status)

    %__MODULE__{name: name, activity_status: status}
  end

  @doc """
  Validates the activity status.

  Raises ArgumentError if the status is invalid.

  ## Examples

      Tenant.validate_status!(:hot)
      # => :ok

      Tenant.validate_status!(:invalid)
      # ** (ArgumentError) Invalid activity_status: :invalid. Must be one of [:active, :inactive, :hot, :cold, :frozen, :offloaded]
  """
  @spec validate_status!(atom()) :: :ok | no_return()
  def validate_status!(status) when status in @valid_statuses, do: :ok

  def validate_status!(status) do
    raise ArgumentError,
          "Invalid activity_status: #{inspect(status)}. Must be one of #{inspect(@valid_statuses)}"
  end

  @doc """
  Returns the list of valid activity statuses.

  ## Examples

      Tenant.valid_statuses()
      # => [:active, :inactive, :hot, :cold, :frozen, :offloaded]
  """
  @spec valid_statuses() :: [activity_status()]
  def valid_statuses, do: @valid_statuses

  @doc """
  Checks if a status is valid.

  ## Examples

      Tenant.valid_status?(:hot)
      # => true

      Tenant.valid_status?(:invalid)
      # => false
  """
  @spec valid_status?(atom()) :: boolean()
  def valid_status?(status), do: status in @valid_statuses

  @doc """
  Converts the tenant to a map for the Weaviate API.

  ## Examples

      tenant = Tenant.new("customer_123", activity_status: :cold)
      Tenant.to_map(tenant)
      # => %{"name" => "customer_123", "activityStatus" => "COLD"}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = tenant) do
    %{
      "name" => tenant.name,
      "activityStatus" => activity_status_to_string(tenant.activity_status)
    }
  end

  @doc """
  Creates a Tenant from a map (e.g., from API response).

  ## Examples

      Tenant.from_map(%{"name" => "customer_123", "activityStatus" => "FROZEN"})
      # => %Tenant{name: "customer_123", activity_status: :frozen}

      Tenant.from_map(%{"name" => "customer_456"})
      # => %Tenant{name: "customer_456", activity_status: :active}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"name" => name} = map) do
    status =
      case map["activityStatus"] do
        nil -> :active
        s when is_binary(s) -> string_to_activity_status(s)
        s when is_atom(s) -> s
      end

    %__MODULE__{name: name, activity_status: status}
  end

  @doc """
  Sets the activity status of a tenant.

  ## Examples

      tenant = Tenant.new("customer_123")
      tenant = Tenant.set_status(tenant, :cold)
  """
  @spec set_status(t(), activity_status()) :: t()
  def set_status(%__MODULE__{} = tenant, status) do
    validate_status!(status)
    %{tenant | activity_status: status}
  end

  @doc """
  Checks if the tenant is active (hot or active status).

  ## Examples

      Tenant.active?(Tenant.new("t1", activity_status: :hot))
      # => true

      Tenant.active?(Tenant.new("t1", activity_status: :cold))
      # => false
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{activity_status: status}), do: status in [:active, :hot]

  @doc """
  Checks if the tenant is inactive.

  ## Examples

      Tenant.inactive?(Tenant.new("t1", activity_status: :cold))
      # => true
  """
  @spec inactive?(t()) :: boolean()
  def inactive?(%__MODULE__{} = tenant), do: not active?(tenant)

  # Convert activity status atom to API string format
  defp activity_status_to_string(:active), do: "ACTIVE"
  defp activity_status_to_string(:inactive), do: "INACTIVE"
  defp activity_status_to_string(:hot), do: "HOT"
  defp activity_status_to_string(:cold), do: "COLD"
  defp activity_status_to_string(:frozen), do: "FROZEN"
  defp activity_status_to_string(:offloaded), do: "OFFLOADED"

  # Status string to atom mapping
  @status_string_map %{
    "ACTIVE" => :active,
    "INACTIVE" => :inactive,
    "HOT" => :hot,
    "COLD" => :cold,
    "WARM" => :hot,
    "FROZEN" => :frozen,
    "OFFLOADED" => :offloaded,
    "FREEZING" => :frozen,
    "UNFREEZING" => :hot,
    "OFFLOADING" => :offloaded,
    "ONLOADING" => :hot
  }

  # Convert API string format to activity status atom
  defp string_to_activity_status(str) when is_binary(str) do
    Map.get(@status_string_map, String.upcase(str), :active)
  end
end
