defmodule SelectoComponents.ExportedViewsIPAllowlistTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.ExportedViews.IPAllowlist

  test "allows unrestricted exports when no allowlist is configured" do
    assert IPAllowlist.allowed?(%{}, {127, 0, 0, 1})
  end

  test "matches exact IPs and CIDR ranges" do
    view = %{ip_allowlist_text: "203.0.113.8\n10.0.0.0/24"}

    assert IPAllowlist.allowed?(view, {203, 0, 113, 8})
    assert IPAllowlist.allowed?(view, {10, 0, 0, 42})
    refute IPAllowlist.allowed?(view, {10, 0, 1, 42})
    refute IPAllowlist.allowed?(view, {127, 0, 0, 1})
  end
end
