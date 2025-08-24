defmodule SelectoComponents.Views.Graph.Process do
  @doc """
  Converts form parameters to view state for form rendering
  """
  def param_to_state(params, _view) do
    %{
      x_axis: SelectoComponents.Views.view_param_process(params, "x_axis", "field"),
      y_axis: SelectoComponents.Views.view_param_process(params, "y_axis", "field"),
      series: SelectoComponents.Views.view_param_process(params, "series", "field"),
      chart_type: Map.get(params, "chart_type", "bar"),
      options: Map.get(params, "options", %{})
    }
  end

  @doc """
  Initial state when view is created without params
  """
  def initial_state(selecto, _view) do
    domain = Selecto.domain(selecto)
    
    %{
      x_axis: Map.get(domain, :default_graph_x_axis, []) 
              |> SelectoComponents.Helpers.build_initial_state(),
      y_axis: Map.get(domain, :default_graph_y_axis, []) 
              |> SelectoComponents.Helpers.build_initial_state(),
      series: Map.get(domain, :default_graph_series, []) 
              |> SelectoComponents.Helpers.build_initial_state(),
      chart_type: Map.get(domain, :default_chart_type, "bar"),
      options: Map.get(domain, :default_chart_options, %{})
    }
  end

  @doc """
  Converts parameters into Selecto query structure
  """
  def view(_opt, params, columns, filtered, _selecto) do
    x_axis_params = Map.get(params, "x_axis", %{})
    y_axis_params = Map.get(params, "y_axis", %{})
    series_params = Map.get(params, "series", %{})
    chart_type = Map.get(params, "chart_type", "bar")

    # Process X-axis (grouping fields)
    x_axis_fields = x_axis_params |> group_by_fields(columns)
    
    # Process Y-axis (aggregate fields)  
    y_axis_fields = y_axis_params |> aggregate_fields(columns)
    
    # Process Series (optional secondary grouping)
    series_fields = series_params |> group_by_fields(columns)

    # Combine all grouping fields (x_axis + series)
    all_group_by = x_axis_fields ++ series_fields
    
    # Build selected fields for query
    selected_fields = Enum.map(all_group_by, fn {_col, sel} -> sel end) ++ y_axis_fields

    {%{
      groups: all_group_by,
      x_axis_groups: x_axis_fields,
      series_groups: series_fields,
      aggregates: y_axis_fields,
      selected: selected_fields,
      filtered: filtered,
      chart_type: chart_type,
      group_by: case all_group_by do
        [] -> []
        group_fields -> [
          {:rollup, Enum.map(1..Enum.count(group_fields), fn g -> {:literal_position, g} end)}
        ]
      end,
      order_by: case all_group_by do
        [] -> []
        group_fields -> Enum.map(1..Enum.count(group_fields), fn g -> {:literal_position, g} end)
      end
    }, %{}}
  end

  @doc """
  Process group by fields (for X-axis and Series)
  """
  def group_by_fields(field_params, columns) do
    field_params
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn field_config ->
      col = columns[field_config["field"]]
      
      # Generate alias
      alias_name = case field_config["alias"] do
        "" -> field_config["field"]
        nil -> field_config["field"]
        custom_alias -> custom_alias
      end

      # Build field selector based on column type
      field_selector = case col.type do
        x when x in [:naive_datetime, :utc_datetime] ->
          {:field, datetime_group_by_processor(col, field_config), alias_name}
        
        :custom_column ->
          case Map.get(col, :requires_select) do
            x when is_list(x) -> {:row, col.requires_select, alias_name}
            x when is_function(x) -> {:row, col.requires_select.(field_config), alias_name}
            nil -> {col.colid, alias_name}
          end
        
        _ ->
          {:field, col.colid, alias_name}
      end

      {col, field_selector}
    end)
  end

  @doc """
  Process aggregate fields (for Y-axis)
  """
  def aggregate_fields(aggregate_params, _columns) do
    aggregate_params
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn field_config ->
      # Generate alias
      alias_name = case field_config["alias"] do
        "" -> field_config["field"]
        nil -> field_config["field"]
        custom_alias -> custom_alias
      end

      # Build aggregate function
      aggregate_function = String.to_atom(
        case field_config["function"] do
          nil -> "count"
          "" -> "count"
          func -> func
        end
      )

      {:field, {aggregate_function, field_config["field"]}, alias_name}
    end)
  end

  @doc """
  Process datetime fields for grouping (Year, Month, Day, etc.)
  """
  defp datetime_group_by_processor(col, config) do
    case config["format"] do
      format when format in ~w(YYYY-MM-DD YYYY-MM YYYY) -> 
        {:to_char, {col.colid, format}}
      format when format in ~w(Year Month Day Hour) ->
        {:extract, col.colid, String.downcase(format)}
      _ -> 
        col.colid
    end
  end
end
