defmodule WeaviateEx.Auth.Azure do
  @moduledoc """
  Azure-specific OIDC handling.

  Detects Azure/Microsoft endpoints and applies appropriate defaults
  for authentication configuration.

  ## Azure OIDC Specifics

    * Uses `{client_id}/.default` scope format
    * Different token endpoint patterns for v1 and v2
    * Resource-based authentication for v1 endpoints

  ## Examples

      # Check if endpoint is Azure
      Azure.azure_endpoint?("https://login.microsoftonline.com/tenant/oauth2/token")
      # => true

      # Apply Azure defaults to auth options
      opts = [token_endpoint: "https://login.microsoftonline.com/...", client_id: "my-id"]
      Azure.apply_azure_defaults(opts)
      # => [token_endpoint: "...", client_id: "my-id", scopes: ["my-id/.default"]]
  """

  @azure_patterns [
    "login.microsoftonline.com",
    "login.microsoft.com",
    "sts.windows.net"
  ]

  @doc """
  Check if a token endpoint is an Azure/Microsoft endpoint.

  ## Examples

      Azure.azure_endpoint?("https://login.microsoftonline.com/tenant/oauth2/token")
      # => true

      Azure.azure_endpoint?("https://auth.example.com/token")
      # => false
  """
  @spec azure_endpoint?(String.t() | nil) :: boolean()
  def azure_endpoint?(nil), do: false

  def azure_endpoint?(endpoint) when is_binary(endpoint) do
    Enum.any?(@azure_patterns, &String.contains?(endpoint, &1))
  end

  @doc """
  Get default scopes for Azure authentication.

  Azure uses the `{client_id}/.default` scope format to request
  all configured permissions for the application.

  ## Examples

      Azure.default_scopes("my-client-id")
      # => ["my-client-id/.default"]
  """
  @spec default_scopes(String.t()) :: [String.t()]
  def default_scopes(client_id) when is_binary(client_id) do
    ["#{client_id}/.default"]
  end

  @doc """
  Apply Azure-specific defaults to authentication options.

  If the token endpoint is detected as Azure and no scopes are provided,
  automatically adds the `.default` scope.

  ## Examples

      opts = [
        token_endpoint: "https://login.microsoftonline.com/tenant/oauth2/token",
        client_id: "my-client-id"
      ]
      Azure.apply_azure_defaults(opts)
      # => [token_endpoint: "...", client_id: "my-client-id", scopes: ["my-client-id/.default"]]
  """
  @spec apply_azure_defaults(keyword()) :: keyword()
  def apply_azure_defaults(opts) do
    token_endpoint = Keyword.get(opts, :token_endpoint)
    client_id = Keyword.get(opts, :client_id)
    existing_scopes = Keyword.get(opts, :scopes)

    cond do
      not azure_endpoint?(token_endpoint) ->
        opts

      not is_nil(existing_scopes) ->
        opts

      is_nil(client_id) ->
        opts

      true ->
        Keyword.put(opts, :scopes, default_scopes(client_id))
    end
  end

  @doc """
  Format resource for Azure v1 endpoints.

  Some Azure v1 endpoints use `resource` instead of `scope`.

  ## Examples

      Azure.format_resource("my-client-id")
      # => "my-client-id"
  """
  @spec format_resource(String.t()) :: String.t()
  def format_resource(client_id) when is_binary(client_id) do
    client_id
  end

  @doc """
  Detect Azure endpoint version from URL.

  Returns `:v1` or `:v2` based on the endpoint URL pattern.

  ## Examples

      Azure.detect_version("https://login.microsoftonline.com/tenant/oauth2/v2.0/token")
      # => :v2

      Azure.detect_version("https://login.microsoftonline.com/tenant/oauth2/token")
      # => :v1
  """
  @spec detect_version(String.t()) :: :v1 | :v2 | :unknown
  def detect_version(endpoint) when is_binary(endpoint) do
    cond do
      String.contains?(endpoint, "/oauth2/v2.0/") -> :v2
      String.contains?(endpoint, "/oauth2/") -> :v1
      true -> :unknown
    end
  end

  @doc """
  Build Azure-specific token request parameters.

  For v1 endpoints, uses `resource` parameter.
  For v2 endpoints, uses `scope` parameter.

  ## Examples

      Azure.build_token_params(:v2, "my-client-id")
      # => [{"scope", "my-client-id/.default"}]
  """
  @spec build_token_params(:v1 | :v2, String.t()) :: [{String.t(), String.t()}]
  def build_token_params(:v1, client_id) do
    [{"resource", format_resource(client_id)}]
  end

  def build_token_params(:v2, client_id) do
    [{"scope", Enum.join(default_scopes(client_id), " ")}]
  end

  def build_token_params(:unknown, client_id) do
    # Default to v2 style
    build_token_params(:v2, client_id)
  end

  @doc """
  Validates Microsoft/Azure password flow requirements.

  Microsoft password flow (ROPC - Resource Owner Password Credential) requires:
  - Username (must be a valid email address for Microsoft auth)
  - Password (non-empty)
  - Client ID

  ## Examples

      Azure.validate_password_flow(%{username: "user@example.com", password: "pass", client_id: "id"})
      # => :ok

      Azure.validate_password_flow(%{username: "invalid", password: "pass", client_id: "id"})
      # => {:error, "Username must be a valid email address for Microsoft auth"}

      Azure.validate_password_flow(%{password: "pass"})
      # => {:error, "Microsoft password flow requires username, password, and client_id"}
  """
  @spec validate_password_flow(map()) :: :ok | {:error, String.t()}
  def validate_password_flow(%{username: username, password: password, client_id: client_id})
      when is_binary(username) and is_binary(password) and is_binary(client_id) do
    cond do
      String.length(password) < 1 ->
        {:error, "Password cannot be empty"}

      not String.contains?(username, "@") ->
        {:error, "Username must be a valid email address for Microsoft auth"}

      String.length(client_id) < 1 ->
        {:error, "Client ID cannot be empty"}

      true ->
        :ok
    end
  end

  def validate_password_flow(_) do
    {:error, "Microsoft password flow requires username, password, and client_id"}
  end

  @doc """
  Check if password flow (ROPC) is configured in the auth options.

  ## Examples

      Azure.password_flow_configured?(%{type: :oidc_password, username: "user", password: "pass"})
      # => true

      Azure.password_flow_configured?(%{type: :api_key})
      # => false
  """
  @spec password_flow_configured?(map()) :: boolean()
  def password_flow_configured?(%{type: :oidc_password}), do: true
  def password_flow_configured?(%{type: :password}), do: true
  def password_flow_configured?(_), do: false
end
