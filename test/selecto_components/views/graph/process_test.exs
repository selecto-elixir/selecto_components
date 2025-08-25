defmodule SelectoComponents.Views.Graph.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Graph.Process

  describe "param_to_state/2" do
    test "converts form parameters to view state" do
      params = %{
        "x_axis" => %{
          "1" => %{"field" => "category", "index" => "0", "alias" => "Category"},
          "2" => %{"field" => "release_year", "index" => "1", "alias" => ""}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Film Count"}
        },
        "series" => %{
          "1" => %{"field" => "rating", "index" => "0", "alias" => "Rating"}
        },
        "chart_type" => "bar",
        "options" => %{"title" => "Films by Category"}
      }

      state = Process.param_to_state(params, :graph)

      assert state.chart_type == "bar"
      assert state.options == %{"title" => "Films by Category"}
      assert length(state.x_axis) == 2
      assert length(state.y_axis) == 1
      assert length(state.series) == 1

      # Check x_axis fields are properly ordered by index
      [first_x, second_x] = state.x_axis
      assert elem(first_x, 1) == "category"
      assert elem(second_x, 1) == "release_year"
    end

    test "handles empty parameters gracefully" do
      params = %{}
      state = Process.param_to_state(params, :graph)

      assert state.chart_type == "bar"
      assert state.options == %{}
      assert state.x_axis == []
      assert state.y_axis == []
      assert state.series == []
    end

    test "defaults chart_type when not provided" do
      params = %{"x_axis" => %{}}
      state = Process.param_to_state(params, :graph)

      assert state.chart_type == "bar"
    end
  end

  describe "initial_state/2" do
    test "creates initial state from selecto domain" do
      # Mock selecto with domain configuration
      domain = %{
        default_graph_x_axis: ["category"],
        default_graph_y_axis: ["count"],
        default_chart_type: "line",
        default_chart_options: %{"title" => "Default Chart"}
      }

      selecto = %{domain: fn -> domain end}

      state = Process.initial_state(selecto, :graph)

      assert state.chart_type == "line"
      assert state.options == %{"title" => "Default Chart"}
      # Note: x_axis and y_axis will be processed by build_initial_state
    end

    test "uses defaults when domain configuration is missing" do
      domain = %{}
      selecto = %{domain: fn -> domain end}

      state = Process.initial_state(selecto, :graph)

      assert state.chart_type == "bar"
      assert state.options == %{}
    end
  end

  describe "view/5" do
    setup do
      columns = %{
        "category" => %{colid: :category, type: :string},
        "rating" => %{colid: :rating, type: :string},
        "film_count" => %{colid: :film_id, type: :integer},
        "release_year" => %{colid: :release_year, type: :integer}
      }

      {:ok, columns: columns}
    end

    test "generates view structure for bar chart with x-axis and y-axis", %{columns: columns} do
      params = %{
        "x_axis" => %{
          "1" => %{"field" => "category", "index" => "0", "alias" => "Category"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Count"}
        },
        "chart_type" => "bar"
      }

      {view_set, _} = Process.view(nil, params, columns, [], nil)

      assert view_set.chart_type == "bar"
      assert length(view_set.x_axis_groups) == 1
      assert length(view_set.aggregates) == 1
      assert length(view_set.selected) == 2  # x_axis + y_axis fields

      # Check grouping structure
      [{col, field_selector}] = view_set.x_axis_groups
      assert col.colid == :category
      assert elem(field_selector, 0) == :field
      assert elem(field_selector, 1) == :category
      assert elem(field_selector, 2) == "Category"

      # Check aggregate structure
      [aggregate] = view_set.aggregates
      assert elem(aggregate, 0) == :field
      assert elem(aggregate, 1) == {:count, "film_count"}
      assert elem(aggregate, 2) == "Count"
    end

    test "generates view structure with series grouping", %{columns: columns} do
      params = %{
        "x_axis" => %{
          "1" => %{"field" => "category", "index" => "0", "alias" => "Category"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Count"}
        },
        "series" => %{
          "1" => %{"field" => "rating", "index" => "0", "alias" => "Rating"}
        },
        "chart_type" => "line"
      }

      {view_set, _} = Process.view(nil, params, columns, [], nil)

      assert view_set.chart_type == "line"
      assert length(view_set.x_axis_groups) == 1
      assert length(view_set.series_groups) == 1
      assert length(view_set.aggregates) == 1
      assert length(view_set.groups) == 2  # x_axis + series
      assert length(view_set.selected) == 3  # x_axis + series + y_axis fields

      # Check that groups include both x_axis and series
      group_fields = Enum.map(view_set.groups, fn {col, _} -> col.colid end)
      assert :category in group_fields
      assert :rating in group_fields
    end

    test "handles datetime fields with format options", %{columns: columns} do
      datetime_columns = Map.put(columns, "created_at", %{colid: :created_at, type: :naive_datetime})

      params = %{
        "x_axis" => %{
          "1" => %{"field" => "created_at", "index" => "0", "alias" => "Month", "format" => "YYYY-MM"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Count"}
        }
      }

      {view_set, _} = Process.view(nil, params, datetime_columns, [], nil)

      [{col, field_selector}] = view_set.x_axis_groups
      assert col.colid == :created_at
      assert elem(field_selector, 0) == :field
      assert elem(field_selector, 1) == {:to_char, {:created_at, "YYYY-MM"}}
      assert elem(field_selector, 2) == "Month"
    end

    test "generates proper order_by and group_by clauses", %{columns: columns} do
      params = %{
        "x_axis" => %{
          "1" => %{"field" => "category", "index" => "0", "alias" => "Category"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "sum", "alias" => "Total"}
        },
        "series" => %{
          "1" => %{"field" => "rating", "index" => "0", "alias" => "Rating"}
        }
      }

      {view_set, _} = Process.view(nil, params, columns, [], nil)

      # Should have rollup grouping for OLAP-style queries
      assert view_set.group_by == [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}]
      assert view_set.order_by == [{:literal_position, 1}, {:literal_position, 2}]
    end

    test "handles multiple aggregate functions", %{columns: columns} do
      params = %{
        "x_axis" => %{
          "1" => %{"field" => "category", "index" => "0", "alias" => "Category"}
        },
        "y_axis" => %{
          "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Count"},
          "2" => %{"field" => "film_count", "index" => "1", "function" => "avg", "alias" => "Average"}
        }
      }

      {view_set, _} = Process.view(nil, params, columns, [], nil)

      assert length(view_set.aggregates) == 2

      [first_agg, second_agg] = view_set.aggregates
      assert elem(first_agg, 1) == {:count, "film_count"}
      assert elem(second_agg, 1) == {:avg, "film_count"}
    end
  end

  describe "group_by_fields/2" do
    setup do
      columns = %{
        "category" => %{colid: :category, type: :string},
        "created_at" => %{colid: :created_at, type: :naive_datetime},
        "custom_field" => %{colid: :custom, type: :custom_column, requires_select: [:field1, :field2]}
      }

      {:ok, columns: columns}
    end

    test "processes regular fields", %{columns: columns} do
      field_params = %{
        "1" => %{"field" => "category", "index" => "0", "alias" => "Category Name"}
      }

      result = Process.group_by_fields(field_params, columns)

      assert length(result) == 1
      [{col, field_selector}] = result
      assert col.colid == :category
      assert field_selector == {:field, :category, "Category Name"}
    end

    test "processes datetime fields with formatting", %{columns: columns} do
      field_params = %{
        "1" => %{"field" => "created_at", "index" => "0", "alias" => "Year", "format" => "YYYY"}
      }

      result = Process.group_by_fields(field_params, columns)

      [{col, field_selector}] = result
      assert col.colid == :created_at
      assert field_selector == {:field, {:to_char, {:created_at, "YYYY"}}, "Year"}
    end

    test "processes custom columns with requires_select", %{columns: columns} do
      field_params = %{
        "1" => %{"field" => "custom_field", "index" => "0", "alias" => "Custom"}
      }

      result = Process.group_by_fields(field_params, columns)

      [{col, field_selector}] = result
      assert col.colid == :custom
      assert field_selector == {:row, [:field1, :field2], "Custom"}
    end

    test "sorts fields by index", %{columns: columns} do
      field_params = %{
        "1" => %{"field" => "category", "index" => "1", "alias" => "Second"},
        "2" => %{"field" => "created_at", "index" => "0", "alias" => "First"}
      }

      result = Process.group_by_fields(field_params, columns)

      assert length(result) == 2
      [{first_col, _}, {second_col, _}] = result
      assert first_col.colid == :created_at  # index 0
      assert second_col.colid == :category   # index 1
    end

    test "uses field name as default alias", %{columns: columns} do
      field_params = %{
        "1" => %{"field" => "category", "index" => "0", "alias" => ""},
        "2" => %{"field" => "created_at", "index" => "1"}  # no alias key
      }

      result = Process.group_by_fields(field_params, columns)

      [{_, first_selector}, {_, second_selector}] = result
      assert elem(first_selector, 2) == "category"
      assert elem(second_selector, 2) == "created_at"
    end
  end

  describe "aggregate_fields/2" do
    test "processes aggregate fields with functions" do
      aggregate_params = %{
        "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Total Films"},
        "2" => %{"field" => "revenue", "index" => "1", "function" => "sum", "alias" => "Total Revenue"}
      }

      result = Process.aggregate_fields(aggregate_params, %{})

      assert length(result) == 2

      [first_agg, second_agg] = result
      assert first_agg == {:field, {:count, "film_count"}, "Total Films"}
      assert second_agg == {:field, {:sum, "revenue"}, "Total Revenue"}
    end

    test "defaults to count function when not specified" do
      aggregate_params = %{
        "1" => %{"field" => "film_count", "index" => "0", "alias" => "Count"},
        "2" => %{"field" => "revenue", "index" => "1", "function" => "", "alias" => "Revenue"}
      }

      result = Process.aggregate_fields(aggregate_params, %{})

      [first_agg, second_agg] = result
      assert elem(elem(first_agg, 1), 0) == :count
      assert elem(elem(second_agg, 1), 0) == :count
    end

    test "uses field name as default alias" do
      aggregate_params = %{
        "1" => %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => ""},
        "2" => %{"field" => "revenue", "index" => "1", "function" => "sum"}  # no alias
      }

      result = Process.aggregate_fields(aggregate_params, %{})

      [first_agg, second_agg] = result
      assert elem(first_agg, 2) == "film_count"
      assert elem(second_agg, 2) == "revenue"
    end

    test "sorts aggregates by index" do
      aggregate_params = %{
        "1" => %{"field" => "second", "index" => "1", "function" => "sum", "alias" => "Second"},
        "2" => %{"field" => "first", "index" => "0", "function" => "count", "alias" => "First"}
      }

      result = Process.aggregate_fields(aggregate_params, %{})

      [first_agg, second_agg] = result
      assert elem(first_agg, 2) == "First"   # index 0
      assert elem(second_agg, 2) == "Second" # index 1
    end
  end
end