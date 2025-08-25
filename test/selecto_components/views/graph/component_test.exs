defmodule SelectoComponents.Views.Graph.ComponentTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Graph.Component

  describe "prepare_chart_data/3" do
    test "prepares bar chart data with single series" do
      assigns = %{
        selecto: %{
          set: %{
            x_axis_groups: [
              {%{colid: :category}, {:field, :category, "Category"}}
            ],
            aggregates: [
              {:field, {:count, "film_id"}, "Film Count"}
            ],
            series_groups: []
          }
        }
      }

      results = [
        ["Action", 30],
        ["Comedy", 45],
        ["Drama", 25]
      ]

      aliases = ["Category", "Film Count"]

      chart_data = Component.prepare_chart_data(assigns, results, aliases)

      assert chart_data.labels == ["Action", "Comedy", "Drama"]
      assert length(chart_data.datasets) == 1

      [dataset] = chart_data.datasets
      assert dataset.label == "Film Count"
      assert dataset.data == [30, 45, 25]
      assert dataset.backgroundColor
      assert dataset.borderColor
    end

    test "prepares line chart data" do
      assigns = %{
        selecto: %{
          set: %{
            x_axis_groups: [
              {%{colid: :year}, {:field, :year, "Year"}}
            ],
            aggregates: [
              {:field, {:count, "film_id"}, "Films"},
              {:field, {:avg, "rating"}, "Avg Rating"}
            ],
            series_groups: []
          }
        }
      }

      results = [
        [2020, 100, 4.2],
        [2021, 120, 4.5],
        [2022, 90, 4.1]
      ]

      aliases = ["Year", "Films", "Avg Rating"]

      chart_data = Component.prepare_chart_data(assigns, results, aliases)

      assert chart_data.labels == ["2020", "2021", "2022"]
      assert length(chart_data.datasets) == 2

      [first_dataset, second_dataset] = chart_data.datasets
      assert first_dataset.label == "Films"
      assert first_dataset.data == [100, 120, 90]
      assert first_dataset.fill == false
      assert first_dataset.tension == 0.4

      assert second_dataset.label == "Avg Rating"
      assert second_dataset.data == [4.2, 4.5, 4.1]
    end

    test "prepares pie chart data" do
      assigns = %{
        selecto: %{
          set: %{
            x_axis_groups: [
              {%{colid: :rating}, {:field, :rating, "Rating"}}
            ],
            aggregates: [
              {:field, {:count, "film_id"}, "Count"}
            ],
            series_groups: []
          }
        }
      }

      results = [
        ["G", 15],
        ["PG", 30],
        ["PG-13", 40],
        ["R", 25]
      ]

      aliases = ["Rating", "Count"]

      chart_data = Component.prepare_chart_data(assigns, results, aliases)

      assert chart_data.labels == ["G", "PG", "PG-13", "R"]
      assert length(chart_data.datasets) == 1

      [dataset] = chart_data.datasets
      assert dataset.data == [15, 30, 40, 25]
      assert length(dataset.backgroundColor) == 4
      assert length(dataset.borderColor) == 4
    end

    test "handles empty results gracefully" do
      assigns = %{
        selecto: %{
          set: %{
            x_axis_groups: [],
            aggregates: [],
            series_groups: []
          }
        }
      }

      results = []
      aliases = []

      chart_data = Component.prepare_chart_data(assigns, results, aliases)

      # Should fall back to simple bar data preparation
      assert chart_data.labels == []
      assert chart_data.datasets == []
    end
  end

  describe "prepare_chart_options/1" do
    test "creates default options for bar chart" do
      assigns = %{
        selecto: %{
          set: %{
            chart_type: "bar"
          }
        }
      }

      options = Component.prepare_chart_options(assigns)

      assert options.responsive == true
      assert options.maintainAspectRatio == false
      assert options.plugins.legend.position == "bottom"
      assert options.plugins.tooltip.mode == "index"
      assert options.scales.x.beginAtZero == false
      assert options.scales.y.beginAtZero == true
    end

    test "creates options for pie chart without scales" do
      assigns = %{
        selecto: %{
          set: %{
            chart_type: "pie"
          }
        }
      }

      options = Component.prepare_chart_options(assigns)

      assert options.responsive == true
      assert options.maintainAspectRatio == false
      assert options.plugins.legend.position == "bottom"
      # Pie charts should not have scales
      refute Map.has_key?(options, :scales)
    end

    test "creates options for doughnut chart without scales" do
      assigns = %{
        selecto: %{
          set: %{
            chart_type: "doughnut"
          }
        }
      }

      options = Component.prepare_chart_options(assigns)

      refute Map.has_key?(options, :scales)
    end
  end

  describe "format_chart_label/1" do
    test "formats various label types" do
      assert Component.format_chart_label(nil) == "N/A"
      assert Component.format_chart_label("Action") == "Action"
      assert Component.format_chart_label(2023) == "2023"
      assert Component.format_chart_label({"Action", 1}) == "Action"
      assert Component.format_chart_label({2023, "id"}) == "2023"
    end
  end

  describe "format_numeric_value/1" do
    test "formats various numeric types" do
      assert Component.format_numeric_value(nil) == 0
      assert Component.format_numeric_value(42) == 42
      assert Component.format_numeric_value(3.14) == 3.14
      assert Component.format_numeric_value("123") == 123
      assert Component.format_numeric_value("45.67") == 45.67
      assert Component.format_numeric_value({100, "id"}) == 100
      assert Component.format_numeric_value({"89.5", "id"}) == 89.5
      assert Component.format_numeric_value("invalid") == 0
    end
  end

  describe "get_aggregate_label/1" do
    test "extracts labels from aggregate field structures" do
      assert Component.get_aggregate_label({:field, {:count, "film_id"}, "Film Count"}) == "Film Count"
      assert Component.get_aggregate_label({:field, {:sum, "revenue"}, "Total Revenue"}) == "Total Revenue"
      assert Component.get_aggregate_label({:field, "category", "Category"}) == "Category"
      assert Component.get_aggregate_label({:field, {:avg, "rating"}, nil}) == "avg(rating)"
      assert Component.get_aggregate_label({:unknown, "field"}) == "Value"
    end
  end

  describe "generate_color/2" do
    test "generates consistent colors for indices" do
      color1 = Component.generate_color(0, 0.7)
      color2 = Component.generate_color(1, 0.7)
      color3 = Component.generate_color(0, 0.7)  # Should be same as color1

      assert color1 == color3  # Same index should produce same color
      refute color1 == color2  # Different indices should produce different colors

      assert color1 =~ ~r/rgba\(\d+, \d+, \d+, 0\.7\)/
      assert color2 =~ ~r/rgba\(\d+, \d+, \d+, 0\.7\)/
    end

    test "cycles through color palette" do
      # Test that colors cycle after 10 (the palette size)
      color_0 = Component.generate_color(0, 1.0)
      color_10 = Component.generate_color(10, 1.0)

      assert color_0 == color_10  # Should be the same color
    end

    test "respects alpha parameter" do
      color_half = Component.generate_color(0, 0.5)
      color_full = Component.generate_color(0, 1.0)

      assert color_half =~ ~r/rgba\(\d+, \d+, \d+, 0\.5\)/
      assert color_full =~ ~r/rgba\(\d+, \d+, \d+, 1\.0\)/
    end
  end

  describe "chart_summary/2" do
    test "generates summary for bar chart" do
      chart_data = %{
        labels: ["A", "B", "C"],
        datasets: [%{}, %{}]
      }

      summary = Component.chart_summary(chart_data, "bar")
      assert summary == "3 categories, 2 series"
    end

    test "generates summary for single series" do
      chart_data = %{
        labels: ["A", "B"],
        datasets: [%{}]
      }

      summary = Component.chart_summary(chart_data, "line")
      assert summary == "2 categories, 1 series"
    end

    test "generates summary for pie chart" do
      chart_data = %{
        labels: ["A", "B", "C", "D"],
        datasets: [%{}]
      }

      summary = Component.chart_summary(chart_data, "pie")
      assert summary == "4 categories"
    end

    test "generates summary for scatter plot" do
      chart_data = %{
        labels: ["Point1", "Point2", "Point3"],
        datasets: [%{}]
      }

      summary = Component.chart_summary(chart_data, "scatter")
      assert summary == "3 data points"
    end

    test "handles empty data" do
      chart_data = %{labels: [], datasets: []}

      summary = Component.chart_summary(chart_data, "bar")
      assert summary == "0 categories, 0 series"
    end

    test "handles missing labels or datasets" do
      chart_data = %{}

      summary = Component.chart_summary(chart_data, "bar")
      assert summary == "0 categories, 0 series"
    end
  end

  describe "get_chart_type/1" do
    test "extracts chart type from assigns" do
      assigns = %{
        selecto: %{
          set: %{
            chart_type: "line"
          }
        }
      }

      assert Component.get_chart_type(assigns) == "line"
    end

    test "defaults to bar when chart_type not specified" do
      assigns = %{
        selecto: %{
          set: %{}
        }
      }

      assert Component.get_chart_type(assigns) == "bar"
    end
  end

  describe "render/1" do
    test "renders loading state when not executed" do
      assigns = %{executed: false, query_results: nil}

      html = Component.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      assert html_string =~ "Loading chart..."
      assert html_string =~ "animate-spin"
    end

    test "renders no results state when executed but no results" do
      assigns = %{executed: true, query_results: nil}

      html = Component.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      assert html_string =~ "No Data Available"
      assert html_string =~ "📊"
    end

    test "renders chart when executed with results" do
      assigns = %{
        executed: true,
        query_results: {[["Action", 30]], [], ["Category", "Count"]},
        selecto: %{
          set: %{
            x_axis_groups: [{%{colid: :category}, {:field, :category, "Category"}}],
            aggregates: [{:field, {:count, "film_id"}, "Count"}],
            series_groups: [],
            chart_type: "bar"
          }
        },
        id: "test-chart"
      }

      html = Component.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      assert html_string =~ "phx-hook=\".GraphViewHook\""
      assert html_string =~ "data-chart-type=\"bar\""
      assert html_string =~ "canvas"
      assert html_string =~ "Export"
      assert html_string =~ "Click data points to drill down"
    end

    test "renders unknown state for unexpected conditions" do
      assigns = %{executed: :unknown, query_results: :invalid}

      html = Component.render(assigns)
      html_string = Phoenix.HTML.safe_to_string(html)

      assert html_string =~ "Unknown Chart State"
      assert html_string =~ "Executed: :unknown"
    end
  end
end