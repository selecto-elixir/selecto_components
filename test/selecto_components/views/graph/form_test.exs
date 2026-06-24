defmodule SelectoComponents.Views.Graph.FormTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Components.ListPicker
  alias SelectoComponents.Views.Graph.Form

  defp dynamic_chunks(%Phoenix.LiveView.Rendered{dynamic: dynamic}) when is_function(dynamic, 1),
    do: dynamic.(false)

  defp dynamic_chunks(_rendered), do: []

  defp static_text(%Phoenix.LiveView.Rendered{} = rendered) do
    Enum.join(rendered.static) <> dynamic_text(rendered)
  end

  defp static_text(chunk) when is_binary(chunk), do: chunk
  defp static_text(chunk) when is_list(chunk), do: Enum.map_join(chunk, &static_text/1)
  defp static_text(_chunk), do: ""

  defp dynamic_text(rendered) do
    rendered
    |> dynamic_chunks()
    |> Enum.map(fn
      %Phoenix.LiveView.Component{} -> ""
      %Phoenix.LiveView.Rendered{} = chunk -> rendered_text(chunk)
      chunk when is_binary(chunk) -> chunk
      chunk when is_list(chunk) -> Enum.map_join(chunk, &rendered_text/1)
      _ -> ""
    end)
    |> Enum.join()
  end

  defp rendered_text(%Phoenix.LiveView.Rendered{} = rendered), do: static_text(rendered)
  defp rendered_text(chunk) when is_binary(chunk), do: chunk
  defp rendered_text(chunk) when is_list(chunk), do: Enum.map_join(chunk, &rendered_text/1)
  defp rendered_text(_chunk), do: ""

  defp marker_count(rendered, marker) do
    rendered
    |> rendered_text()
    |> :binary.matches(marker)
    |> length()
  end

  defp list_picker(rendered, id) do
    rendered
    |> component_chunks()
    |> Enum.find(fn
      %Phoenix.LiveView.Component{component: ListPicker, assigns: assigns} ->
        Map.get(assigns, :fieldname) == id

      _ ->
        false
    end)
  end

  defp component_chunks(%Phoenix.LiveView.Rendered{} = rendered) do
    rendered
    |> dynamic_chunks()
    |> Enum.flat_map(&component_chunks/1)
  end

  defp component_chunks(%Phoenix.LiveView.Component{} = component), do: [component]

  defp component_chunks(chunks) when is_list(chunks),
    do: Enum.flat_map(chunks, &component_chunks/1)

  defp component_chunks(_chunk), do: []

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
      assert text =~ "X-Axis"
      assert text =~ "Y-Axis"
      assert text =~ "Series"
      assert text =~ "Display Options"
      assert text =~ "Chart Title"
      assert text =~ "Legend Position"
      assert static_text(rendered) =~ "color: var(--sc-text-primary);"
      assert static_text(rendered) =~ "color: var(--sc-text-secondary);"

      assert marker_count(rendered, "checked") == 3

      x_axis_picker = list_picker(rendered, "x_axis")
      y_axis_picker = list_picker(rendered, "y_axis")
      series_picker = list_picker(rendered, "series")

      assert x_axis_picker.assigns.fieldname == "x_axis"
      assert y_axis_picker.assigns.fieldname == "y_axis"
      assert series_picker.assigns.fieldname == "series"
      assert x_axis_picker.assigns.selected_items != []
      assert y_axis_picker.assigns.selected_items != []
      assert x_axis_picker.assigns.between_item != []
      assert series_picker.assigns.between_item != []
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
      assert text =~ "X-Axis"
      assert text =~ "Y-Axis"
      assert text =~ "Series"
      assert text =~ "Display Options"

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
              color_by: [
                {"uuid4", "category", %{"field" => "category", "index" => "0"}}
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
      color_by_picker = list_picker(rendered, "color_by")

      assert x_axis_picker.component == ListPicker
      assert y_axis_picker.component == ListPicker
      assert series_picker.component == ListPicker
      assert color_by_picker.component == ListPicker

      assert x_axis_picker.assigns.fieldname == "x_axis"
      assert y_axis_picker.assigns.fieldname == "y_axis"
      assert series_picker.assigns.fieldname == "series"
      assert color_by_picker.assigns.fieldname == "color_by"

      assert x_axis_picker.assigns.selected_items ==
               [{"uuid1", "category", %{"field" => "category", "index" => "0"}}]

      assert y_axis_picker.assigns.selected_items ==
               [{"uuid2", "film_count", %{"field" => "film_count", "index" => "0"}}]

      assert series_picker.assigns.selected_items ==
               [{"uuid3", "rating", %{"field" => "rating", "index" => "0"}}]

      assert color_by_picker.assigns.selected_items ==
               [{"uuid4", "category", %{"field" => "category", "index" => "0"}}]
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
              color_by: [],
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
      color_by_picker = list_picker(rendered, "color_by")

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

      refute Enum.any?(color_by_picker.assigns.available, fn {_field, _label, format} ->
               format in [:component, :link]
             end)
    end
  end
end
