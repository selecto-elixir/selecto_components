defmodule SelectoComponents.ExportedViewsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.ExportedViews

  test "build_create_attrs snapshots the current view state" do
    assigns = %{
      selecto: %{
        domain: %{name: "orders"},
        postgrex_opts: :repo,
        adapter: Selecto.DB.PostgreSQL
      },
      view_config: %{
        view_mode: "detail",
        filters: [],
        views: %{detail: %{selected: []}}
      },
      views: [{:detail, SelectoComponents.Views.Detail, "Detail", %{}}],
      path: "/orders",
      exported_view_context: "tenant:1:/orders",
      current_user_id: "1"
    }

    attrs =
      ExportedViews.build_create_attrs(assigns, %{
        "name" => "Order export",
        "cache_ttl_hours" => "6",
        "ip_allowlist_text" => "10.0.0.0/24"
      })

    assert attrs.name == "Order export"
    assert attrs.context == "tenant:1:/orders"
    assert attrs.view_type == "detail"
    assert attrs.cache_ttl_hours == 6
    assert attrs.ip_allowlist_text == "10.0.0.0/24"
    assert is_binary(attrs.public_id)

    assert {:ok, snapshot} = ExportedViews.decode_term(attrs.snapshot_blob)
    assert snapshot.params["view_mode"] == "detail"
    assert snapshot.context == "tenant:1:/orders"
  end

  test "build_create_attrs redacts secrets from persisted connection options" do
    assigns = %{
      selecto: %{
        domain: %{name: "orders"},
        postgrex_opts: [
          hostname: "db",
          username: "demo",
          password: "secret",
          ssl_opts: [cacertfile: "/tmp/ca.pem"]
        ],
        adapter: Selecto.DB.PostgreSQL
      },
      view_config: %{view_mode: "detail", filters: [], views: %{detail: %{selected: []}}},
      views: [{:detail, SelectoComponents.Views.Detail, "Detail", %{}}],
      path: "/orders"
    }

    attrs = ExportedViews.build_create_attrs(assigns, %{"name" => "Safe export"})
    assert {:ok, snapshot} = ExportedViews.decode_term(attrs.snapshot_blob)
    assert snapshot.postgrex_opts[:hostname] == "db"
    assert snapshot.postgrex_opts[:username] == "demo"
    refute Keyword.has_key?(snapshot.postgrex_opts, :password)
    refute Keyword.has_key?(snapshot.postgrex_opts, :ssl_opts)
  end

  test "decode_term rejects unsafe binaries" do
    blob = <<131, 100, 0, 21, "selecto_new_atom_test">>

    assert {:error, :invalid_blob} = ExportedViews.decode_term(blob)
  end

  test "cache_status distinguishes fresh stale and disabled exports" do
    now = ~U[2026-03-16 10:00:00Z]

    assert ExportedViews.cache_status(%{cache_blob: nil}, now) == :missing

    assert ExportedViews.cache_status(
             %{cache_blob: <<1>>, cache_expires_at: ~U[2026-03-16 12:00:00Z]},
             now
           ) == :fresh

    assert ExportedViews.cache_status(
             %{cache_blob: <<1>>, cache_expires_at: ~U[2026-03-16 08:00:00Z]},
             now
           ) == :stale

    assert ExportedViews.cache_status(%{disabled_at: now}, now) == :disabled
  end
end
