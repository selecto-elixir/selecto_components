defmodule SelectoComponents.Views.Detail.Process do
  alias SelectoComponents.Views.Detail.Options

  def param_to_state(params, _v) do
    ## state is used to draw the form
    %{
      selected: SelectoComponents.Views.view_param_process(params, "selected", "field"),
      order_by: SelectoComponents.Views.view_param_process(params, "order_by", "field"),
      per_page: normalize_per_page_param(Map.get(params, "per_page")),
      max_rows: Options.normalize_max_rows_param(Map.get(params, "max_rows")),
      prevent_denormalization:
        params["prevent_denormalization"] in ["on", "true"] ||
          (params["prevent_denormalization"] == nil && params["selected"] == nil)
    }
  end

  def initial_state(selecto, _v) do
    %{
      order_by:
        Map.get(Selecto.domain(selecto), :default_order_by, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      selected:
        Map.get(Selecto.domain(selecto), :default_selected, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      per_page: "30",
      max_rows: Options.default_max_rows(),
      prevent_denormalization: true
    }
  end

  ### Process incoming params to build Selecto.set for view
  def view(_opt, params, columns, filtered, selecto) do
    per_page = parse_positive_integer(Map.get(params, "per_page"), 30)
    max_rows = Options.normalize_max_rows_param(Map.get(params, "max_rows"))

    detail_columns =
      Map.get(params, "selected", %{})
      |> Map.values()
      |> Enum.sort(fn a, b ->
        String.to_integer(a["index"]) <= String.to_integer(b["index"])
      end)

    # Check if denormalization prevention is enabled (checkbox sends "on" when checked)
    prevent_denorm =
      params["prevent_denormalization"] in ["on", "true"] ||
        (params["prevent_denormalization"] == nil && params["selected"] == nil)

    # Process columns for denormalization if enabled
    {selected_columns, subselect_configs, denorm_groups} =
      if prevent_denorm do
        column_names = Enum.map(detail_columns, & &1["field"])

        {normal_cols, denorm_groups} =
          SelectoComponents.DenormalizationDetector.detect_and_group_columns(
            selecto,
            column_names
          )

        if normal_cols == [] and detail_columns != [] do
          # If every selected column denormalizes, keep the original selection
          # so we don't build an empty SELECT list.
          {detail_columns, [], %{}}
        else
          # Filter detail_columns to only include normal columns
          normal_detail_columns =
            Enum.filter(detail_columns, fn col ->
              col["field"] in normal_cols
            end)

          # Generate subselect configurations for UI display
          subselect_configs =
            Enum.map(denorm_groups, fn {path, cols} ->
              config = SelectoComponents.SubselectBuilder.generate_nested_config(path, cols)
              # Add the actual columns to the config for later use
              config =
                Map.put(
                  config,
                  :columns,
                  Enum.map(cols, fn col ->
                    {UUID.uuid4(), col, %{}}
                  end)
                )

              config
            end)

          {normal_detail_columns, subselect_configs, denorm_groups}
        end
      else
        {detail_columns, [], %{}}
      end

    ### Selecto Set for Detail View, view_meta for view data
    {%{
       columns: selected_columns,
       selected: selected_columns |> selected(columns),
       order_by:
         Map.get(params, "order_by", %{})
         |> order_by(columns),
       filtered: filtered,
       group_by: [],
       groups: [],
       subselects: subselect_configs,
       # Store the groups for building actual subselects
       denorm_groups: denorm_groups,
       denormalizing_columns: if(prevent_denorm, do: detail_columns -- selected_columns, else: [])
     },
     %{
       page: String.to_integer(Map.get(params, "detail_page", "0")),
       per_page: per_page,
       max_rows: max_rows,
       prevent_denormalization: prevent_denorm,
       subselect_configs: subselect_configs
     }}
  end

  defp normalize_per_page_param(value) do
    value
    |> parse_positive_integer(30)
    |> to_string()
  end

  defp parse_positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> default
    end
  end

  defp parse_positive_integer(_value, default), do: default

  defp order_by(order_by, _columns) do
    order_by
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn e ->
      case e["dir"] do
        "desc" -> {:desc, e["field"]}
        _ -> e["field"]
      end
    end)
  end

  defp selected(detail_selected, columns) do
    date_formats = SelectoComponents.Helpers.date_formats()

    detail_selected
    |> Enum.map(fn e ->
      col = columns[e["field"]]

      alias =
        case e["alias"] do
          "" -> e["field"]
          nil -> e["field"]
          _ -> e["alias"]
        end

      # move to a validation lib
      case col.type do
        x when x in [:naive_datetime, :utc_datetime] ->
          {:field, {:to_char, {col.colid, date_formats[e["format"]]}}, alias}

        :custom_column ->
          case Map.get(col, :requires_select) do
            x when is_list(x) -> {:row, col.requires_select, alias}
            x when is_function(x) -> {:row, col.requires_select.(e), alias}
            nil -> {:field, col.colid, alias}
          end

        _ ->
          {:field, col.colid, alias}
      end
    end)
    |> List.flatten()
  end
end
