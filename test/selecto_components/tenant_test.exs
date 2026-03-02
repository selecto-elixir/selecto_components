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
end
