defmodule SelectoComponents.Views.Graph.IntegrationTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Graph.{Process, Component, Form}

  describe "end-to-end graph view workflow" do
    setup do
      # Mock selecto with realistic domain
      selecto = %{
        domain: fn ->
          %{
            default_graph_x_axis: ["category"],
            default_graph_y_axis: ["film_count"],
            default_chart_type: "bar"
          }
        end,
        set: %{},
        field: fn field ->
          case field do
            "category" -> %{colid: :category, type: :string}
            "rating" -> %{colid: :rating, type: :string}
            "film_count" -> %{colid: :film_id, type: :integer}
            "release_year" -> %{colid: :release_year, type: :integer}
            "created_at" -> %{colid: :created_at, type: :naive_datetime}
          end
        end
      }

      columns = %{
        "category" => %{colid: :category, type: :string},
        "rating" => %{colid: :rating, type: :string},
        "film_count" => %{colid: :film_id, type: :integer},
        "release_year" => %{colid: :release_year, type: :integer},
        "created_at" => %{colid: :created_at, type: :naive_datetime}
      }

      {:ok, selecto: selecto, columns: columns}
    end

    test "complete workflow: initial state -> form params -> view generation -> component rendering", %{
      selecto: selecto,
      columns: columns
    } do
      # Step 1: Generate initial state
      initial_state = Process.initial_state(selecto, :graph)
      assert initial_state.chart_type == "bar"

      # Step 2: Simulate user form submission
      form_params = %{
        "x_axis" => %{
          "1" => %{"field" => "category", "index" => "0", "alias" => "Film Category"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Number of Films"}
        },
        "series" => %{
          "1" => %{"field" => "rating", "index" => "0", "alias" => "Rating"}
        },
        "chart_type" => "bar",
        "options" => %{
          "title" => "Films by Category and Rating",
          "x_axis_label" => "Category",
          "y_axis_label" => "Count"
        }
      }

      # Step 3: Convert form params to state
      state = Process.param_to_state(form_params, :graph)
      assert state.chart_type == "bar"
      assert state.options["title"] == "Films by Category and Rating"
      assert length(state.x_axis) == 1
      assert length(state.y_axis) == 1
      assert length(state.series) == 1

      # Step 4: Generate Selecto view structure
      {view_set, _} = Process.view(nil, form_params, columns, [], nil)
      
      assert view_set.chart_type == "bar"
      assert length(view_set.x_axis_groups) == 1
      assert length(view_set.aggregates) == 1
      assert length(view_set.series_groups) == 1
      assert length(view_set.groups) == 2  # x_axis + series
      
      # Check GROUP BY and ORDER BY are properly set for multi-dimensional data
      assert view_set.group_by == [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}]
      assert view_set.order_by == [{:literal_position, 1}, {:literal_position, 2}]

      # Step 5: Simulate query execution results
      query_results = [
        ["Action", "PG-13", 25],
        ["Action", "R", 15],
        ["Comedy", "PG", 30],
        ["Comedy", "PG-13", 20],
        ["Drama", "R", 35],
        ["Drama", "PG-13", 10]
      ]

      aliases = ["Film Category", "Rating", "Number of Films"]

      # Step 6: Prepare chart data
      assigns = %{
        selecto: %{set: view_set},
        chart_options: %{title: "Films by Category and Rating"}
      }

      chart_data = Component.prepare_chart_data(assigns, query_results, aliases)

      # Should group data properly for multi-series bar chart
      assert length(chart_data.labels) > 0
      assert length(chart_data.datasets) > 0

      # Step 7: Test component rendering
      render_assigns = %{
        executed: true,
        query_results: {query_results, [], aliases},
        selecto: %{set: view_set},
        id: "integration-test-chart"
      }

      html = Component.render(render_assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      assert html_string =~ "phx-hook=\".GraphViewHook\""
      assert html_string =~ "data-chart-type=\"bar\""
      assert html_string =~ "canvas"
      assert html_string =~ "Export"

      # Step 8: Test form rendering with the state
      form_assigns = %{
        view_config: %{
          views: %{
            graph: state
          }
        },
        view: :graph,
        columns: [
          {"category", "Category", :string},
          {"rating", "Rating", :string},
          {"film_count", "Film Count", :integer}
        ],
        selecto: selecto
      }

      form_html = Form.render(form_assigns)
      form_html_string = Phoenix.HTML.safe_to_string(form_html)

      assert form_html_string =~ "Chart Type"
      assert form_html_string =~ "X-Axis (Categories)"
      assert form_html_string =~ "Y-Axis (Values)"
      assert form_html_string =~ "Series Grouping"
    end

    test "datetime grouping workflow with temporal data", %{selecto: selecto, columns: columns} do
      # Test datetime field with year/month grouping
      form_params = %{
        "x_axis" => %{
          "1" => %{"field" => "created_at", "index" => "0", "alias" => "Year", "format" => "YYYY"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Films per Year"}
        },
        "chart_type" => "line"
      }

      {view_set, _} = Process.view(nil, form_params, columns, [], nil)

      # Check datetime processing
      [{col, field_selector}] = view_set.x_axis_groups
      assert col.colid == :created_at
      assert elem(field_selector, 0) == :field
      assert elem(field_selector, 1) == {:to_char, {:created_at, "YYYY"}}
      assert elem(field_selector, 2) == "Year"

      # Simulate temporal query results
      query_results = [
        ["2020", 120],
        ["2021", 135], 
        ["2022", 90],
        ["2023", 110]
      ]

      aliases = ["Year", "Films per Year"]

      assigns = %{selecto: %{set: view_set}}
      chart_data = Component.prepare_chart_data(assigns, query_results, aliases)

      # Line chart should have proper temporal formatting
      assert chart_data.labels == ["2020", "2021", "2022", "2023"]
      assert length(chart_data.datasets) == 1

      [dataset] = chart_data.datasets
      assert dataset.label == "Films per Year"
      assert dataset.data == [120, 135, 90, 110]
      assert dataset.fill == false  # Line chart shouldn't fill by default
      assert dataset.tension == 0.4
    end

    test "pie chart workflow with categorical data", %{selecto: selecto, columns: columns} do
      form_params = %{
        "x_axis" => %{
          "1" => %{"field" => "rating", "index" => "0", "alias" => "Movie Rating"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Count"}
        },
        "chart_type" => "pie"
      }

      {view_set, _} = Process.view(nil, form_params, columns, [], nil)
      
      query_results = [
        ["G", 45],
        ["PG", 89],
        ["PG-13", 123],
        ["R", 67],
        ["NC-17", 12]
      ]

      aliases = ["Movie Rating", "Count"]

      assigns = %{selecto: %{set: view_set}}
      chart_data = Component.prepare_chart_data(assigns, query_results, aliases)

      # Pie chart should have proper structure
      assert chart_data.labels == ["G", "PG", "PG-13", "R", "NC-17"]
      assert length(chart_data.datasets) == 1

      [dataset] = chart_data.datasets
      assert dataset.data == [45, 89, 123, 67, 12]
      assert length(dataset.backgroundColor) == 5  # One color per slice
      assert length(dataset.borderColor) == 5

      # Test chart options for pie chart (should not have scales)
      chart_options = Component.prepare_chart_options(assigns)
      refute Map.has_key?(chart_options, :scales)
    end

    test "multi-aggregate workflow with multiple Y-axis values", %{selecto: selecto, columns: columns} do
      form_params = %{
        "x_axis" => %{
          "1" => %{"field" => "category", "index" => "0", "alias" => "Category"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Film Count"},
          "2" => %{"field" => "film_count", "index" => "1", "function" => "sum", "alias" => "Total Films"}
        },
        "chart_type" => "bar"
      }

      {view_set, _} = Process.view(nil, form_params, columns, [], nil)

      # Should have 2 aggregates
      assert length(view_set.aggregates) == 2
      [first_agg, second_agg] = view_set.aggregates

      assert elem(first_agg, 1) == {:count, "film_count"}
      assert elem(first_agg, 2) == "Film Count"
      assert elem(second_agg, 1) == {:sum, "film_count"}
      assert elem(second_agg, 2) == "Total Films"

      # Simulate results with multiple aggregates
      query_results = [
        ["Action", 30, 450],
        ["Comedy", 45, 650],
        ["Drama", 25, 380]
      ]

      aliases = ["Category", "Film Count", "Total Films"]

      assigns = %{selecto: %{set: view_set}}
      chart_data = Component.prepare_chart_data(assigns, query_results, aliases)

      # Should create multiple datasets
      assert length(chart_data.datasets) == 2
      [count_dataset, sum_dataset] = chart_data.datasets

      assert count_dataset.label == "Film Count"
      assert count_dataset.data == [30, 45, 25]

      assert sum_dataset.label == "Total Films"
      assert sum_dataset.data == [450, 650, 380]
    end

    test "error handling and edge cases", %{selecto: selecto, columns: columns} do
      # Test with empty parameters
      empty_params = %{}
      state = Process.param_to_state(empty_params, :graph)
      {view_set, _} = Process.view(nil, empty_params, columns, [], nil)

      # Should handle gracefully
      assert state.chart_type == "bar"
      assert view_set.groups == []
      assert view_set.aggregates == []

      # Test component with empty results
      empty_assigns = %{
        executed: true,
        query_results: {[], [], []},
        selecto: %{set: view_set},
        id: "empty-chart"
      }

      chart_data = Component.prepare_chart_data(empty_assigns, [], [])
      
      # Should fall back to simple preparation
      assert chart_data.labels == []
      assert chart_data.datasets == []

      # Test rendering with no data
      html = Component.render(empty_assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      # Should still render chart container
      assert html_string =~ "phx-hook=\".GraphViewHook\""
      assert html_string =~ "canvas"
    end
  end
end