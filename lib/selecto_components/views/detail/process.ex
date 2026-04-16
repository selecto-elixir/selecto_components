defmodule SelectoComponents.Views.Detail.Process do
  alias SelectoComponents.Helpers.BucketParser
  alias SelectoComponents.Views.Detail.Options
  alias SelectoComponents.Views.Detail.RowActions

  def param_to_state(params, _v) do
    ## state is used to draw the form
    %{
      selected: SelectoComponents.Views.view_param_process(params, "selected", "field"),
      order_by: SelectoComponents.Views.view_param_process(params, "order_by", "field"),
      per_page: normalize_per_page_param(Map.get(params, "per_page")),
      max_rows: Options.normalize_max_rows_param(Map.get(params, "max_rows")),
      count_mode: Options.normalize_count_mode_param(Map.get(params, "count_mode")),
      row_click_action:
        Options.normalize_row_click_action_param(Map.get(params, "row_click_action")),
      prevent_denormalization: prevent_denormalization_enabled?(params)
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
      count_mode: Options.default_count_mode(),
      row_click_action: "",
      prevent_denormalization: true
    }
  end

  ### Process incoming params to build Selecto.set for view
  def view(_opt, params, columns, filtered, selecto) do
    per_page = parse_positive_integer(Map.get(params, "per_page"), 30)
    max_rows = Options.normalize_max_rows_param(Map.get(params, "max_rows"))
    count_mode = Options.normalize_count_mode_param(Map.get(params, "count_mode"))

    row_click_action =
      Options.normalize_row_click_action_param(Map.get(params, "row_click_action"))

    detail_columns =
      params
      |> Map.get("selected", %{})
      |> normalize_selected_entries()

    row_action = RowActions.current_action(selecto, row_click_action)

    query_detail_columns =
      detail_columns
      |> append_required_row_action_fields(
        RowActions.additional_required_fields(row_action, detail_columns)
      )

    # Check if denormalization prevention is enabled (checkbox sends "on" when checked)
    prevent_denorm = prevent_denormalization_enabled?(params)

    # Process columns for denormalization if enabled
    {selected_columns, visible_columns, subselect_configs, denorm_groups} =
      if prevent_denorm do
        column_names = Enum.map(query_detail_columns, & &1["field"])

        {normal_cols, denorm_groups} =
          SelectoComponents.DenormalizationDetector.detect_and_group_columns(
            selecto,
            column_names
          )

        if normal_cols == [] and query_detail_columns != [] do
          # If every selected column denormalizes, keep the original selection
          # so we don't build an empty SELECT list.
          {query_detail_columns, detail_columns, [], %{}}
        else
          # Filter query columns to only include normal columns
          normal_query_detail_columns =
            Enum.filter(query_detail_columns, fn col ->
              col["field"] in normal_cols
            end)

          # Keep only visible columns in the rendered table
          normal_detail_columns =
            Enum.filter(detail_columns, fn col ->
              col["field"] in normal_cols
            end)

          visible_denorm_groups =
            filter_visible_denorm_groups(denorm_groups, detail_columns)

          # Generate subselect configurations for UI display
          subselect_configs =
            Enum.map(visible_denorm_groups, fn {path, cols} ->
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

          {normal_query_detail_columns, normal_detail_columns, subselect_configs, denorm_groups}
        end
      else
        {query_detail_columns, detail_columns, [], %{}}
      end

    ### Selecto Set for Detail View, view_meta for view data
    {%{
       columns: visible_columns,
       row_action_query_columns: selected_columns,
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
       denormalizing_columns: if(prevent_denorm, do: detail_columns -- visible_columns, else: [])
     },
     %{
       page: String.to_integer(Map.get(params, "detail_page", "0")),
       per_page: per_page,
       max_rows: max_rows,
       count_mode: count_mode,
       row_click_action: row_click_action,
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

  defp normalize_selected_entries(selected) when is_map(selected) do
    selected
    |> Enum.map(fn {uuid, entry} ->
      normalize_selected_entry(entry, to_string(uuid), nil)
    end)
    |> sort_selected_entries()
  end

  defp normalize_selected_entries(selected) when is_list(selected) do
    selected
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} ->
      normalize_selected_entry(entry, nil, idx)
    end)
    |> sort_selected_entries()
  end

  defp normalize_selected_entries(_), do: []

  defp prevent_denormalization_enabled?(params) when is_map(params) do
    case Map.get(params, "prevent_denormalization") do
      value when value in [true, "true", "on", 1, "1"] ->
        true

      value when value in [false, "false", 0, "0"] ->
        false

      [value | _rest] ->
        value in [true, "true", "on", 1, "1"]

      nil ->
        Map.get(params, "selected") == nil

      _other ->
        false
    end
  end

  defp prevent_denormalization_enabled?(_params), do: true

  defp normalize_selected_entry(%{} = config, fallback_uuid, fallback_index) do
    config
    |> map_string_keys()
    |> Map.put_new("uuid", fallback_uuid || UUID.uuid4())
    |> Map.put_new("index", to_string(fallback_index || 0))
    |> Map.put_new("alias", "")
  end

  defp normalize_selected_entry({uuid, field, %{} = config}, _fallback_uuid, fallback_index) do
    config
    |> map_string_keys()
    |> Map.put_new("uuid", to_string(uuid))
    |> Map.put_new("field", to_string(field))
    |> Map.put_new("index", to_string(fallback_index || 0))
    |> Map.put_new("alias", "")
  end

  defp normalize_selected_entry({uuid, field, config}, fallback_uuid, fallback_index) do
    config_map = if is_map(config), do: map_string_keys(config), else: %{}

    config_map
    |> Map.put_new("uuid", to_string(uuid || fallback_uuid || UUID.uuid4()))
    |> Map.put_new("field", to_string(field))
    |> Map.put_new("index", to_string(fallback_index || 0))
    |> Map.put_new("alias", "")
  end

  defp normalize_selected_entry([uuid, field, %{} = config], _fallback_uuid, fallback_index) do
    config
    |> map_string_keys()
    |> Map.put_new("uuid", to_string(uuid))
    |> Map.put_new("field", to_string(field))
    |> Map.put_new("index", to_string(fallback_index || 0))
    |> Map.put_new("alias", "")
  end

  defp normalize_selected_entry([uuid, field, _config], _fallback_uuid, fallback_index) do
    %{
      "uuid" => to_string(uuid),
      "field" => to_string(field),
      "index" => to_string(fallback_index || 0),
      "alias" => ""
    }
  end

  defp normalize_selected_entry(field, fallback_uuid, fallback_index) when is_binary(field) do
    %{
      "uuid" => fallback_uuid || UUID.uuid4(),
      "field" => field,
      "index" => to_string(fallback_index || 0),
      "alias" => ""
    }
  end

  defp normalize_selected_entry(field, fallback_uuid, fallback_index) when is_atom(field) do
    normalize_selected_entry(Atom.to_string(field), fallback_uuid, fallback_index)
  end

  defp normalize_selected_entry(_entry, fallback_uuid, fallback_index) do
    %{
      "uuid" => fallback_uuid || UUID.uuid4(),
      "field" => nil,
      "index" => to_string(fallback_index || 0),
      "alias" => ""
    }
  end

  defp sort_selected_entries(entries) do
    Enum.sort(entries, fn a, b ->
      selected_entry_index(a) <= selected_entry_index(b)
    end)
  end

  defp append_required_row_action_fields(detail_columns, []), do: detail_columns

  defp append_required_row_action_fields(detail_columns, required_fields) do
    existing_fields =
      detail_columns
      |> Enum.map(&Map.get(&1, "field"))
      |> MapSet.new()

    next_index =
      detail_columns
      |> Enum.map(&selected_entry_index/1)
      |> Enum.max(fn -> -1 end)
      |> Kernel.+(1)

    hidden_columns =
      required_fields
      |> Enum.reject(&MapSet.member?(existing_fields, &1))
      |> Enum.with_index(next_index)
      |> Enum.map(fn {field, index} ->
        %{
          "uuid" => UUID.uuid4(),
          "field" => field,
          "index" => to_string(index),
          "alias" => field,
          "hidden" => true,
          "row_action_required" => true
        }
      end)

    detail_columns ++ hidden_columns
  end

  defp filter_visible_denorm_groups(denorm_groups, detail_columns) do
    visible_fields =
      detail_columns
      |> Enum.map(&Map.get(&1, "field"))
      |> MapSet.new()

    Enum.filter(denorm_groups, fn {_path, cols} ->
      Enum.any?(cols, &MapSet.member?(visible_fields, &1))
    end)
  end

  defp selected_entry_index(entry) do
    case Integer.parse(to_string(Map.get(entry, "index", "0"))) do
      {index, _} -> index
      :error -> 0
    end
  end

  defp map_string_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} when is_binary(key) -> {key, value}
      {key, value} -> {to_string(key), value}
    end)
  end

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
      case Selecto.Temporal.date_like_type(col) || col.type do
        x when x in [:naive_datetime, :utc_datetime, :date] ->
          datetime_selected(col, e, alias, date_formats)

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

  defp datetime_selected(col, config, alias_name, date_formats) do
    format = Map.get(config, "format")
    bucket_ranges = Map.get(config, "bucket_ranges")

    case format do
      "age_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        field_with_alias = detail_field_ref(col.colid)

        case_sql =
          BucketParser.generate_bucket_case_sql(
            "(CURRENT_DATE - DATE(#{field_with_alias}))",
            bucket_ranges,
            :integer
          )

        {:field, {:raw_sql, case_sql}, alias_name}

      "custom_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        field_with_alias = detail_field_ref(col.colid)

        case_sql =
          BucketParser.generate_bucket_case_sql(
            field_with_alias,
            bucket_ranges,
            :date
          )

        {:field, {:raw_sql, case_sql}, alias_name}

      "year_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        field_with_alias = detail_field_ref(col.colid)

        case_sql =
          BucketParser.generate_bucket_case_sql(
            "EXTRACT(YEAR FROM #{field_with_alias})",
            bucket_ranges,
            :integer
          )

        {:field, {:raw_sql, case_sql}, alias_name}

      _ ->
        to_char_format = Map.get(date_formats, format)

        if is_binary(to_char_format) and to_char_format != "" do
          {:field, {:to_char, {col.colid, to_char_format}}, alias_name}
        else
          {:field, col.colid, alias_name}
        end
    end
  end

  defp detail_field_ref(colid) do
    colid_str = to_string(colid)
    if String.contains?(colid_str, "."), do: colid_str, else: "selecto_root." <> colid_str
  end
end
