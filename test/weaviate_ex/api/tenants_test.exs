defmodule WeaviateEx.API.TenantsTest do
  @moduledoc """
  Tests for multi-tenancy operations (Phase 2.5).

  Following TDD approach - tests written first, then stub, then implementation.
  """

  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Tenants
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "list/2" do
    test "lists all tenants for a collection", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/schema/Article/tenants"

        {:ok,
         [
           %{"name" => "TenantA", "activityStatus" => "HOT"},
           %{"name" => "TenantB", "activityStatus" => "HOT"},
           %{"name" => "TenantC", "activityStatus" => "COLD"}
         ]}
      end)

      assert {:ok, tenants} = Tenants.list(client, "Article")
      assert length(tenants) == 3
      assert Enum.at(tenants, 0)["name"] == "TenantA"
      assert Enum.at(tenants, 2)["activityStatus"] == "COLD"
    end

    test "handles collection with no tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, _body, _opts ->
        {:ok, []}
      end)

      assert {:ok, []} = Tenants.list(client, "Article")
    end

    test "handles collection not found error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Tenants.list(client, "NonExistent")
    end
  end

  describe "get/3" do
    test "gets specific tenant information", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/schema/Article/tenants/TenantA"

        {:ok, %{"name" => "TenantA", "activityStatus" => "HOT"}}
      end)

      assert {:ok, tenant} = Tenants.get(client, "Article", "TenantA")
      assert tenant["name"] == "TenantA"
      assert tenant["activityStatus"] == "HOT"
    end

    test "handles tenant not found", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Tenants.get(client, "Article", "NonExistent")
    end
  end

  describe "create/3" do
    test "creates single tenant", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/schema/Article/tenants"
        assert is_list(body)
        assert length(body) == 1
        assert hd(body)["name"] == "TenantA"

        {:ok, [%{"name" => "TenantA", "activityStatus" => "HOT"}]}
      end)

      assert {:ok, tenants} = Tenants.create(client, "Article", "TenantA")
      assert length(tenants) == 1
      assert hd(tenants)["name"] == "TenantA"
    end

    test "creates multiple tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert length(body) == 3
        assert Enum.map(body, & &1["name"]) == ["TenantA", "TenantB", "TenantC"]

        {:ok,
         [
           %{"name" => "TenantA", "activityStatus" => "HOT"},
           %{"name" => "TenantB", "activityStatus" => "HOT"},
           %{"name" => "TenantC", "activityStatus" => "HOT"}
         ]}
      end)

      assert {:ok, tenants} = Tenants.create(client, "Article", ["TenantA", "TenantB", "TenantC"])
      assert length(tenants) == 3
    end

    test "creates tenant with specific activity status", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert hd(body)["activityStatus"] == "COLD"

        {:ok, [%{"name" => "TenantA", "activityStatus" => "COLD"}]}
      end)

      assert {:ok, _tenants} =
               Tenants.create(client, "Article", "TenantA", activity_status: :cold)
    end

    test "handles duplicate tenant error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :conflict, message: "Tenant already exists"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :conflict}} =
               Tenants.create(client, "Article", "ExistingTenant")
    end
  end

  describe "update/4" do
    test "updates tenant activity status to COLD", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/schema/Article/tenants"
        assert is_list(body)
        assert hd(body)["name"] == "TenantA"
        assert hd(body)["activityStatus"] == "COLD"

        {:ok, [%{"name" => "TenantA", "activityStatus" => "COLD"}]}
      end)

      assert {:ok, tenants} = Tenants.update(client, "Article", "TenantA", activity_status: :cold)
      assert hd(tenants)["activityStatus"] == "COLD"
    end

    test "updates tenant activity status to HOT", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, _path, body, _opts ->
        assert hd(body)["activityStatus"] == "HOT"

        {:ok, [%{"name" => "TenantA", "activityStatus" => "HOT"}]}
      end)

      assert {:ok, _tenants} =
               Tenants.update(client, "Article", "TenantA", activity_status: :hot)
    end

    test "updates multiple tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, _path, body, _opts ->
        assert length(body) == 2
        assert Enum.all?(body, &(&1["activityStatus"] == "COLD"))

        {:ok,
         [
           %{"name" => "TenantA", "activityStatus" => "COLD"},
           %{"name" => "TenantB", "activityStatus" => "COLD"}
         ]}
      end)

      assert {:ok, tenants} =
               Tenants.update(client, "Article", ["TenantA", "TenantB"], activity_status: :cold)

      assert length(tenants) == 2
    end

    test "handles tenant not found error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Tenants.update(client, "Article", "NonExistent", activity_status: :cold)
    end
  end

  describe "delete/3" do
    test "deletes single tenant", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, path, body, _opts ->
        assert path == "/v1/schema/Article/tenants"
        assert is_list(body)
        assert hd(body) == "TenantA"

        {:ok, %{}}
      end)

      assert {:ok, _} = Tenants.delete(client, "Article", "TenantA")
    end

    test "deletes multiple tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, _path, body, _opts ->
        assert length(body) == 3
        assert body == ["TenantA", "TenantB", "TenantC"]

        {:ok, %{}}
      end)

      assert {:ok, _} = Tenants.delete(client, "Article", ["TenantA", "TenantB", "TenantC"])
    end

    test "handles tenant not found error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Tenants.delete(client, "Article", "NonExistent")
    end
  end

  describe "exists?/3" do
    test "returns true for existing tenant", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, _body, _opts ->
        assert path == "/v1/schema/Article/tenants/TenantA"
        {:ok, %{"name" => "TenantA"}}
      end)

      assert {:ok, true} = Tenants.exists?(client, "Article", "TenantA")
    end

    test "returns false for non-existent tenant", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found}}
      end)

      assert {:ok, false} = Tenants.exists?(client, "Article", "NonExistent")
    end
  end

  describe "activity status helpers" do
    test "activate/3 sets tenant to HOT", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, _path, body, _opts ->
        assert hd(body)["activityStatus"] == "HOT"
        {:ok, [%{"name" => "TenantA", "activityStatus" => "HOT"}]}
      end)

      assert {:ok, _} = Tenants.activate(client, "Article", "TenantA")
    end

    test "deactivate/3 sets tenant to COLD", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, _path, body, _opts ->
        assert hd(body)["activityStatus"] == "COLD"
        {:ok, [%{"name" => "TenantA", "activityStatus" => "COLD"}]}
      end)

      assert {:ok, _} = Tenants.deactivate(client, "Article", "TenantA")
    end

    test "activate multiple tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, _path, body, _opts ->
        assert length(body) == 2
        assert Enum.all?(body, &(&1["activityStatus"] == "HOT"))
        {:ok, []}
      end)

      assert {:ok, _} = Tenants.activate(client, "Article", ["TenantA", "TenantB"])
    end
  end

  describe "count/2" do
    test "counts total tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, _body, _opts ->
        {:ok,
         [
           %{"name" => "TenantA"},
           %{"name" => "TenantB"},
           %{"name" => "TenantC"}
         ]}
      end)

      assert {:ok, 3} = Tenants.count(client, "Article")
    end

    test "counts zero tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, _body, _opts ->
        {:ok, []}
      end)

      assert {:ok, 0} = Tenants.count(client, "Article")
    end
  end

  describe "filter by activity status" do
    test "list_active/2 returns only HOT tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, _body, _opts ->
        {:ok,
         [
           %{"name" => "TenantA", "activityStatus" => "HOT"},
           %{"name" => "TenantB", "activityStatus" => "HOT"},
           %{"name" => "TenantC", "activityStatus" => "COLD"}
         ]}
      end)

      assert {:ok, active} = Tenants.list_active(client, "Article")
      assert length(active) == 2
      assert Enum.all?(active, &(&1["activityStatus"] == "HOT"))
    end

    test "list_inactive/2 returns only COLD tenants", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, _body, _opts ->
        {:ok,
         [
           %{"name" => "TenantA", "activityStatus" => "HOT"},
           %{"name" => "TenantB", "activityStatus" => "COLD"},
           %{"name" => "TenantC", "activityStatus" => "COLD"}
         ]}
      end)

      assert {:ok, inactive} = Tenants.list_inactive(client, "Article")
      assert length(inactive) == 2
      assert Enum.all?(inactive, &(&1["activityStatus"] == "COLD"))
    end
  end
end
