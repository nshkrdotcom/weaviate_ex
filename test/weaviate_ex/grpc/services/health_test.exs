defmodule WeaviateEx.GRPC.Services.HealthTest do
  use ExUnit.Case, async: true

  alias Weaviate.V1.{WeaviateHealthCheckRequest, WeaviateHealthCheckResponse}

  @moduletag :grpc

  describe "WeaviateHealthCheckRequest protobuf" do
    test "can create with service name" do
      request = %WeaviateHealthCheckRequest{service: "weaviate.v1.Weaviate"}
      assert request.service == "weaviate.v1.Weaviate"
    end

    test "can create with empty service for overall health" do
      request = %WeaviateHealthCheckRequest{service: ""}
      assert request.service == ""
    end
  end

  describe "WeaviateHealthCheckResponse protobuf" do
    test "can have SERVING status" do
      response = %WeaviateHealthCheckResponse{status: :SERVING}
      assert response.status == :SERVING
    end

    test "can have NOT_SERVING status" do
      response = %WeaviateHealthCheckResponse{status: :NOT_SERVING}
      assert response.status == :NOT_SERVING
    end

    test "can have UNKNOWN status" do
      response = %WeaviateHealthCheckResponse{status: :UNKNOWN}
      assert response.status == :UNKNOWN
    end
  end

  describe "health status values" do
    test "SERVING indicates healthy state" do
      response = %WeaviateHealthCheckResponse{status: :SERVING}
      assert response.status == :SERVING
    end

    test "NOT_SERVING indicates unhealthy state" do
      response = %WeaviateHealthCheckResponse{status: :NOT_SERVING}
      assert response.status == :NOT_SERVING
    end

    test "UNKNOWN indicates indeterminate state" do
      response = %WeaviateHealthCheckResponse{status: :UNKNOWN}
      assert response.status == :UNKNOWN
    end
  end
end
