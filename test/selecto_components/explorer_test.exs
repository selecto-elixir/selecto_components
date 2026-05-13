defmodule SelectoComponents.ExplorerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Explorer
  alias SelectoComponents.Explorer.Config

  test "renders explorer shell with controls and results zones" do
    html = render_component(Explorer, base_assigns(%{}))

    assert html =~ ~s(data-selecto-explorer-shell)
    assert html =~ ~s(data-selecto-explorer-controls)
    assert html =~ ~s(data-selecto-explorer-results)
    assert html =~ ~s(id="selecto-form-explorer-test-controls")
    assert html =~ ~s(id="selecto-results-explorer-test-results-)
  end

  test "supports config-driven explorer setup" do
    config =
      Config.new(%{
        id: "config-explorer",
        selecto: selecto(),
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{}}
        ],
        title: "Products Explorer",
        presentation: %{timezone: "America/New_York"}
      })

    html =
      render_component(Explorer, %{
        config: config,
        active_tab: "view",
        view_config: %{
          view_mode: "detail",
          filters: [],
          views: %{
            detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
            aggregate: %{group_by: [], aggregate: [], per_page: "30"}
          }
        },
        executed: false,
        applied_view: nil
      })

    assert html =~ "Products Explorer"
    assert html =~ ~s(id="selecto-explorer-config-explorer")
    assert html =~ ~s(id="selecto-form-config-explorer-controls")
  end

  defp base_assigns(overrides) do
    Map.merge(
      %{
        id: "explorer-test",
        selecto: selecto(),
        active_tab: "view",
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{}}
        ],
        view_config: %{
          view_mode: "detail",
          filters: [],
          views: %{
            detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
            aggregate: %{group_by: [], aggregate: [], per_page: "30"}
          }
        },
        executed: false,
        applied_view: nil
      },
      overrides
    )
  end

  defp selecto do
    domain = %{
      name: "ExplorerTest",
      source: %{
        source_table: "products",
        primary_key: :id,
        fields: [:id, :name, :status],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          name: %{type: :string, name: "Name", colid: :name},
          status: %{type: :string, name: "Status", colid: :status}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end
end
