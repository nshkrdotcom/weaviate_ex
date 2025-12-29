defmodule WeaviateEx.GRPC.Services.TenantsTest do
  use ExUnit.Case, async: true

  alias Weaviate.V1.{Tenant, TenantNames, TenantsGetReply, TenantsGetRequest}

  @moduletag :grpc

  describe "TenantsGetRequest protobuf" do
    test "can create with collection" do
      request = %TenantsGetRequest{collection: "Article"}
      assert request.collection == "Article"
    end

    test "supports names filter via TenantNames oneof" do
      tenant_names = %TenantNames{values: ["tenant-a", "tenant-b"]}

      request = %TenantsGetRequest{
        collection: "Article",
        params: {:names, tenant_names}
      }

      assert request.collection == "Article"
      assert {:names, names} = request.params
      assert names.values == ["tenant-a", "tenant-b"]
    end
  end

  describe "TenantsGetReply protobuf" do
    test "has tenants list" do
      reply = %TenantsGetReply{tenants: []}
      assert reply.tenants == []
    end

    test "has took field" do
      reply = %TenantsGetReply{took: 0.5}
      assert reply.took == 0.5
    end

    test "can contain Tenant structs" do
      reply = %TenantsGetReply{
        tenants: [
          %Tenant{name: "tenant-a", activity_status: :TENANT_ACTIVITY_STATUS_HOT},
          %Tenant{name: "tenant-b", activity_status: :TENANT_ACTIVITY_STATUS_COLD}
        ],
        took: 0.3
      }

      assert length(reply.tenants) == 2
      assert Enum.at(reply.tenants, 0).name == "tenant-a"
    end
  end

  describe "Tenant protobuf" do
    test "has name field" do
      tenant = %Tenant{name: "tenant-a"}
      assert tenant.name == "tenant-a"
    end

    test "has activity_status field" do
      tenant = %Tenant{
        name: "tenant-a",
        activity_status: :TENANT_ACTIVITY_STATUS_HOT
      }

      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_HOT
    end
  end

  describe "tenant activity statuses" do
    test "HOT status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_HOT}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_HOT
    end

    test "COLD status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_COLD}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_COLD
    end

    test "FROZEN status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_FROZEN}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_FROZEN
    end

    test "OFFLOADED status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_OFFLOADED}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_OFFLOADED
    end

    test "ACTIVE status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_ACTIVE}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_ACTIVE
    end

    test "INACTIVE status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_INACTIVE}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_INACTIVE
    end

    test "UNFREEZING status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_UNFREEZING}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_UNFREEZING
    end

    test "FREEZING status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_FREEZING}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_FREEZING
    end

    test "OFFLOADING status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_OFFLOADING}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_OFFLOADING
    end

    test "ONLOADING status" do
      tenant = %Tenant{name: "t", activity_status: :TENANT_ACTIVITY_STATUS_ONLOADING}
      assert tenant.activity_status == :TENANT_ACTIVITY_STATUS_ONLOADING
    end
  end

  describe "TenantNames protobuf" do
    test "can hold list of tenant names" do
      names = %TenantNames{values: ["tenant-1", "tenant-2", "tenant-3"]}
      assert names.values == ["tenant-1", "tenant-2", "tenant-3"]
    end

    test "can be empty" do
      names = %TenantNames{values: []}
      assert names.values == []
    end
  end
end
