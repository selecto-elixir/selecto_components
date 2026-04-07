defmodule SelectoComponents.Form.FilterPanelTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.FilterPanel
  alias SelectoComponents.Form.FilterRendering
  alias SelectoComponents.Theme

  test "renders the filter panel and tree builder" do
    html =
      render_component(
        fn assigns ->
          ~H"""
          <FilterPanel.panel
            active_tab={@active_tab}
            theme={@theme}
            filter_sets_adapter={@filter_sets_adapter}
            user_id={@user_id}
            domain={@domain}
            current_filters={@current_filters}
            id={@id}
            tree_builder_suffix={@tree_builder_suffix}
            available_filters={@available_filters}
            filters={@filters}
          >
            <:filter_form :let={{uuid, _index, _section, _filter_value}}>
              <span data-filter-slot={uuid}>filter</span>
            </:filter_form>
          </FilterPanel.panel>
          """
        end,
        base_assigns()
      )

    assert html =~ ~s(id="main-tabpanel-filter")
    assert html =~ "data-filter-slot"
  end

  defp base_assigns do
    domain = %{
      name: "FilterPanelTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :status],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          status: %{type: :string, name: "Status", colid: :status}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    selecto = Selecto.configure(domain, nil)
    filters = [{"f1", "filters", %{"filter" => "status", "comp" => "=", "value" => "open"}}]

    %{
      active_tab: "filter",
      theme: Theme.default_theme(:light),
      filter_sets_adapter: nil,
      user_id: 123,
      domain: "/reports/work-items",
      current_filters: filters,
      id: "filter-panel-test",
      tree_builder_suffix: FilterRendering.hash_filter_structure(filters),
      available_filters: FilterRendering.build_filter_list(selecto),
      filters: filters
    }
  end
end
