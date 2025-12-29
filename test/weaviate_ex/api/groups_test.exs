defmodule WeaviateEx.API.GroupsTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Groups
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "list_known/1" do
    test "returns list of known group names", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/groups", nil, _opts ->
        {:ok, ["engineering", "qa", "platform"]}
      end)

      assert {:ok, groups} = Groups.list_known(client)
      assert groups == ["engineering", "qa", "platform"]
    end

    test "returns empty list when no groups known", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/authz/groups", nil, _opts ->
        {:ok, []}
      end)

      assert {:ok, []} = Groups.list_known(client)
    end
  end

  describe "get_assigned_roles/2" do
    test "returns roles for group", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :get,
                                    "/v1/authz/groups/engineering/roles",
                                    nil,
                                    _opts ->
        {:ok, ["developer", "viewer"]}
      end)

      assert {:ok, roles} = Groups.get_assigned_roles(client, "engineering")
      assert roles == ["developer", "viewer"]
    end

    test "returns empty list for group with no roles", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :get,
                                    "/v1/authz/groups/empty-group/roles",
                                    nil,
                                    _opts ->
        {:ok, []}
      end)

      assert {:ok, []} = Groups.get_assigned_roles(client, "empty-group")
    end
  end

  describe "assign_roles/3" do
    test "assigns roles to OIDC group", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/authz/groups/engineering/assign-roles",
                                    body,
                                    _opts ->
        assert body["roles"] == ["developer", "editor"]
        {:ok, %{}}
      end)

      assert :ok = Groups.assign_roles(client, "engineering", ["developer", "editor"])
    end
  end

  describe "revoke_roles/3" do
    test "revokes roles from group", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/authz/groups/engineering/revoke-roles",
                                    body,
                                    _opts ->
        assert body["roles"] == ["admin"]
        {:ok, %{}}
      end)

      assert :ok = Groups.revoke_roles(client, "engineering", ["admin"])
    end
  end
end
