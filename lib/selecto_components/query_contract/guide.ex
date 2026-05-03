defmodule SelectoComponents.QueryContract.Guide do
  @moduledoc """
  Markdown guide renderer for Selecto query contracts.

  The guide is a readable companion to `query_contract.json`. It is meant for
  humans, external tools, and AI assistants that benefit from compact prose over
  the full JSON artifact.
  """

  alias SelectoComponents.QueryContract

  @default_field_limit 40

  @type diagnostics :: Selecto.Domain.Diagnostics.t()

  @spec markdown(term(), keyword()) :: {:ok, String.t(), diagnostics()} | {:error, diagnostics()}
  def markdown(input, opts \\ []) do
    with {:ok, document, diagnostics} <- QueryContract.json_document(input, opts) do
      {:ok, render(document, opts), diagnostics}
    end
  end

  @doc false
  @spec render(map(), keyword()) :: String.t()
  def render(document, opts \\ []) when is_map(document) do
    field_limit = Keyword.get(opts, :field_limit, @default_field_limit)
    fields = document |> Map.get("fields", []) |> prioritized_fields(document)
    shown_fields = Enum.take(fields, field_limit)
    choice_sources = Map.get(document, "choice_sources", [])

    [
      title_section(document),
      context_section(document),
      field_section(shown_fields, length(fields), field_limit),
      filter_section(Map.get(document, "filters", [])),
      join_section(Map.get(document, "joins", [])),
      choice_source_section(choice_sources),
      choice_backed_field_section(fields, choice_sources),
      vocabulary_section(fields),
      example_section(document),
      safety_section()
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  defp title_section(document) do
    domain = Map.get(document, "domain", %{})
    name = Map.get(domain, "name") || Map.get(document, "name") || "Selecto Domain"

    [
      "# #{escape_text(name)} Query Guide",
      "",
      maybe_line("Domain id", Map.get(domain, "id")),
      maybe_line("Path", Map.get(domain, "path")),
      maybe_line("Generated", Map.get(document, "generated_at")),
      maybe_line("Description", Map.get(domain, "description")),
      "",
      "This guide summarizes the query contract. Use the JSON contract for the complete machine-readable schema."
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp prioritized_fields(fields, document) do
    default_ids =
      document
      |> Map.get("defaults", %{})
      |> Map.get("default_selected", [])
      |> Enum.map(&to_string/1)

    default_rank =
      default_ids
      |> Enum.with_index()
      |> Map.new()

    fields
    |> Enum.sort_by(fn field ->
      id = to_string(Map.get(field, "id", ""))

      case Map.fetch(default_rank, id) do
        {:ok, index} -> {0, index, id}
        :error -> {1, 0, id}
      end
    end)
  end

  defp context_section(document) do
    context = Map.get(document, "context", %{})

    [
      "## Context",
      "",
      "- View modes: #{inline_list(Map.get(context, "view_modes", []))}",
      "- Default view mode: #{inline_code(Map.get(context, "default_view_mode"))}",
      "- Exports: #{inline_list(Map.get(context, "exports", []))}",
      "- Saved views enabled: #{Map.get(context, "saved_views_enabled", false)}",
      "- Exported views enabled: #{Map.get(context, "exported_views_enabled", false)}"
    ]
    |> Enum.join("\n")
  end

  defp field_section([], _total, _limit), do: ""

  defp field_section(fields, total, _limit) do
    limit_note =
      if total > length(fields) do
        "\n\nShowing #{length(fields)} of #{total} fields. See `query_contract.json` for the complete list."
      else
        ""
      end

    table =
      [
        "| Field | Label | Type | Query Use |",
        "| --- | --- | --- | --- |"
        | Enum.map(fields, &field_row/1)
      ]
      |> Enum.join("\n")

    ["## Fields", "", table, limit_note]
    |> Enum.join("\n")
  end

  defp field_row(field) do
    use =
      [
        flag(field, "detail_selectable", "select"),
        flag(field, "filterable", "filter"),
        flag(field, "sortable", "sort"),
        flag(field, "groupable", "group"),
        flag(field, "aggregatable", "aggregate")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    [
      field_cell(Map.get(field, "id")),
      table_cell(Map.get(field, "label")),
      table_cell(Map.get(field, "type")),
      table_cell(use)
    ]
    |> table_row()
  end

  defp filter_section([]), do: ""

  defp filter_section(filters) do
    table =
      [
        "| Filter | Field | Type | Comparators |",
        "| --- | --- | --- | --- |"
        | Enum.map(filters, &filter_row/1)
      ]
      |> Enum.join("\n")

    ["## Filters", "", table]
    |> Enum.join("\n")
  end

  defp filter_row(filter) do
    [
      field_cell(Map.get(filter, "id")),
      field_cell(Map.get(filter, "field") || "virtual"),
      table_cell(Map.get(filter, "type")),
      table_cell(Enum.join(Map.get(filter, "comparators", []), ", "))
    ]
    |> table_row()
  end

  defp join_section([]), do: ""

  defp join_section(joins) do
    table =
      [
        "| Join | Target | Type | Fields |",
        "| --- | --- | --- | --- |"
        | joins
          |> Enum.take(20)
          |> Enum.map(&join_row/1)
      ]
      |> Enum.join("\n")

    ["## Joins", "", table]
    |> Enum.join("\n")
  end

  defp join_row(join) do
    [
      field_cell(Map.get(join, "id")),
      field_cell(Map.get(join, "target_schema")),
      table_cell(Map.get(join, "type")),
      table_cell(Enum.join(Map.get(join, "fields", []), ", "))
    ]
    |> table_row()
  end

  defp choice_source_section([]), do: ""

  defp choice_source_section(choice_sources) do
    table =
      [
        "| Choice Source | Domain | Value | Label | Options | Validate |",
        "| --- | --- | --- | --- | --- | --- |"
        | Enum.map(choice_sources, &choice_source_row/1)
      ]
      |> Enum.join("\n")

    ["## Choice Sources", "", table]
    |> Enum.join("\n")
  end

  defp choice_source_row(choice_source) do
    links = Map.get(choice_source, "links", %{})

    [
      field_cell(Map.get(choice_source, "id")),
      field_cell(Map.get(choice_source, "domain")),
      field_cell(Map.get(choice_source, "value_field")),
      field_cell(Map.get(choice_source, "label_field")),
      table_cell(Map.get(links, "options")),
      table_cell(Map.get(links, "validate"))
    ]
    |> table_row()
  end

  defp choice_backed_field_section(fields, choice_sources) do
    choice_source_index = choice_source_index(choice_sources)

    rows =
      fields
      |> Enum.flat_map(&choice_backed_field_rows(&1, choice_source_index))

    if rows == [] do
      ""
    else
      table =
        [
          "| Field | Choice Source | Control | Options | Validate |",
          "| --- | --- | --- | --- | --- |"
          | rows
        ]
        |> Enum.join("\n")

      ["## Choice-Backed Fields", "", table]
      |> Enum.join("\n")
    end
  end

  defp choice_backed_field_rows(field, choice_source_index) do
    field
    |> choice_source_ids()
    |> Enum.map(fn choice_source_id ->
      choice_source = Map.get(choice_source_index, to_string(choice_source_id), %{})
      metadata = Map.get(field, "choice_source_metadata", %{})
      links = choice_source_links(choice_source, metadata)

      [
        field_cell(Map.get(field, "id")),
        field_cell(choice_source_id),
        table_cell(choice_source_control(choice_source, metadata)),
        table_cell(Map.get(links, "options")),
        table_cell(Map.get(links, "validate"))
      ]
      |> table_row()
    end)
  end

  defp choice_source_ids(field) do
    field
    |> Map.get("choice_source")
    |> case do
      nil -> []
      [] -> []
      values when is_list(values) -> values
      value -> [value]
    end
    |> Enum.reject(&is_nil/1)
  end

  defp choice_source_index(choice_sources) do
    choice_sources
    |> Enum.filter(&is_map/1)
    |> Map.new(fn choice_source -> {to_string(Map.get(choice_source, "id")), choice_source} end)
  end

  defp choice_source_control(choice_source, metadata) do
    metadata_presentation = Map.get(metadata, "presentation", %{})
    presentation = Map.get(choice_source, "presentation", %{})

    Map.get(metadata_presentation, "control") ||
      Map.get(presentation, "control") ||
      Map.get(metadata_presentation, :control) ||
      Map.get(presentation, :control)
  end

  defp choice_source_links(choice_source, metadata) do
    links = Map.get(choice_source, "links", %{})

    if links == %{} do
      %{
        "options" => get_in(metadata, ["options_request", "url"]),
        "validate" => get_in(metadata, ["validate_request_template", "url"])
      }
    else
      links
    end
  end

  defp vocabulary_section(fields) do
    comparators =
      fields
      |> Enum.flat_map(&Map.get(&1, "comparators", []))
      |> Enum.uniq()
      |> Enum.sort()

    aggregate_functions =
      fields
      |> Enum.flat_map(&Map.get(&1, "aggregate_functions", []))
      |> Enum.uniq()
      |> Enum.sort()

    [
      "## Intent Vocabulary",
      "",
      "- Comparators: #{inline_list(comparators)}",
      "- Aggregate functions: #{inline_list(aggregate_functions)}"
    ]
    |> Enum.join("\n")
  end

  defp example_section(document) do
    default_selected =
      document
      |> Map.get("defaults", %{})
      |> Map.get("default_selected", [])

    fields =
      default_selected
      |> Enum.take(5)
      |> Enum.map(&to_string/1)

    [
      "## Example Intent",
      "",
      "```json",
      Jason.encode!(%{view_mode: "detail", select: fields, filters: []}, pretty: true),
      "```"
    ]
    |> Enum.join("\n")
  end

  defp safety_section do
    [
      "## Safety Notes",
      "",
      "- This guide does not grant permission to run raw SQL.",
      "- Generated query state should be validated against the JSON contract before use.",
      "- Host application authentication and authorization still decide what a user may access."
    ]
    |> Enum.join("\n")
  end

  defp maybe_line(_label, nil), do: ""
  defp maybe_line(_label, ""), do: ""
  defp maybe_line(label, value), do: "- #{label}: #{inline_code(value)}"

  defp flag(field, key, label), do: if(Map.get(field, key), do: label)

  defp inline_list([]), do: "`none`"

  defp inline_list(values) do
    values
    |> Enum.map(&inline_code/1)
    |> Enum.join(", ")
  end

  defp inline_code(nil), do: "`none`"

  defp inline_code(value) do
    escaped =
      value
      |> to_string()
      |> String.replace("`", "\\`")

    "`#{escaped}`"
  end

  defp field_cell(value), do: inline_code(value)

  defp table_cell(nil), do: ""

  defp table_cell(value) do
    value
    |> to_string()
    |> String.replace("|", "\\|")
    |> String.replace("\n", " ")
  end

  defp table_row(cells), do: "| " <> Enum.join(cells, " | ") <> " |"

  defp escape_text(value) do
    value
    |> to_string()
    |> String.replace("#", "\\#")
  end
end
