defmodule SelectoComponents.Views.Aggregate.Component do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent
  alias SelectoComponents.Env
  alias SelectoComponents.Presentation
  alias SelectoComponents.QueryResults
  alias SelectoComponents.Theme
  alias SelectoComponents.Views.Aggregate.Options

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       aggregate_page: 0,
       aggregate_page_loading?: false,
       aggregate_requested_page: nil,
       theme: Theme.default_theme(:light)
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
        presentation_context: Map.get(assigns, :presentation_context, %{}),
        theme:
          Map.get(assigns, :theme, Map.get(socket.assigns, :theme, Theme.default_theme(:light))),
        last_update: System.system_time(:microsecond)
      )

    if Env.dev?() do
      IO.puts("[theme-debug][Aggregate.Component] update theme=#{socket.assigns.theme.id}")
    end

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
  defp format_value(value, column_def \\ nil, presentation_context \\ %{}) do
    case value do
      nil ->
        "[NULL]"

      # Empty string from ROLLUP NULL
      "" ->
        "[NULL]"

      {coefficient, scale} when is_integer(coefficient) and is_integer(scale) and scale >= 0 ->
        safe_cell_value(
          format_decimal_tuple(coefficient, scale),
          column_def,
          presentation_context
        )

      {display_value, _id} when is_nil(display_value) or display_value == "" ->
        "[NULL]"

      {display_value, _id} ->
        safe_cell_value(display_value, column_def, presentation_context)

      tuple when is_tuple(tuple) ->
        elem_val = elem(tuple, 0)

        if is_nil(elem_val) or elem_val == "" do
          "[NULL]"
        else
          safe_cell_value(elem_val, column_def, presentation_context)
        end

      # Includes "[NULL]" strings from COALESCE
      _ ->
        safe_cell_value(value, column_def, presentation_context)
    end
  end

  defp safe_cell_value(value, column_def, presentation_context) do
    case value do
      {:safe, _} = safe_value ->
        safe_value

      nil ->
        ""

      {coefficient, scale}
      when is_integer(coefficient) and is_integer(scale) and scale >= 0 ->
        format_decimal_tuple(coefficient, scale)

      value when is_atom(value) ->
        Atom.to_string(value)

      value when is_tuple(value) ->
        inspect(value)

      _ ->
        value
        |> Presentation.format_cell(maybe_normalized_column(column_def), presentation_context)
        |> QueryResults.normalize_value()
    end
  end

  # Format an aggregate value, applying format function if present
  defp format_aggregate_value(value, coldef, presentation_context) do
    formatted =
      case coldef do
        %{format: fmt_fun} when is_function(fmt_fun) -> fmt_fun.(value)
        _ -> value
      end

    format_value(formatted, coldef, presentation_context)
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

      filter_value = filter_value_for_group(value, field, coldef)

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
    {row_style, font_weight, indent_px} =
      case display_level do
        # Grand total
        0 ->
          {"background: color-mix(in srgb, var(--sc-accent-soft) 55%, var(--sc-surface-bg)); border-top: 2px solid var(--sc-accent);",
           "font-bold", 0}

        # Level 1 subtotal
        1 ->
          {"background: var(--sc-surface-bg-alt); border-top: 1px solid var(--sc-surface-border);",
           "font-semibold", 16}

        # Level 2 (or detail if only 2 levels)
        2 ->
          {"background: var(--sc-surface-bg); border-top: 1px solid var(--sc-surface-border);",
           "font-normal", 32}

        # Level 3
        3 ->
          {"background: var(--sc-surface-bg); border-top: 1px solid var(--sc-surface-border);",
           "font-normal", 48}

        # Deeper levels
        _ ->
          {"background: var(--sc-surface-bg); border-top: 1px solid var(--sc-surface-border);",
           "font-normal", 64}
      end

    # The maximum level is the number of group-by columns
    # If we're at max level, it's a detail row (not a subtotal)
    is_detail = display_level == assigns.num_group_by

    # For detail rows, use normal styling unless row is a continuation marker
    {row_style, font_weight} =
      cond do
        continued? ->
          {"background: color-mix(in srgb, var(--sc-accent-soft) 35%, var(--sc-surface-bg)); border-top: 1px dashed var(--sc-accent);",
           "font-semibold italic"}

        is_detail ->
          {"background: var(--sc-surface-bg); border-top: 1px solid var(--sc-surface-border);",
           "font-normal"}

        true ->
          {row_style, font_weight}
      end

    # Build filter attributes for drill-down (accumulated from all parent levels)
    filter_attrs = build_filter_attrs(group_cols, assigns.group_by, display_level)

    assigns =
      assign(assigns,
        group_cols: group_cols,
        agg_cols: agg_cols,
        row_style: row_style,
        font_weight: font_weight,
        indent_px: indent_px,
        filter_attrs: filter_attrs,
        continued?: continued?,
        display_level: display_level,
        grand_total?: grand_total?,
        active_group_range: active_group_range_for_level(assigns.group_by, display_level),
        group_blocks: row_group_blocks(assigns.group_by, group_cols)
      )

    ~H"""
    <tr style={@row_style}>
      <%!-- Render visible group-by blocks --%>
      <%= for block <- @group_blocks do %>
        <td class={"px-3 py-2 text-sm #{@font_weight}"} style="color: var(--sc-text-primary); border-bottom: 1px solid var(--sc-surface-border);">
          <div style={"padding-left: #{group_block_padding(block, @active_group_range, @indent_px)}px"}>
            <%= if @grand_total? and @display_level == 0 and block.start_idx == 0 do %>
              <%!-- Grand total row --%>
              <span style="color: var(--sc-text-muted); font-style: italic;">Total</span>
            <% else %>
              <%= if display_group_block?(block, @active_group_range) do %>
                <%= if @continued? do %>
                  <span style="color: var(--sc-accent);">
                    {group_block_value(block, @presentation_context)} (continued)
                  </span>
                <% else %>
                  <div
                    phx-click="agg_add_filters"
                    {@filter_attrs}
                    class="cursor-pointer hover:underline"
                  >
                    {group_block_value(block, @presentation_context)}
                  </div>
                <% end %>
              <% end %>
            <% end %>
          </div>
        </td>
      <% end %>

      <%!-- Render aggregate columns --%>
      <%= for {value, {_alias, {:agg, _agg, coldef}}} <- Enum.zip(@agg_cols, @aggregate) do %>
        <td class={"px-3 py-2 text-sm #{@font_weight}"} style="color: var(--sc-text-primary); border-bottom: 1px solid var(--sc-surface-border);">
          <%= if @continued? do %>
            <span style="color: var(--sc-accent);">-</span>
          <% else %>
            {format_aggregate_value(value, coldef, @presentation_context)}
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
        <div class="p-4 italic" style="color: var(--sc-text-muted);">
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
            <div class="p-4 italic" style="color: var(--sc-accent);">Loading view...</div>
          </div>
          """

        {true, nil} ->
          # Executed but no results - this is an error state
          ~H"""
            <div>
              <div class="p-4" style="color: var(--sc-danger);">
                <div class="font-semibold">No Results</div>
                <div class="mt-1 text-sm">Query executed but returned no results.</div>
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
            <div class="p-4" style="color: var(--sc-text-secondary);">
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
            <div class="p-4 italic" style="color: var(--sc-accent);">Loading view...</div>
          </div>
          """

        assigns.query_results == nil ->
          ~H"""
          <div>
            <div class="p-4 italic" style="color: var(--sc-accent);">Loading view...</div>
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
            <div class="p-4" style="color: var(--sc-danger);">
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
      case Map.get(assigns.selecto.set, :groups, []) do
        groups when is_list(groups) and groups != [] ->
          length(groups)

        _ ->
          case rollup_group_by do
            [{:rollup, positions}] when is_list(positions) -> Enum.count(positions)
            _ -> 0
          end
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
              configured_column(assigns.selecto, field_name) ||
                Selecto.field(assigns.selecto, field_name) || %{name: display_alias, format: nil}

            {:field, field_id, _alias} when is_binary(field_id) or is_atom(field_id) ->
              # Selecto.field now returns full custom column definitions with group_by_filter
              result =
                configured_column(assigns.selecto, field_id) ||
                  Selecto.field(assigns.selecto, field_id)

              if result == nil do
                # Field not found - use basic definition
                %{name: display_alias, format: nil}
              else
                result
              end

            {:field, {_extract_type, field_id, _format}, _alias} ->
              # Handle extracted fields (e.g., date parts)
              configured_column(assigns.selecto, field_id) ||
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
                  configured_column(assigns.selecto, field_name) ||
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
              configured_column(assigns.selecto, field_id) ||
                Selecto.field(assigns.selecto, field_id)

            {:field, field_id, _alias} when is_atom(field_id) ->
              configured_column(assigns.selecto, field_id) ||
                Selecto.field(assigns.selecto, field_id)

            {:field, {_func, field_id}, _alias} when is_binary(field_id) ->
              configured_column(assigns.selecto, field_id) ||
                Selecto.field(assigns.selecto, field_id)

            {:field, field_id, _alias} when is_binary(field_id) ->
              configured_column(assigns.selecto, field_id) ||
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

    display_group_axes = visible_group_axes(group_by)
    grid_enabled = truthy?(Map.get(aggregate_meta, :grid_enabled, false))

    grid_available? =
      grid_enabled and length(display_group_axes) == 2 and length(aggregates_processed) == 1

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
            aggregates_processed,
            grid_colorize,
            grid_color_scale,
            assigns.theme
          ),
        else: nil

    assigns =
      assign(assigns,
        presentation_context: Map.get(assigns, :presentation_context, %{}),
        rollup_rows: rollup_rows,
        paged_rollup_rows: paged_rollup_rows,
        num_group_by: num_group_by,
        group_by: group_by,
        display_group_headers: display_group_headers(group_by),
        display_group_axes: display_group_axes,
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
        grid_legend_colors: grid_palette(assigns.theme)
      )

    ~H"""
    <div>
      <div
        :if={!@grid_available?}
        class={Theme.slot(@theme, :panel) <> " mb-3 flex flex-wrap items-center justify-between gap-3 px-3 py-2"}
        style="background: var(--sc-surface-bg-alt);"
      >
        <div class={Theme.slot(@theme, :panel) <> " inline-flex items-center gap-1 p-1"} style="background: var(--sc-surface-bg);">
          <button
            type="button"
            phx-click="set_aggregate_page"
            phx-value-page={0}
            phx-target={@myself}
            class={Theme.slot(@theme, :button_secondary) <> " h-8 w-8 disabled:cursor-not-allowed disabled:opacity-40"}
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
            class={Theme.slot(@theme, :button_secondary) <> " h-8 gap-1 px-2 text-sm disabled:cursor-not-allowed disabled:opacity-40"}
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
            class={Theme.slot(@theme, :button_secondary) <> " h-8 gap-1 px-2 text-sm disabled:cursor-not-allowed disabled:opacity-40"}
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
            class={Theme.slot(@theme, :button_secondary) <> " h-8 w-8 disabled:cursor-not-allowed disabled:opacity-40"}
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

        <div class="text-sm font-medium" style="color: var(--sc-text-secondary);">
          <span class="font-semibold tabular-nums">
            {@aggregate_page_start}-{@aggregate_page_end}
          </span>
          of <span class="font-semibold tabular-nums">{@aggregate_total_rows}</span>
          rows
        </div>

        <div class="text-xs tabular-nums" style="color: var(--sc-text-muted);">
          Page
          <span class="font-semibold">
            {if @aggregate_total_pages > 0, do: @aggregate_page + 1, else: 0}
          </span>
          of <span class="font-semibold">{@aggregate_total_pages}</span>
          <span :if={@aggregate_page_loading?} class="ml-2" style="color: var(--sc-accent);">
            Loading...
          </span>
        </div>
      </div>

      <div
        :if={@aggregate_rows_capped?}
        class="mb-3 rounded-md border px-3 py-2 text-sm"
        style="background: color-mix(in srgb, var(--sc-accent-soft) 40%, var(--sc-surface-bg)); border-color: var(--sc-surface-border); color: var(--sc-text-primary);"
      >
        Showing the first <span class="font-semibold tabular-nums">{@aggregate_total_rows}</span>
        rows out of <span class="font-semibold tabular-nums">{@aggregate_total_rows_before_cap}</span>
        to keep rendering responsive. Narrow filters/grouping, or increase
          <code class="rounded px-1 py-0.5" style="background: var(--sc-surface-bg);">
            :aggregate_max_client_rows
          </code>
        (currently <span class="font-semibold">{inspect(@aggregate_max_client_rows)}</span>)
        if you need to render more rows at once.
      </div>

      <div
        :if={@grid_enabled and not @grid_available?}
        class="mb-3 rounded-md border px-3 py-2 text-sm"
        style="background: color-mix(in srgb, var(--sc-accent-soft) 50%, var(--sc-surface-bg)); border-color: var(--sc-surface-border); color: var(--sc-text-primary);"
      >
        Grid view requires exactly 2 Group By axes and 1 Aggregate.
      </div>

      <%= if @grid_available? and @grid_data do %>
        <div class="mb-2 flex flex-wrap items-center gap-2 text-sm" style="color: var(--sc-text-secondary);">
          <span class="font-medium">Aggregate Grid</span>
          <span
            :if={@grid_colorize}
            class="rounded-full border px-2 py-0.5 text-xs font-medium"
            style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-text-secondary);"
          >
            {String.capitalize(@grid_color_scale)} color scale
          </span>
        </div>
        <div
          :if={@grid_colorize}
          class="mb-3 flex flex-wrap items-center gap-2 rounded-md border px-3 py-2 text-xs"
          style="background: color-mix(in srgb, var(--sc-accent-soft) 45%, var(--sc-surface-bg)); border-color: var(--sc-surface-border); color: var(--sc-text-secondary);"
        >
          <span class="font-medium">Color legend</span>
          <span>Low</span>
          <div class="flex items-center gap-1" aria-label="Grid color legend">
            <span
              :for={color <- @grid_legend_colors}
              class="h-3 w-5 rounded-sm border"
              style={"border-color: var(--sc-surface-border); background-color: #{color};"}
            />
          </div>
          <span>High</span>
        </div>
        <div
          id={"aggregate-grid-wrapper-#{@myself}"}
          class={Theme.slot(@theme, :panel) <> " mb-1 max-h-[70vh] overflow-x-auto overflow-y-auto"}
        >
          <table class="min-w-full table-auto">
            <thead style="background: var(--sc-surface-bg-alt);">
              <tr>
                <th class="sticky left-0 top-0 z-30 px-3 py-3.5 text-left text-sm font-semibold" style="background: var(--sc-surface-bg-alt); color: var(--sc-text-primary); box-shadow: 1px 0 0 0 var(--sc-surface-border);">
                  {@grid_data.row_alias}
                </th>
                <%= for col_value <- @grid_data.col_headers do %>
                  <th class="sticky top-0 z-20 px-3 py-3.5 text-left text-sm font-semibold" style="background: var(--sc-surface-bg-alt); color: var(--sc-text-primary);">
                    <span class={null_grid_text_class(format_group_value(col_value, @grid_data.col_coldef, @presentation_context))}>
                      {format_group_value(col_value, @grid_data.col_coldef, @presentation_context)}
                    </span>
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border);">
              <tr :for={row_value <- @grid_data.row_headers}>
                <td class="sticky left-0 z-10 px-3 py-2 text-sm font-semibold" style="background: var(--sc-surface-bg); color: var(--sc-text-primary); box-shadow: 1px 0 0 0 var(--sc-surface-border);">
                  <span class={null_grid_text_class(format_group_value(row_value, @grid_data.row_coldef, @presentation_context))}>
                    {format_group_value(row_value, @grid_data.row_coldef, @presentation_context)}
                  </span>
                </td>
          <td
            :for={col_value <- @grid_data.col_headers}
            class="px-3 py-2 text-sm"
            style={Map.get(@grid_data.cell_styles, {row_value, col_value}, "background: var(--sc-surface-bg); color: var(--sc-text-primary);")}
          >
                  <div
                    phx-click="agg_add_filters"
                    {build_filter_attrs(
                      Map.get(@grid_data.cell_group_cols, {row_value, col_value}, []),
                      @group_by,
                      @num_group_by
                    )}
                    class="cursor-pointer whitespace-nowrap hover:underline"
                  >
                    <span class={null_grid_text_class(format_aggregate_value(Map.get(@grid_data.cells, {row_value, col_value}), @grid_data.agg_coldef, @presentation_context))}>
                      {format_aggregate_value(Map.get(@grid_data.cells, {row_value, col_value}), @grid_data.agg_coldef, @presentation_context)}
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% else %>
        <div
          id={"aggregate-table-wrapper-#{@myself}"}
          class={Theme.slot(@theme, :panel) <> " responsive-table-wrapper overflow-x-auto"}
        >
          <table class="min-w-full table-auto">
            <thead style="background: var(--sc-surface-bg-alt);">
              <tr>
                <%!-- Headers for group by columns --%>
                <%= for alias <- @display_group_headers do %>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold" style="color: var(--sc-text-primary); border-bottom: 1px solid var(--sc-surface-border);">
                    {alias}
                  </th>
                <% end %>

                <%!-- Headers for aggregate columns --%>
                <%= for {alias, {:agg, _agg, _coldef}} <- @aggregate do %>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold" style="color: var(--sc-text-primary); border-bottom: 1px solid var(--sc-surface-border);">
                    {alias}
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border);">
              <.rollup_row
                :for={{level, row, continued?, grand_total?} <- @paged_rollup_rows}
                level={level}
                row={row}
                continued?={continued?}
                grand_total?={grand_total?}
                num_group_by={@num_group_by}
                group_by={@group_by}
                aggregate={@aggregate}
                presentation_context={@presentation_context}
                theme={@theme}
              />
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false

  defp build_grid_data(
         paged_rollup_rows,
         num_group_by,
         group_by,
         aggregates,
         colorize?,
         scale_mode,
         theme
       ) do
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

    display_group_axes = visible_group_axes(group_by)
    row_axis = Enum.at(display_group_axes, 0, default_grid_axis("Group 1"))
    col_axis = Enum.at(display_group_axes, 1, default_grid_axis("Group 2"))

    {row_headers, col_headers, cells, cell_group_cols} =
      Enum.reduce(detail_rows, {[], [], %{}, %{}}, fn row,
                                                      {row_acc, col_acc, cells_acc,
                                                       group_cols_acc} ->
        row_value = grid_axis_value(row, row_axis)
        col_value = grid_axis_value(row, col_axis)
        agg_value = Enum.at(row, num_group_by)
        group_cols = Enum.take(row, num_group_by)

        row_acc = if row_value in row_acc, do: row_acc, else: row_acc ++ [row_value]
        col_acc = if col_value in col_acc, do: col_acc, else: col_acc ++ [col_value]
        cells_acc = Map.put(cells_acc, {row_value, col_value}, agg_value)
        group_cols_acc = Map.put(group_cols_acc, {row_value, col_value}, group_cols)

        {row_acc, col_acc, cells_acc, group_cols_acc}
      end)

    row_coldef = grid_axis_coldef(row_axis)
    col_coldef = grid_axis_coldef(col_axis)
    agg_coldef = grid_coldef(aggregates, 0)

    row_headers = sort_group_values(row_headers, row_coldef)
    col_headers = sort_group_values(col_headers, col_coldef)
    cell_styles = build_grid_cell_styles(cells, colorize?, scale_mode, theme)

    %{
      row_alias: row_axis.alias,
      row_headers: row_headers,
      col_headers: col_headers,
      cells: cells,
      cell_group_cols: cell_group_cols,
      cell_styles: cell_styles,
      row_coldef: row_coldef,
      col_coldef: col_coldef,
      agg_coldef: agg_coldef
    }
  end

  defp build_grid_cell_styles(cells, false, _scale_mode, _theme) when is_map(cells) do
    Enum.into(cells, %{}, fn {key, _value} ->
      {key, "background: var(--sc-surface-bg); color: var(--sc-text-primary);"}
    end)
  end

  defp build_grid_cell_styles(cells, true, scale_mode, theme) when is_map(cells) do
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
      {key, grid_cell_style(value, max_positive_value, scale_mode, theme)}
    end)
  end

  defp grid_cell_style(value, max_positive_value, scale_mode, theme) do
    case grid_palette_color(value, max_positive_value, scale_mode, theme) do
      nil -> "background: var(--sc-surface-bg); color: var(--sc-text-primary);"
      color -> "background-color: #{color}; color: var(--sc-text-primary);"
    end
  end

  defp grid_palette_color(_value, nil, _scale_mode, _theme), do: nil

  defp grid_palette_color(value, max_positive_value, scale_mode, theme) do
    with num when is_number(num) <- numeric_value(value),
         true <- num > 0,
         true <- max_positive_value > 0 do
      palette = grid_palette(theme)

      ratio =
        case Options.normalize_grid_color_scale_mode(scale_mode) do
          "log" -> :math.log(num + 1) / :math.log(max_positive_value + 1)
          _ -> num / max_positive_value
        end

      palette_index =
        ratio
        |> Kernel.*(length(palette))
        |> Float.ceil()
        |> trunc()
        |> min(length(palette))
        |> max(1)

      Enum.at(palette, palette_index - 1)
    else
      _ -> nil
    end
  end

  defp grid_palette(_theme) do
    [
      "color-mix(in srgb, var(--sc-accent) 10%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 16%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 22%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 28%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 34%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 40%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 46%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 52%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 58%, var(--sc-surface-bg))",
      "color-mix(in srgb, var(--sc-accent) 64%, var(--sc-surface-bg))"
    ]
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

  defp selected_field_alias({_kind, _field, alias_name}, _fallback)
       when is_binary(alias_name) and alias_name != "",
       do: alias_name

  defp selected_field_alias(_selected_field, fallback), do: fallback

  defp grid_coldef(group_by, idx) do
    case Enum.at(group_by, idx) do
      {_alias, {:group_by, _field, coldef}} -> coldef
      {_alias, {:agg, _field, coldef}} -> coldef
      _ -> %{}
    end
  end

  defp grid_axis_coldef(%{defs: [{_alias, {:group_by, _field, coldef}}]}), do: coldef

  defp grid_axis_coldef(%{defs: defs}) when is_list(defs) do
    %{
      linked_defs: Enum.map(defs, fn {_alias, {:group_by, _field, coldef}} -> coldef end)
    }
  end

  defp grid_axis_coldef(_axis), do: %{}

  defp default_grid_axis(alias_name) do
    %{
      alias: alias_name,
      defs: [],
      start_idx: nil,
      end_idx: nil
    }
  end

  defp grid_axis_value(row, %{start_idx: start_idx, end_idx: end_idx})
       when is_list(row) and is_integer(start_idx) and is_integer(end_idx) do
    values = Enum.slice(row, start_idx, end_idx - start_idx + 1)

    case values do
      [single] -> single
      many -> many
    end
  end

  defp grid_axis_value(_row, _axis), do: nil

  defp format_group_value(value, coldef, presentation_context) do
    if linked_grid_axis?(coldef) and is_list(value) do
      value
      |> Enum.zip(Map.get(coldef, :linked_defs, []))
      |> Enum.map(fn {part_value, part_coldef} ->
        format_group_value(part_value, part_coldef, presentation_context)
      end)
      |> Enum.join(" / ")
    else
      display_value = display_value_for_group(value, coldef)

      case Map.get(coldef || %{}, :group_format) || Map.get(coldef || %{}, "group_format") do
        "D" ->
          weekday_name(display_value)

        format when is_binary(format) and format != "" ->
          format_value(display_value, nil, presentation_context)

        _ ->
          format_value(display_value, coldef, presentation_context)
      end
    end
  end

  defp linked_grid_axis?(coldef) when is_map(coldef),
    do: is_list(Map.get(coldef, :linked_defs)) and Map.get(coldef, :linked_defs) != []

  defp linked_grid_axis?(_coldef), do: false

  defp display_value_for_group(value, coldef) do
    if composite_group_value?(coldef) do
      case value do
        {display_value, _filter_value} -> display_value
        [display_value, _filter_value] -> display_value
        _ -> value
      end
    else
      value
    end
  end

  defp filter_value_for_group(value, field, coldef) do
    extracted_value =
      if composite_group_value?(coldef) or match?({:row, _fields, _alias}, field) do
        case value do
          {_display_value, filter_value} -> filter_value
          [_display_value, filter_value] -> filter_value
          _ -> value
        end
      else
        value
      end

    case extracted_value do
      nil -> "__NULL__"
      "" -> "__NULL__"
      "[NULL]" -> "__NULL__"
      _ -> extracted_value
    end
  end

  defp composite_group_value?(coldef) do
    join_mode = Map.get(coldef || %{}, :join_mode) || Map.get(coldef || %{}, "join_mode")

    group_by_filter_select =
      Map.get(coldef || %{}, :group_by_filter_select) ||
        Map.get(coldef || %{}, "group_by_filter_select")

    join_mode in [:lookup, :star, :tag] or not is_nil(group_by_filter_select)
  end

  defp null_grid_text_class("[NULL]"), do: nil
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

  defp configured_column(_selecto, nil), do: nil

  defp configured_column(selecto, key) do
    columns = Selecto.columns(selecto)

    Map.get(columns, key) ||
      case key do
        value when is_atom(value) ->
          Map.get(columns, Atom.to_string(value))

        value when is_binary(value) ->
          case safe_existing_atom(value) do
            nil -> nil
            atom_key -> Map.get(columns, atom_key)
          end

        _ ->
          nil
      end
  end

  defp safe_existing_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  defp safe_existing_atom(_value), do: nil

  defp maybe_normalized_column(nil), do: nil
  defp maybe_normalized_column(column_def), do: Selecto.Presentation.normalize_column(column_def)

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
      |> maybe_set_linked_to_next(cfg)
    else
      maybe_set_linked_to_next(coldef, cfg)
    end
  end

  defp maybe_set_group_by_format(coldef, _), do: coldef

  defp maybe_set_linked_to_next(coldef, cfg) when is_map(coldef) and is_map(cfg) do
    linked? =
      Map.get(cfg, "linked_to_next", Map.get(cfg, :linked_to_next))
      |> truthy?()

    coldef
    |> Map.put(:linked_to_next, linked?)
    |> Map.put("linked_to_next", linked?)
  end

  defp maybe_set_linked_to_next(coldef, _cfg), do: coldef

  defp display_group_headers(group_by) when is_list(group_by) do
    group_by
    |> visible_group_axes()
    |> Enum.map(& &1.alias)
  end

  defp display_group_headers(_group_by), do: []

  defp visible_group_axes(group_by) when is_list(group_by) do
    linked_group_ranges(group_by)
    |> Enum.map(fn {start_idx, end_idx} ->
      defs = Enum.slice(group_by, start_idx, end_idx - start_idx + 1)

      %{
        alias:
          defs
          |> Enum.map(fn {alias_name, _definition} -> alias_name end)
          |> Enum.join(" / "),
        defs: defs,
        start_idx: start_idx,
        end_idx: end_idx
      }
    end)
  end

  defp visible_group_axes(_group_by), do: []

  defp active_group_range_for_level(_group_by, 0), do: nil

  defp active_group_range_for_level(group_by, display_level)
       when is_list(group_by) and display_level > 0 do
    display_idx = display_level - 1

    linked_group_ranges(group_by)
    |> Enum.find(fn {start_idx, end_idx} ->
      display_idx >= start_idx and display_idx <= end_idx
    end)
  end

  defp active_group_range_for_level(_group_by, _display_level), do: nil

  defp linked_group_ranges(group_by) when is_list(group_by) do
    {ranges, current_start} =
      Enum.with_index(group_by)
      |> Enum.reduce({[], nil}, fn {{_alias, {:group_by, _field, coldef}}, idx},
                                   {ranges, current_start} ->
        current_start = if is_nil(current_start), do: idx, else: current_start

        if linked_to_next?(coldef) do
          {ranges, current_start}
        else
          {ranges ++ [{current_start, idx}], nil}
        end
      end)

    case current_start do
      nil -> ranges
      start_idx -> ranges ++ [{start_idx, max(length(group_by) - 1, start_idx)}]
    end
  end

  defp linked_group_ranges(_group_by), do: []

  defp linked_to_next?(coldef) when is_map(coldef) do
    truthy?(Map.get(coldef, :linked_to_next, Map.get(coldef, "linked_to_next")))
  end

  defp linked_to_next?(_coldef), do: false

  defp row_group_blocks(group_by, group_cols) when is_list(group_by) and is_list(group_cols) do
    linked_group_ranges(group_by)
    |> Enum.map(fn {start_idx, end_idx} ->
      %{
        start_idx: start_idx,
        end_idx: end_idx,
        defs: Enum.slice(group_by, start_idx, end_idx - start_idx + 1),
        values: Enum.slice(group_cols, start_idx, end_idx - start_idx + 1)
      }
    end)
  end

  defp row_group_blocks(_group_by, _group_cols), do: []

  defp group_block_value(%{defs: defs, values: values}, presentation_context) do
    formatted_values =
      values
      |> Enum.zip(defs)
      |> Enum.take_while(fn {value, _definition} -> value not in [nil, ""] end)
      |> Enum.map(fn {value, {_alias, {:group_by, _field, coldef}}} ->
        format_group_value(value, coldef, presentation_context)
      end)

    case formatted_values do
      [] ->
        case Enum.zip(values, defs) do
          [{value, {_alias, {:group_by, _field, coldef}}} | _rest] ->
            format_group_value(value, coldef, presentation_context)

          _ ->
            ""
        end

      values_to_join ->
        Enum.join(values_to_join, " / ")
    end
  end

  defp group_block_value(_block, _presentation_context), do: ""

  defp display_group_block?(_block, nil), do: false

  defp display_group_block?(%{start_idx: start_idx, end_idx: end_idx}, {active_start, active_end}) do
    start_idx == active_start and end_idx == active_end
  end

  defp group_block_padding(%{start_idx: start_idx}, {active_start, _active_end}, indent_px)
       when start_idx == active_start,
       do: indent_px

  defp group_block_padding(_block, _active_group_range, _indent_px), do: 0

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
