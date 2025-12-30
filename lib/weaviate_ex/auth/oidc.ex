defmodule WeaviateEx.Auth.OIDC.Config do
  @moduledoc """
  OIDC provider configuration discovered from well-known endpoint.
  """

  @type t :: %__MODULE__{
          issuer: String.t() | nil,
          token_endpoint: String.t() | nil,
          authorization_endpoint: String.t() | nil,
          userinfo_endpoint: String.t() | nil,
          jwks_uri: String.t() | nil
        }

  defstruct issuer: nil,
            token_endpoint: nil,
            authorization_endpoint: nil,
            userinfo_endpoint: nil,
            jwks_uri: nil
end

defmodule WeaviateEx.Auth.OIDC.TokenResponse do
  @moduledoc """
  OIDC token response from token endpoint.
  """

  @type t :: %__MODULE__{
          access_token: String.t() | nil,
          token_type: String.t() | nil,
          expires_in: non_neg_integer() | nil,
          refresh_token: String.t() | nil,
          id_token: String.t() | nil,
          scope: String.t() | nil,
          issued_at: DateTime.t() | nil
        }

  defstruct access_token: nil,
            token_type: nil,
            expires_in: nil,
            refresh_token: nil,
            id_token: nil,
            scope: nil,
            issued_at: nil

  @doc """
  Calculate the expiration timestamp from issued_at and expires_in.
  """
  @spec expires_at(t()) :: DateTime.t() | nil
  def expires_at(%__MODULE__{issued_at: nil}), do: nil
  def expires_at(%__MODULE__{expires_in: nil}), do: nil

  def expires_at(%__MODULE__{issued_at: issued_at, expires_in: expires_in}) do
    DateTime.add(issued_at, expires_in, :second)
  end

  @doc """
  Check if the token is expired.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{} = token) do
    case expires_at(token) do
      nil -> false
      expires -> DateTime.compare(DateTime.utc_now(), expires) != :lt
    end
  end

  @doc """
  Check if the token will expire within the given buffer time (in seconds).
  Default buffer is 60 seconds.
  """
  @spec expiring_soon?(t(), non_neg_integer()) :: boolean()
  def expiring_soon?(%__MODULE__{} = token, buffer_seconds \\ 60) do
    case expires_at(token) do
      nil ->
        false

      expires ->
        buffer_time = DateTime.add(DateTime.utc_now(), buffer_seconds, :second)
        DateTime.compare(buffer_time, expires) != :lt
    end
  end
end

defmodule WeaviateEx.Auth.OIDC do
  @moduledoc """
  OIDC (OpenID Connect) authentication support.

  Provides functions for:
  - Discovering OIDC configuration from issuer
  - Obtaining tokens via client_credentials or password grant
  - Refreshing tokens

  ## Example

      # Discover OIDC configuration
      {:ok, config} = OIDC.discover("https://auth.example.com")

      # Get token with client credentials
      auth = %{type: :oidc_client_credentials, client_id: "id", client_secret: "secret", scopes: []}
      {:ok, token} = OIDC.get_token(config, auth)

      # Refresh token
      {:ok, new_token} = OIDC.refresh_token(config, token.refresh_token)
  """

  alias WeaviateEx.Auth.OIDC.{Config, TokenResponse}

  @doc """
  Parses scope string into list of scopes.

  Handles both space-separated (OAuth standard) and comma-separated formats.

  ## Examples

      iex> OIDC.parse_scopes("openid profile email")
      ["openid", "profile", "email"]

      iex> OIDC.parse_scopes("openid,profile,email")
      ["openid", "profile", "email"]

      iex> OIDC.parse_scopes(["openid", "profile"])
      ["openid", "profile"]

      iex> OIDC.parse_scopes(nil)
      []
  """
  @spec parse_scopes(String.t() | list(String.t()) | nil) :: list(String.t())
  def parse_scopes(scopes) when is_binary(scopes) do
    scopes
    |> String.split(~r/[\s,]+/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def parse_scopes(scopes) when is_list(scopes), do: scopes
  def parse_scopes(_), do: []

  @doc """
  Discover OIDC configuration from the issuer's well-known endpoint.

  ## Example

      {:ok, config} = OIDC.discover("https://auth.example.com")
  """
  @spec discover(String.t()) :: {:ok, Config.t()} | {:error, term()}
  def discover(issuer_url) do
    well_known_url = String.trim_trailing(issuer_url, "/") <> "/.well-known/openid-configuration"

    case http_get(well_known_url) do
      {:ok, %{status: 200, body: body}} ->
        parse_discovery_response(body)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Exchange credentials for an access token.

  Supports both client_credentials and password grant types.
  """
  @spec get_token(Config.t(), map()) :: {:ok, TokenResponse.t()} | {:error, term()}
  def get_token(%Config{token_endpoint: token_endpoint}, auth) do
    params = build_token_params(auth)

    case http_post_form(token_endpoint, params) do
      {:ok, %{status: 200, body: body}} ->
        parse_token_response(body)

      {:ok, %{status: _status, body: body}} ->
        parse_error_response(body)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Refresh an access token using a refresh token.
  """
  @spec refresh_token(Config.t(), String.t()) :: {:ok, TokenResponse.t()} | {:error, term()}
  def refresh_token(%Config{token_endpoint: token_endpoint}, refresh_token) do
    params = [
      {"grant_type", "refresh_token"},
      {"refresh_token", refresh_token}
    ]

    case http_post_form(token_endpoint, params) do
      {:ok, %{status: 200, body: body}} ->
        parse_token_response(body)

      {:ok, %{status: _status, body: body}} ->
        parse_error_response(body)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Build token request parameters based on auth type
  defp build_token_params(%{type: :oidc_client_credentials} = auth) do
    params = [
      {"grant_type", "client_credentials"},
      {"client_id", auth.client_id},
      {"client_secret", auth.client_secret}
    ]

    maybe_add_scope(params, auth.scopes)
  end

  defp build_token_params(%{type: :oidc_password} = auth) do
    params = [
      {"grant_type", "password"},
      {"username", auth.username},
      {"password", auth.password}
    ]

    params =
      if auth.client_id do
        params ++ [{"client_id", auth.client_id}]
      else
        params
      end

    params =
      if auth.client_secret do
        params ++ [{"client_secret", auth.client_secret}]
      else
        params
      end

    maybe_add_scope(params, auth.scopes)
  end

  defp maybe_add_scope(params, []), do: params
  defp maybe_add_scope(params, nil), do: params

  defp maybe_add_scope(params, scopes) do
    params ++ [{"scope", Enum.join(scopes, " ")}]
  end

  # Parse discovery response
  defp parse_discovery_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok,
         %Config{
           issuer: data["issuer"],
           token_endpoint: data["token_endpoint"],
           authorization_endpoint: data["authorization_endpoint"],
           userinfo_endpoint: data["userinfo_endpoint"],
           jwks_uri: data["jwks_uri"]
         }}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  # Parse token response
  defp parse_token_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok,
         %TokenResponse{
           access_token: data["access_token"],
           token_type: data["token_type"],
           expires_in: data["expires_in"],
           refresh_token: data["refresh_token"],
           id_token: data["id_token"],
           scope: data["scope"],
           issued_at: DateTime.utc_now()
         }}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  # Parse error response
  defp parse_error_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:error,
         %{
           error: data["error"],
           error_description: data["error_description"]
         }}

      {:error, _} ->
        {:error, :unknown_error}
    end
  end

  # HTTP GET request using Finch
  defp http_get(url) do
    request = Finch.build(:get, url)

    case Finch.request(request, WeaviateEx.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # HTTP POST with form-urlencoded body
  defp http_post_form(url, params) do
    body = URI.encode_query(params)

    headers = [
      {"content-type", "application/x-www-form-urlencoded"}
    ]

    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, WeaviateEx.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
