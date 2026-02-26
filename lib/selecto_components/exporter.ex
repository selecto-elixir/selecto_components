defmodule SelectoComponents.Exporter do
  @moduledoc false

  @type export_result :: %{
          filename: String.t(),
          mime_type: String.t(),
          content: String.t()
        }

  @spec build(String.t() | atom(), term(), keyword()) :: {:ok, export_result()} | {:error, atom()}
  def build(format, query_results, opts \\ [])

  def build(format, {_rows, _columns, _aliases} = query_results, opts) do
    format = normalize_format(format)

    with {:ok, normalized} <- normalize_rows(query_results) do
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

  defp normalize_rows({rows, columns, _aliases}) when is_list(rows) and is_list(columns) do
    headers = headers(columns, rows)

    normalized_rows =
      Enum.map(rows, fn row ->
        normalize_row(row, columns, headers)
      end)

    {:ok, %{headers: headers, rows: normalized_rows}}
  end

  defp normalize_rows(_query_results), do: {:error, :no_results}

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
    escaped = String.replace(value, "\"", "\"\"")

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
end
