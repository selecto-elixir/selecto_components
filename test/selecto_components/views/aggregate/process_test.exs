defmodule SelectoComponents.Views.Aggregate.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Aggregate.Process

  test "param_to_state reads aggregate grid toggle" do
    state = Process.param_to_state(%{"aggregate_grid" => "true"}, %{})
    assert state.grid == true

    state = Process.param_to_state(%{"aggregate_grid" => "false"}, %{})
    assert state.grid == false
  end

  test "param_to_state reads aggregate grid color settings" do
    state =
      Process.param_to_state(
        %{
          "aggregate_grid_colorize" => "true",
          "aggregate_grid_color_scale" => "log"
        },
        %{}
      )

    assert state.grid_colorize == true
    assert state.grid_color_scale == "log"
  end

  test "aggregates honors count distinct from format" do
    columns = %{"id" => %{name: "Category ID", type: :id, colid: "id"}}

    assert Process.aggregates(
             %{"a1" => %{"field" => "id", "format" => "count_distinct"}},
             columns
           ) ==
             [{:field, {:count_distinct, "id"}, "Category ID Distinct Count"}]
  end

  test "aggregates build filtered boolean counts" do
    columns = %{"active" => %{name: "Active", type: :boolean, colid: "active"}}

    assert Process.aggregates(
             %{
               "a1" => %{"field" => "active", "format" => "true_count"},
               "a2" => %{"field" => "active", "format" => "false_count", "index" => "1"}
             },
             columns
           ) == [
             {:field, {:count, "active", {"active", true}}, "Active True Count"},
             {:field, {:count, "active", {"active", false}}, "Active False Count"}
           ]
  end

  test "aggregates can treat null as zero for sum" do
    columns = %{"total" => %{name: "Total", type: :decimal, colid: "total"}}

    assert Process.aggregates(
             %{
               "a1" => %{
                 "field" => "total",
                 "format" => "sum",
                 "ignore_nulls_in_sum" => "true"
               }
             },
             columns
           ) == [
             {:field, {:sum, {:coalesce, ["total", 0]}}, "Total Sum"}
           ]
  end

  test "group by uses column display names by default" do
    columns = %{
      "category.category_name" => %{
        name: "Category: Category name",
        type: :string,
        colid: "category.category_name"
      }
    }

    assert Process.group_by(
             %{"g1" => %{"field" => "category.category_name", "format" => "default"}},
             columns,
             nil
           ) ==
             [
               {%{
                  "group_format" => "default",
                  name: "Category: Category name",
                  type: :string,
                  colid: "category.category_name",
                  group_format: "default"
                }, {:field, "category.category_name", "Category Name"}}
             ]
  end

  test "aggregates use friendly default labels" do
    columns = %{
      "order_details.order_id" => %{
        name: "Order Details: Order id",
        type: :id,
        colid: "order_details.order_id"
      }
    }

    assert Process.aggregates(
             %{"a1" => %{"field" => "order_details.order_id", "format" => "count_distinct"}},
             columns
           ) ==
             [{:field, {:count_distinct, "order_details.order_id"}, "Order ID Distinct Count"}]
  end
end
