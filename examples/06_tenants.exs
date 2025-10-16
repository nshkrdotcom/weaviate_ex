# Multi-Tenancy Example
# Run: mix run examples/06_tenants.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, Tenants, VectorConfig}

ExampleHelper.check_weaviate!()

ExampleHelper.section("Multi-Tenancy - Tenant Management")

{:ok, client} = WeaviateEx.Client.new(base_url: "http://localhost:8080")

# Create multi-tenant collection
config =
  VectorConfig.new("TenantArticle")
  |> VectorConfig.with_vectorizer(:none)
  |> VectorConfig.with_multi_tenancy(enabled: true)
  |> VectorConfig.with_properties([
    %{"name" => "title", "dataType" => ["text"]}
  ])

Collections.create(client, config)

# Create tenants
ExampleHelper.step("Create multiple tenants")

ExampleHelper.command(
  ~s/Tenants.create(client, "TenantArticle", ["CompanyA", "CompanyB", "CompanyC"])/
)

{:ok, created} = Tenants.create(client, "TenantArticle", ["CompanyA", "CompanyB", "CompanyC"])
ExampleHelper.result("Created Tenants", Enum.map(created, & &1["name"]))

# List tenants
ExampleHelper.step("List all tenants")
ExampleHelper.command(~s/Tenants.list(client, "TenantArticle")/)
{:ok, tenants} = Tenants.list(client, "TenantArticle")
ExampleHelper.success("Found #{length(tenants)} tenants")

# Get specific tenant
ExampleHelper.step("Get tenant details")
ExampleHelper.command(~s/Tenants.get(client, "TenantArticle", "CompanyA")/)
{:ok, tenant} = Tenants.get(client, "TenantArticle", "CompanyA")
ExampleHelper.result("Tenant", tenant)

# Check existence
ExampleHelper.step("Check if tenant exists")
ExampleHelper.command(~s/Tenants.exists?(client, "TenantArticle", "CompanyA")/)
{:ok, true} = Tenants.exists?(client, "TenantArticle", "CompanyA")
ExampleHelper.success("Tenant exists")

# Deactivate tenant (set to COLD)
ExampleHelper.step("Deactivate tenant (set to COLD)")
ExampleHelper.command(~s/Tenants.deactivate(client, "TenantArticle", "CompanyB")/)
{:ok, _} = Tenants.deactivate(client, "TenantArticle", "CompanyB")
ExampleHelper.success("Tenant CompanyB deactivated")

# List active tenants only
ExampleHelper.step("List only active tenants")
ExampleHelper.command(~s/Tenants.list_active(client, "TenantArticle")/)
{:ok, active} = Tenants.list_active(client, "TenantArticle")
ExampleHelper.result("Active Tenants", Enum.map(active, & &1["name"]))

# Activate tenant
ExampleHelper.step("Activate tenant (set to HOT)")
ExampleHelper.command(~s/Tenants.activate(client, "TenantArticle", "CompanyB")/)
{:ok, _} = Tenants.activate(client, "TenantArticle", "CompanyB")
ExampleHelper.success("Tenant CompanyB activated")

# Count tenants
ExampleHelper.step("Count total tenants")
ExampleHelper.command(~s/Tenants.count(client, "TenantArticle")/)
{:ok, count} = Tenants.count(client, "TenantArticle")
ExampleHelper.success("Total tenants: #{count}")

# Delete tenant
ExampleHelper.step("Delete tenant")
ExampleHelper.command(~s/Tenants.delete(client, "TenantArticle", "CompanyC")/)
{:ok, _} = Tenants.delete(client, "TenantArticle", "CompanyC")
ExampleHelper.success("Deleted CompanyC")

ExampleHelper.cleanup(client, "TenantArticle")
IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
