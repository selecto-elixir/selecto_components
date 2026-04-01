defmodule SelectoComponents.Exporter do
  @moduledoc false

  @csv_formula_prefixes ["=", "+", "-", "@"]

  alias SelectoComponents.Exporter.Dataset

  @type export_result :: %{
          filename: String.t(),
          mime_type: String.t(),
          content: binary(),
          browser_content: String.t(),
          browser_content_encoding: String.t()
        }

  @spec build(String.t() | atom(), term(), keyword()) :: {:ok, export_result()} | {:error, atom()}
  def build(format, query_results, opts \\ [])

  def build(format, {_rows, _columns, _aliases} = query_results, opts) do
    format = normalize_format(format)

    with {:ok, dataset} <- Dataset.from_query_results(query_results, opts) do
      case format do
        "json" -> build_json(dataset, opts)
        "csv" -> build_csv(dataset, opts)
        "tsv" -> build_tsv(dataset, opts)
        "xlsx" -> build_xlsx(dataset, opts)
        _ -> {:error, :unsupported_format}
      end
    end
  end

  def build(_format, _query_results, _opts), do: {:error, :no_results}

  defp build_json(dataset, opts) do
    exported_at = exported_at(opts)
    view_mode = normalize_view_mode(Keyword.get(opts, :view_mode, "results"))
    filename = "selecto_#{view_mode}_#{filename_timestamp(exported_at)}.json"

    payload = %{
      exported_at: DateTime.to_iso8601(exported_at),
      view_mode: view_mode,
      row_count: length(dataset.rows),
      columns: dataset.headers,
      rows: dataset.rows
    }

    {:ok,
     %{
       filename: filename,
       mime_type: "application/json",
       content: Jason.encode!(payload, pretty: true),
       browser_content: Jason.encode!(payload, pretty: true),
       browser_content_encoding: "utf8"
     }}
  end

  defp build_csv(dataset, opts) do
    build_delimited_export(dataset, opts, ",", "csv", "text/csv;charset=utf-8")
  end

  defp build_tsv(dataset, opts) do
    build_delimited_export(
      dataset,
      opts,
      "\t",
      "tsv",
      "text/tab-separated-values;charset=utf-8"
    )
  end

  defp build_xlsx(dataset, opts) do
    exported_at = exported_at(opts)
    view_mode = normalize_view_mode(Keyword.get(opts, :view_mode, "results"))
    filename = "selecto_#{view_mode}_#{filename_timestamp(exported_at)}.xlsx"

    with {:ok, content} <- build_xlsx_binary(dataset, view_mode, exported_at) do
      {:ok,
       %{
         filename: filename,
         mime_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
         content: content,
         browser_content: Base.encode64(content),
         browser_content_encoding: "base64"
       }}
    end
  end

  defp build_delimited_export(dataset, opts, delimiter, extension, mime_type) do
    exported_at = exported_at(opts)
    view_mode = normalize_view_mode(Keyword.get(opts, :view_mode, "results"))
    filename = "selecto_#{view_mode}_#{filename_timestamp(exported_at)}.#{extension}"

    header_row = Enum.map_join(dataset.headers, delimiter, &delimited_cell(&1, delimiter))

    data_rows =
      Enum.map(dataset.rows, fn row_map ->
        dataset.headers
        |> Enum.map(fn header -> Map.get(row_map, header) end)
        |> Enum.map_join(delimiter, fn value ->
          value
          |> Dataset.value_to_string()
          |> delimited_cell(delimiter)
        end)
      end)

    content =
      [header_row | data_rows]
      |> Enum.join("\n")

    {:ok,
     %{
       filename: filename,
       mime_type: mime_type,
       content: content,
       browser_content: content,
       browser_content_encoding: "utf8"
     }}
  end

  defp delimited_cell(value, delimiter) do
    escaped =
      value
      |> neutralize_csv_formula()
      |> String.replace("\"", "\"\"")

    if String.contains?(escaped, [delimiter, "\n", "\r", "\""]) do
      "\"#{escaped}\""
    else
      escaped
    end
  end

  defp build_xlsx_binary(dataset, view_mode, exported_at) do
    worksheet = worksheet_xml(dataset)
    workbook = workbook_xml()
    workbook_rels = workbook_rels_xml()
    root_rels = root_rels_xml()
    content_types = content_types_xml()
    core = core_xml(view_mode, exported_at)
    app = app_xml()
    styles = styles_xml()

    files = [
      {~c"[Content_Types].xml", content_types},
      {~c"_rels/.rels", root_rels},
      {~c"docProps/app.xml", app},
      {~c"docProps/core.xml", core},
      {~c"xl/workbook.xml", workbook},
      {~c"xl/_rels/workbook.xml.rels", workbook_rels},
      {~c"xl/styles.xml", styles},
      {~c"xl/worksheets/sheet1.xml", worksheet}
    ]

    case :zip.create(~c"selecto_export.xlsx", files, [:memory]) do
      {:ok, {_name, binary}} -> {:ok, binary}
      {:error, reason} -> {:error, reason}
    end
  end

  defp worksheet_xml(dataset) do
    rows =
      [dataset.headers | Enum.map(dataset.rows, &row_values(dataset.headers, &1))]
      |> Enum.with_index(1)
      |> Enum.map_join("", fn {row, row_index} ->
        "<row r=\"#{row_index}\">#{cells_xml(row, row_index)}</row>"
      end)

    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <sheetData>#{rows}</sheetData>
    </worksheet>
    """
    |> String.trim()
  end

  defp cells_xml(row, row_index) do
    row
    |> Enum.with_index(1)
    |> Enum.map_join("", fn {value, col_index} ->
      ref = cell_ref(col_index, row_index)
      xlsx_cell_xml(ref, value)
    end)
  end

  defp xlsx_cell_xml(ref, nil), do: "<c r=\"#{ref}\" t=\"inlineStr\"><is><t></t></is></c>"

  defp xlsx_cell_xml(ref, value) when is_integer(value) or is_float(value) do
    "<c r=\"#{ref}\"><v>#{value}</v></c>"
  end

  defp xlsx_cell_xml(ref, true), do: "<c r=\"#{ref}\" t=\"b\"><v>1</v></c>"
  defp xlsx_cell_xml(ref, false), do: "<c r=\"#{ref}\" t=\"b\"><v>0</v></c>"

  defp xlsx_cell_xml(ref, value) do
    escaped = value |> Dataset.sanitize_value() |> Dataset.value_to_string() |> xml_escape()
    "<c r=\"#{ref}\" t=\"inlineStr\"><is><t xml:space=\"preserve\">#{escaped}</t></is></c>"
  end

  defp row_values(headers, row_map) do
    Enum.map(headers, &Map.get(row_map, &1))
  end

  defp cell_ref(col_index, row_index) do
    "#{column_ref(col_index)}#{row_index}"
  end

  defp column_ref(index) when index > 0 do
    do_column_ref(index, "")
  end

  defp do_column_ref(0, acc), do: acc

  defp do_column_ref(index, acc) do
    remainder = rem(index - 1, 26)
    letter = <<remainder + ?A>>
    do_column_ref(div(index - 1, 26), letter <> acc)
  end

  defp content_types_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
      <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
    </Types>
    """
    |> String.trim()
  end

  defp root_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
      <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
    </Relationships>
    """
    |> String.trim()
  end

  defp workbook_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
        <sheet name="Export" sheetId="1" r:id="rId1"/>
      </sheets>
    </workbook>
    """
    |> String.trim()
  end

  defp workbook_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """
    |> String.trim()
  end

  defp styles_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
      <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
      <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
      <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """
    |> String.trim()
  end

  defp core_xml(view_mode, exported_at) do
    timestamp = DateTime.to_iso8601(exported_at)
    title = xml_escape("Selecto #{view_mode} export")

    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <dc:title>#{title}</dc:title>
      <dc:creator>SelectoComponents</dc:creator>
      <cp:lastModifiedBy>SelectoComponents</cp:lastModifiedBy>
      <dcterms:created xsi:type="dcterms:W3CDTF">#{timestamp}</dcterms:created>
      <dcterms:modified xsi:type="dcterms:W3CDTF">#{timestamp}</dcterms:modified>
    </cp:coreProperties>
    """
    |> String.trim()
  end

  defp app_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
      <Application>SelectoComponents</Application>
    </Properties>
    """
    |> String.trim()
  end

  defp xml_escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
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
