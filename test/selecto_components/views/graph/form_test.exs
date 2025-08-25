defmodule SelectoComponents.Views.Graph.FormTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Graph.Form

  describe "render/1" do
    test "renders complete graph configuration form" do
      assigns = %{
        view_config: %{
          views: %{
            graph: %{
              chart_type: "bar",
              x_axis: [
                {"uuid1", "category", %{"field" => "category", "index" => "0", "alias" => "Category"}}
              ],
              y_axis: [
                {"uuid2", "film_count", %{"field" => "film_count", "index" => "0", "function" => "count", "alias" => "Count"}}
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

      html = Form.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      # Check chart type selection
      assert html_string =~ "Chart Type"
      assert html_string =~ "value=\"bar\" selected"
      assert html_string =~ "Bar Chart"
      assert html_string =~ "Line Chart"
      assert html_string =~ "Pie Chart"

      # Check X-axis configuration section
      assert html_string =~ "X-Axis (Categories)"
      assert html_string =~ "SelectoComponents.Components.ListPicker"
      assert html_string =~ "fieldname=\"x_axis\""

      # Check Y-axis configuration section
      assert html_string =~ "Y-Axis (Values)"
      assert html_string =~ "fieldname=\"y_axis\""

      # Check Series configuration section
      assert html_string =~ "Series Grouping (Optional)"
      assert html_string =~ "Add a secondary grouping"
      assert html_string =~ "fieldname=\"series\""

      # Check chart options section
      assert html_string =~ "Chart Options"
      assert html_string =~ "Chart Title"
      assert html_string =~ "value=\"Films by Category\""
      assert html_string =~ "X-Axis Label"
      assert html_string =~ "value=\"Category\""
      assert html_string =~ "Y-Axis Label" 
      assert html_string =~ "value=\"Number of Films\""

      # Check legend position dropdown
      assert html_string =~ "Legend Position"
      assert html_string =~ "value=\"bottom\" selected"

      # Check checkbox options
      assert html_string =~ "Show Grid Lines"
      assert html_string =~ "checked"
      assert html_string =~ "Enable Animations"
      assert html_string =~ "Responsive"
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

      html = Form.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      # Should render structure even with empty configuration
      assert html_string =~ "Chart Type"
      assert html_string =~ "value=\"line\" selected"
      assert html_string =~ "X-Axis (Categories)"
      assert html_string =~ "Y-Axis (Values)"
      assert html_string =~ "Series Grouping (Optional)"
      assert html_string =~ "Chart Options"

      # Empty options should not have values
      refute html_string =~ "value=\""
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

      html = Form.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      assert html_string =~ "value=\"bar\""
      assert html_string =~ "value=\"line\""
      assert html_string =~ "value=\"pie\" selected"
      assert html_string =~ "value=\"scatter\""
      assert html_string =~ "value=\"area\""
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

      html = Form.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      assert html_string =~ "value=\"top\" selected"
      assert html_string =~ "value=\"bottom\""
      assert html_string =~ "value=\"left\""
      assert html_string =~ "value=\"right\""
      assert html_string =~ "value=\"none\""
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

      html = Form.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      # show_grid should be checked
      grid_checkbox = Regex.run(~r/name="options\[show_grid\]".*?(?:checked|>)/s, html_string)
      assert grid_checkbox
      assert Enum.any?(grid_checkbox, &String.contains?(&1, "checked"))

      # enable_animations should not be checked (value is "false")
      animations_checkbox = Regex.run(~r/name="options\[enable_animations\]".*?(?:checked|>)/s, html_string)
      assert animations_checkbox
      refute Enum.any?(animations_checkbox, &String.contains?(&1, "checked"))

      # responsive should be checked (default behavior when not "false")
      responsive_checkbox = Regex.run(~r/name="options\[responsive\]".*?(?:checked|>)/s, html_string)
      assert responsive_checkbox
      assert Enum.any?(responsive_checkbox, &String.contains?(&1, "checked"))
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

      html = Form.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      # Check that axis configuration components are referenced
      assert html_string =~ "SelectoComponents.Views.Graph.XAxisConfig"
      assert html_string =~ "SelectoComponents.Views.Graph.YAxisConfig"
      assert html_string =~ "SelectoComponents.Views.Graph.SeriesConfig"

      # Check that proper prefixes are used for form fields
      assert html_string =~ "x_axis[uuid1]"
      assert html_string =~ "y_axis[uuid2]" 
      assert html_string =~ "series[uuid3]"
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

      html = Form.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      # X-axis and Series sections should exclude :component and :link fields
      # This is tested by checking the ListPicker available parameter filtering
      x_axis_section = Regex.run(~r/X-Axis \(Categories\).*?Series Grouping/s, html_string)
      assert x_axis_section

      series_section = Regex.run(~r/Series Grouping \(Optional\).*?Chart Options/s, html_string)  
      assert series_section

      # The filtering happens in the available parameter, which is a code expression
      # We can verify the filter logic is present
      assert html_string =~ "format not in [:component, :link]"
    end
  end
end