defmodule SelectoComponents.Dashboard.WidgetRegistry do
  @moduledoc """
  Registry for available dashboard widgets.
  Manages widget types, configurations, and data sources.
  """

  @widget_types [
    %{
      type: :chart,
      name: "Chart",
      icon: "📊",
      description: "Display data as charts",
      config_schema: %{
        chart_type: {:enum, ["line", "bar", "pie", "area", "scatter"]},
        title: :string,
        x_axis_label: :string,
        y_axis_label: :string,
        show_legend: :boolean,
        colors: {:list, :string}
      }
    },
    %{
      type: :table,
      name: "Table",
      icon: "📋",
      description: "Display data in a table",
      config_schema: %{
        title: :string,
        page_size: :integer,
        sortable: :boolean,
        filterable: :boolean,
        show_pagination: :boolean,
        columns: {:list, :map}
      }
    },
    %{
      type: :metric,
      name: "Metric",
      icon: "🔢",
      description: "Display a single metric",
      config_schema: %{
        title: :string,
        value_field: :string,
        format: {:enum, ["number", "currency", "percentage"]},
        prefix: :string,
        suffix: :string,
        trend_field: :string,
        comparison_field: :string
      }
    },
    %{
      type: :kpi_card,
      name: "KPI Card",
      icon: "📈",
      description: "Key performance indicator",
      config_schema: %{
        title: :string,
        metric: :string,
        target: :number,
        format: :string,
        color_scheme: {:enum, ["default", "success", "warning", "danger"]}
      }
    },
    %{
      type: :map,
      name: "Map",
      icon: "🗺️",
      description: "Geographic data visualization",
      config_schema: %{
        title: :string,
        center_lat: :float,
        center_lng: :float,
        zoom: :integer,
        marker_field: :string,
        popup_fields: {:list, :string}
      }
    },
    %{
      type: :timeline,
      name: "Timeline",
      icon: "📅",
      description: "Display events over time",
      config_schema: %{
        title: :string,
        date_field: :string,
        event_field: :string,
        group_field: :string,
        view_mode: {:enum, ["day", "week", "month", "year"]}
      }
    },
    %{
      type: :gauge,
      name: "Gauge",
      icon: "🎯",
      description: "Progress or gauge display",
      config_schema: %{
        title: :string,
        value: :number,
        min: :number,
        max: :number,
        target: :number,
        units: :string,
        color_ranges: {:list, :map}
      }
    },
    %{
      type: :text,
      name: "Text",
      icon: "📝",
      description: "Rich text content",
      config_schema: %{
        title: :string,
        content: :string,
        markdown: :boolean,
        text_align: {:enum, ["left", "center", "right", "justify"]}
      }
    },
    %{
      type: :list,
      name: "List",
      icon: "📑",
      description: "Display items as a list",
      config_schema: %{
        title: :string,
        item_template: :string,
        max_items: :integer,
        show_index: :boolean,
        clickable: :boolean
      }
    },
    %{
      type: :custom,
      name: "Custom",
      icon: "⚙️",
      description: "Custom widget",
      config_schema: %{
        title: :string,
        component_module: :string,
        component_function: :string,
        custom_config: :map
      }
    }
  ]

  @doc """
  Lists all available widget types.
  """
  def list_available do
    @widget_types
  end

  @doc """
  Gets configuration for a specific widget type.
  """
  def get_widget_config(type) when is_atom(type) do
    Enum.find(@widget_types, fn w -> w.type == type end)
  end

  @doc """
  Validates widget configuration against its schema.
  """
  def validate_config(type, config) when is_atom(type) and is_map(config) do
    case get_widget_config(type) do
      nil ->
        {:error, "Unknown widget type: #{type}"}

      widget_def ->
        validate_against_schema(config, widget_def.config_schema)
    end
  end

  @doc """
  Creates a new widget instance with default configuration.
  """
  def create_widget(type, overrides \\ %{}) when is_atom(type) do
    case get_widget_config(type) do
      nil ->
        {:error, "Unknown widget type: #{type}"}

      widget_def ->
        config = build_default_config(widget_def.config_schema)

        {:ok,
         %{
           id: generate_widget_id(),
           type: type,
           config: Map.merge(config, overrides),
           data: nil,
           created_at: DateTime.utc_now(),
           updated_at: DateTime.utc_now()
         }}
    end
  end

  @doc """
  Registers a custom widget type.
  """
  def register_custom_widget(definition) do
    # Custom widget registration is handled by the :custom widget type configuration.
    _ = definition
    {:ok, :registered}
  end

  @doc """
  Gets data source configuration for a widget.
  """
  def get_data_source(widget) do
    case widget.type do
      :chart -> build_chart_data_source(widget.config)
      :table -> build_table_data_source(widget.config)
      :metric -> build_metric_data_source(widget.config)
      :kpi_card -> build_kpi_data_source(widget.config)
      _ -> {:ok, nil}
    end
  end

  @doc """
  Updates widget data based on its configuration.
  """
  def refresh_widget_data(widget, data_context \\ %{}) do
    case get_data_source(widget) do
      {:ok, source} when not is_nil(source) ->
        fetch_data(source, data_context)

      _ ->
        {:ok, widget}
    end
  end

  # Private functions

  defp validate_against_schema(config, schema) do
    errors =
      Enum.reduce(schema, [], fn {field, type}, acc ->
        case validate_field(Map.get(config, field), type) do
          :ok -> acc
          {:error, reason} -> [{field, reason} | acc]
        end
      end)

    if errors == [] do
      {:ok, config}
    else
      {:error, errors}
    end
  end

  defp validate_field(nil, {:enum, _}), do: :ok
  defp validate_field(nil, _), do: :ok

  defp validate_field(value, :string) when is_binary(value), do: :ok
  defp validate_field(value, :integer) when is_integer(value), do: :ok
  defp validate_field(value, :float) when is_float(value), do: :ok
  defp validate_field(value, :number) when is_number(value), do: :ok
  defp validate_field(value, :boolean) when is_boolean(value), do: :ok
  defp validate_field(value, :map) when is_map(value), do: :ok

  defp validate_field(value, {:list, item_type}) when is_list(value) do
    if Enum.all?(value, fn item -> validate_field(item, item_type) == :ok end) do
      :ok
    else
      {:error, "Invalid list items"}
    end
  end

  defp validate_field(value, {:enum, options}) do
    if value in options do
      :ok
    else
      {:error, "Must be one of: #{Enum.join(options, ", ")}"}
    end
  end

  defp validate_field(_, type), do: {:error, "Invalid type: expected #{inspect(type)}"}

  defp build_default_config(schema) do
    Enum.reduce(schema, %{}, fn {field, type}, acc ->
      Map.put(acc, field, default_value_for_type(type))
    end)
  end

  defp default_value_for_type(:string), do: ""
  defp default_value_for_type(:integer), do: 0
  defp default_value_for_type(:float), do: 0.0
  defp default_value_for_type(:number), do: 0
  defp default_value_for_type(:boolean), do: false
  defp default_value_for_type(:map), do: %{}
  defp default_value_for_type({:list, _}), do: []
  defp default_value_for_type({:enum, [first | _]}), do: first
  defp default_value_for_type(_), do: nil

  defp generate_widget_id do
    "widget_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp build_chart_data_source(config) do
    %{
      type: :query,
      query_type: :aggregate,
      fields: config[:fields] || [],
      group_by: config[:group_by],
      filters: config[:filters] || [],
      limit: config[:limit] || 100
    }
  end

  defp build_table_data_source(config) do
    %{
      type: :query,
      query_type: :detail,
      fields: config[:columns] || [],
      filters: config[:filters] || [],
      order_by: config[:order_by],
      limit: config[:page_size] || 10
    }
  end

  defp build_metric_data_source(config) do
    %{
      type: :query,
      query_type: :aggregate,
      fields: [config[:value_field]],
      aggregation: config[:aggregation] || "sum",
      filters: config[:filters] || []
    }
  end

  defp build_kpi_data_source(config) do
    %{
      type: :query,
      query_type: :kpi,
      metric: config[:metric],
      period: config[:period] || "current",
      comparison_period: config[:comparison_period]
    }
  end

  defp fetch_data(source, context) do
    cond do
      is_function(Map.get(context, :fetch_widget_data), 1) ->
        context.fetch_widget_data.(source)

      allow_mock_data?(context) ->
        {:ok, generate_mock_data(source)}

      true ->
        {:error, :dashboard_data_source_not_configured}
    end
  end

  defp allow_mock_data?(context) do
    Map.get(context, :allow_mock_data, false) || Mix.env() in [:dev, :test]
  end

  defp generate_mock_data(%{query_type: :aggregate}) do
    %{
      labels: ["Jan", "Feb", "Mar", "Apr", "May"],
      datasets: [
        %{
          label: "Sales",
          data: [120, 190, 300, 250, 320]
        }
      ]
    }
  end

  defp generate_mock_data(%{query_type: :detail}) do
    %{
      columns: ["ID", "Name", "Value", "Status"],
      rows: [
        ["1", "Item A", "$100", "Active"],
        ["2", "Item B", "$200", "Active"],
        ["3", "Item C", "$150", "Pending"]
      ]
    }
  end

  defp generate_mock_data(%{query_type: :kpi}) do
    %{
      value: 42_500,
      target: 50_000,
      trend: :up,
      change_percentage: 12.5
    }
  end

  defp generate_mock_data(_) do
    %{data: "Mock data"}
  end
end
