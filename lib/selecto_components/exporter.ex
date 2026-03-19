defmodule SelectoComponents.Exporter do
  @moduledoc false

  @csv_formula_prefixes ["=", "+", "-", "@"]

  @type export_result :: %{
          filename: String.t(),
          mime_type: String.t(),
          content: String.t()
        }

  @spec build(String.t() | atom(), term(), keyword()) :: {:ok, export_result()} | {:error, atom()}
  def build(format, query_results, opts \\ [])

  def build(format, {_rows, _columns, _aliases} = query_results, opts) do
    format = normalize_format(format)

    with {:ok, normalized} <- normalize_rows(query_results, opts) do
      case format do
        "json" -> build_json(normalized, opts)
        "csv" -> build_csv(normalized, opts)
        _ -> {:error, :unsupported_format}
      end
    end
  end

  def build(_format, _query_results, _opts), do: {:error, :no_results}

  defp build_json(normalized, opts) do
    exported_at = exported_at(opts)
    view_mode = normalize_view_mode(Keyword.get(opts, :view_mode, "results"))
    filename = "selecto_#{view_mode}_#{filename_timestamp(exported_at)}.json"

    payload = %{
      exported_at: DateTime.to_iso8601(exported_at),
      view_mode: view_mode,
      row_count: length(normalized.rows),
      columns: normalized.headers,
      rows: normalized.rows
    }

    {:ok,
     %{
       filename: filename,
       mime_type: "application/json",
       content: Jason.encode!(payload, pretty: true)
     }}
  end

  defp build_csv(normalized, opts) do
    exported_at = exported_at(opts)
    view_mode = normalize_view_mode(Keyword.get(opts, :view_mode, "results"))
    filename = "selecto_#{view_mode}_#{filename_timestamp(exported_at)}.csv"

    header_row = Enum.map_join(normalized.headers, ",", &csv_cell/1)

    data_rows =
      Enum.map(normalized.rows, fn row_map ->
        normalized.headers
        |> Enum.map(fn header -> Map.get(row_map, header) end)
        |> Enum.map_join(",", fn value ->
          value
          |> value_to_string()
          |> csv_cell()
        end)
      end)

    content =
      [header_row | data_rows]
      |> Enum.join("\n")

    {:ok,
     %{
       filename: filename,
       mime_type: "text/csv;charset=utf-8",
       content: content
     }}
  end

  defp normalize_rows({rows, columns, _aliases} = query_results, opts)
       when is_list(rows) and is_list(columns) do
    if aggregate_grid_export?(opts) do
      normalize_grid_rows(query_results, opts)
    else
      normalize_tabular_rows(query_results)
    end
  end

  defp normalize_rows(_query_results, _opts), do: {:error, :no_results}

  defp normalize_tabular_rows({rows, columns, _aliases}) do
    headers = headers(columns, rows)

    normalized_rows =
      Enum.map(rows, fn row ->
        normalize_row(row, columns, headers)
      end)

    {:ok, %{headers: headers, rows: normalized_rows}}
  end

  defp normalize_grid_rows({rows, columns, _aliases}, opts) do
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

    {:ok, %{headers: headers, rows: normalized_rows}}
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

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default

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

  defp normalize_row(row, columns, headers) when is_map(row) do
    Enum.reduce(headers, %{}, fn header, acc ->
      value = fetch_map_value_for_header(row, header, columns)
      Map.put(acc, header, sanitize_value(value))
    end)
  end

  defp normalize_row(row, _columns, headers) when is_tuple(row) do
    row
    |> Tuple.to_list()
    |> normalize_row_from_list(headers)
  end

  defp normalize_row(row, _columns, headers) when is_list(row) do
    normalize_row_from_list(row, headers)
  end

  defp normalize_row(value, _columns, []) do
    %{"value" => sanitize_value(value)}
  end

  defp normalize_row(value, _columns, headers) do
    header = List.first(headers)
    Map.new(headers, fn h -> {h, if(h == header, do: sanitize_value(value), else: nil)} end)
  end

  defp normalize_row_from_list(list_row, headers) do
    headers
    |> Enum.zip(list_row)
    |> Enum.into(%{}, fn {header, value} ->
      {header, sanitize_value(value)}
    end)
  end

  defp fetch_map_value_for_header(row, header, columns) do
    column_reference = Enum.find(columns, fn column -> to_string(column) == header end)

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

  defp sanitize_value(nil), do: nil
  defp sanitize_value(value) when is_binary(value), do: value
  defp sanitize_value(value) when is_number(value), do: value
  defp sanitize_value(value) when is_boolean(value), do: value
  defp sanitize_value(%Date{} = value), do: Date.to_iso8601(value)
  defp sanitize_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp sanitize_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp sanitize_value(%Time{} = value), do: Time.to_iso8601(value)

  defp sanitize_value(%_{} = value) do
    cond do
      function_exported?(value.__struct__, :to_string, 1) -> to_string(value)
      true -> inspect(value)
    end
  end

  defp sanitize_value(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), sanitize_value(v)} end)
    |> Map.new()
  end

  defp sanitize_value(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&sanitize_value/1)
  end

  defp sanitize_value(value) when is_list(value) do
    Enum.map(value, &sanitize_value/1)
  end

  defp sanitize_value(value), do: inspect(value)

  defp value_to_string(nil), do: ""
  defp value_to_string(value) when is_binary(value), do: value
  defp value_to_string(value) when is_number(value), do: to_string(value)
  defp value_to_string(value) when is_boolean(value), do: to_string(value)

  defp value_to_string(value) when is_map(value) or is_list(value) or is_tuple(value) do
    Jason.encode!(sanitize_value(value))
  end

  defp value_to_string(value), do: to_string(sanitize_value(value))

  defp csv_cell(value) do
    escaped =
      value
      |> neutralize_csv_formula()
      |> String.replace("\"", "\"\"")

    if String.contains?(escaped, [",", "\n", "\r", "\""]) do
      "\"#{escaped}\""
    else
      escaped
    end
  end

  defp normalize_format(format) when is_atom(format),
    do: format |> Atom.to_string() |> normalize_format()

  defp normalize_format(format) when is_binary(format),
    do: format |> String.trim() |> String.downcase()

  defp normalize_format(_format), do: ""

  defp normalize_view_mode(view_mode) when is_atom(view_mode), do: Atom.to_string(view_mode)
  defp normalize_view_mode(view_mode) when is_binary(view_mode), do: view_mode
  defp normalize_view_mode(_view_mode), do: "results"

  defp exported_at(opts) do
    case Keyword.get(opts, :exported_at) do
      %DateTime{} = dt -> dt
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp filename_timestamp(%DateTime{} = date_time) do
    date_time
    |> DateTime.to_naive()
    |> Calendar.strftime("%Y%m%d_%H%M%S")
  end

  defp neutralize_csv_formula(value) when is_binary(value) do
    trimmed = String.trim_leading(value)

    if trimmed != "" and String.starts_with?(trimmed, @csv_formula_prefixes) do
      "'" <> value
    else
      value
    end
  end
end
