defmodule SelectoComponents.Form.ViewPanelTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.ViewPanel
  alias SelectoComponents.Theme

  test "renders the view panel and current view mode form" do
    html = render_component(&ViewPanel.panel/1, base_assigns(%{}))

    assert html =~ ~s(id="main-tabpanel-view")
    assert html =~ ~s(id="tabs-view_mode")
    assert html =~ ~s(id="tabpanel-detail")
    assert html =~ "Columns"
  end

  defp base_assigns(overrides) do
    domain = %{
      name: "ViewPanelTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :status, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          status: %{type: :string, name: "Status", colid: :status},
          title: %{type: :string, name: "Title", colid: :title}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Map.merge(
      %{
        active_tab: "view",
        theme: Theme.default_theme(:light),
        saved_view_config_module: nil,
        view_config: %{
          view_mode: "detail",
          filters: [],
          views: %{
            detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"}
          }
        },
        saved_view_context: nil,
        current_user_id: 123,
        parent_id: %Phoenix.LiveComponent.CID{cid: 1},
        views: [{:detail, SelectoComponents.Views.Detail, "Detail View", %{}}],
        columns: [
          {:id, "ID", %{type: :integer, format: nil, icon: nil, icon_family: nil}},
          {:status, "Status", %{type: :string, format: nil, icon: nil, icon_family: nil}},
          {:title, "Title", %{type: :string, format: nil, icon: nil, icon_family: nil}}
        ],
        selecto: Selecto.configure(domain, nil)
      },
      overrides
    )
  end
end
