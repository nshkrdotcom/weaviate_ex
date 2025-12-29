defmodule WeaviateEx.Backup.LocationTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Backup.Location

  describe "filesystem/1" do
    test "creates Filesystem struct" do
      location = Location.filesystem("/var/backups")

      assert %Location.Filesystem{} = location
      assert location.path == "/var/backups"
    end
  end

  describe "Location.Filesystem" do
    test "new/1 creates struct" do
      location = Location.Filesystem.new("/backups")

      assert location.path == "/backups"
    end

    test "to_api/1 returns correct map" do
      location = Location.Filesystem.new("/var/weaviate/backups")
      api_map = Location.Filesystem.to_api(location)

      assert api_map == %{path: "/var/weaviate/backups"}
    end
  end

  describe "s3/3" do
    test "creates S3 struct with required fields" do
      location = Location.s3("my-bucket", "/backups")

      assert %Location.S3{} = location
      assert location.bucket == "my-bucket"
      assert location.path == "/backups"
      assert location.use_ssl == true
    end

    test "creates S3 struct with all options" do
      location =
        Location.s3("my-bucket", "/backups",
          endpoint: "s3.us-west-2.amazonaws.com",
          region: "us-west-2",
          access_key_id: "AKIAIOSFODNN7EXAMPLE",
          secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
          use_ssl: false
        )

      assert location.bucket == "my-bucket"
      assert location.path == "/backups"
      assert location.endpoint == "s3.us-west-2.amazonaws.com"
      assert location.region == "us-west-2"
      assert location.access_key_id == "AKIAIOSFODNN7EXAMPLE"
      assert location.secret_access_key == "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      assert location.use_ssl == false
    end
  end

  describe "Location.S3.to_api/1" do
    test "includes all provided fields" do
      location =
        Location.S3.new("my-bucket", "/backups",
          endpoint: "s3.amazonaws.com",
          region: "us-east-1",
          access_key_id: "key123",
          secret_access_key: "secret456"
        )

      api_map = Location.S3.to_api(location)

      assert api_map[:bucket] == "my-bucket"
      assert api_map[:path] == "/backups"
      assert api_map[:endpoint] == "s3.amazonaws.com"
      assert api_map[:region] == "us-east-1"
      assert api_map[:accessKeyId] == "key123"
      assert api_map[:secretAccessKey] == "secret456"
      assert api_map[:useSSL] == true
    end

    test "excludes nil optional fields" do
      location = Location.S3.new("my-bucket", "/backups")
      api_map = Location.S3.to_api(location)

      assert api_map[:bucket] == "my-bucket"
      assert api_map[:path] == "/backups"
      assert api_map[:useSSL] == true
      refute Map.has_key?(api_map, :endpoint)
      refute Map.has_key?(api_map, :region)
      refute Map.has_key?(api_map, :accessKeyId)
      refute Map.has_key?(api_map, :secretAccessKey)
    end
  end

  describe "gcs/3" do
    test "creates GCS struct with required fields" do
      location = Location.gcs("my-bucket", "/backups")

      assert %Location.GCS{} = location
      assert location.bucket == "my-bucket"
      assert location.path == "/backups"
    end

    test "creates GCS struct with all options" do
      credentials = %{"type" => "service_account", "project_id" => "my-project"}

      location =
        Location.gcs("my-bucket", "/backups",
          project_id: "my-project",
          credentials: credentials
        )

      assert location.project_id == "my-project"
      assert location.credentials == credentials
    end
  end

  describe "Location.GCS.to_api/1" do
    test "includes all provided fields" do
      credentials = %{"type" => "service_account"}

      location =
        Location.GCS.new("my-bucket", "/backups",
          project_id: "my-project",
          credentials: credentials
        )

      api_map = Location.GCS.to_api(location)

      assert api_map[:bucket] == "my-bucket"
      assert api_map[:path] == "/backups"
      assert api_map[:projectId] == "my-project"
      assert api_map[:credentials] == credentials
    end

    test "excludes nil optional fields" do
      location = Location.GCS.new("my-bucket", "/backups")
      api_map = Location.GCS.to_api(location)

      assert api_map[:bucket] == "my-bucket"
      assert api_map[:path] == "/backups"
      refute Map.has_key?(api_map, :projectId)
      refute Map.has_key?(api_map, :credentials)
    end
  end

  describe "azure/3" do
    test "creates Azure struct with required fields" do
      location = Location.azure("my-container", "/backups")

      assert %Location.Azure{} = location
      assert location.container == "my-container"
      assert location.path == "/backups"
    end

    test "creates Azure struct with connection_string" do
      location =
        Location.azure("my-container", "/backups",
          connection_string: "DefaultEndpointsProtocol=https;AccountName=..."
        )

      assert location.connection_string == "DefaultEndpointsProtocol=https;AccountName=..."
    end
  end

  describe "Location.Azure.to_api/1" do
    test "includes connection_string when provided" do
      location =
        Location.Azure.new("my-container", "/backups",
          connection_string: "connection-string-here"
        )

      api_map = Location.Azure.to_api(location)

      assert api_map[:container] == "my-container"
      assert api_map[:path] == "/backups"
      assert api_map[:connectionString] == "connection-string-here"
    end

    test "excludes nil connection_string" do
      location = Location.Azure.new("my-container", "/backups")
      api_map = Location.Azure.to_api(location)

      assert api_map[:container] == "my-container"
      assert api_map[:path] == "/backups"
      refute Map.has_key?(api_map, :connectionString)
    end
  end

  describe "backend/1" do
    test "returns :filesystem for Filesystem location" do
      location = Location.filesystem("/backups")
      assert Location.backend(location) == :filesystem
    end

    test "returns :s3 for S3 location" do
      location = Location.s3("bucket", "/path")
      assert Location.backend(location) == :s3
    end

    test "returns :gcs for GCS location" do
      location = Location.gcs("bucket", "/path")
      assert Location.backend(location) == :gcs
    end

    test "returns :azure for Azure location" do
      location = Location.azure("container", "/path")
      assert Location.backend(location) == :azure
    end
  end

  describe "to_api/1" do
    test "delegates to Filesystem.to_api for Filesystem" do
      location = Location.filesystem("/backups")
      api_map = Location.to_api(location)

      assert api_map == %{path: "/backups"}
    end

    test "delegates to S3.to_api for S3" do
      location = Location.s3("bucket", "/path")
      api_map = Location.to_api(location)

      assert api_map[:bucket] == "bucket"
      assert api_map[:path] == "/path"
    end

    test "delegates to GCS.to_api for GCS" do
      location = Location.gcs("bucket", "/path")
      api_map = Location.to_api(location)

      assert api_map[:bucket] == "bucket"
      assert api_map[:path] == "/path"
    end

    test "delegates to Azure.to_api for Azure" do
      location = Location.azure("container", "/path")
      api_map = Location.to_api(location)

      assert api_map[:container] == "container"
      assert api_map[:path] == "/path"
    end
  end
end
