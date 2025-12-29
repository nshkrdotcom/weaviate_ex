defmodule WeaviateEx.API.RBAC.ScopeTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.RBAC.Scope

  describe "new/1" do
    test "creates scope with all collections" do
      scope = Scope.new(collections: :all)

      assert scope.collections == :all
      assert scope.tenants == nil
      assert scope.shards == nil
    end

    test "creates scope with specific collections" do
      scope = Scope.new(collections: ["Article", "Author"])

      assert scope.collections == ["Article", "Author"]
    end

    test "creates scope with tenants" do
      scope = Scope.new(collections: ["Article"], tenants: ["tenant-a", "tenant-b"])

      assert scope.collections == ["Article"]
      assert scope.tenants == ["tenant-a", "tenant-b"]
    end

    test "creates scope with shards" do
      scope = Scope.new(collections: ["Article"], shards: ["shard-1"])

      assert scope.shards == ["shard-1"]
    end

    test "creates scope with all tenants" do
      scope = Scope.new(collections: ["Article"], tenants: :all)

      assert scope.tenants == :all
    end

    test "creates empty scope" do
      scope = Scope.new([])

      assert scope.collections == nil
      assert scope.tenants == nil
      assert scope.shards == nil
    end
  end

  describe "all_collections/0" do
    test "creates scope matching all collections" do
      scope = Scope.all_collections()

      assert scope.collections == :all
      assert scope.tenants == nil
      assert scope.shards == nil
    end
  end

  describe "collection/1" do
    test "creates scope for single collection" do
      scope = Scope.collection("Article")

      assert scope.collections == ["Article"]
    end
  end

  describe "collections/1" do
    test "creates scope for multiple collections" do
      scope = Scope.collections(["Article", "Author", "Comment"])

      assert scope.collections == ["Article", "Author", "Comment"]
    end
  end

  describe "with_tenants/2" do
    test "adds tenants to scope" do
      scope =
        Scope.collection("Article")
        |> Scope.with_tenants(["tenant-a", "tenant-b"])

      assert scope.collections == ["Article"]
      assert scope.tenants == ["tenant-a", "tenant-b"]
    end

    test "adds all tenants to scope" do
      scope =
        Scope.collection("Article")
        |> Scope.with_tenants(:all)

      assert scope.tenants == :all
    end
  end

  describe "with_shards/2" do
    test "adds shards to scope" do
      scope =
        Scope.collection("Article")
        |> Scope.with_shards(["shard-0", "shard-1"])

      assert scope.shards == ["shard-0", "shard-1"]
    end
  end

  describe "to_api/1" do
    test "converts all collections scope to API format" do
      scope = Scope.all_collections()
      api = Scope.to_api(scope)

      assert api["collection"] == "*"
    end

    test "converts single collection scope to API format" do
      scope = Scope.collection("Article")
      api = Scope.to_api(scope)

      assert api["collection"] == "Article"
    end

    test "converts multiple collections scope to API format" do
      scope = Scope.collections(["Article", "Author"])
      api = Scope.to_api(scope)

      # API uses repeated collection field
      assert api["collections"] == ["Article", "Author"]
    end

    test "converts scope with tenants to API format" do
      scope = Scope.new(collections: ["Article"], tenants: ["tenant-a"])
      api = Scope.to_api(scope)

      assert api["collection"] == "Article"
      assert api["tenant"] == "tenant-a"
    end

    test "converts scope with all tenants to API format" do
      scope = Scope.new(collections: ["Article"], tenants: :all)
      api = Scope.to_api(scope)

      assert api["tenant"] == "*"
    end

    test "converts nil scope to empty map" do
      assert Scope.to_api(nil) == %{}
    end
  end

  describe "from_api/1" do
    test "parses all collections from API" do
      api = %{"collection" => "*"}
      scope = Scope.from_api(api)

      assert scope.collections == :all
    end

    test "parses single collection from API" do
      api = %{"collection" => "Article"}
      scope = Scope.from_api(api)

      assert scope.collections == ["Article"]
    end

    test "parses scope with tenant from API" do
      api = %{"collection" => "Article", "tenant" => "tenant-a"}
      scope = Scope.from_api(api)

      assert scope.collections == ["Article"]
      assert scope.tenants == ["tenant-a"]
    end

    test "parses scope with all tenants from API" do
      api = %{"collection" => "Article", "tenant" => "*"}
      scope = Scope.from_api(api)

      assert scope.tenants == :all
    end

    test "parses empty map to nil" do
      assert Scope.from_api(%{}) == nil
      assert Scope.from_api(nil) == nil
    end
  end

  describe "struct fields" do
    test "scope has all required fields" do
      scope = %Scope{}

      assert Map.has_key?(scope, :collections)
      assert Map.has_key?(scope, :tenants)
      assert Map.has_key?(scope, :shards)
    end
  end
end
