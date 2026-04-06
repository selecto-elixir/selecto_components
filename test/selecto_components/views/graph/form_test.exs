defmodule SelectoComponents.Views.Graph.FormTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Components.ListPicker
  alias SelectoComponents.Views.Graph.Form

  defp static_text(rendered), do: Enum.join(rendered.static)
  defp dynamic_chunks(rendered), do: rendered.dynamic.(false)

  defp dynamic_text(rendered) do
    rendered
    |> dynamic_chunks()
    |> Enum.map(fn
      %Phoenix.LiveView.Component{} -> ""
      chunk when is_binary(chunk) -> chunk
      chunk when is_list(chunk) -> IO.iodata_to_binary(chunk)
      _ -> ""
    end)
    |> Enum.join()
  end

  defp rendered_text(rendered), do: static_text(rendered) <> dynamic_text(rendered)

  defp marker_count(rendered, marker) do
    rendered
    |> dynamic_chunks()
    |> Enum.count(fn
      %Phoenix.LiveView.Component{} ->
        false

      chunk when is_binary(chunk) ->
        String.contains?(chunk, marker)

      chunk when is_list(chunk) ->
        chunk
        |> IO.iodata_to_binary()
        |> String.contains?(marker)

      _ ->
        false
    end)
  end

  defp list_picker(rendered, id) do
    Enum.find(dynamic_chunks(rendered), fn
      %Phoenix.LiveView.Component{component: ListPicker, assigns: assigns} ->
        Map.get(assigns, :fieldname) == id

      _ ->
        false
    end)
  end

  describe "render/1" do
    test "renders complete graph configuration form" do
      assigns = %{
        view_config: %{
          views: %{
            graph: %{
              chart_type: "bar",
              x_axis: [
                {"uuid1", "category",
                 %{"field" => "category", "index" => "0", "alias" => "Category"}}
              ],
              y_axis: [
                {"uuid2", "film_count",
                 %{
                   "field" => "film_count",
                   "index" => "0",
                   "function" => "count",
                   "alias" => "Count"
                 }}
              ],
              series: [],
              options: %{
                "title" => "Films by Category",
                "x_axis_label" => "Category",
                "y_axis_label" => "Number of Films",
                "legend_position" => "bottom",
                "show_grid" => "true",
                "enable_animations" => "true",
                "responsive" => "true"
              }
            }
          }
        },
        view: :graph,
        columns: [
          {"category", "Category", :string},
          {"film_count", "Film Count", :integer},
          {"rating", "Rating", :string}
        ],
        selecto: %{
          field: fn field ->
            case field do
              "category" -> %{colid: :category, type: :string}
              "film_count" -> %{colid: :film_count, type: :integer}
              "rating" -> %{colid: :rating, type: :string}
            end
          end
        }
      }

      rendered = Form.render(assigns)
      text = rendered_text(rendered)

      assert text =~ "Chart Type"
      assert text =~ "X-Axis (Categories)"
      assert text =~ "Y-Axis (Values)"
      assert text =~ "Series Grouping (Optional)"
      assert text =~ "Chart Options"
      assert text =~ "Chart Title"
      assert text =~ "Legend Position"
      assert static_text(rendered) =~ "color: var(--sc-text-primary);"
      assert static_text(rendered) =~ "color: var(--sc-text-secondary);"

      assert marker_count(rendered, "checked") == 3

      x_axis_picker = list_picker(rendered, "x_axis")
      y_axis_picker = list_picker(rendered, "y_axis")

      assert x_axis_picker.assigns.fieldname == "x_axis"
      assert y_axis_picker.assigns.fieldname == "y_axis"
      assert x_axis_picker.assigns.selected_items != []
      assert y_axis_picker.assigns.selected_items != []
    end

    test "renders with minimal configuration" do
      assigns = %{
        view_config: %{
          views: %{
            graph: %{
              chart_type: "line",
              x_axis: [],
              y_axis: [],
              series: [],
              options: %{}
            }
          }
        },
        view: :graph,
        columns: [],
        selecto: %{
          field: fn _field -> %{colid: :unknown, type: :string} end
        }
      }

      rendered = Form.render(assigns)
      text = rendered_text(rendered)

      assert text =~ "Chart Type"
      assert text =~ "X-Axis (Categories)"
      assert text =~ "Y-Axis (Values)"
      assert text =~ "Series Grouping (Optional)"
      assert text =~ "Chart Options"

      for id <- ["x_axis", "y_axis", "series"] do
        assert list_picker(rendered, id).assigns.selected_items == []
      end
    end

    test "renders chart type options correctly" do
      assigns = %{
        view_config: %{
          views: %{
            graph: %{
              chart_type: "pie",
              x_axis: [],
              y_axis: [],
              series: [],
              options: %{}
            }
          }
        },
        view: :graph,
        columns: [],
        selecto: %{field: fn _field -> %{colid: :unknown, type: :string} end}
      }

      rendered = Form.render(assigns)
      text = rendered_text(rendered)

      assert text =~ "Chart Type"
    end

    test "renders legend position options correctly" do
      assigns = %{
        view_config: %{
          views: %{
            graph: %{
              chart_type: "bar",
              x_axis: [],
              y_axis: [],
              series: [],
              options: %{"legend_position" => "top"}
            }
          }
        },
        view: :graph,
        columns: [],
        selecto: %{field: fn _field -> %{colid: :unknown, type: :string} end}
      }

      rendered = Form.render(assigns)
      text = rendered_text(rendered)

      assert text =~ "Legend Position"
      assert static_text(rendered) =~ "accent-color: var(--sc-accent);"
    end

    test "renders checkbox states correctly" do
      assigns = %{
        view_config: %{
          views: %{
            graph: %{
              chart_type: "bar",
              x_axis: [],
              y_axis: [],
              series: [],
              options: %{
                "show_grid" => "true",
                "enable_animations" => "false",
                "responsive" => "true"
              }
            }
          }
        },
        view: :graph,
        columns: [],
        selecto: %{field: fn _field -> %{colid: :unknown, type: :string} end}
      }

      rendered = Form.render(assigns)
      assert marker_count(rendered, "checked") == 2
    end

    test "includes proper LiveComponent references" do
      assigns = %{
        view_config: %{
          views: %{
            graph: %{
              chart_type: "bar",
              x_axis: [
                {"uuid1", "category", %{"field" => "category", "index" => "0"}}
              ],
              y_axis: [
                {"uuid2", "film_count", %{"field" => "film_count", "index" => "0"}}
              ],
              series: [
                {"uuid3", "rating", %{"field" => "rating", "index" => "0"}}
              ],
              options: %{}
            }
          }
        },
        view: :graph,
        columns: [{"category", "Category", :string}],
        selecto: %{
          field: fn field -> %{colid: String.to_atom(field), type: :string} end
        }
      }

      rendered = Form.render(assigns)
      x_axis_picker = list_picker(rendered, "x_axis")
      y_axis_picker = list_picker(rendered, "y_axis")
      series_picker = list_picker(rendered, "series")

      assert x_axis_picker.component == ListPicker
      assert y_axis_picker.component == ListPicker
      assert series_picker.component == ListPicker

      assert x_axis_picker.assigns.fieldname == "x_axis"
      assert y_axis_picker.assigns.fieldname == "y_axis"
      assert series_picker.assigns.fieldname == "series"

      assert x_axis_picker.assigns.selected_items ==
               [{"uuid1", "category", %{"field" => "category", "index" => "0"}}]

      assert y_axis_picker.assigns.selected_items ==
               [{"uuid2", "film_count", %{"field" => "film_count", "index" => "0"}}]

      assert series_picker.assigns.selected_items ==
               [{"uuid3", "rating", %{"field" => "rating", "index" => "0"}}]
    end

    test "filters available columns for x-axis and series" do
      assigns = %{
        view_config: %{
          views: %{
            graph: %{
              chart_type: "bar",
              x_axis: [],
              y_axis: [],
              series: [],
              options: %{}
            }
          }
        },
        view: :graph,
        columns: [
          {"category", "Category", :string},
          {"link_field", "Link", :link},
          {"component_field", "Component", :component},
          {"normal_field", "Normal", :integer}
        ],
        selecto: %{field: fn _field -> %{colid: :unknown, type: :string} end}
      }

      rendered = Form.render(assigns)
      x_axis_picker = list_picker(rendered, "x_axis")
      series_picker = list_picker(rendered, "series")

      assert Enum.any?(x_axis_picker.assigns.available, &match?({"category", _, :string}, &1))

      assert Enum.any?(
               x_axis_picker.assigns.available,
               &match?({"normal_field", _, :integer}, &1)
             )

      refute Enum.any?(x_axis_picker.assigns.available, fn {_field, _label, format} ->
               format in [:component, :link]
             end)

      refute Enum.any?(series_picker.assigns.available, fn {_field, _label, format} ->
               format in [:component, :link]
             end)
    end
  end
end
