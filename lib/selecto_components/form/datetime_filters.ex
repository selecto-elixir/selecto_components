defmodule SelectoComponents.Form.DatetimeFilters do
  @moduledoc """
  Date and time filter processing for SelectoComponents.Form.

  This module handles the conversion of various datetime filter formats
  (shortcuts, relative dates, ranges) into actual database query filters.

  ## Supported Formats

  - **Shortcuts**: "today", "yesterday", "this_week", "last_month", etc.
  - **Relative Dates**: "5" (5 days ago), "3-7" (3 to 7 days ago), "5-" (from 5 days ago onwards)
  - **Ranges**: BETWEEN with start and end dates
  - **Standard Comparisons**: >, <, >=, <=, = with datetime values
  """

  @doc """
  Process a datetime filter configuration into actual database filter(s).

  Takes a filter configuration map and converts it based on the comparison operator:
  - BETWEEN: Converts to two filters (>= start and < end)
  - SHORTCUT: Expands shortcuts like "today", "last_week" into date ranges
  - RELATIVE: Parses relative date patterns like "5", "3-7", "5-"
  - Standard ops: Parses the datetime value

  Returns either a single filter map or a list of filter maps.

  ## Examples

      iex> process_datetime_filter(%{"comp" => "SHORTCUT", "value" => "today"})
      [%{"comp" => ">=", "value" => ~N[2024-01-15 00:00:00]},
       %{"comp" => "<", "value" => ~N[2024-01-16 00:00:00]}]

      iex> process_datetime_filter(%{"comp" => ">=", "value" => "2024-01-15"})
      %{"comp" => ">=", "value" => ~N[2024-01-15 00:00:00]}
  """
  @spec process_datetime_filter(map()) :: map() | [map()]
  def process_datetime_filter(filter_config) do
    case Map.get(filter_config, "comp") do
      "BETWEEN" ->
        # Convert to SQL between with inclusive start and exclusive end
        start_date = parse_datetime_value(filter_config["value_start"])
        end_date = parse_datetime_value(filter_config["value_end"])

        # Return two filters: >= start and < end
        [
          %{filter_config | "comp" => ">=", "value" => start_date},
          %{filter_config | "comp" => "<", "value" => end_date}
        ]

      "SHORTCUT" ->
        process_date_shortcut(filter_config["value"], filter_config)

      "RELATIVE" ->
        process_relative_date(filter_config["value"], filter_config)

      _ ->
        # Standard comparison, just parse the value
        %{filter_config | "value" => parse_datetime_value(filter_config["value"])}
    end
  end

  # Process date shortcuts into actual date ranges
  defp process_date_shortcut(shortcut, base_config) do
    today = get_local_today()

    case shortcut do
      "today" ->
        start_of_day = NaiveDateTime.new!(today, ~T[00:00:00])
        end_of_day = NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])
        [
          %{base_config | "comp" => ">=", "value" => start_of_day},
          %{base_config | "comp" => "<", "value" => end_of_day}
        ]

      "yesterday" ->
        yesterday = Date.add(today, -1)
        start_of_day = NaiveDateTime.new!(yesterday, ~T[00:00:00])
        end_of_day = NaiveDateTime.new!(today, ~T[00:00:00])
        [
          %{base_config | "comp" => ">=", "value" => start_of_day},
          %{base_config | "comp" => "<", "value" => end_of_day}
        ]

      "tomorrow" ->
        tomorrow = Date.add(today, 1)
        start_of_day = NaiveDateTime.new!(tomorrow, ~T[00:00:00])
        end_of_day = NaiveDateTime.new!(Date.add(tomorrow, 1), ~T[00:00:00])
        [
          %{base_config | "comp" => ">=", "value" => start_of_day},
          %{base_config | "comp" => "<", "value" => end_of_day}
        ]

      "this_week" ->
        start_of_week = beginning_of_week(today)
        end_of_week = Date.add(start_of_week, 7)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_week, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_week, ~T[00:00:00])}
        ]

      "last_week" ->
        start_of_week = beginning_of_week(Date.add(today, -7))
        end_of_week = Date.add(start_of_week, 7)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_week, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_week, ~T[00:00:00])}
        ]

      "this_month" ->
        start_of_month = Date.beginning_of_month(today)
        start_of_next_month = Date.beginning_of_month(Date.add(today, 32))
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_next_month, ~T[00:00:00])}
        ]

      "last_month" ->
        last_month = Date.add(today, -today.day)
        start_of_month = Date.beginning_of_month(last_month)
        end_of_month = Date.beginning_of_month(today)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_month, ~T[00:00:00])}
        ]

      "next_week" ->
        start_of_next_week = beginning_of_week(Date.add(today, 7))
        end_of_next_week = Date.add(start_of_next_week, 7)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_next_week, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_next_week, ~T[00:00:00])}
        ]

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
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_next_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_next_month, ~T[00:00:00])}
        ]

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
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_quarter, ~T[00:00:00])}
        ]

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
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_quarter, ~T[00:00:00])}
        ]

      "last_year" ->
        start_of_last_year = Date.new!(today.year - 1, 1, 1)
        start_of_this_year = Date.new!(today.year, 1, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_last_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_this_year, ~T[00:00:00])}
        ]

      "next_year" ->
        start_of_next_year = Date.new!(today.year + 1, 1, 1)
        start_of_year_after = Date.new!(today.year + 2, 1, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_next_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_year_after, ~T[00:00:00])}
        ]

      "mtd" ->
        # Month to date
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "this_quarter" ->
        start_of_quarter = beginning_of_quarter(today)
        # Calculate start of next quarter properly
        next_quarter_month = rem(div(today.month - 1, 3) + 1, 4) * 3 + 1
        next_quarter_year = if next_quarter_month == 1, do: today.year + 1, else: today.year
        start_of_next_quarter = Date.new!(next_quarter_year, next_quarter_month, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_next_quarter, ~T[00:00:00])}
        ]

      "qtd" ->
        # Quarter to date
        start_of_quarter = beginning_of_quarter(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "this_year" ->
        start_of_year = Date.new!(today.year, 1, 1)
        start_of_next_year = Date.new!(today.year + 1, 1, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_next_year, ~T[00:00:00])}
        ]

      "ytd" ->
        # Year to date
        start_of_year = Date.new!(today.year, 1, 1)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "last_" <> days when days in ~w(7_days 30_days 60_days 90_days) ->
        num_days = String.to_integer(String.replace(days, "_days", ""))
        # "Last 7 days" means from 6 days ago through today (inclusive), which is 7 days total
        start_date = Date.add(today, -(num_days - 1))
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_date, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])}
        ]

      "next_" <> days when days in ~w(7_days 30_days) ->
        num_days = String.to_integer(String.replace(days, "_days", ""))
        end_date = Date.add(today, num_days + 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(today, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_date, ~T[00:00:00])}
        ]

      "ytd_vs_last" ->
        # For simplicity, just show this year's YTD for now
        # TODO: Implement proper OR support for comparing periods
        start_of_year = Date.new!(today.year, 1, 1)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "last_ytd" ->
        # Last year's YTD to the same day
        start_of_last_year = Date.new!(today.year - 1, 1, 1)
        # Handle leap year edge case for Feb 29
        same_day_last_year = try do
          Date.new!(today.year - 1, today.month, today.day)
        rescue
          _ -> Date.new!(today.year - 1, today.month, today.day - 1)
        end
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_last_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(Date.add(same_day_last_year, 1), ~T[00:00:00])}
        ]

      "qtd_vs_last" ->
        # For simplicity, just show this quarter's QTD for now
        # TODO: Implement proper OR support for comparing periods
        start_of_quarter = beginning_of_quarter(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "mtd_vs_last" ->
        # For simplicity, just show this month's MTD for now
        # TODO: Implement proper OR support for comparing periods
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "mtd_vs_last_year" ->
        # This month MTD - simplified for now
        # TODO: Implement proper OR support for comparing periods
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      _ ->
        # Unknown shortcut, return as-is
        base_config
    end
  end

  # Process relative date patterns
  defp process_relative_date(pattern, base_config) do
    today = get_local_today()

    cond do
      # Pattern: "5" - exactly 5 days ago
      Regex.match?(~r/^\d+$/, pattern) ->
        days_ago = String.to_integer(pattern)
        target_date = Date.add(today, -days_ago)
        start_of_day = NaiveDateTime.new!(target_date, ~T[00:00:00])
        end_of_day = NaiveDateTime.new!(Date.add(target_date, 1), ~T[00:00:00])
        [
          %{base_config | "comp" => ">=", "value" => start_of_day},
          %{base_config | "comp" => "<", "value" => end_of_day}
        ]

      # Pattern: "3-7" - between 3 and 7 days ago (inclusive range in the past)
      # For "13-7": 13 days ago to 7 days ago
      Regex.match?(~r/^(\d+)-(\d+)$/, pattern) ->
        [_, first_str, second_str] = Regex.run(~r/^(\d+)-(\d+)$/, pattern)
        first_days = String.to_integer(first_str)
        second_days = String.to_integer(second_str)
        # Determine the older and newer dates (larger number = further in past)
        older_days = max(first_days, second_days)
        newer_days = min(first_days, second_days)
        start_date = Date.add(today, -older_days)  # Further in the past
        end_date = Date.add(today, -newer_days + 1)  # More recent (exclusive end)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_date, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_date, ~T[00:00:00])}
        ]

      # Pattern: "-5" - all dates before 5 days ago (older than 5 days ago)
      # -0 means all dates before today (all past)
      # -1 means all dates before yesterday
      Regex.match?(~r/^-(\d+)$/, pattern) ->
        [_, days_str] = Regex.run(~r/^-(\d+)$/, pattern)
        days = String.to_integer(days_str)
        # < means before the start of N days ago
        cutoff_date = Date.add(today, -days)
        %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(cutoff_date, ~T[00:00:00])}

      # Pattern: "5-" - from 5 days ago onwards (including 5 days ago, today and future)
      # 0- means today and all future
      # 1- means from yesterday onwards
      Regex.match?(~r/^(\d+)-$/, pattern) ->
        [_, days_str] = Regex.run(~r/^(\d+)-$/, pattern)
        days = String.to_integer(days_str)
        start_date = Date.add(today, -days)
        # >= means from that day onwards
        %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_date, ~T[00:00:00])}

      true ->
        base_config
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

  # Parse datetime value from string
  defp parse_datetime_value(value) when is_binary(value) do
    cond do
      String.contains?(value, "T") ->
        case NaiveDateTime.from_iso8601(value <> ":00") do
          {:ok, dt} -> dt
          _ -> value
        end
      String.length(value) == 10 ->
        case Date.from_iso8601(value) do
          {:ok, date} -> NaiveDateTime.new!(date, ~T[00:00:00])
          _ -> value
        end
      true ->
        value
    end
  end
  defp parse_datetime_value(value), do: value
end