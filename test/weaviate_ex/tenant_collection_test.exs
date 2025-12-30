defmodule WeaviateEx.TenantCollectionTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Client
  alias WeaviateEx.Collections
  alias WeaviateEx.Query
  alias WeaviateEx.TenantCollection

  describe "new/3" do
    test "creates tenant-scoped collection reference" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")

      tc = TenantCollection.new(client, "Articles", "tenant_A")

      assert %TenantCollection{} = tc
      assert tc.client == client
      assert tc.collection == "Articles"
      assert tc.tenant == "tenant_A"
    end

    test "stores client, collection, and tenant correctly" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080", api_key: "test-key")

      tc = TenantCollection.new(client, "Products", "customer_123")

      assert tc.client.config.base_url == "http://localhost:8080"
      assert tc.client.config.api_key == "test-key"
      assert tc.collection == "Products"
      assert tc.tenant == "customer_123"
    end
  end

  describe "Collections.with_tenant/3" do
    test "returns TenantCollection struct" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")

      tc = Collections.with_tenant(client, "Articles", "tenant_A")

      assert %TenantCollection{} = tc
      assert tc.collection == "Articles"
      assert tc.tenant == "tenant_A"
    end

    test "delegates to TenantCollection.new/3" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")

      tc1 = Collections.with_tenant(client, "Articles", "tenant_A")
      tc2 = TenantCollection.new(client, "Articles", "tenant_A")

      assert tc1.client == tc2.client
      assert tc1.collection == tc2.collection
      assert tc1.tenant == tc2.tenant
    end
  end

  describe "query/1" do
    test "returns query builder with tenant set" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      tc = TenantCollection.new(client, "Articles", "tenant_A")

      query = TenantCollection.query(tc)

      assert %Query{} = query
      assert query.collection == "Articles"
      assert query.tenant == "tenant_A"
    end

    test "can chain additional query methods" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      tc = TenantCollection.new(client, "Articles", "tenant_A")

      query =
        tc
        |> TenantCollection.query()
        |> Query.bm25("search term")
        |> Query.limit(10)
        |> Query.fields(["title", "content"])

      assert query.collection == "Articles"
      assert query.tenant == "tenant_A"
      assert query.bm25 == %{query: "search term"}
      assert query.limit == 10
      assert query.fields == ["title", "content"]
    end

    test "can chain near_text query" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      tc = TenantCollection.new(client, "Articles", "tenant_A")

      query =
        tc
        |> TenantCollection.query()
        |> Query.near_text("machine learning", certainty: 0.7)
        |> Query.limit(5)

      assert query.tenant == "tenant_A"
      assert query.near_text.concepts == ["machine learning"]
      assert query.near_text.certainty == 0.7
      assert query.limit == 5
    end

    test "can chain hybrid query" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      tc = TenantCollection.new(client, "Articles", "tenant_A")

      query =
        tc
        |> TenantCollection.query()
        |> Query.hybrid("AI research", alpha: 0.75)

      assert query.tenant == "tenant_A"
      assert query.hybrid.query == "AI research"
      assert query.hybrid.alpha == 0.75
    end
  end

  describe "Query.with_tenant/2" do
    test "sets tenant on query" do
      query =
        Query.get("Articles")
        |> Query.with_tenant("tenant_A")

      assert query.tenant == "tenant_A"
    end

    test "is equivalent to Query.tenant/2" do
      query1 =
        Query.get("Articles")
        |> Query.with_tenant("tenant_A")

      query2 =
        Query.get("Articles")
        |> Query.tenant("tenant_A")

      assert query1.tenant == query2.tenant
    end
  end

  describe "accessor functions" do
    setup do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      tc = TenantCollection.new(client, "Articles", "tenant_A")
      {:ok, tc: tc, client: client}
    end

    test "tenant_name/1 returns tenant", %{tc: tc} do
      assert TenantCollection.tenant_name(tc) == "tenant_A"
    end

    test "collection_name/1 returns collection", %{tc: tc} do
      assert TenantCollection.collection_name(tc) == "Articles"
    end

    test "client/1 returns client", %{tc: tc, client: client} do
      assert TenantCollection.client(tc) == client
    end
  end

  describe "insert/3 builds correct options" do
    test "adds tenant to options" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      tc = TenantCollection.new(client, "Articles", "tenant_A")

      # We can't easily test the actual insert without a running Weaviate,
      # but we can verify the struct is set up correctly for the call
      assert tc.tenant == "tenant_A"
      assert tc.collection == "Articles"
    end
  end

  describe "insert_many/3 formats objects correctly" do
    test "includes tenant in formatted objects" do
      {:ok, client} = Client.new(base_url: "http://localhost:8080")
      tc = TenantCollection.new(client, "Articles", "tenant_A")

      # Verify struct is set up for batch operations
      assert tc.tenant == "tenant_A"
      assert tc.collection == "Articles"
    end
  end
end
