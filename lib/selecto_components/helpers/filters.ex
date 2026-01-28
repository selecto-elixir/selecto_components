defmodule SelectoComponents.Helpers.Filters do

  import Ecto.Type ## For cast

  # Sanitize LIKE pattern values to prevent SQL injection
  # Escapes special SQL wildcard characters: %, _, \
  defp sanitize_like_value(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")  # Escape backslash first
    |> String.replace("%", "\\%")     # Escape percent
    |> String.replace("_", "\\_")     # Escape underscore
  end
  defp sanitize_like_value(value), do: value

  defp parse_num(type, num) do
    {:ok, v} = cast(type, num)
    v
  end


  defp _make_num_filter(type, filter)  do
    comp = Map.get(filter, "comp")
    case comp do
      "=" ->
        parse_num(type, Map.get(filter, "value"))

      "null" ->
        nil

      "IS_EMPTY" ->
        nil

      "IS NULL" ->
        nil

      "not_null" ->
        :not_null

      "IS_NOT_EMPTY" ->
        :not_null

      "IS NOT NULL" ->
        :not_null

      "between" ->
        {:between, parse_num(type, Map.get(filter, "value")),parse_num(type, Map.get(filter, "value2"))}

      "IN" ->
        # Parse comma-separated IDs and convert to list
        value = Map.get(filter, "value", "")
        ids = value
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&parse_num(type, &1))
        {:in, ids}

      "NOT IN" ->
        # Parse comma-separated IDs and convert to NOT IN list
        value = Map.get(filter, "value", "")
        ids = value
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&parse_num(type, &1))
        {:not_in, ids}

      x when x in ~w( != <= >= < >) ->
        {x, parse_num(type, Map.get(filter, "value"))}
    end
  end

  defp make_text_search_filter(filter) do
    { Map.get(filter, "filter"), {:text_search, Map.get(filter, "value")}}
  end

  defp _make_string_filter(filter) do
    comp = Map.get(filter, "comp")

    case comp do
      "null" -> {Map.get(filter, "filter"), nil}
      "IS_EMPTY" -> {Map.get(filter, "filter"), nil}
      "IS NULL" -> {Map.get(filter, "filter"), nil}
      "not_null" -> {Map.get(filter, "filter"), :not_null}
      "IS_NOT_EMPTY" -> {Map.get(filter, "filter"), :not_null}
      "IS NOT NULL" -> {Map.get(filter, "filter"), :not_null}
      _ ->
        ignore_case = Map.get(filter, "ignore_case")

        {filpart, value} = if ignore_case == "Y" do
          {
            {:upper, Map.get(filter, "filter")},
            String.upcase( Map.get(filter, "value") )}
        else
          {Map.get(filter, "filter"), Map.get(filter, "value")}
        end

        valpart = case comp do
          "=" -> value
          "null" -> nil
          "IS_EMPTY" -> nil
          "IS NULL" -> nil
          "not_null" -> :not_null
          "IS_NOT_EMPTY" -> :not_null
          "IS NOT NULL" -> :not_null
          x when x in ~w( != <= >= < >) -> {x, value}
          "starts" -> {:like, sanitize_like_value(value) <> "%"}
          "ends" -> {:like, "%" <> sanitize_like_value(value)}
          "contains" -> {:like, "%" <> sanitize_like_value(value) <> "%"}
          "LIKE" -> {:like, "%" <> sanitize_like_value(value) <> "%"}
          "NOT LIKE" -> {:not_like, "%" <> sanitize_like_value(value) <> "%"}
        end

        {filpart, valpart}
    end
  end

  defp _make_date_filter(filter) do
    comp = Map.get(filter, "comp", "=")

    case comp do
      "RELATIVE" ->
        # Handle relative date patterns like "13-7" (13 to 7 days ago)
        pattern = Map.get(filter, "value", "")
        process_relative_date_filter(pattern)

      "SHORTCUT" ->
        # Handle date shortcuts like "this_month", "last_week", etc.
        shortcut = Map.get(filter, "value", "")
        process_date_shortcut_filter(shortcut)

      "DATE=" ->
        # For DATE=, we want to match the entire day
        date_str = Map.get(filter, "value")
        if date_str do
          case Date.from_iso8601(date_str) do
            {:ok, date} ->
              # Convert to datetime range for the entire day
              start_dt = NaiveDateTime.new!(date, ~T[00:00:00])
              end_dt = NaiveDateTime.new!(date, ~T[23:59:59])
              {:between, start_dt, end_dt}
            _ ->
              # Fallback to original behavior if date parsing fails
              {start, stop} = Selecto.Helpers.Date.val_to_dates(filter)
              {:between, start, stop}
          end
        else
          {start, stop} = Selecto.Helpers.Date.val_to_dates(filter)
          {:between, start, stop}
        end

      "DATE!=" ->
        # For DATE!=, we want to exclude the entire day
        date_str = Map.get(filter, "value")
        if date_str do
          case Date.from_iso8601(date_str) do
            {:ok, date} ->
              # Convert to datetime range for the entire day and negate
              start_dt = NaiveDateTime.new!(date, ~T[00:00:00])
              end_dt = NaiveDateTime.new!(date, ~T[23:59:59])
              {:not, {:between, start_dt, end_dt}}
            _ ->
              # Fallback
              {start, stop} = Selecto.Helpers.Date.val_to_dates(filter)
              {:not, {:between, start, stop}}
          end
        else
          {start, stop} = Selecto.Helpers.Date.val_to_dates(filter)
          {:not, {:between, start, stop}}
        end

      "BETWEEN" ->
        # For BETWEEN datetime, use the start and end values
        start_str = Map.get(filter, "value_start") || Map.get(filter, "value")
        end_str = Map.get(filter, "value_end") || Map.get(filter, "value2")

        if start_str && end_str do
          start_dt = parse_datetime_preserving_time(start_str)
          end_dt = parse_datetime_preserving_time(end_str)
          {:between, start_dt, end_dt}
        else
          # Fallback to original behavior
          {start, stop} = Selecto.Helpers.Date.val_to_dates(filter)
          {:between, start, stop}
        end

      "DATE_BETWEEN" ->
        # For DATE_BETWEEN, use the start and end dates (ignoring time)
        start_str = Map.get(filter, "value_start") || Map.get(filter, "value")
        end_str = Map.get(filter, "value_end") || Map.get(filter, "value2")

        if start_str && end_str do
          with {:ok, start_date} <- Date.from_iso8601(start_str),
               {:ok, end_date} <- Date.from_iso8601(end_str) do
            start_dt = NaiveDateTime.new!(start_date, ~T[00:00:00])
            # For end date, we want to include the entire day, so go to start of next day
            end_dt = NaiveDateTime.new!(end_date, ~T[00:00:00])
            {:between, start_dt, end_dt}
          else
            _ ->
              # Fallback to original behavior
              {start, stop} = Selecto.Helpers.Date.val_to_dates(filter)
              {:between, start, stop}
          end
        else
          # Fallback to original behavior
          {start, stop} = Selecto.Helpers.Date.val_to_dates(filter)
          {:between, start, stop}
        end

      _ ->
        # Default behavior for other comparison operators
        # For < and <= operators with datetime values, preserve the exact time
        value_str = Map.get(filter, "value")

        case {comp, value_str} do
          {"<", value} when is_binary(value) ->
            # Check if it has a time component
            if String.match?(value, ~r/\d{2}:\d{2}/) do
              # Parse the datetime directly preserving time
              datetime = parse_datetime_preserving_time(value)
              {:<, datetime}
            else
              # Date only, use beginning of day
              filter_with_value2 = Map.put_new(filter, "value2", "")
              {start, _stop} = Selecto.Helpers.Date.val_to_dates(filter_with_value2)
              {:<, start}
            end

          {"<=", value} when is_binary(value) ->
            # Check if it has a time component
            if String.match?(value, ~r/\d{2}:\d{2}/) do
              # Parse the datetime directly preserving time
              datetime = parse_datetime_preserving_time(value)
              {:<=, datetime}
            else
              # Date only, use end of day
              filter_with_value2 = Map.put_new(filter, "value2", "")
              {_start, stop} = Selecto.Helpers.Date.val_to_dates(filter_with_value2)
              {:<=, stop}
            end

          {">", value} when is_binary(value) ->
            # Check if it has a time component
            if String.match?(value, ~r/\d{2}:\d{2}/) do
              # Parse the datetime directly preserving time
              datetime = parse_datetime_preserving_time(value)
              {:>, datetime}
            else
              # Date only, use end of day
              filter_with_value2 = Map.put_new(filter, "value2", "")
              {_start, stop} = Selecto.Helpers.Date.val_to_dates(filter_with_value2)
              {:>, stop}
            end

          {">=", value} when is_binary(value) ->
            # Check if it has a time component
            if String.match?(value, ~r/\d{2}:\d{2}/) do
              # Parse the datetime directly preserving time
              datetime = parse_datetime_preserving_time(value)
              {:>=, datetime}
            else
              # Date only, use beginning of day
              filter_with_value2 = Map.put_new(filter, "value2", "")
              {start, _stop} = Selecto.Helpers.Date.val_to_dates(filter_with_value2)
              {:>=, start}
            end

          _ ->
            # For other operators, use the standard date range logic
            filter_with_value2 = Map.put_new(filter, "value2", "")
            {start, stop} = Selecto.Helpers.Date.val_to_dates(filter_with_value2)

            case comp do
              "=" -> {:between, start, stop}
              "!=" -> {:not, {:between, start, stop}}
              "IS NULL" -> nil
              "IS_EMPTY" -> nil
              "IS NOT NULL" -> :not_null
              "IS_NOT_EMPTY" -> :not_null
              _ -> {:between, start, stop}
            end
        end
    end
  end

  ## Build filters that can be sent to the selecto
  @doc """
  Recursively build filters from form input that can be sent to Selecto.

  Returns a list of filter tuples. Invalid or erroring filters are logged and skipped
  rather than crashing the entire filter chain.
  """
  def filter_recurse(selecto, filters, section) do
    # Filter out any bucket_ranges strings that shouldn't be filters
    section_filters = Map.get(filters, section, [])
    |> Enum.reject(fn
      filter when is_binary(filter) ->
        # Check if this looks like a bucket range string
        String.match?(filter, ~r/^\d+-\d+,\d+\+$|^\d+,\d+-\d+,|\d+\+/)
      _ ->
        false
    end)

    result = Enum.reduce(section_filters, [], fn filter_item, acc ->
      case process_single_filter(selecto, filters, filter_item) do
        {:ok, filter_results} when is_list(filter_results) ->
          acc ++ filter_results
        {:ok, filter_result} ->
          acc ++ [filter_result]
        {:skip, _reason} ->
          # Filter was intentionally skipped (e.g., column not found, invalid value)
          acc
        {:error, error} ->
          # Log error but continue processing other filters
          require Logger
          Logger.warning("Filter processing error: #{inspect(error)}, filter: #{inspect(filter_item)}")
          acc
      end
    end)

    # Handle POLYMORPHIC filters separately
    result = result ++ handle_polymorphic_filters(section_filters)
    result
  end

  # Process a single filter with error handling
  defp process_single_filter(selecto, filters, %{"is_section" => "Y", "uuid" => uuid, "conjunction" => conj}) do
    conjunction_atom = case conj do
      "AND" -> :and
      "OR" -> :or
      _ -> :and
    end
    nested_filters = filter_recurse(selecto, filters, uuid)
    {:ok, [{conjunction_atom, nested_filters}]}
  end

  defp process_single_filter(selecto, _filters, f) when is_map(f) do
    try do
      filter_key = Map.get(f, "filter")

      # Check for custom filter apply function
      if get_in(Selecto.filters(selecto), [filter_key, :apply]) do
        result = Selecto.filters(selecto)[filter_key].apply.(selecto, f)
        {:ok, [result]}
      else
        process_column_filter(selecto, f, filter_key)
      end
    rescue
      e ->
        {:error, %{exception: Exception.message(e), filter: f}}
    end
  end

  defp process_single_filter(_selecto, _filters, filter_item) do
    {:skip, {:invalid_format, filter_item}}
  end

  # Process a filter based on column type
  defp process_column_filter(selecto, f, filter_key) do
    # Try to find the column - it might be under an alias or original name
    column = find_column(selecto, filter_key)

    if column == nil do
      {:skip, {:column_not_found, filter_key}}
    else
      build_typed_filter(column, f, filter_key)
    end
  end

  # Find column by key, colid, or name
  defp find_column(selecto, filter_key) do
    columns = Selecto.columns(selecto)

    case columns[filter_key] do
      nil ->
        # Try to find by matching colid or name
        columns
        |> Enum.find(fn {_key, col} ->
          col.colid == filter_key || col.name == filter_key
        end)
        |> case do
          {_key, col} -> col
          nil -> nil
        end

      column ->
        column
    end
  end

  # Build filter based on column type
  defp build_typed_filter(column, f, filter_key) do
    case column.type do
      x when x in [:id, :integer, :float, :decimal] ->
        case safe_make_num_filter(x, f) do
          {:ok, filter_val} -> {:ok, [{filter_key, filter_val}]}
          {:error, reason} -> {:skip, {:invalid_numeric, reason}}
        end

      :tsvector ->
        {:ok, [make_text_search_filter(f)]}

      :boolean ->
        value = case Map.get(f, "value") do
          "true" -> true
          true -> true
          _ -> false
        end
        {:ok, [{filter_key, value}]}

      :string ->
        {:ok, [_make_string_filter(f)]}

      :custom_column ->
        {:ok, [_make_string_filter(f)]}

      x when x in [:naive_datetime, :utc_datetime, :date] ->
        case safe_make_date_filter(f) do
          {:ok, {:or, conditions}} ->
            or_filters = Enum.map(conditions, fn filter_val ->
              {filter_key, filter_val}
            end)
            {:ok, [{:or, or_filters}]}

          {:ok, filter_val} ->
            {:ok, [{filter_key, filter_val}]}

          {:error, reason} ->
            {:skip, {:invalid_date, reason}}
        end

      {:parameterized, _, enum_conf} ->
        # Validate enum value against mappings
        value = Map.get(f, "value")
        case validate_enum_value(value, enum_conf) do
          :ok -> {:ok, [{filter_key, value}]}
          {:error, reason} -> {:skip, {:invalid_enum, reason}}
        end

      unknown_type ->
        # For unknown types, try as string filter
        require Logger
        Logger.debug("Unknown column type #{inspect(unknown_type)} for filter #{filter_key}, treating as string")
        {:ok, [_make_string_filter(f)]}
    end
  end

  # Safe wrapper for numeric filter creation
  defp safe_make_num_filter(type, filter) do
    {:ok, _make_num_filter(type, filter)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Safe wrapper for date filter creation
  defp safe_make_date_filter(filter) do
    result = _make_date_filter(filter)
    {:ok, result}
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Validate enum value against allowed mappings
  defp validate_enum_value(nil, _enum_conf), do: :ok
  defp validate_enum_value("", _enum_conf), do: :ok

  defp validate_enum_value(value, enum_conf) do
    # Extract mappings from enum configuration
    mappings = case enum_conf do
      %{mappings: mappings} -> mappings
      %{"mappings" => mappings} -> mappings
      _ -> nil
    end

    case mappings do
      nil ->
        # No mappings defined, allow any value
        :ok

      mappings when is_map(mappings) ->
        # Check if value is a valid key in mappings
        valid_keys = Map.keys(mappings) |> Enum.map(&to_string/1)
        if to_string(value) in valid_keys do
          :ok
        else
          {:error, "Value '#{value}' is not a valid enum value. Allowed: #{Enum.join(valid_keys, ", ")}"}
        end

      mappings when is_list(mappings) ->
        # List of allowed values
        valid_values = Enum.map(mappings, fn
          {k, _v} -> to_string(k)
          v -> to_string(v)
        end)
        if to_string(value) in valid_values do
          :ok
        else
          {:error, "Value '#{value}' is not a valid enum value. Allowed: #{Enum.join(valid_values, ", ")}"}
        end

      _ ->
        # Unknown mappings format, allow any value
        :ok
    end
  end

  # Handle polymorphic filters that need special OR condition generation
  defp handle_polymorphic_filters(section_filters) do
    Enum.flat_map(section_filters, fn
      %{"comp" => "POLYMORPHIC"} = f ->
        # Parse polymorphic selection: types and values for each type
        selected_types = case Map.get(f, "selected_types") do
          json when is_binary(json) -> Jason.decode!(json)
          list when is_list(list) -> list
          _ -> []
        end

        poly_values = Map.get(f, "poly_values", %{})

        # Build OR conditions: (type='Product' AND id IN (1,2,3)) OR (type='Order' AND id IN (4,5))
        type_conditions = Enum.flat_map(selected_types, fn entity_type ->
          ids_str = Map.get(poly_values, entity_type, "")
          ids = parse_poly_ids(ids_str)

          if length(ids) > 0 do
            # Generate condition: type = 'Product' AND id IN (1,2,3)
            filter_name = Map.get(f, "filter")
            type_field = "#{filter_name}_type"  # e.g., "commentable_type"
            id_field = "#{filter_name}_id"      # e.g., "commentable_id"

            [{:and, [
              {type_field, entity_type},
              {id_field, {:in, ids}}
            ]}]
          else
            []
          end
        end)

        if length(type_conditions) > 0 do
          [{:or, type_conditions}]
        else
          []
        end

      _ -> []
    end)
  end

  # Parse comma-separated IDs for polymorphic filters
  defp parse_poly_ids(ids_str) when is_binary(ids_str) do
    ids_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn id_str ->
      case Integer.parse(id_str) do
        {id, _} -> id
        :error -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
  defp parse_poly_ids(_), do: []

  # Process relative date patterns like "13-7" (13 to 7 days ago)
  defp process_relative_date_filter(pattern) do
    # Use the server's local date as "today"
    today = get_local_today()

    cond do
      # Pattern: "5" - exactly 5 days ago
      Regex.match?(~r/^\d+$/, pattern) ->
        days_ago = String.to_integer(pattern)
        target_date = Date.add(today, -days_ago)
        start_dt = NaiveDateTime.new!(target_date, ~T[00:00:00])
        end_dt = NaiveDateTime.new!(Date.add(target_date, 1), ~T[00:00:00])
        {:between, start_dt, end_dt}

      # Pattern: "13-7" - between 13 and 7 days ago
      Regex.match?(~r/^(\d+)-(\d+)$/, pattern) ->
        [_, first_str, second_str] = Regex.run(~r/^(\d+)-(\d+)$/, pattern)
        first_days = String.to_integer(first_str)
        second_days = String.to_integer(second_str)
        # Determine the older and newer dates (larger number = further in past)
        older_days = max(first_days, second_days)
        newer_days = min(first_days, second_days)
        start_dt = NaiveDateTime.new!(Date.add(today, -older_days), ~T[00:00:00])
        end_dt = NaiveDateTime.new!(Date.add(today, -newer_days + 1), ~T[00:00:00])
        {:between, start_dt, end_dt}

      # Pattern: "-5" - all dates before 5 days ago (older than 5 days ago)
      # -0 means all dates before today (all past)
      # -1 means all dates before yesterday
      Regex.match?(~r/^-(\d+)$/, pattern) ->
        [_, days_str] = Regex.run(~r/^-(\d+)$/, pattern)
        days = String.to_integer(days_str)
        # < means before the start of N days ago
        cutoff_dt = NaiveDateTime.new!(Date.add(today, -days), ~T[00:00:00])
        {:<, cutoff_dt}

      # Pattern: "5-" - from 5 days ago onwards (including today and future)
      # 0- means today and all future
      Regex.match?(~r/^(\d+)-$/, pattern) ->
        [_, days_str] = Regex.run(~r/^(\d+)-$/, pattern)
        days = String.to_integer(days_str)
        start_date = Date.add(today, -days)
        start_dt = NaiveDateTime.new!(start_date, ~T[00:00:00])
        # >= means from that day onwards
        {:>=, start_dt}

      true ->
        # Default to today if pattern doesn't match
        start_dt = NaiveDateTime.new!(today, ~T[00:00:00])
        end_dt = NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])
        {:between, start_dt, end_dt}
    end
  end

  # Process date shortcuts like "this_month", "last_week", etc.
  defp process_date_shortcut_filter(shortcut) do
    today = get_local_today()

    case shortcut do
      "today" ->
        start_dt = NaiveDateTime.new!(today, ~T[00:00:00])
        end_dt = NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])
        {:between, start_dt, end_dt}

      "yesterday" ->
        yesterday = Date.add(today, -1)
        start_dt = NaiveDateTime.new!(yesterday, ~T[00:00:00])
        end_dt = NaiveDateTime.new!(today, ~T[00:00:00])
        {:between, start_dt, end_dt}

      "tomorrow" ->
        tomorrow = Date.add(today, 1)
        start_dt = NaiveDateTime.new!(tomorrow, ~T[00:00:00])
        end_dt = NaiveDateTime.new!(Date.add(tomorrow, 1), ~T[00:00:00])
        {:between, start_dt, end_dt}

      "this_week" ->
        start_of_week = beginning_of_week(today)
        end_of_week = Date.add(start_of_week, 7)
        {:between, NaiveDateTime.new!(start_of_week, ~T[00:00:00]),
                  NaiveDateTime.new!(end_of_week, ~T[00:00:00])}

      "last_week" ->
        start_of_week = beginning_of_week(Date.add(today, -7))
        end_of_week = Date.add(start_of_week, 7)
        {:between, NaiveDateTime.new!(start_of_week, ~T[00:00:00]),
                  NaiveDateTime.new!(end_of_week, ~T[00:00:00])}

      "next_week" ->
        start_of_next_week = beginning_of_week(Date.add(today, 7))
        end_of_next_week = Date.add(start_of_next_week, 7)
        {:between, NaiveDateTime.new!(start_of_next_week, ~T[00:00:00]),
                  NaiveDateTime.new!(end_of_next_week, ~T[00:00:00])}

      "this_month" ->
        start_of_month = Date.beginning_of_month(today)
        start_of_next_month = Date.beginning_of_month(Date.add(today, 32))
        {:between, NaiveDateTime.new!(start_of_month, ~T[00:00:00]),
                  NaiveDateTime.new!(start_of_next_month, ~T[00:00:00])}

      "last_month" ->
        last_month = Date.add(today, -today.day)
        start_of_month = Date.beginning_of_month(last_month)
        end_of_month = Date.beginning_of_month(today)
        {:between, NaiveDateTime.new!(start_of_month, ~T[00:00:00]),
                  NaiveDateTime.new!(end_of_month, ~T[00:00:00])}

      "next_month" ->
        # Get first day of next month
        {start_of_next_month, end_of_next_month} = if today.month == 12 do
          {Date.new!(today.year + 1, 1, 1), Date.new!(today.year + 1, 2, 1)}
        else
          start_month = Date.new!(today.year, today.month + 1, 1)
          # Handle month after next
          end_month = if today.month == 11 do
            Date.new!(today.year + 1, 1, 1)
          else
            Date.new!(today.year, today.month + 2, 1)
          end
          {start_month, end_month}
        end
        {:between, NaiveDateTime.new!(start_of_next_month, ~T[00:00:00]),
                  NaiveDateTime.new!(end_of_next_month, ~T[00:00:00])}

      "this_year" ->
        start_of_year = Date.new!(today.year, 1, 1)
        start_of_next_year = Date.new!(today.year + 1, 1, 1)
        {:between, NaiveDateTime.new!(start_of_year, ~T[00:00:00]),
                  NaiveDateTime.new!(start_of_next_year, ~T[00:00:00])}

      "last_year" ->
        start_of_last_year = Date.new!(today.year - 1, 1, 1)
        start_of_this_year = Date.new!(today.year, 1, 1)
        {:between, NaiveDateTime.new!(start_of_last_year, ~T[00:00:00]),
                  NaiveDateTime.new!(start_of_this_year, ~T[00:00:00])}

      "next_year" ->
        start_of_next_year = Date.new!(today.year + 1, 1, 1)
        start_of_year_after = Date.new!(today.year + 2, 1, 1)
        {:between, NaiveDateTime.new!(start_of_next_year, ~T[00:00:00]),
                  NaiveDateTime.new!(start_of_year_after, ~T[00:00:00])}

      "this_quarter" ->
        start_of_quarter = beginning_of_quarter(today)
        # Calculate start of next quarter properly
        next_quarter_month = rem(div(today.month - 1, 3) + 1, 4) * 3 + 1
        next_quarter_year = if next_quarter_month == 1, do: today.year + 1, else: today.year
        start_of_next_quarter = Date.new!(next_quarter_year, next_quarter_month, 1)
        {:between, NaiveDateTime.new!(start_of_quarter, ~T[00:00:00]),
                  NaiveDateTime.new!(start_of_next_quarter, ~T[00:00:00])}

      "last_quarter" ->
        # Calculate last quarter
        current_quarter = div(today.month - 1, 3)
        {start_of_quarter, end_of_quarter} = if current_quarter == 0 do
          # Last quarter of previous year (Q4)
          {Date.new!(today.year - 1, 10, 1), Date.new!(today.year, 1, 1)}
        else
          # Previous quarter this year
          start_month = (current_quarter - 1) * 3 + 1
          end_month = current_quarter * 3 + 1
          {Date.new!(today.year, start_month, 1), Date.new!(today.year, end_month, 1)}
        end
        {:between, NaiveDateTime.new!(start_of_quarter, ~T[00:00:00]),
                  NaiveDateTime.new!(end_of_quarter, ~T[00:00:00])}

      "next_quarter" ->
        # Calculate next quarter
        current_quarter = div(today.month - 1, 3)
        {start_of_quarter, end_of_quarter} = if current_quarter == 3 do
          # First quarter of next year (Q1)
          {Date.new!(today.year + 1, 1, 1), Date.new!(today.year + 1, 4, 1)}
        else
          # Next quarter this year
          start_month = (current_quarter + 1) * 3 + 1
          end_month = if current_quarter == 2, do: 1, else: (current_quarter + 2) * 3 + 1
          end_year = if current_quarter == 2, do: today.year + 1, else: today.year
          {Date.new!(today.year, start_month, 1), Date.new!(end_year, end_month, 1)}
        end
        {:between, NaiveDateTime.new!(start_of_quarter, ~T[00:00:00]),
                  NaiveDateTime.new!(end_of_quarter, ~T[00:00:00])}

      "mtd" ->
        # Month to date
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)
        {:between, NaiveDateTime.new!(start_of_month, ~T[00:00:00]),
                  NaiveDateTime.new!(tomorrow, ~T[00:00:00])}

      "qtd" ->
        # Quarter to date
        start_of_quarter = beginning_of_quarter(today)
        tomorrow = Date.add(today, 1)
        {:between, NaiveDateTime.new!(start_of_quarter, ~T[00:00:00]),
                  NaiveDateTime.new!(tomorrow, ~T[00:00:00])}

      "ytd" ->
        # Year to date
        start_of_year = Date.new!(today.year, 1, 1)
        tomorrow = Date.add(today, 1)
        {:between, NaiveDateTime.new!(start_of_year, ~T[00:00:00]),
                  NaiveDateTime.new!(tomorrow, ~T[00:00:00])}

      "ytd_vs_last" ->
        # This year YTD and last year YTD
        start_of_this_year = Date.new!(today.year, 1, 1)
        start_of_last_year = Date.new!(today.year - 1, 1, 1)
        tomorrow = Date.add(today, 1)

        # Handle leap year edge case for Feb 29
        same_day_last_year = try do
          Date.new!(today.year - 1, today.month, today.day)
        rescue
          _ -> Date.new!(today.year - 1, today.month, today.day - 1)
        end

        # Return OR condition with both date ranges
        {:or, [
          {:between, NaiveDateTime.new!(start_of_this_year, ~T[00:00:00]),
                     NaiveDateTime.new!(tomorrow, ~T[00:00:00])},
          {:between, NaiveDateTime.new!(start_of_last_year, ~T[00:00:00]),
                     NaiveDateTime.new!(Date.add(same_day_last_year, 1), ~T[00:00:00])}
        ]}

      "last_ytd" ->
        # Last year's YTD to the same day
        start_of_last_year = Date.new!(today.year - 1, 1, 1)
        # Handle leap year edge case for Feb 29
        same_day_last_year = try do
          Date.new!(today.year - 1, today.month, today.day)
        rescue
          _ -> Date.new!(today.year - 1, today.month, today.day - 1)
        end
        {:between, NaiveDateTime.new!(start_of_last_year, ~T[00:00:00]),
                  NaiveDateTime.new!(Date.add(same_day_last_year, 1), ~T[00:00:00])}

      "qtd_vs_last" ->
        # This quarter QTD and same quarter last year QTD
        start_of_quarter = beginning_of_quarter(today)
        tomorrow = Date.add(today, 1)

        # Same quarter last year
        last_year_quarter_start = Date.new!(today.year - 1, start_of_quarter.month, 1)

        # Handle leap year edge case
        same_day_last_year = try do
          Date.new!(today.year - 1, today.month, today.day)
        rescue
          _ -> Date.new!(today.year - 1, today.month, today.day - 1)
        end

        {:or, [
          {:between, NaiveDateTime.new!(start_of_quarter, ~T[00:00:00]),
                     NaiveDateTime.new!(tomorrow, ~T[00:00:00])},
          {:between, NaiveDateTime.new!(last_year_quarter_start, ~T[00:00:00]),
                     NaiveDateTime.new!(Date.add(same_day_last_year, 1), ~T[00:00:00])}
        ]}

      "mtd_vs_last" ->
        # This month MTD and last month MTD
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)

        # Last month (handle January case)
        {last_month_year, last_month_month} = if today.month == 1 do
          {today.year - 1, 12}
        else
          {today.year, today.month - 1}
        end

        last_month_start = Date.new!(last_month_year, last_month_month, 1)

        # Get same day last month (handle month-end edge cases)
        days_in_last_month = Date.days_in_month(Date.new!(last_month_year, last_month_month, 1))
        last_month_day = min(today.day, days_in_last_month)
        same_day_last_month = Date.new!(last_month_year, last_month_month, last_month_day)

        {:or, [
          {:between, NaiveDateTime.new!(start_of_month, ~T[00:00:00]),
                     NaiveDateTime.new!(tomorrow, ~T[00:00:00])},
          {:between, NaiveDateTime.new!(last_month_start, ~T[00:00:00]),
                     NaiveDateTime.new!(Date.add(same_day_last_month, 1), ~T[00:00:00])}
        ]}

      "mtd_vs_last_year" ->
        # This month MTD and same month last year MTD
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)

        # Same month last year
        last_year_month_start = Date.new!(today.year - 1, today.month, 1)

        # Handle leap year edge case
        same_day_last_year = try do
          Date.new!(today.year - 1, today.month, today.day)
        rescue
          _ -> Date.new!(today.year - 1, today.month, today.day - 1)
        end

        {:or, [
          {:between, NaiveDateTime.new!(start_of_month, ~T[00:00:00]),
                     NaiveDateTime.new!(tomorrow, ~T[00:00:00])},
          {:between, NaiveDateTime.new!(last_year_month_start, ~T[00:00:00]),
                     NaiveDateTime.new!(Date.add(same_day_last_year, 1), ~T[00:00:00])}
        ]}

      shortcut when shortcut in ~w(last_7_days last_30_days last_60_days last_90_days) ->
        num_days = shortcut
          |> String.replace("last_", "")
          |> String.replace("_days", "")
          |> String.to_integer()
        # "Last 7 days" means from 6 days ago through today (inclusive), which is 7 days total
        start_date = Date.add(today, -(num_days - 1))
        {:between, NaiveDateTime.new!(start_date, ~T[00:00:00]),
                  NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])}

      shortcut when shortcut in ~w(next_7_days next_30_days) ->
        num_days = shortcut
          |> String.replace("next_", "")
          |> String.replace("_days", "")
          |> String.to_integer()
        end_date = Date.add(today, num_days + 1)
        {:between, NaiveDateTime.new!(today, ~T[00:00:00]),
                  NaiveDateTime.new!(end_date, ~T[00:00:00])}

      _ ->
        # Default to today if shortcut doesn't match
        start_dt = NaiveDateTime.new!(today, ~T[00:00:00])
        end_dt = NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])
        {:between, start_dt, end_dt}
    end
  end

  # Helper to find beginning of week (Monday)
  defp beginning_of_week(date) do
    day_of_week = Date.day_of_week(date, :monday)
    Date.add(date, -(day_of_week - 1))
  end

  # Helper to find beginning of quarter
  defp beginning_of_quarter(date) do
    quarter_month = div(date.month - 1, 3) * 3 + 1
    Date.new!(date.year, quarter_month, 1)
  end

  # Get the server's local date (no timezone adjustments)
  defp get_local_today() do
    # Use the server's local date from Erlang calendar functions
    {{year, month, day}, _time} = :calendar.local_time()
    Date.new!(year, month, day)
  end

  defp parse_datetime_preserving_time(datetime_str) do
    # Add Z suffix if not present for timezone
    datetime_str =
      cond do
        String.match?(datetime_str, ~r/Z$/) -> datetime_str
        String.match?(datetime_str, ~r/\d\d:\d\d:\d\d/) -> datetime_str <> "Z"
        String.match?(datetime_str, ~r/\d\d:\d\d/) -> datetime_str <> ":00Z"
        true -> datetime_str <> "T00:00:00Z"
      end

    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} -> datetime
      _ ->
        # Fallback to NaiveDateTime if DateTime parsing fails
        case NaiveDateTime.from_iso8601(datetime_str) do
          {:ok, datetime} -> datetime
          _ ->
            # Last resort - try to parse as date only
            case Date.from_iso8601(datetime_str) do
              {:ok, date} -> NaiveDateTime.new!(date, ~T[00:00:00])
              _ -> NaiveDateTime.utc_now()
            end
        end
    end
  end
end
