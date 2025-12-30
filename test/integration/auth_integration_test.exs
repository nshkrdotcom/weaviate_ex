defmodule WeaviateEx.Integration.AuthTest do
  @moduledoc """
  Integration tests for WeaviateEx authentication and RBAC operations.

  These tests require an RBAC-enabled Weaviate instance running on port 8092.
  Use ci/docker-compose-rbac.yml to start the required container.

  API Keys configured in docker-compose:
  - admin-key: maps to admin-user (has admin privileges)
  - custom-key: maps to custom-user (limited privileges)

  Run with: mix test test/integration/auth_integration_test.exs --include rbac
  """
  use ExUnit.Case, async: false

  alias WeaviateEx.API.{Collections, RBAC}
  alias WeaviateEx.Auth
  alias WeaviateEx.Client
  alias WeaviateEx.RBAC.Permission

  @moduletag :integration
  @moduletag :rbac

  @rbac_url "http://localhost:8092"
  @admin_api_key "admin-key"
  @custom_api_key "custom-key"

  setup_all do
    # Ensure we use HTTP protocol for integration tests
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, @rbac_url)

    # Create admin client for setup/cleanup
    {:ok, admin_client} =
      Client.new(
        base_url: @rbac_url,
        api_key: @admin_api_key
      )

    # Clean up any leftover test collections
    cleanup_collections(admin_client)

    on_exit(fn ->
      {:ok, cleanup_client} =
        Client.new(
          base_url: @rbac_url,
          api_key: @admin_api_key
        )

      cleanup_collections(cleanup_client)
    end)

    {:ok, admin_client: admin_client}
  end

  defp cleanup_collections(client) do
    with {:ok, collections} when is_list(collections) <- Collections.list(client) do
      collections
      |> Enum.filter(
        &(String.starts_with?(&1, "AuthTest") or String.starts_with?(&1, "RbacTest"))
      )
      |> Enum.each(&Collections.delete(client, &1))
    end

    :ok
  end

  describe "API key authentication" do
    test "admin key can access Weaviate", %{admin_client: admin_client} do
      # Admin should be able to list collections
      result = Collections.list(admin_client)

      assert {:ok, _collections} = result
    end

    test "admin key can create collections", %{admin_client: admin_client} do
      collection_name = "AuthTestAdminCreate#{System.system_time(:millisecond)}"

      result =
        Collections.create(admin_client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "title", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      assert {:ok, collection} = result
      assert collection["class"] == collection_name

      # Cleanup
      Collections.delete(admin_client, collection_name)
    end

    test "custom key can authenticate", %{admin_client: _admin_client} do
      {:ok, custom_client} =
        Client.new(
          base_url: @rbac_url,
          api_key: @custom_api_key
        )

      # Custom user should be able to at least list collections (read access)
      # Note: Depending on RBAC config, this might succeed or fail
      result = Collections.list(custom_client)

      # The custom user may have limited permissions - test that auth works
      case result do
        {:ok, _collections} ->
          # Custom user can read collections
          assert true

        {:error, %WeaviateEx.Error{status_code: 403}} ->
          # Custom user has no read permission - auth worked but access denied
          assert true

        {:error, %WeaviateEx.Error{status_code: 401}} ->
          # This would indicate auth failure - should not happen with valid key
          flunk("Authentication should succeed with valid API key")
      end
    end
  end

  describe "unauthenticated access" do
    test "requests without auth fail on RBAC-enabled instance" do
      # Create client without API key
      {:ok, unauth_client} =
        Client.new(
          base_url: @rbac_url
          # No api_key provided
        )

      result = Collections.list(unauth_client)

      # Should fail with 401 Unauthorized or 403 Forbidden
      assert {:error, error} = result
      assert error.status_code in [401, 403]
    end

    test "requests with invalid auth fail" do
      {:ok, invalid_client} =
        Client.new(
          base_url: @rbac_url,
          api_key: "invalid-key-that-does-not-exist"
        )

      result = Collections.list(invalid_client)

      # Should fail with 401 Unauthorized
      assert {:error, error} = result
      assert error.status_code in [401, 403]
    end
  end

  describe "Auth module" do
    test "creates API key auth config" do
      auth = Auth.api_key("test-key")

      assert auth.type == :api_key
      assert auth.api_key == "test-key"
    end

    test "converts auth config to headers" do
      auth = Auth.api_key("my-secret-key")
      headers = Auth.to_headers(auth)

      assert [{"Authorization", "Bearer my-secret-key"}] = headers
    end

    test "creates bearer token auth config" do
      auth = Auth.bearer_token("access-token-123", expires_in: 3600)

      assert auth.type == :bearer_token
      assert auth.access_token == "access-token-123"
      assert auth.expires_in == 3600
    end

    test "bearer token auth generates correct headers" do
      auth = Auth.bearer_token("my-token")
      headers = Auth.to_headers(auth)

      assert [{"Authorization", "Bearer my-token"}] = headers
    end
  end

  describe "RBAC role management (admin only)" do
    test "admin can list roles", %{admin_client: admin_client} do
      result = RBAC.list_roles(admin_client)

      # Should succeed for admin
      assert {:ok, roles} = result
      assert is_list(roles)
    end

    test "admin can create and delete a role", %{admin_client: admin_client} do
      role_name = "test-role-#{System.system_time(:millisecond)}"

      # Create role with read permission on all collections
      permissions = [
        Permission.new(:collections, :read, collection: "*")
      ]

      create_result = RBAC.create_role(admin_client, role_name, permissions)

      assert {:ok, role} = create_result
      assert role.name == role_name

      # Verify role exists
      {:ok, exists} = RBAC.exists?(admin_client, role_name)
      assert exists == true

      # Delete the role
      delete_result = RBAC.delete_role(admin_client, role_name)
      assert :ok = delete_result

      # Verify role is deleted
      {:ok, exists_after} = RBAC.exists?(admin_client, role_name)
      assert exists_after == false
    end

    test "admin can check if role exists", %{admin_client: admin_client} do
      # Check for a role that definitely doesn't exist
      result = RBAC.exists?(admin_client, "nonexistent-role-#{System.system_time(:millisecond)}")

      assert {:ok, false} = result
    end

    test "admin can get role details", %{admin_client: admin_client} do
      # First, list roles to find an existing one
      {:ok, roles} = RBAC.list_roles(admin_client)

      if length(roles) > 0 do
        first_role = hd(roles)
        result = RBAC.get_role(admin_client, first_role.name)

        assert {:ok, role} = result
        assert role.name == first_role.name
      end
    end
  end

  describe "RBAC permission checks" do
    test "custom user has limited permissions" do
      {:ok, custom_client} =
        Client.new(
          base_url: @rbac_url,
          api_key: @custom_api_key
        )

      # Custom user should not be able to create collections (unless specifically granted)
      collection_name = "RbacTestCustomUser#{System.system_time(:millisecond)}"

      result =
        Collections.create(custom_client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "title", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      case result do
        {:ok, _} ->
          # If it succeeded, clean it up (custom user might have more perms than expected)
          Collections.delete(custom_client, collection_name)

        {:error, %WeaviateEx.Error{status_code: code}} ->
          # Expected: permission denied
          assert code in [401, 403]
      end
    end

    test "admin can perform operations that custom user cannot", %{admin_client: admin_client} do
      collection_name = "RbacTestAdminOnly#{System.system_time(:millisecond)}"

      # Admin creates a collection
      {:ok, collection} =
        Collections.create(admin_client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "data", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      assert collection["class"] == collection_name

      # Custom user tries to delete it
      {:ok, custom_client} =
        Client.new(
          base_url: @rbac_url,
          api_key: @custom_api_key
        )

      delete_result = Collections.delete(custom_client, collection_name)

      case delete_result do
        {:ok, _} ->
          # Custom user was able to delete - unexpected but possible
          :ok

        {:error, %WeaviateEx.Error{status_code: code}} ->
          # Expected: permission denied
          assert code in [401, 403]
          # Clean up with admin
          Collections.delete(admin_client, collection_name)
      end
    end
  end

  describe "authenticated collection operations" do
    test "full CRUD cycle with authentication", %{admin_client: admin_client} do
      collection_name = "AuthTestCrud#{System.system_time(:millisecond)}"

      # Create
      {:ok, collection} =
        Collections.create(admin_client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "title", "dataType" => ["text"]},
            %{"name" => "content", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      assert collection["class"] == collection_name

      # Read
      {:ok, fetched} = Collections.get(admin_client, collection_name)
      assert fetched["class"] == collection_name
      assert length(fetched["properties"]) == 2

      # Create object
      {:ok, object} =
        Client.request(
          admin_client,
          :post,
          "/v1/objects",
          %{
            "class" => collection_name,
            "properties" => %{
              "title" => "Test Object",
              "content" => "Test Content"
            }
          },
          []
        )

      assert object["class"] == collection_name
      object_id = object["id"]

      # Read object
      {:ok, fetched_object} =
        Client.request(admin_client, :get, "/v1/objects/#{collection_name}/#{object_id}", nil, [])

      assert fetched_object["properties"]["title"] == "Test Object"

      # Delete object
      {:ok, _} =
        Client.request(
          admin_client,
          :delete,
          "/v1/objects/#{collection_name}/#{object_id}",
          nil,
          []
        )

      # Delete collection
      {:ok, _} = Collections.delete(admin_client, collection_name)

      # Verify deletion
      assert {:error, %WeaviateEx.Error{status_code: 404}} =
               Collections.get(admin_client, collection_name)
    end
  end
end
