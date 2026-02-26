defmodule SelectoComponents.Views.Aggregate.Component do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent

  @aggregate_per_page_options [30, 100, 200, 300, "all"]
  @default_aggregate_per_page "100"

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       aggregate_page: 0
     )}
  end

  @impl true
  def update(assigns, socket) do
    previous_exe_id = get_in(socket.assigns, [:view_meta, :exe_id])
    incoming_exe_id = get_in(assigns, [:view_meta, :exe_id])

    aggregate_page =
      if previous_exe_id && incoming_exe_id && previous_exe_id != incoming_exe_id do
        0
      else
        Map.get(socket.assigns, :aggregate_page, 0)
      end

    # Force a complete re-assignment to ensure LiveView recognizes data changes
    socket = assign(socket, assigns)

    # Add a timestamp to force re-rendering if data changed
    socket =
      assign(socket,
        aggregate_page: aggregate_page,
        last_update: System.system_time(:microsecond)
      )

    {:ok, socket}
  end

  # Determine the hierarchy level of a ROLLUP result row
  # With COALESCE, NULL values appear as "[NULL]" strings
  # ROLLUP NULLs remain as nil or empty string
  defp rollup_level(row, num_group_by_cols) do
    group_cols = Enum.take(row, num_group_by_cols)

    non_nil_count =
      Enum.count(group_cols, fn col ->
        # Count as filled if:
        # - Not nil
        # - Not empty string (ROLLUP NULL)
        # - Not "[NULL]" string (but this IS a filled value from COALESCE - data NULL)
        not is_nil(col) and col != ""
      end)

    non_nil_count
  end

  # Prepare ROLLUP results with hierarchy metadata
  # With COALESCE, data NULLs show as "[NULL]", ROLLUP NULLs show as nil/empty
  # Filter out redundant [NULL] rows that are identical to their rollup subtotal
  defp prepare_rollup_rows(results, num_group_by_cols) do
    rows_with_metadata =
      results
      |> Enum.with_index()
      |> Enum.map(fn {row, idx} ->
        level = rollup_level(row, num_group_by_cols)
        group_cols = Enum.take(row, num_group_by_cols)

        # Check if this row has [NULL] at its current level (data NULL from LEFT JOIN)
        # Level 0 = grand total (no [NULL] possible)
        # Level N = first N columns filled, so check position N-1 for [NULL]
        has_null_at_level = level > 0 && Enum.at(group_cols, level - 1) == "[NULL]"

        {level, row, has_null_at_level, idx}
      end)

    # Filter out [NULL] rows if the next row (rollup subtotal) has identical aggregates
    rows_with_metadata
    |> Enum.with_index()
    |> Enum.filter(fn {{level, row, has_null_at_level, _orig_idx}, current_idx} ->
      if has_null_at_level do
        # This is a row ending with [NULL] - check if next row is its rollup with same values
        next_row = Enum.at(rows_with_metadata, current_idx + 1)
        group_cols = Enum.take(row, num_group_by_cols)

        case next_row do
          {next_level, next_row_data, _has_null, _next_idx} when next_level == level - 1 ->
            # Next row is at the right level - verify it's OUR rollup by checking group columns
            current_group_prefix = Enum.take(group_cols, level - 1)
            next_group_cols = Enum.take(next_row_data, num_group_by_cols)
            next_group_prefix = Enum.take(next_group_cols, level - 1)

            if current_group_prefix == next_group_prefix do
              # Same group - this is our rollup subtotal, compare aggregates
              current_aggs = Enum.drop(row, num_group_by_cols)
              next_aggs = Enum.drop(next_row_data, num_group_by_cols)

              # If aggregates are identical, skip this [NULL] row (redundant)
              not (current_aggs == next_aggs)
            else
              # Different group - this must be end of our group, skip [NULL] row (redundant)
              false
            end

          _ ->
            # Next row is not at the right level or doesn't exist - skip [NULL] row
            false
        end
      else
        # Not a [NULL] row, always keep
        true
      end
    end)
    |> Enum.map(fn {{level, row, _has_null, _orig_idx}, _current_idx} ->
      {level, row}
    end)
  end

  # Format a value for display
  # With COALESCE, "[NULL]" strings are already in the data and should be displayed as-is
  # ROLLUP NULLs (nil/empty) should also be shown as "[NULL]"
  defp format_value(value) do
    case value do
      nil ->
        "[NULL]"

      # Empty string from ROLLUP NULL
      "" ->
        "[NULL]"

      {display_value, _id} when is_nil(display_value) or display_value == "" ->
        "[NULL]"

      {display_value, _id} ->
        display_value

      tuple when is_tuple(tuple) ->
        elem_val = elem(tuple, 0)
        if is_nil(elem_val) or elem_val == "", do: "[NULL]", else: elem_val

      # Includes "[NULL]" strings from COALESCE
      _ ->
        value
    end
  end

  # Format an aggregate value, applying format function if present
  defp format_aggregate_value(value, coldef) do
    formatted =
      case coldef do
        %{format: fmt_fun} when is_function(fmt_fun) -> fmt_fun.(value)
        _ -> value
      end

    format_value(formatted)
  end

  # Build filter attributes for drill-down from group column values
  # Now includes special handling for NULL values - uses "__NULL__" marker for IS_EMPTY filter
  # Uses indexed phx-value attributes to support multiple filter levels
  defp build_filter_attrs(group_cols, group_by_defs, level) do
    group_cols
    |> Enum.zip(group_by_defs)
    |> Enum.with_index()
    |> Enum.filter(fn {{_value, _def}, idx} ->
      # Include all values (including nil) up to current level
      idx < level
    end)
    |> Enum.reduce(%{}, fn {{value, {_alias, {:group_by, field, coldef}}}, idx}, acc ->
      # Determine the filter field name
      # Check for special join modes (lookup, star, tag) that use ID-based filtering
      filter_field =
        case coldef do
          %{group_by_filter: filter} when not is_nil(filter) ->
            filter

          %{"group_by_filter" => filter} when not is_nil(filter) ->
            filter

          # Special join modes - use the configured ID field for filtering
          %{join_mode: mode, id_field: id_field}
          when mode in [:lookup, :star, :tag] and not is_nil(id_field) ->
            # colid might be nil, so extract table prefix from the field tuple
            table_prefix =
              case field do
                {:row, [display_field | _], _} ->
                  # ROW selector - extract from display field
                  case display_field do
                    {:coalesce, [inner | _]} -> extract_table_prefix(inner)
                    _ -> extract_table_prefix(display_field)
                  end

                {:field, field_ref, _} ->
                  extract_table_prefix(field_ref)

                _ ->
                  nil
              end

            # Build the filter field as "table.id_field"
            if table_prefix do
              "#{table_prefix}.#{id_field}"
            else
              Atom.to_string(id_field)
            end

          # Try with string keys too
          %{"join_mode" => mode, "id_field" => id_field}
          when mode in ["lookup", "star", "tag"] and not is_nil(id_field) ->
            # colid might be nil, so extract table prefix from the field tuple
            table_prefix =
              case field do
                {:row, [display_field | _], _} ->
                  # ROW selector - extract from display field
                  case display_field do
                    {:coalesce, [inner | _]} -> extract_table_prefix(inner)
                    _ -> extract_table_prefix(display_field)
                  end

                {:field, field_ref, _} ->
                  extract_table_prefix(field_ref)

                _ ->
                  nil
              end

            # Build the filter field as "table.id_field"
            if table_prefix do
              "#{table_prefix}.#{id_field}"
            else
              to_string(id_field)
            end

          _ ->
            # Extract field name from field tuple, handling COALESCE wrapper
            case field do
              {:field, {:coalesce, [inner_field | _]}, _} ->
                # Field is wrapped in COALESCE - extract the inner field
                case inner_field do
                  {:to_char, {field_name, _format}} -> Atom.to_string(field_name)
                  field_id when is_atom(field_id) -> Atom.to_string(field_id)
                  field_id when is_binary(field_id) -> field_id
                  _ -> "id"
                end

              {:field, {:to_char, {field_name, _format}}, _} ->
                Atom.to_string(field_name)

              {:field, field_id, _} when is_atom(field_id) ->
                Atom.to_string(field_id)

              {:field, field_id, _} when is_binary(field_id) ->
                field_id

              _ ->
                "id"
            end
        end

      # Extract the actual value (handle tuples and NULL)
      filter_value =
        case value do
          # Special marker for IS_EMPTY filter (ROLLUP NULL)
          nil -> "__NULL__"
          # Empty string from ROLLUP NULL
          "" -> "__NULL__"
          # COALESCE result for data NULL
          "[NULL]" -> "__NULL__"
          # COALESCE result in tuple
          {_display, "[NULL]"} -> "__NULL__"
          {_display, filter_val} when is_nil(filter_val) or filter_val == "" -> "__NULL__"
          {_display, filter_val} -> filter_val
          _ -> value
        end

      # Use indexed phx-value attributes to support multiple group levels
      # phx-value-field0, phx-value-value0, phx-value-field1, phx-value1, etc.
      acc
      |> Map.put("phx-value-field#{idx}", filter_field)
      |> Map.put("phx-value-value#{idx}", to_string(filter_value))
    end)
  end

  # Extract table prefix from a field reference
  # Examples: "category.category_name" -> "category", :category_name -> nil
  defp extract_table_prefix(field_ref) do
    case field_ref do
      field_str when is_binary(field_str) ->
        case String.split(field_str, ".") do
          [table, _field] -> table
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # Render a single row with hierarchy styling
  defp rollup_row(assigns) do
    # Extract group columns and aggregate columns from the row
    group_cols = Enum.take(assigns.row, assigns.num_group_by)
    agg_cols = Enum.drop(assigns.row, assigns.num_group_by)

    # Determine styling based on hierarchy level
    {row_class, font_weight, indent_px} =
      case assigns.level do
        # Grand total
        0 -> {"bg-blue-50 border-t-2 border-blue-300", "font-bold", 0}
        # Level 1 subtotal
        1 -> {"bg-gray-50", "font-semibold", 16}
        # Level 2 (or detail if only 2 levels)
        2 -> {"", "font-normal", 32}
        # Level 3
        3 -> {"", "font-normal", 48}
        # Deeper levels
        _ -> {"", "font-normal", 64}
      end

    # The maximum level is the number of group-by columns
    # If we're at max level, it's a detail row (not a subtotal)
    is_detail = assigns.level == assigns.num_group_by

    # For detail rows, use normal styling
    {row_class, font_weight} =
      if is_detail do
        {"", "font-normal"}
      else
        {row_class, font_weight}
      end

    # Build filter attributes for drill-down (accumulated from all parent levels)
    filter_attrs = build_filter_attrs(group_cols, assigns.group_by, assigns.level)

    assigns =
      assign(assigns,
        group_cols: group_cols,
        agg_cols: agg_cols,
        row_class: row_class,
        font_weight: font_weight,
        indent_px: indent_px,
        filter_attrs: filter_attrs
      )

    ~H"""
    <tr class={@row_class}>
      <%!-- Render group by columns --%>
      <%= for {{value, {_alias, {:group_by, _field, coldef}}}, idx} <- Enum.zip(@group_cols, @group_by) |> Enum.with_index() do %>
        <td class={"px-3 py-2 text-sm text-gray-900 #{@font_weight}"}>
          <div style={"padding-left: #{if idx == 0, do: @indent_px, else: 0}px"}>
            <%= if @level == 0 and idx == 0 do %>
              <%!-- Grand total row --%>
              <span class="text-gray-400 italic">Total</span>
            <% else %>
              <%!-- Show value only for the rightmost filled/unfilled column at this level --%>
              <%!-- For level N, show column at index N-1 (0-indexed) --%>
              <%= if idx == @level - 1 do %>
                <div
                  phx-click="agg_add_filters"
                  {@filter_attrs}
                  class="cursor-pointer hover:underline"
                >
                  {format_value(value)}
                </div>
              <% end %>
            <% end %>
          </div>
        </td>
      <% end %>

      <%!-- Render aggregate columns --%>
      <%= for {value, {_alias, {:agg, _agg, coldef}}} <- Enum.zip(@agg_cols, @aggregate) do %>
        <td class={"px-3 py-2 text-sm text-gray-900 #{@font_weight}"}>
          {format_aggregate_value(value, coldef)}
        </td>
      <% end %>
    </tr>
    """
  end

  @impl true
  def render(assigns) do
    # Check for execution error first
    if Map.get(assigns, :execution_error) do
      # Error is already displayed by the form component wrapper
      # Just show a message that view cannot be rendered
      ~H"""
      <div>
        <div class="text-gray-500 italic p-4">
          View cannot be displayed due to query error. Please check the error message above.
        </div>
      </div>
      """
    else
      # Check if we have valid query results and execution state
      case {assigns[:executed], assigns.query_results} do
        {false, _} ->
          # Query is being executed or hasn't been executed yet
          ~H"""
          <div>
            <div class="text-blue-500 italic p-4">Loading view...</div>
          </div>
          """

        {true, nil} ->
          # Executed but no results - this is an error state
          ~H"""
          <div>
            <div class="text-red-500 p-4">
              <div class="font-semibold">No Results</div>
              <div class="text-sm mt-1">Query executed but returned no results.</div>
            </div>
          </div>
          """

        {true, {results, _fields, aliases}} ->
          # Valid execution with results - proceed with normal rendering

          # Extract the actual selected fields from the selecto configuration
          # Note: assigns.selecto.set.group_by contains ROLLUP config, not actual fields
          # The actual fields are in assigns.selecto.set.selected
          selected_fields = assigns.selecto.set.selected || []

          # Also get the original group_by and aggregates for processing
          rollup_group_by = assigns.selecto.set.group_by || []
          aggregates = assigns.selecto.set.aggregates || []

          # Use the rollup rendering logic instead of simple flat rendering
          render_aggregate_view(
            assigns,
            results,
            aliases,
            selected_fields,
            rollup_group_by,
            aggregates
          )

        _ ->
          # Fallback for unexpected states
          ~H"""
          <div>
            <div class="text-yellow-500 p-4">
              <div class="font-semibold">Unknown State</div>
              <div class="text-sm mt-1">
                Executed: {inspect(assigns[:executed])}<br />
                Query Results: {inspect(assigns.query_results != nil)}
              </div>
            </div>
          </div>
          """
      end
    end
  end

  defp render_aggregate_view(
         assigns,
         results,
         aliases,
         selected_fields,
         rollup_group_by,
         aggregates
       ) do
    # Use the actual selected fields for counting instead of group_by + aggregates
    # because ROLLUP can add extra fields to the query result
    expected_field_count = Enum.count(selected_fields)
    aliases_count = Enum.count(aliases)

    # If still mismatched at render time, check if we should show loading or error state
    if aliases_count != expected_field_count do
      # If we have no query results or they're stale, show loading
      # If executed is false, we're waiting for a new query
      cond do
        not assigns[:executed] ->
          ~H"""
          <div>
            <div class="text-blue-500 italic p-4">Loading view...</div>
          </div>
          """

        assigns.query_results == nil ->
          ~H"""
          <div>
            <div class="text-blue-500 italic p-4">Loading view...</div>
          </div>
          """

        true ->
          # We have results but they don't match - this suggests a configuration issue
          assigns =
            assign(assigns,
              expected_field_count: expected_field_count,
              aliases_count: aliases_count,
              selected_fields_count: Enum.count(selected_fields),
              aggregates_count: Enum.count(aggregates),
              aliases_debug: inspect(aliases)
            )

          ~H"""
          <div>
            <div class="text-red-500 p-4">
              <div class="font-semibold">View Configuration Error</div>
              <div class="text-sm mt-1">
                Expected {@expected_field_count} fields but got {@aliases_count} from query.
                This usually indicates a mismatch between the view configuration and query results.
              </div>
              <details class="mt-2 text-xs">
                <summary class="cursor-pointer">Debug Info</summary>
                <div>Selected Fields: {@selected_fields_count}</div>
                <div>Aggregate Fields: {@aggregates_count}</div>
                <div>Query Aliases: {@aliases_debug}</div>
              </details>
            </div>
          </div>
          """
      end
    else
      render_synchronized_view(
        assigns,
        results,
        aliases,
        selected_fields,
        rollup_group_by,
        aggregates
      )
    end
  end

  defp render_synchronized_view(
         assigns,
         results,
         aliases,
         selected_fields,
         rollup_group_by,
         aggregates
       ) do
    # Process the selected fields to match the aliases
    # The selected fields should match 1:1 with the aliases from the query
    field_mappings = Enum.zip(aliases, selected_fields)

    # Split the mappings back into group_by and aggregate sections
    # We need to determine which selected fields are group by vs aggregates
    # Look at the rollup_group_by to determine how many group by fields we have

    # Count the actual group by fields (not the ROLLUP wrapper)
    num_group_by =
      case rollup_group_by do
        [{:rollup, positions}] when is_list(positions) -> Enum.count(positions)
        _ -> 0
      end

    # num_aggregates = Enum.count(selected_fields) - num_group_by

    group_by_mappings = Enum.take(field_mappings, num_group_by)
    aggregate_mappings = Enum.drop(field_mappings, num_group_by)

    selecto_group_by_config =
      case assigns do
        %{selecto: %{set: set}} when is_map(set) ->
          Map.get(set, :gb_params) || Map.get(set, "gb_params")

        _ ->
          nil
      end

    view_config_group_by =
      case assigns do
        %{view_config: view_config} when is_map(view_config) ->
          Map.get(view_config, :group_by) || Map.get(view_config, "group_by")

        _ ->
          nil
      end

    group_by_config = selecto_group_by_config || view_config_group_by || %{}

    group_by_param_fields =
      group_by_config
      |> Map.values()
      |> Enum.sort(fn a, b ->
        to_index = fn cfg ->
          cfg
          |> Map.get("index", Map.get(cfg, :index, "0"))
          |> to_string()
          |> String.to_integer()
        end

        to_index.(a) <= to_index.(b)
      end)
      |> Enum.map(fn cfg -> Map.get(cfg, "field") || Map.get(cfg, :field) end)

    # Convert to the format expected by the template
    group_by =
      group_by_mappings
      |> Enum.with_index()
      |> Enum.map(fn {{alias, field}, idx} ->
        # Get the proper column definition from selecto
        # Now that Selecto.field returns full definitions, we get all properties
        coldef =
          case field do
            {:field, {:to_char, {field_name, _format}}, _alias} ->
              # Handle formatted date fields
              Selecto.field(assigns.selecto, field_name) || %{name: alias, format: nil}

            {:field, field_id, _alias} when is_binary(field_id) or is_atom(field_id) ->
              # Selecto.field now returns full custom column definitions with group_by_filter
              result = Selecto.field(assigns.selecto, field_id)

              if result == nil do
                # Field not found - use basic definition
                %{name: alias, format: nil}
              else
                result
              end

            {:field, {_extract_type, field_id, _format}, _alias} ->
              # Handle extracted fields (e.g., date parts)
              Selecto.field(assigns.selecto, field_id) || %{name: alias}

            {:row, [display_field | _rest], _alias} ->
              # For row selectors (e.g., join mode columns), look up the actual column definition
              # display_field might be wrapped in COALESCE - extract the original field name
              field_name =
                case display_field do
                  {:coalesce, [inner_field | _]} -> inner_field
                  other -> other
                end

              # Look up metadata from domain.schemas for joined fields
              result =
                if is_binary(field_name) && String.contains?(field_name, ".") do
                  [schema_name, field_only] = String.split(field_name, ".", parts: 2)

                  # Look up from domain.schemas[schema].columns[field]
                  domain = Selecto.domain(assigns.selecto)

                  schema_atom =
                    try do
                      String.to_existing_atom(schema_name)
                    rescue
                      ArgumentError -> nil
                    end

                  field_atom =
                    try do
                      String.to_existing_atom(field_only)
                    rescue
                      ArgumentError -> nil
                    end

                  if schema_atom && field_atom do
                    get_in(domain, [:schemas, schema_atom, :columns, field_atom])
                  else
                    nil
                  end
                else
                  Selecto.field(assigns.selecto, field_name)
                end

              if result == nil do
                # Field not found - use basic definition
                %{name: alias, format: nil}
              else
                result
              end

            _ ->
              # Fallback to basic definition
              %{name: alias, format: nil}
          end

        coldef = maybe_set_group_by_filter(coldef, Enum.at(group_by_param_fields, idx))
        {alias, {:group_by, field, coldef}}
      end)

    aggregates_processed =
      Enum.zip(aggregate_mappings, aggregates)
      |> Enum.map(fn {{alias, _field}, agg} ->
        # Get the proper column definition from selecto
        coldef =
          case agg do
            {:field, {_func, field_id}, _alias} when is_atom(field_id) ->
              Selecto.field(assigns.selecto, field_id)

            {:field, field_id, _alias} when is_atom(field_id) ->
              Selecto.field(assigns.selecto, field_id)

            _ ->
              # Fallback to empty map for unknown aggregate types
              %{}
          end

        {alias, {:agg, agg, coldef}}
      end)

    # Prepare rollup rows with hierarchy level metadata
    num_group_by = length(group_by)
    rollup_rows = prepare_rollup_rows(results, num_group_by)

    total_rows = length(rollup_rows)

    per_page_setting =
      assigns
      |> Map.get(:view_meta, %{})
      |> Map.get(:per_page, @default_aggregate_per_page)
      |> normalize_aggregate_per_page()

    per_page = aggregate_per_page_to_int(per_page_setting, total_rows)

    max_page =
      if total_rows > 0 and per_page > 0 do
        div(total_rows - 1, per_page)
      else
        0
      end

    current_page =
      assigns
      |> Map.get(:aggregate_page, 0)
      |> normalize_page()
      |> min(max_page)

    row_offset = current_page * per_page

    page_start =
      if total_rows > 0 do
        row_offset + 1
      else
        0
      end

    page_end =
      if total_rows > 0 do
        min(row_offset + per_page, total_rows)
      else
        0
      end

    paged_rollup_rows =
      if per_page_setting == "all" do
        rollup_rows
      else
        Enum.slice(rollup_rows, row_offset, per_page)
      end

    total_pages = if total_rows > 0, do: max_page + 1, else: 0

    assigns =
      assign(assigns,
        rollup_rows: rollup_rows,
        paged_rollup_rows: paged_rollup_rows,
        num_group_by: num_group_by,
        group_by: group_by,
        aggregate: aggregates_processed,
        aggregate_total_rows: total_rows,
        aggregate_page: current_page,
        aggregate_max_page: max_page,
        aggregate_total_pages: total_pages,
        aggregate_page_start: page_start,
        aggregate_page_end: page_end
      )

    ~H"""
    <div>
      <div class="mb-3 flex flex-wrap items-center justify-between gap-3 rounded-lg border border-gray-200 bg-gradient-to-r from-gray-50 to-white px-3 py-2">
        <div class="inline-flex items-center gap-1 rounded-md border border-gray-200 bg-white p-1 shadow-sm">
          <button
            type="button"
            phx-click="set_aggregate_page"
            phx-value-page={0}
            phx-target={@myself}
            class="inline-flex h-8 w-8 items-center justify-center rounded border border-gray-200 text-gray-600 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
            title="First page"
            aria-label="First page"
            disabled={@aggregate_page <= 0}
          >
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M18 18L12 12l6-6M10 18 4 12l6-6M4 6v12"
              />
            </svg>
          </button>

          <button
            type="button"
            phx-click="set_aggregate_page"
            phx-value-page={@aggregate_page - 1}
            phx-target={@myself}
            class="inline-flex h-8 items-center gap-1 rounded border border-gray-200 px-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
            title="Previous page"
            aria-label="Previous page"
            disabled={@aggregate_page <= 0}
          >
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="m15 18-6-6 6-6" />
            </svg>
            Prev
          </button>

          <button
            type="button"
            phx-click="set_aggregate_page"
            phx-value-page={@aggregate_page + 1}
            phx-target={@myself}
            class="inline-flex h-8 items-center gap-1 rounded border border-gray-200 px-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
            title="Next page"
            aria-label="Next page"
            disabled={@aggregate_page >= @aggregate_max_page}
          >
            Next
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="m9 6 6 6-6 6" />
            </svg>
          </button>

          <button
            type="button"
            phx-click="set_aggregate_page"
            phx-value-page={@aggregate_max_page}
            phx-target={@myself}
            class="inline-flex h-8 w-8 items-center justify-center rounded border border-gray-200 text-gray-600 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
            title="Last page"
            aria-label="Last page"
            disabled={@aggregate_page >= @aggregate_max_page}
          >
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M6 18l6-6-6-6m8 12 6-6-6-6m6 0v12"
              />
            </svg>
          </button>
        </div>

        <div class="text-sm font-medium text-gray-700">
          <span class="font-semibold tabular-nums">
            {@aggregate_page_start}-{@aggregate_page_end}
          </span>
          of <span class="font-semibold tabular-nums">{@aggregate_total_rows}</span>
          rows
        </div>

        <div class="text-xs text-gray-500 tabular-nums">
          Page
          <span class="font-semibold">
            {if @aggregate_total_pages > 0, do: @aggregate_page + 1, else: 0}
          </span>
          of <span class="font-semibold">{@aggregate_total_pages}</span>
        </div>
      </div>

      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200 divide-gray-200 rounded-sm table-auto sm:rounded">
        <thead class="bg-gray-50">
          <tr>
            <%!-- Headers for group by columns --%>
            <%= for {alias, {:group_by, _field, _coldef}} <- @group_by do %>
              <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                {alias}
              </th>
            <% end %>

            <%!-- Headers for aggregate columns --%>
            <%= for {alias, {:agg, _agg, _coldef}} <- @aggregate do %>
              <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                {alias}
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200 bg-white">
          <.rollup_row
            :for={{level, row} <- @paged_rollup_rows}
            level={level}
            row={row}
            num_group_by={@num_group_by}
            group_by={@group_by}
            aggregate={@aggregate}
          />
        </tbody>
      </table>
    </div>
    """
  end

  defp maybe_set_group_by_filter(coldef, field_name)
       when is_map(coldef) and is_binary(field_name) and field_name != "" do
    coldef
    |> Map.put_new(:group_by_filter, field_name)
    |> Map.put_new("group_by_filter", field_name)
  end

  defp maybe_set_group_by_filter(coldef, _), do: coldef

  @impl true
  def handle_event("set_aggregate_page", %{"page" => page_param}, socket) do
    page =
      page_param
      |> parse_page_param()
      |> normalize_page()
      |> clamp_aggregate_page_if_known(socket.assigns)

    {:noreply, assign(socket, :aggregate_page, page)}
  end

  defp normalize_aggregate_per_page(per_page) when is_integer(per_page),
    do: normalize_aggregate_per_page(to_string(per_page))

  defp normalize_aggregate_per_page(per_page) when is_binary(per_page) do
    normalized = String.downcase(String.trim(per_page))

    if normalized in Enum.map(@aggregate_per_page_options, &to_string/1) do
      normalized
    else
      @default_aggregate_per_page
    end
  end

  defp normalize_aggregate_per_page(_), do: @default_aggregate_per_page

  defp aggregate_per_page_to_int("all", total_rows), do: max(total_rows, 1)

  defp aggregate_per_page_to_int(per_page, _total_rows) when is_binary(per_page) do
    case Integer.parse(per_page) do
      {value, ""} when value > 0 -> value
      _ -> String.to_integer(@default_aggregate_per_page)
    end
  end

  defp aggregate_per_page_to_int(_per_page, _total_rows),
    do: String.to_integer(@default_aggregate_per_page)

  defp parse_page_param(page_param) when is_binary(page_param) do
    case Integer.parse(page_param) do
      {page, ""} -> page
      _ -> 0
    end
  end

  defp parse_page_param(page_param) when is_integer(page_param), do: page_param
  defp parse_page_param(_page_param), do: 0

  defp normalize_page(page) when is_integer(page), do: max(page, 0)
  defp normalize_page(_page), do: 0

  defp clamp_aggregate_page_if_known(page, assigns) do
    case Map.get(assigns, :aggregate_max_page) do
      max_page when is_integer(max_page) and max_page >= 0 -> min(page, max_page)
      _ -> page
    end
  end
end
