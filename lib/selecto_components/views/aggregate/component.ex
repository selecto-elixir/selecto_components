defmodule SelectoComponents.Views.Aggregate.Component do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent
  alias SelectoComponents.Views.Aggregate.Options

  @grid_palette [
    "#eafcff",
    "#d7f8fc",
    "#c6f2f8",
    "#bdeff0",
    "#f8efe9",
    "#f8e2d8",
    "#f8d3c4",
    "#f6c1b1",
    "#f4ab9a",
    "#f1988b"
  ]

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       aggregate_page: 0,
       aggregate_page_loading?: false,
       aggregate_requested_page: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    previous_exe_id = get_in(socket.assigns, [:view_meta, :exe_id])
    incoming_exe_id = get_in(assigns, [:view_meta, :exe_id])
    incoming_server_paged? = get_in(assigns, [:view_meta, :aggregate_server_paged?]) == true

    incoming_page =
      assigns
      |> Map.get(:aggregate_page, get_in(assigns, [:view_meta, :aggregate_page]))
      |> normalize_page()

    aggregate_page =
      if previous_exe_id && incoming_exe_id && previous_exe_id != incoming_exe_id do
        incoming_page
      else
        Map.get(socket.assigns, :aggregate_page, incoming_page)
      end

    # Force a complete re-assignment to ensure LiveView recognizes data changes
    socket = assign(socket, assigns)

    # Add a timestamp to force re-rendering if data changed
    socket =
      assign(socket,
        aggregate_page: aggregate_page,
        aggregate_server_paged?: incoming_server_paged?,
        aggregate_page_loading?: false,
        aggregate_requested_page: nil,
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
  # Filter out redundant [NULL] rows that are identical to their rollup subtotal.
  # Also mark which level-0 row is the true grand total so data NULL groups
  # can still render as clickable [NULL] buckets.
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
    filtered_rows =
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
      grand_total? = idx == last_level0_idx
      {level, row, grand_total?}
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

      {coefficient, scale} when is_integer(coefficient) and is_integer(scale) and scale >= 0 ->
        format_decimal_tuple(coefficient, scale)

      {display_value, _id} when is_nil(display_value) or display_value == "" ->
        "[NULL]"

      {display_value, _id} ->
        safe_cell_value(display_value)

      tuple when is_tuple(tuple) ->
        elem_val = elem(tuple, 0)
        if is_nil(elem_val) or elem_val == "", do: "[NULL]", else: safe_cell_value(elem_val)

      # Includes "[NULL]" strings from COALESCE
      _ ->
        safe_cell_value(value)
    end
  end

  defp safe_cell_value(value) do
    case value do
      nil ->
        ""

      {coefficient, scale}
      when is_integer(coefficient) and is_integer(scale) and scale >= 0 ->
        format_decimal_tuple(coefficient, scale)

      value when is_tuple(value) ->
        inspect(value)

      value when is_atom(value) ->
        Atom.to_string(value)

      _ ->
        if Phoenix.HTML.Safe.impl_for(value) do
          value
        else
          inspect(value)
        end
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

  defp format_decimal_tuple(coefficient, 0), do: Integer.to_string(coefficient)

  defp format_decimal_tuple(coefficient, scale) when coefficient < 0 do
    "-" <> format_decimal_tuple(abs(coefficient), scale)
  end

  defp format_decimal_tuple(coefficient, scale) do
    digits = Integer.to_string(coefficient)

    if String.length(digits) <= scale do
      "0." <> String.duplicate("0", scale - String.length(digits)) <> digits
    else
      split_at = String.length(digits) - scale
      {whole, fractional} = String.split_at(digits, split_at)
      whole <> "." <> fractional
    end
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
      |> Map.put("phx-value-gidx#{idx}", to_string(idx))
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
    continued? = Map.get(assigns, :continued?, false)
    grand_total? = Map.get(assigns, :grand_total?, false)

    display_level =
      if assigns.level == 0 and not grand_total? and assigns.num_group_by > 0 do
        1
      else
        assigns.level
      end

    # Extract group columns and aggregate columns from the row
    group_cols = Enum.take(assigns.row, assigns.num_group_by)
    agg_cols = Enum.drop(assigns.row, assigns.num_group_by)

    # Determine styling based on hierarchy level
    {row_class, font_weight, indent_px} =
      case display_level do
        # Grand total
        0 ->
          {"bg-blue-50 border-t-2 border-blue-300 dark:bg-blue-950/40 dark:border-blue-700",
           "font-bold", 0}

        # Level 1 subtotal
        1 ->
          {"bg-gray-50 dark:bg-gray-800/70", "font-semibold", 16}

        # Level 2 (or detail if only 2 levels)
        2 ->
          {"", "font-normal", 32}

        # Level 3
        3 ->
          {"", "font-normal", 48}

        # Deeper levels
        _ ->
          {"", "font-normal", 64}
      end

    # The maximum level is the number of group-by columns
    # If we're at max level, it's a detail row (not a subtotal)
    is_detail = display_level == assigns.num_group_by

    # For detail rows, use normal styling unless row is a continuation marker
    {row_class, font_weight} =
      cond do
        continued? ->
          {"bg-amber-50 border-t border-amber-200 dark:bg-amber-950/30 dark:border-amber-800",
           "font-semibold italic"}

        is_detail ->
          {"", "font-normal"}

        true ->
          {row_class, font_weight}
      end

    # Build filter attributes for drill-down (accumulated from all parent levels)
    filter_attrs = build_filter_attrs(group_cols, assigns.group_by, display_level)

    assigns =
      assign(assigns,
        group_cols: group_cols,
        agg_cols: agg_cols,
        row_class: row_class,
        font_weight: font_weight,
        indent_px: indent_px,
        filter_attrs: filter_attrs,
        continued?: continued?,
        display_level: display_level,
        grand_total?: grand_total?
      )

    ~H"""
    <tr class={@row_class}>
      <%!-- Render group by columns --%>
      <%= for {{value, {_alias, {:group_by, _field, coldef}}}, idx} <- Enum.zip(@group_cols, @group_by) |> Enum.with_index() do %>
        <td class={"px-3 py-2 text-sm text-gray-900 dark:text-gray-100 #{@font_weight}"}>
          <div style={"padding-left: #{if idx == 0, do: @indent_px, else: 0}px"}>
            <%= if @grand_total? and @display_level == 0 and idx == 0 do %>
              <%!-- Grand total row --%>
              <span class="text-gray-400 italic dark:text-gray-500">Total</span>
            <% else %>
              <%!-- Show value only for the rightmost filled/unfilled column at this level --%>
              <%!-- For level N, show column at index N-1 (0-indexed) --%>
              <%= if idx == @display_level - 1 do %>
                <%= if @continued? do %>
                  <span class="text-amber-900 dark:text-amber-200">
                    {format_group_value(value, coldef)} (continued)
                  </span>
                <% else %>
                  <div
                    phx-click="agg_add_filters"
                    {@filter_attrs}
                    class="cursor-pointer hover:underline"
                  >
                    {format_group_value(value, coldef)}
                  </div>
                <% end %>
              <% end %>
            <% end %>
          </div>
        </td>
      <% end %>

      <%!-- Render aggregate columns --%>
      <%= for {value, {_alias, {:agg, _agg, coldef}}} <- Enum.zip(@agg_cols, @aggregate) do %>
        <td class={"px-3 py-2 text-sm text-gray-900 dark:text-gray-100 #{@font_weight}"}>
          <%= if @continued? do %>
            <span class="text-amber-700 dark:text-amber-300">-</span>
          <% else %>
            {format_aggregate_value(value, coldef)}
          <% end %>
        </td>
      <% end %>
    </tr>
    """
  end

  defp prepend_continued_group_headers(rows, num_group_by, aggregate_count, row_offset)
       when is_list(rows) do
    rendered_rows =
      Enum.map(rows, fn {level, row, grand_total?} -> {level, row, false, grand_total?} end)

    if row_offset > 0 do
      case rows do
        [{level, row, _grand_total?} | _] when level > 1 ->
          group_cols = Enum.take(row, num_group_by)

          continued_rows =
            1..(level - 1)
            |> Enum.map(fn parent_level ->
              parent_group_cols =
                Enum.take(group_cols, parent_level) ++
                  List.duplicate(nil, max(num_group_by - parent_level, 0))

              parent_agg_cols = List.duplicate(nil, aggregate_count)

              {parent_level, parent_group_cols ++ parent_agg_cols, true, false}
            end)

          continued_rows ++ rendered_rows

        _ ->
          rendered_rows
      end
    else
      rendered_rows
    end
  end

  defp prepend_continued_group_headers(rows, _num_group_by, _aggregate_count, _row_offset),
    do: rows

  @impl true
  def render(assigns) do
    # Check for execution error first
    if Map.get(assigns, :execution_error) do
      # Error is already displayed by the form component wrapper
      # Just show a message that view cannot be rendered
      ~H"""
      <div>
        <div class="p-4 italic text-gray-500 dark:text-gray-400">
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
            <div class="p-4 italic text-blue-500 dark:text-blue-300">Loading view...</div>
          </div>
          """

        {true, nil} ->
          # Executed but no results - this is an error state
          ~H"""
          <div>
            <div class="p-4 text-red-500 dark:text-red-300">
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
          selected_fields = Map.get(assigns.selecto.set, :selected, []) || []

          # Also get the original group_by and aggregates for processing
          rollup_group_by = Map.get(assigns.selecto.set, :group_by, []) || []
          aggregates = Map.get(assigns.selecto.set, :aggregates, []) || []

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
            <div class="p-4 text-yellow-500 dark:text-yellow-300">
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
            <div class="p-4 italic text-blue-500 dark:text-blue-300">Loading view...</div>
          </div>
          """

        assigns.query_results == nil ->
          ~H"""
          <div>
            <div class="p-4 italic text-blue-500 dark:text-blue-300">Loading view...</div>
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

    group_by_param_configs =
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

    group_by_param_fields =
      Enum.map(group_by_param_configs, fn cfg -> Map.get(cfg, "field") || Map.get(cfg, :field) end)

    # Convert to the format expected by the template
    group_by =
      group_by_mappings
      |> Enum.with_index()
      |> Enum.map(fn {{query_alias, field}, idx} ->
        display_alias = selected_field_alias(field, query_alias)

        # Get the proper column definition from selecto
        # Now that Selecto.field returns full definitions, we get all properties
        coldef =
          case field do
            {:field, {:to_char, {field_name, _format}}, _alias} ->
              # Handle formatted date fields
              Selecto.field(assigns.selecto, field_name) || %{name: display_alias, format: nil}

            {:field, field_id, _alias} when is_binary(field_id) or is_atom(field_id) ->
              # Selecto.field now returns full custom column definitions with group_by_filter
              result = Selecto.field(assigns.selecto, field_id)

              if result == nil do
                # Field not found - use basic definition
                %{name: display_alias, format: nil}
              else
                result
              end

            {:field, {_extract_type, field_id, _format}, _alias} ->
              # Handle extracted fields (e.g., date parts)
              Selecto.field(assigns.selecto, field_id) || %{name: display_alias}

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
                %{name: display_alias, format: nil}
              else
                result
              end

            _ ->
              # Fallback to basic definition
              %{name: display_alias, format: nil}
          end

        coldef = maybe_set_group_by_filter(coldef, Enum.at(group_by_param_fields, idx))
        coldef = maybe_set_group_by_format(coldef, Enum.at(group_by_param_configs, idx))
        {display_alias, {:group_by, field, coldef}}
      end)

    aggregates_processed =
      Enum.zip(aggregate_mappings, aggregates)
      |> Enum.map(fn {{query_alias, selected_field}, agg} ->
        display_alias = selected_field_alias(selected_field, query_alias)

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

        {display_alias, {:agg, agg, coldef}}
      end)

    # Prepare rollup rows with hierarchy level metadata
    num_group_by = length(group_by)
    rollup_rows = prepare_rollup_rows(results, num_group_by)

    page_row_count = length(rollup_rows)
    aggregate_meta = Map.get(assigns, :view_meta, %{})
    server_paged? = Map.get(aggregate_meta, :aggregate_server_paged?, false)

    total_rows_before_cap =
      Map.get(aggregate_meta, :aggregate_total_rows_before_cap, page_row_count)

    rows_capped? = Map.get(aggregate_meta, :aggregate_rows_capped?, false)

    max_client_rows =
      Map.get(aggregate_meta, :aggregate_max_client_rows, Options.default_max_client_rows())

    per_page_setting =
      assigns
      |> Map.get(:view_meta, %{})
      |> Map.get(:per_page, Options.default_per_page())
      |> Options.normalize_per_page_param()

    per_page = Options.per_page_to_int(per_page_setting, page_row_count)

    {paged_rollup_rows, aggregate_total_rows, current_page, max_page, page_start, page_end,
     row_offset} =
      if server_paged? do
        total_rows =
          max(Map.get(aggregate_meta, :aggregate_total_rows, page_row_count), page_row_count)

        max_page =
          if total_rows > 0 and per_page > 0 do
            div(total_rows - 1, per_page)
          else
            0
          end

        current_page =
          aggregate_meta
          |> Map.get(:aggregate_page, Map.get(assigns, :aggregate_page, 0))
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
            min(row_offset + page_row_count, total_rows)
          else
            0
          end

        {rollup_rows, total_rows, current_page, max_page, page_start, page_end, row_offset}
      else
        max_page =
          if page_row_count > 0 and per_page > 0 do
            div(page_row_count - 1, per_page)
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
          if page_row_count > 0 do
            row_offset + 1
          else
            0
          end

        page_end =
          if page_row_count > 0 do
            min(row_offset + per_page, page_row_count)
          else
            0
          end

        paged_rows =
          if per_page_setting == "all" do
            rollup_rows
          else
            Enum.slice(rollup_rows, row_offset, per_page)
          end

        {paged_rows, page_row_count, current_page, max_page, page_start, page_end, row_offset}
      end

    paged_rollup_rows =
      prepend_continued_group_headers(
        paged_rollup_rows,
        num_group_by,
        length(aggregates_processed),
        row_offset
      )

    total_pages = if aggregate_total_rows > 0, do: max_page + 1, else: 0

    grid_enabled = truthy?(Map.get(aggregate_meta, :grid_enabled, false))
    grid_available? = grid_enabled and num_group_by == 2 and length(aggregates_processed) == 1
    grid_colorize = truthy?(Map.get(aggregate_meta, :grid_colorize, false))

    grid_color_scale =
      aggregate_meta
      |> Map.get(:grid_color_scale, Options.default_grid_color_scale_mode())
      |> Options.normalize_grid_color_scale_mode()

    grid_data =
      if grid_available?,
        do:
          build_grid_data(
            rollup_rows,
            num_group_by,
            group_by,
            grid_colorize,
            grid_color_scale
          ),
        else: nil

    assigns =
      assign(assigns,
        rollup_rows: rollup_rows,
        paged_rollup_rows: paged_rollup_rows,
        num_group_by: num_group_by,
        group_by: group_by,
        aggregate: aggregates_processed,
        aggregate_server_paged?: server_paged?,
        aggregate_total_rows: aggregate_total_rows,
        aggregate_total_rows_before_cap: total_rows_before_cap,
        aggregate_rows_capped?: rows_capped?,
        aggregate_max_client_rows: max_client_rows,
        aggregate_page: current_page,
        aggregate_max_page: max_page,
        aggregate_total_pages: total_pages,
        aggregate_page_start: page_start,
        aggregate_page_end: page_end,
        grid_enabled: grid_enabled,
        grid_colorize: grid_colorize,
        grid_color_scale: grid_color_scale,
        grid_available?: grid_available?,
        grid_data: grid_data,
        grid_legend_colors: @grid_palette
      )

    ~H"""
    <div>
      <div
        :if={!@grid_available?}
        class="mb-3 flex flex-wrap items-center justify-between gap-3 rounded-lg border border-gray-200 bg-gradient-to-r from-gray-50 to-white px-3 py-2 dark:border-gray-700 dark:from-gray-900 dark:to-gray-800"
      >
        <div class="inline-flex items-center gap-1 rounded-md border border-gray-200 bg-white p-1 shadow-sm dark:border-gray-700 dark:bg-gray-900">
          <button
            type="button"
            phx-click="set_aggregate_page"
            phx-value-page={0}
            phx-target={@myself}
            class="inline-flex h-8 w-8 items-center justify-center rounded border border-gray-200 text-gray-600 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800 dark:disabled:hover:bg-gray-900"
            title="First page"
            aria-label="First page"
            disabled={@aggregate_page <= 0 or @aggregate_page_loading?}
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
            class="inline-flex h-8 items-center gap-1 rounded border border-gray-200 px-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800 dark:disabled:hover:bg-gray-900"
            title="Previous page"
            aria-label="Previous page"
            disabled={@aggregate_page <= 0 or @aggregate_page_loading?}
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
            class="inline-flex h-8 items-center gap-1 rounded border border-gray-200 px-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800 dark:disabled:hover:bg-gray-900"
            title="Next page"
            aria-label="Next page"
            disabled={@aggregate_page >= @aggregate_max_page or @aggregate_page_loading?}
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
            class="inline-flex h-8 w-8 items-center justify-center rounded border border-gray-200 text-gray-600 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800 dark:disabled:hover:bg-gray-900"
            title="Last page"
            aria-label="Last page"
            disabled={@aggregate_page >= @aggregate_max_page or @aggregate_page_loading?}
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

        <div class="text-sm font-medium text-gray-700 dark:text-gray-200">
          <span class="font-semibold tabular-nums">
            {@aggregate_page_start}-{@aggregate_page_end}
          </span>
          of <span class="font-semibold tabular-nums">{@aggregate_total_rows}</span>
          rows
        </div>

        <div class="text-xs text-gray-500 tabular-nums dark:text-gray-400">
          Page
          <span class="font-semibold">
            {if @aggregate_total_pages > 0, do: @aggregate_page + 1, else: 0}
          </span>
          of <span class="font-semibold">{@aggregate_total_pages}</span>
          <span :if={@aggregate_page_loading?} class="ml-2 text-blue-600 dark:text-blue-300">
            Loading...
          </span>
        </div>
      </div>

      <div
        :if={@aggregate_rows_capped?}
        class="mb-3 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950/30 dark:text-amber-100"
      >
        Showing the first <span class="font-semibold tabular-nums">{@aggregate_total_rows}</span>
        rows out of <span class="font-semibold tabular-nums">{@aggregate_total_rows_before_cap}</span>
        to keep rendering responsive. Narrow filters/grouping, or increase
        <code class="rounded bg-amber-100 px-1 py-0.5 dark:bg-amber-900/40">
          :aggregate_max_client_rows
        </code>
        (currently <span class="font-semibold">{inspect(@aggregate_max_client_rows)}</span>)
        if you need to render more rows at once.
      </div>

      <div
        :if={@grid_enabled and not @grid_available?}
        class="mb-3 rounded-md border border-blue-200 bg-blue-50 px-3 py-2 text-sm text-blue-900 dark:border-blue-800 dark:bg-blue-950/30 dark:text-blue-100"
      >
        Grid view requires exactly 2 Group By fields and 1 Aggregate.
      </div>

      <%= if @grid_available? and @grid_data do %>
        <div class="mb-2 flex flex-wrap items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
          <span class="font-medium">Aggregate Grid</span>
          <span
            :if={@grid_colorize}
            class="rounded-full border border-cyan-200 bg-white px-2 py-0.5 text-xs font-medium text-gray-600 dark:border-cyan-900 dark:bg-gray-900 dark:text-gray-300"
          >
            {String.capitalize(@grid_color_scale)} color scale
          </span>
        </div>
        <div
          :if={@grid_colorize}
          class="mb-3 flex flex-wrap items-center gap-2 rounded-md border border-cyan-100 bg-cyan-50/60 px-3 py-2 text-xs text-gray-700 dark:border-cyan-900/60 dark:bg-cyan-950/20 dark:text-gray-200"
        >
          <span class="font-medium">Color legend</span>
          <span>Low</span>
          <div class="flex items-center gap-1" aria-label="Grid color legend">
            <span
              :for={color <- @grid_legend_colors}
              class="h-3 w-5 rounded-sm border border-gray-200 dark:border-gray-700"
              style={"background-color: #{color};"}
            />
          </div>
          <span>High</span>
        </div>
        <div class="mb-1 overflow-x-auto overflow-y-auto rounded-sm ring-1 ring-gray-200 dark:ring-gray-700 max-h-[70vh]">
          <table class="min-w-full divide-y divide-gray-200 table-auto dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-800/80">
              <tr>
                <th class="sticky left-0 top-0 z-30 bg-gray-50 px-3 py-3.5 text-left text-sm font-semibold text-gray-900 shadow-[1px_0_0_0_rgba(229,231,235,1)] dark:bg-gray-800 dark:text-gray-100 dark:shadow-[1px_0_0_0_rgba(55,65,81,1)]">
                  {@grid_data.row_alias}
                </th>
                <%= for col_value <- @grid_data.col_headers do %>
                  <th class="sticky top-0 z-20 bg-gray-50 px-3 py-3.5 text-left text-sm font-semibold text-gray-900 dark:bg-gray-800 dark:text-gray-100">
                    <span class={null_grid_text_class(format_group_value(col_value, @grid_data.col_coldef))}>
                      {format_group_value(col_value, @grid_data.col_coldef)}
                    </span>
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-900">
              <tr :for={row_value <- @grid_data.row_headers}>
                <td class="sticky left-0 z-10 bg-white px-3 py-2 text-sm font-semibold text-gray-800 shadow-[1px_0_0_0_rgba(229,231,235,1)] dark:bg-gray-900 dark:text-gray-100 dark:shadow-[1px_0_0_0_rgba(55,65,81,1)]">
                  <span class={null_grid_text_class(format_group_value(row_value, @grid_data.row_coldef))}>
                    {format_group_value(row_value, @grid_data.row_coldef)}
                  </span>
                </td>
                <td
                  :for={col_value <- @grid_data.col_headers}
                  class="px-3 py-2 text-sm text-gray-900 dark:text-gray-100"
                  style={Map.get(@grid_data.cell_styles, {row_value, col_value}, "background-color: #ffffff; color: #111827;")}
                >
                  <div
                    phx-click="agg_add_filters"
                    {build_filter_attrs([row_value, col_value], @group_by, 2)}
                    class="cursor-pointer whitespace-nowrap hover:underline"
                  >
                    <span class={null_grid_text_class(format_value(Map.get(@grid_data.cells, {row_value, col_value})))}>
                      {format_value(Map.get(@grid_data.cells, {row_value, col_value}))}
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% else %>
        <table class="min-w-full overflow-hidden divide-y divide-gray-200 rounded-sm table-auto ring-1 ring-gray-200 dark:divide-gray-700 dark:ring-gray-700 sm:rounded">
          <thead class="bg-gray-50 dark:bg-gray-800/80">
            <tr>
              <%!-- Headers for group by columns --%>
              <%= for {alias, {:group_by, _field, _coldef}} <- @group_by do %>
                <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900 dark:text-gray-100">
                  {alias}
                </th>
              <% end %>

              <%!-- Headers for aggregate columns --%>
              <%= for {alias, {:agg, _agg, _coldef}} <- @aggregate do %>
                <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900 dark:text-gray-100">
                  {alias}
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-900">
            <.rollup_row
              :for={{level, row, continued?, grand_total?} <- @paged_rollup_rows}
              level={level}
              row={row}
              continued?={continued?}
              grand_total?={grand_total?}
              num_group_by={@num_group_by}
              group_by={@group_by}
              aggregate={@aggregate}
            />
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false

  defp build_grid_data(paged_rollup_rows, num_group_by, group_by, colorize?, scale_mode) do
    detail_rows =
      Enum.reduce(paged_rollup_rows, [], fn
        {level, row, grand_total?}, acc when level == num_group_by ->
          if grand_total? do
            acc
          else
            [row | acc]
          end

        {level, row, continued?, grand_total?}, acc when level == num_group_by ->
          if continued? or grand_total? do
            acc
          else
            [row | acc]
          end

        _other, acc ->
          acc
      end)
      |> Enum.reverse()

    {row_headers, col_headers, cells} =
      Enum.reduce(detail_rows, {[], [], %{}}, fn row, {row_acc, col_acc, cells_acc} ->
        row_value = Enum.at(row, 0)
        col_value = Enum.at(row, 1)
        agg_value = Enum.at(row, 2)

        row_acc = if row_value in row_acc, do: row_acc, else: row_acc ++ [row_value]
        col_acc = if col_value in col_acc, do: col_acc, else: col_acc ++ [col_value]
        cells_acc = Map.put(cells_acc, {row_value, col_value}, agg_value)

        {row_acc, col_acc, cells_acc}
      end)

    row_coldef = grid_coldef(group_by, 0)
    col_coldef = grid_coldef(group_by, 1)

    row_headers = sort_group_values(row_headers, row_coldef)
    col_headers = sort_group_values(col_headers, col_coldef)
    cell_styles = build_grid_cell_styles(cells, colorize?, scale_mode)

    %{
      row_alias: grid_row_alias(group_by),
      row_headers: row_headers,
      col_headers: col_headers,
      cells: cells,
      cell_styles: cell_styles,
      row_coldef: row_coldef,
      col_coldef: col_coldef
    }
  end

  defp build_grid_cell_styles(cells, false, _scale_mode) when is_map(cells) do
    Enum.into(cells, %{}, fn {key, _value} ->
      {key, "background-color: #ffffff; color: #111827;"}
    end)
  end

  defp build_grid_cell_styles(cells, true, scale_mode) when is_map(cells) do
    max_positive_value =
      cells
      |> Map.values()
      |> Enum.reduce(nil, fn value, acc ->
        case numeric_value(value) do
          num when is_number(num) and num > 0 -> if(is_nil(acc), do: num, else: max(acc, num))
          _ -> acc
        end
      end)

    Enum.into(cells, %{}, fn {key, value} ->
      {key, grid_cell_style(value, max_positive_value, scale_mode)}
    end)
  end

  defp grid_cell_style(value, max_positive_value, scale_mode) do
    case grid_palette_color(value, max_positive_value, scale_mode) do
      nil -> "background-color: #ffffff; color: #111827;"
      color -> "background-color: #{color}; color: #111827;"
    end
  end

  defp grid_palette_color(_value, nil, _scale_mode), do: nil

  defp grid_palette_color(value, max_positive_value, scale_mode) do
    with num when is_number(num) <- numeric_value(value),
         true <- num > 0,
         true <- max_positive_value > 0 do
      ratio =
        case Options.normalize_grid_color_scale_mode(scale_mode) do
          "log" -> :math.log(num + 1) / :math.log(max_positive_value + 1)
          _ -> num / max_positive_value
        end

      palette_index =
        ratio
        |> Kernel.*(length(@grid_palette))
        |> Float.ceil()
        |> trunc()
        |> min(length(@grid_palette))
        |> max(1)

      Enum.at(@grid_palette, palette_index - 1)
    else
      _ -> nil
    end
  end

  defp numeric_value(value) when is_integer(value), do: value
  defp numeric_value(value) when is_float(value), do: value

  defp numeric_value(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp numeric_value(_value), do: nil

  defp grid_row_alias([{alias_name, _} | _]) when is_binary(alias_name), do: alias_name
  defp grid_row_alias(_), do: "Group 1"

  defp selected_field_alias({_kind, _field, alias_name}, _fallback)
       when is_binary(alias_name) and alias_name != "",
       do: alias_name

  defp selected_field_alias(_selected_field, fallback), do: fallback

  defp grid_coldef(group_by, idx) do
    case Enum.at(group_by, idx) do
      {_alias, {:group_by, _field, coldef}} -> coldef
      _ -> %{}
    end
  end

  defp format_group_value(value, coldef) do
    case Map.get(coldef || %{}, :group_format) || Map.get(coldef || %{}, "group_format") do
      "D" -> weekday_name(value)
      _ -> format_value(value)
    end
  end

  defp null_grid_text_class("[NULL]"), do: "text-gray-400 dark:text-gray-500"
  defp null_grid_text_class(_value), do: nil

  defp weekday_name(value) do
    case parse_int(value) do
      1 -> "Sunday"
      2 -> "Monday"
      3 -> "Tuesday"
      4 -> "Wednesday"
      5 -> "Thursday"
      6 -> "Friday"
      7 -> "Saturday"
      _ -> format_value(value)
    end
  end

  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {num, ""} -> num
      _ -> nil
    end
  end

  defp parse_int(_), do: nil

  defp sort_group_values(values, coldef) when is_list(values) do
    format = Map.get(coldef || %{}, :group_format) || Map.get(coldef || %{}, "group_format")

    case format do
      "D" -> Enum.sort_by(values, &weekday_sort_key/1)
      "HH24" -> Enum.sort_by(values, &int_sort_key/1)
      "MM" -> Enum.sort_by(values, &int_sort_key/1)
      "DD" -> Enum.sort_by(values, &int_sort_key/1)
      _ -> values
    end
  end

  defp weekday_sort_key(value) do
    case parse_int(value) do
      int when is_integer(int) and int >= 1 and int <= 7 -> {0, int}
      _ -> {1, to_string(value)}
    end
  end

  defp int_sort_key(value) do
    case parse_int(value) do
      int when is_integer(int) -> {0, int}
      _ -> {1, to_string(value)}
    end
  end

  defp maybe_set_group_by_filter(coldef, field_name)
       when is_map(coldef) and is_binary(field_name) and field_name != "" do
    coldef
    |> Map.put_new(:group_by_filter, field_name)
    |> Map.put_new("group_by_filter", field_name)
  end

  defp maybe_set_group_by_filter(coldef, _), do: coldef

  defp maybe_set_group_by_format(coldef, cfg) when is_map(coldef) and is_map(cfg) do
    format = Map.get(cfg, "format") || Map.get(cfg, :format)

    if is_binary(format) and format != "" do
      coldef
      |> Map.put(:group_format, format)
      |> Map.put("group_format", format)
    else
      coldef
    end
  end

  defp maybe_set_group_by_format(coldef, _), do: coldef

  @impl true
  def handle_event("set_aggregate_page", %{"page" => page_param}, socket) do
    page =
      page_param
      |> parse_page_param()
      |> normalize_page()
      |> clamp_aggregate_page_if_known(socket.assigns)

    if Map.get(socket.assigns, :aggregate_server_paged?, false) do
      send(self(), {:update_aggregate_page, page})

      {:noreply,
       assign(socket,
         aggregate_page_loading?: true,
         aggregate_requested_page: page
       )}
    else
      {:noreply, assign(socket, :aggregate_page, page)}
    end
  end

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
