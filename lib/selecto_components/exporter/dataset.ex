defmodule SelectoComponents.Exporter.Dataset do
  @moduledoc false

  alias SelectoComponents.Presentation

  @type t :: %{
          kind: :table | :grid,
          headers: [String.t()],
          row_keys: [String.t()],
          rows: [map()],
          metadata: map()
        }

  @spec from_query_results(term(), keyword()) :: {:ok, t()} | {:error, :no_results}
  def from_query_results({rows, columns, _aliases} = query_results, opts)
      when is_list(rows) and is_list(columns) do
    if aggregate_grid_export?(opts) do
      build_grid_dataset(query_results, opts)
    else
      build_table_dataset(query_results, opts)
    end
  end

  def from_query_results(_query_results, _opts), do: {:error, :no_results}

  @spec sanitize_value(term()) :: term()
  def sanitize_value(nil), do: nil
  def sanitize_value(value) when is_binary(value), do: value
  def sanitize_value(value) when is_number(value), do: value
  def sanitize_value(value) when is_boolean(value), do: value
  def sanitize_value(%Date{} = value), do: Date.to_iso8601(value)
  def sanitize_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  def sanitize_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def sanitize_value(%Time{} = value), do: Time.to_iso8601(value)

  def sanitize_value(%_{} = value) do
    cond do
      function_exported?(value.__struct__, :to_string, 1) -> to_string(value)
      true -> inspect(value)
    end
  end

  def sanitize_value(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), sanitize_value(v)} end)
    |> Map.new()
  end

  def sanitize_value(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&sanitize_value/1)
  end

  def sanitize_value(value) when is_list(value) do
    Enum.map(value, &sanitize_value/1)
  end

  def sanitize_value(value), do: inspect(value)

  @spec value_to_string(term()) :: String.t()
  def value_to_string(nil), do: ""
  def value_to_string(value) when is_binary(value), do: value
  def value_to_string(value) when is_number(value), do: to_string(value)
  def value_to_string(value) when is_boolean(value), do: to_string(value)

  def value_to_string(value) when is_map(value) or is_list(value) or is_tuple(value) do
    Jason.encode!(sanitize_value(value))
  end

  def value_to_string(value), do: to_string(sanitize_value(value))

  defp build_table_dataset({rows, columns, _aliases} = query_results, opts) do
    headers = headers(columns, rows)
    row_keys = Enum.map(0..max(length(headers) - 1, 0), &"__col_#{&1}")
    row_column_defs = row_column_defs(opts, query_results)
    presentation_context = Keyword.get(opts, :presentation_context, %{})
    export_mode = Keyword.get(opts, :export_mode, :raw)

    normalized_rows =
      Enum.map(rows, fn row ->
        normalize_row(row, columns, headers, row_keys,
          row_column_defs: row_column_defs,
          presentation_context: presentation_context,
          export_mode: export_mode
        )
      end)

    {:ok,
     %{
       kind: :table,
       headers: headers,
       row_keys: row_keys,
       rows: normalized_rows,
       metadata: %{
         row_count: length(normalized_rows),
         export_mode: export_mode,
         presentation_context: presentation_context
       }
     }}
  end

  defp build_grid_dataset({rows, columns, _aliases}, opts) do
    row_header = grid_header(opts, 0, Enum.at(columns, 0))
    col_headers = unique_grid_axis_values(rows, 1)
    cells = build_grid_cells(rows)
    headers = [row_header | Enum.map(col_headers, &sanitize_value/1)]
    row_headers = unique_grid_axis_values(rows, 0)

    normalized_rows =
      Enum.map(row_headers, fn row_value ->
        base_row = %{row_header => sanitize_value(row_value)}

        Enum.reduce(col_headers, base_row, fn col_value, acc ->
          Map.put(acc, sanitize_value(col_value), Map.get(cells, {row_value, col_value}))
        end)
      end)

    {:ok,
     %{
       kind: :grid,
       headers: headers,
       row_keys: headers,
       rows: normalized_rows,
       metadata: %{row_count: length(normalized_rows), row_header: row_header}
     }}
  end

  defp aggregate_grid_export?(opts) do
    view_mode = normalize_view_mode(Keyword.get(opts, :view_mode, "results"))
    view_config = Keyword.get(opts, :view_config, %{})
    aggregate_view = aggregate_view_config(view_config)

    view_mode == "aggregate" and truthy?(get_map_value(aggregate_view, :grid, false)) and
      aggregate_grid_compatible?(aggregate_view)
  end

  defp aggregate_grid_compatible?(aggregate_view) do
    group_count = aggregate_view |> get_map_value(:group_by, []) |> count_view_items()
    aggregate_count = aggregate_view |> get_map_value(:aggregate, []) |> count_view_items()
    group_count == 2 and aggregate_count == 1
  end

  defp aggregate_view_config(view_config) when is_map(view_config) do
    get_map_value(get_map_value(view_config, :views, %{}), :aggregate, %{})
  end

  defp aggregate_view_config(_), do: %{}

  defp count_view_items(items) when is_list(items), do: length(items)
  defp count_view_items(items) when is_map(items), do: map_size(items)
  defp count_view_items(_), do: 0

  defp grid_header(opts, idx, fallback) do
    aggregate_view = aggregate_view_config(Keyword.get(opts, :view_config, %{}))

    aggregate_view
    |> get_map_value(:group_by, [])
    |> ordered_view_items()
    |> Enum.at(idx)
    |> item_alias_or_fallback(fallback)
    |> to_string()
  end

  defp ordered_view_items(items) when is_list(items), do: items

  defp ordered_view_items(items) when is_map(items) do
    items
    |> Map.values()
    |> Enum.sort_by(fn item -> item |> get_map_value(:index, "0") |> to_string() end)
  end

  defp ordered_view_items(_), do: []

  defp item_alias_or_fallback({_uuid, _field, opts}, fallback) when is_map(opts) do
    alias_value = get_map_value(opts, :alias, "")
    if alias_value in [nil, ""], do: fallback, else: alias_value
  end

  defp item_alias_or_fallback(item, fallback) when is_map(item) do
    alias_value = get_map_value(item, :alias, "")
    if alias_value in [nil, ""], do: fallback, else: alias_value
  end

  defp item_alias_or_fallback(_, fallback), do: fallback

  defp unique_grid_axis_values(rows, idx) do
    rows
    |> aggregate_grid_detail_rows(2)
    |> Enum.reduce([], fn row, acc ->
      value = Enum.at(row, idx)
      if value in acc, do: acc, else: acc ++ [value]
    end)
  end

  defp build_grid_cells(rows) do
    rows
    |> aggregate_grid_detail_rows(2)
    |> Enum.reduce(%{}, fn row, acc ->
      Map.put(acc, {Enum.at(row, 0), Enum.at(row, 1)}, sanitize_value(Enum.at(row, 2)))
    end)
  end

  defp aggregate_grid_detail_rows(rows, num_group_by) do
    rows
    |> prepare_rollup_rows(num_group_by)
    |> Enum.reduce([], fn
      {level, row, false}, acc when level == num_group_by -> [row | acc]
      _other, acc -> acc
    end)
    |> Enum.reverse()
  end

  defp prepare_rollup_rows(results, num_group_by_cols) do
    rows_with_metadata =
      results
      |> Enum.with_index()
      |> Enum.map(fn {row, idx} ->
        level = rollup_level(row, num_group_by_cols)
        group_cols = Enum.take(row, num_group_by_cols)
        has_null_at_level = level > 0 and Enum.at(group_cols, level - 1) == "[NULL]"
        {level, row, has_null_at_level, idx}
      end)

    filtered_rows =
      rows_with_metadata
      |> Enum.with_index()
      |> Enum.filter(fn {{level, row, has_null_at_level, _orig_idx}, current_idx} ->
        if has_null_at_level do
          next_row = Enum.at(rows_with_metadata, current_idx + 1)
          group_cols = Enum.take(row, num_group_by_cols)

          case next_row do
            {next_level, next_row_data, _has_null, _next_idx} when next_level == level - 1 ->
              current_group_prefix = Enum.take(group_cols, level - 1)
              next_group_cols = Enum.take(next_row_data, num_group_by_cols)
              next_group_prefix = Enum.take(next_group_cols, level - 1)

              if current_group_prefix == next_group_prefix do
                current_aggs = Enum.drop(row, num_group_by_cols)
                next_aggs = Enum.drop(next_row_data, num_group_by_cols)
                not (current_aggs == next_aggs)
              else
                false
              end

            _ ->
              false
          end
        else
          true
        end
      end)

    last_level0_idx =
      filtered_rows
      |> Enum.with_index()
      |> Enum.reduce(nil, fn
        {{{0, row, _has_null, _orig_idx}, _current_idx}, idx}, acc ->
          group_cols = Enum.take(row, num_group_by_cols)
          if Enum.all?(group_cols, &(&1 in [nil, ""])), do: idx, else: acc

        _other, acc ->
          acc
      end)

    filtered_rows
    |> Enum.with_index()
    |> Enum.map(fn {{{level, row, _has_null, _orig_idx}, _current_idx}, idx} ->
      {level, row, idx == last_level0_idx}
    end)
  end

  defp rollup_level(row, num_group_by_cols) do
    row
    |> Enum.take(num_group_by_cols)
    |> Enum.count(fn col -> not is_nil(col) and col != "" end)
  end

  defp headers(columns, rows) do
    column_headers = Enum.map(columns, &to_string/1)

    cond do
      column_headers != [] ->
        column_headers

      rows == [] ->
        []

      is_map(hd(rows)) ->
        hd(rows)
        |> Map.keys()
        |> Enum.map(&to_string/1)
        |> Enum.sort()

      true ->
        []
    end
  end

  defp row_column_defs(opts, {_rows, columns, aliases}) do
    selecto = Keyword.get(opts, :selecto)

    Enum.with_index(columns)
    |> Enum.reduce(%{}, fn {column_name, idx}, acc ->
      alias_name = Enum.at(aliases, idx)
      column_def = find_column_def(selecto, column_name, alias_name)

      acc
      |> Map.put(idx, column_def)
      |> maybe_put_alias_column_def(alias_name, column_def)
      |> Map.put_new(to_string(column_name), column_def)
    end)
  end

  defp row_column_defs(_opts, _query_results), do: %{}

  defp maybe_put_alias_column_def(acc, nil, _column_def), do: acc

  defp maybe_put_alias_column_def(acc, alias_name, column_def),
    do: Map.put_new(acc, to_string(alias_name), column_def)

  defp find_column_def(nil, _column_name, _alias_name), do: nil

  defp find_column_def(selecto, column_name, alias_name) do
    configured_column(selecto, column_name) ||
      configured_column(selecto, alias_name) ||
      Selecto.field(selecto, column_name) ||
      if(alias_name, do: Selecto.field(selecto, alias_name), else: nil)
  end

  defp configured_column(_selecto, nil), do: nil

  defp configured_column(selecto, key) do
    columns = Selecto.columns(selecto)

    Map.get(columns, key) ||
      case key do
        value when is_binary(value) ->
          case safe_existing_atom(value) do
            nil -> nil
            atom_key -> Map.get(columns, atom_key)
          end

        _ ->
          nil
      end
  end

  defp normalize_row(row, columns, headers, row_keys, opts) when is_map(row) do
    headers
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {header, idx}, acc ->
      value = fetch_map_value_for_header(row, header, columns, idx)
      Map.put(acc, Enum.at(row_keys, idx), format_export_value(value, idx, header, opts))
    end)
  end

  defp normalize_row(row, _columns, headers, row_keys, opts) when is_tuple(row) do
    row
    |> Tuple.to_list()
    |> normalize_row_from_list(row_keys, headers, opts)
  end

  defp normalize_row(row, _columns, headers, row_keys, opts) when is_list(row) do
    normalize_row_from_list(row, row_keys, headers, opts)
  end

  defp normalize_row(value, _columns, headers, [], opts) do
    %{"value" => format_export_value(value, 0, List.first(headers), opts)}
  end

  defp normalize_row(value, _columns, headers, row_keys, opts) do
    row_key = List.first(row_keys)

    Map.new(row_keys, fn key ->
      {key,
       if(key == row_key,
         do: format_export_value(value, 0, List.first(headers), opts),
         else: nil
       )}
    end)
  end

  defp normalize_row_from_list(list_row, row_keys, headers, opts) do
    row_keys
    |> Enum.with_index()
    |> Enum.into(%{}, fn {header, idx} ->
      value = Enum.at(list_row, idx)
      {header, format_export_value(value, idx, Enum.at(headers, idx), opts)}
    end)
  end

  defp format_export_value(value, idx, header, opts) do
    export_mode = Keyword.get(opts, :export_mode, :raw)
    presentation_context = Keyword.get(opts, :presentation_context, %{})
    row_column_defs = Keyword.get(opts, :row_column_defs, %{})

    column_def =
      Map.get(row_column_defs, idx) || Map.get(row_column_defs, to_string(header || ""))

    value
    |> Presentation.format_value(column_def, presentation_context, mode: export_mode)
    |> sanitize_value()
  end

  defp fetch_map_value_for_header(row, header, columns, idx) do
    column_reference =
      Enum.at(columns, idx) || Enum.find(columns, fn column -> to_string(column) == header end)

    atom_key =
      cond do
        is_atom(column_reference) -> column_reference
        is_binary(column_reference) -> safe_existing_atom(column_reference)
        true -> safe_existing_atom(header)
      end

    row
    |> Map.get(header, Map.get(row, column_reference, Map.get(row, atom_key)))
  end

  defp safe_existing_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  defp safe_existing_atom(_value), do: nil

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default

  defp normalize_view_mode(view_mode) when is_atom(view_mode), do: Atom.to_string(view_mode)
  defp normalize_view_mode(view_mode) when is_binary(view_mode), do: view_mode
  defp normalize_view_mode(_view_mode), do: "results"
end
