defmodule SelectoComponents.TenantTest do
  use ExUnit.Case, async: true

  test "scoped_context returns original context when tenant is missing" do
    assert SelectoComponents.Tenant.scoped_context("/pagila", nil) == "/pagila"
  end

  test "scoped_context prefixes context with tenant namespace and id" do
    scoped =
      SelectoComponents.Tenant.scoped_context("/pagila", %{tenant_id: "acme", namespace: "org"})

    assert scoped == "org:acme:/pagila"
  end

  test "scoped_context isolates persisted keys between tenants" do
    tenant_a = SelectoComponents.Tenant.scoped_context("/pagila", %{tenant_id: "acme"})
    tenant_b = SelectoComponents.Tenant.scoped_context("/pagila", %{tenant_id: "globex"})

    assert tenant_a == "tenant:acme:/pagila"
    assert tenant_b == "tenant:globex:/pagila"
    refute tenant_a == tenant_b
  end

  test "scoped_context supports atom contexts used in adapter modules" do
    scoped = SelectoComponents.Tenant.scoped_context(:pagila_films, %{tenant_id: "acme"})
    assert scoped == "tenant:acme:pagila_films"
  end
end
