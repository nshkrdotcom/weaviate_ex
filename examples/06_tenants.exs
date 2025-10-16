# Multi-Tenancy Example
# Run: mix run examples/06_tenants.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, Tenants, Data, VectorConfig}
import ExampleHelper

ExampleHelper.check_weaviate!()

section("Multi-Tenancy - Tenant Management")

{:ok, client} = WeaviateEx.Client.new("http://localhost:8080")

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
step("Create multiple tenants")
command(~s/Tenants.create(client, "TenantArticle", ["CompanyA", "CompanyB", "CompanyC"])/)
{:ok, created} = Tenants.create(client, "TenantArticle", ["CompanyA", "CompanyB", "CompanyC"])
result("Created Tenants", Enum.map(created, & &1["name"]))

# List tenants
step("List all tenants")
command(~s/Tenants.list(client, "TenantArticle")/)
{:ok, tenants} = Tenants.list(client, "TenantArticle")
success("Found #{length(tenants)} tenants")

# Get specific tenant
step("Get tenant details")
command(~s/Tenants.get(client, "TenantArticle", "CompanyA")/)
{:ok, tenant} = Tenants.get(client, "TenantArticle", "CompanyA")
result("Tenant", tenant)

# Check existence
step("Check if tenant exists")
command(~s/Tenants.exists?(client, "TenantArticle", "CompanyA")/)
{:ok, true} = Tenants.exists?(client, "TenantArticle", "CompanyA")
success("Tenant exists")

# Deactivate tenant (set to COLD)
step("Deactivate tenant (set to COLD)")
command(~s/Tenants.deactivate(client, "TenantArticle", "CompanyB")/)
{:ok, _} = Tenants.deactivate(client, "TenantArticle", "CompanyB")
success("Tenant CompanyB deactivated")

# List active tenants only
step("List only active tenants")
command(~s/Tenants.list_active(client, "TenantArticle")/)
{:ok, active} = Tenants.list_active(client, "TenantArticle")
result("Active Tenants", Enum.map(active, & &1["name"]))

# Activate tenant
step("Activate tenant (set to HOT)")
command(~s/Tenants.activate(client, "TenantArticle", "CompanyB")/)
{:ok, _} = Tenants.activate(client, "TenantArticle", "CompanyB")
success("Tenant CompanyB activated")

# Count tenants
step("Count total tenants")
command(~s/Tenants.count(client, "TenantArticle")/)
{:ok, count} = Tenants.count(client, "TenantArticle")
success("Total tenants: #{count}")

# Delete tenant
step("Delete tenant")
command(~s/Tenants.delete(client, "TenantArticle", "CompanyC")/)
{:ok, _} = Tenants.delete(client, "TenantArticle", "CompanyC")
success("Deleted CompanyC")

cleanup(client, "TenantArticle")
IO.puts("\n#{green("✓")} Example complete!\n")
