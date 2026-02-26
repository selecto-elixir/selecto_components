defmodule SelectoComponents.Helpers.Filters do
  alias SelectoComponents.Helpers.BucketParser

  ## For cast
  import Ecto.Type

  # Sanitize LIKE pattern values to prevent SQL injection
  # Escapes special SQL wildcard characters: %, _, \
  defp sanitize_like_value(value) when is_binary(value) do
    value
    # Escape backslash first
    |> String.replace("\\", "\\\\")
    # Escape percent
    |> String.replace("%", "\\%")
    # Escape underscore
    |> String.replace("_", "\\_")
  end

  defp sanitize_like_value(value), do: value

  defp parse_num(type, num) do
    {:ok, v} = cast(type, num)
    v
  end

  defp blank?(value) when value in [nil, ""], do: true
  defp blank?(_value), do: false

  defp normalize_comp(filter, default) do
    to_string(Map.get(filter, "comp") || default) |> String.upcase()
  end

  defp parse_csv_values(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&blank?/1)
  end

  defp parse_csv_values(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&blank?/1)
  end

  defp parse_csv_values(_value), do: []

  defp parse_between_values(filter) do
    start_raw = Map.get(filter, "value_start") || Map.get(filter, "value")
    end_raw = Map.get(filter, "value_end") || Map.get(filter, "value2")

    cond do
      is_binary(start_raw) and start_raw != "" and is_binary(end_raw) and end_raw != "" ->
        {start_raw, end_raw}

      is_binary(start_raw) and String.contains?(start_raw, ",") ->
        case String.split(start_raw, ",", parts: 2) do
          [left, right] -> {left, right}
          _ -> {start_raw, end_raw}
        end

      true ->
        {start_raw, end_raw}
    end
  end

  defp get_string_value(filter) do
    value = Map.get(filter, "value")
    if blank?(value), do: raise(ArgumentError, "value is required"), else: to_string(value)
  end

  defp _make_num_filter(type, filter) do
    comp_norm = normalize_comp(filter, "=")

    case comp_norm do
      "=" ->
        parse_num(type, Map.get(filter, "value"))

      "NULL" ->
        nil

      "IS_EMPTY" ->
        nil

      "IS NULL" ->
        nil

      "NOT_NULL" ->
        :not_null

      "IS_NOT_EMPTY" ->
        :not_null

      "IS NOT NULL" ->
        :not_null

      "BETWEEN" ->
        {start_raw, end_raw} = parse_between_values(filter)

        {:between, parse_num(type, start_raw), parse_num(type, end_raw)}

      "IN" ->
        # Parse comma-separated IDs and convert to list
        ids =
          Map.get(filter, "value", "")
          |> parse_csv_values()
          |> Enum.map(&parse_num(type, &1))

        {:in, ids}

      "NOT IN" ->
        # Parse comma-separated IDs and convert to NOT IN list
        ids =
          Map.get(filter, "value", "")
          |> parse_csv_values()
          |> Enum.map(&parse_num(type, &1))

        {:not_in, ids}

      x when x in ~w( != <= >= < >) ->
        {x, parse_num(type, Map.get(filter, "value"))}

      _ ->
        raise ArgumentError, "unsupported numeric comparison operator #{inspect(comp_norm)}"
    end
  end

  defp make_text_search_filter(filter) do
    {Map.get(filter, "filter"), {:text_search, Map.get(filter, "value")}}
  end

  defp _make_string_filter(filter) do
    comp_norm = normalize_comp(filter, "=")
    ignore_case = Map.get(filter, "ignore_case") == "Y"
    filter_field = Map.get(filter, "filter")

    filpart =
      if ignore_case do
        {:upper, filter_field}
      else
        filter_field
      end

    transform =
      fn value ->
        value = to_string(value)
        if ignore_case, do: String.upcase(value), else: value
      end

    case comp_norm do
      "NULL" ->
        {filter_field, nil}

      "IS_EMPTY" ->
        {filter_field, nil}

      "IS NULL" ->
        {filter_field, nil}

      "NOT_NULL" ->
        {filter_field, :not_null}

      "IS_NOT_EMPTY" ->
        {filter_field, :not_null}

      "IS NOT NULL" ->
        {filter_field, :not_null}

      "=" ->
        {filpart, transform.(get_string_value(filter))}

      "!=" ->
        {filpart, {"!=", transform.(get_string_value(filter))}}

      x when x in ~w(<= >= < >) ->
        {filpart, {x, transform.(get_string_value(filter))}}

      "BETWEEN" ->
        {start_raw, end_raw} = parse_between_values(filter)

        if blank?(start_raw) or blank?(end_raw) do
          raise ArgumentError, "BETWEEN requires start and end values"
        end

        {filpart, {:between, transform.(start_raw), transform.(end_raw)}}

      "IN" ->
        values = Map.get(filter, "value", "") |> parse_csv_values() |> Enum.map(transform)
        if values == [], do: raise(ArgumentError, "IN requires at least one value")
        {filpart, {:in, values}}

      "NOT IN" ->
        values = Map.get(filter, "value", "") |> parse_csv_values() |> Enum.map(transform)
        if values == [], do: raise(ArgumentError, "NOT IN requires at least one value")
        {filpart, {:not_in, values}}

      "STARTS" ->
        value = get_string_value(filter)

        if BucketParser.exclude_articles?(Map.get(filter, "exclude_articles"), false) do
          normalized_expr =
            BucketParser.normalized_text_sql(
              filter_field,
              %{"exclude_articles" => true}
            )

          normalized_value = value |> String.downcase() |> String.trim()
          {{:raw_sql, normalized_expr}, {:like, sanitize_like_value(normalized_value) <> "%"}}
        else
          value = transform.(value)
          {filpart, {:like, sanitize_like_value(value) <> "%"}}
        end

      "ENDS" ->
        value = transform.(get_string_value(filter))
        {filpart, {:like, "%" <> sanitize_like_value(value)}}

      "CONTAINS" ->
        value = transform.(get_string_value(filter))
        {filpart, {:like, "%" <> sanitize_like_value(value) <> "%"}}

      "TEXT_PREFIX" ->
        prefix_length = BucketParser.parse_prefix_length(Map.get(filter, "prefix_length"), 2)

        exclude_articles =
          BucketParser.exclude_articles?(Map.get(filter, "exclude_articles"), true)

        normalized_expr =
          BucketParser.normalized_text_sql(
            filter_field,
            %{"exclude_articles" => exclude_articles}
          )

        prefix =
          filter
          |> get_string_value()
          |> String.downcase()
          |> String.slice(0, prefix_length)

        if blank?(prefix) do
          raise ArgumentError, "TEXT_PREFIX requires a non-empty prefix value"
        end

        {{:raw_sql, normalized_expr}, {:like, sanitize_like_value(prefix) <> "%"}}

      "TEXT_PREFIX_OTHER" ->
        exclude_articles =
          BucketParser.exclude_articles?(Map.get(filter, "exclude_articles"), true)

        normalized_expr =
          BucketParser.normalized_text_sql(
            filter_field,
            %{"exclude_articles" => exclude_articles}
          )

        {:raw_sql_filter, ["(", normalized_expr, " = '')"]}

      "LIKE" ->
        value = transform.(get_string_value(filter))
        {filpart, {:like, "%" <> sanitize_like_value(value) <> "%"}}

      "NOT LIKE" ->
        value = transform.(get_string_value(filter))
        {filpart, {:not_like, "%" <> sanitize_like_value(value) <> "%"}}

      _ ->
        raise ArgumentError, "unsupported string comparison operator #{inspect(comp_norm)}"
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
    section_filters =
      Map.get(filters, section, [])
      |> Enum.reject(fn
        filter when is_binary(filter) ->
          # Check if this looks like a bucket range string
          String.match?(filter, ~r/^\d+-\d+,\d+\+$|^\d+,\d+-\d+,|\d+\+/)

        _ ->
          false
      end)

    result =
      Enum.reduce(section_filters, [], fn filter_item, acc ->
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

            Logger.warning(
              "Filter processing error: #{inspect(error)}, filter: #{inspect(filter_item)}"
            )

            acc
        end
      end)

    # Handle POLYMORPHIC filters separately
    result = result ++ handle_polymorphic_filters(section_filters)
    result
  end

  # Process a single filter with error handling
  defp process_single_filter(selecto, filters, %{
         "is_section" => "Y",
         "uuid" => uuid,
         "conjunction" => conj
       }) do
    conjunction_atom =
      case conj do
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
      filter_config = Selecto.filters(selecto)[filter_key]
      apply_fun = get_in(filter_config || %{}, [:apply])

      cond do
        is_function(apply_fun, 2) ->
          result = apply_fun.(selecto, f)
          {:ok, [result]}

        is_map(filter_config) and present_field?(filter_config) ->
          target_filter = Map.get(filter_config, :field) |> to_string()
          process_column_filter(selecto, Map.put(f, "filter", target_filter), target_filter)

        true ->
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

  defp present_field?(filter_config) do
    field = Map.get(filter_config, :field)
    field not in [nil, ""]
  end

  # Process a filter based on column type
  defp process_column_filter(selecto, f, filter_key) do
    # Try to find the column - it might be under an alias or original name
    column = find_column(selecto, filter_key)

    if column == nil do
      {:skip, {:column_not_found, filter_key}}
    else
      build_typed_filter(selecto, column, f, filter_key)
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
  defp build_typed_filter(selecto, column, f, filter_key) do
    case column.type do
      x when x in [:id, :integer, :float, :decimal] ->
        case safe_make_num_filter(x, f) do
          {:ok, filter_val} -> {:ok, [{filter_key, filter_val}]}
          {:error, reason} -> {:skip, {:invalid_numeric, reason}}
        end

      :tsvector ->
        {:ok, [make_text_search_filter(f)]}

      :boolean ->
        value =
          case Map.get(f, "value") do
            "true" -> true
            true -> true
            _ -> false
          end

        {:ok, [{filter_key, value}]}

      :string ->
        case enum_values_for_filter(selecto, filter_key, column) do
          nil ->
            case safe_make_string_filter(f) do
              {:ok, filter_val} -> {:ok, [filter_val]}
              {:error, reason} -> {:skip, {:invalid_string, reason}}
            end

          enum_values ->
            case safe_make_enum_filter(filter_key, f, enum_values) do
              {:ok, filter_val} -> {:ok, [filter_val]}
              {:error, reason} -> {:skip, {:invalid_enum, reason}}
            end
        end

      :custom_column ->
        case safe_make_string_filter(f) do
          {:ok, filter_val} -> {:ok, [filter_val]}
          {:error, reason} -> {:skip, {:invalid_custom_column, reason}}
        end

      x when x in [:naive_datetime, :utc_datetime, :date] ->
        case safe_make_date_filter(f) do
          {:ok, {:or, conditions}} ->
            or_filters =
              Enum.map(conditions, fn filter_val ->
                {filter_key, filter_val}
              end)

            {:ok, [{:or, or_filters}]}

          {:ok, filter_val} ->
            {:ok, [{filter_key, filter_val}]}

          {:error, reason} ->
            {:skip, {:invalid_date, reason}}
        end

      {:array, _inner_type} ->
        case safe_make_array_filter(filter_key, f) do
          {:ok, filter_val} -> {:ok, [filter_val]}
          {:error, reason} -> {:skip, {:invalid_array, reason}}
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

        Logger.debug(
          "Unknown column type #{inspect(unknown_type)} for filter #{filter_key}, treating as string"
        )

        case safe_make_string_filter(f) do
          {:ok, filter_val} -> {:ok, [filter_val]}
          {:error, reason} -> {:skip, {:invalid_unknown_type, reason}}
        end
    end
  end

  # Safe wrapper for numeric filter creation
  defp safe_make_num_filter(type, filter) do
    {:ok, _make_num_filter(type, filter)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Safe wrapper for string filter creation
  defp safe_make_string_filter(filter) do
    {:ok, _make_string_filter(filter)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Safe wrapper for array filter creation
  defp safe_make_array_filter(filter_key, filter) do
    {:ok, _make_array_filter(filter_key, filter)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Safe wrapper for enum filter creation
  defp safe_make_enum_filter(filter_key, filter, enum_values) do
    {:ok, _make_enum_filter(filter_key, filter, enum_values)}
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

  defp _make_array_filter(filter_key, filter) do
    comp_norm = normalize_comp(filter, "LIKE")

    case comp_norm do
      "NULL" ->
        {filter_key, nil}

      "IS_EMPTY" ->
        {filter_key, nil}

      "IS NULL" ->
        {filter_key, nil}

      "NOT_NULL" ->
        {filter_key, :not_null}

      "IS_NOT_EMPTY" ->
        {filter_key, :not_null}

      "IS NOT NULL" ->
        {filter_key, :not_null}

      "IN" ->
        values = Map.get(filter, "value", "") |> parse_csv_values()
        if values == [], do: raise(ArgumentError, "IN requires at least one value")
        {:array_overlap, filter_key, values}

      "NOT IN" ->
        values = Map.get(filter, "value", "") |> parse_csv_values()
        if values == [], do: raise(ArgumentError, "NOT IN requires at least one value")
        {:not, {:array_overlap, filter_key, values}}

      "!=" ->
        value = get_string_value(filter)
        {:not, {filter_key, {:contains, value}}}

      "NOT LIKE" ->
        value = get_string_value(filter)
        {:not, {filter_key, {:contains, value}}}

      "=" ->
        value = get_string_value(filter)
        {filter_key, {:contains, value}}

      "LIKE" ->
        value = get_string_value(filter)
        {filter_key, {:contains, value}}

      _ ->
        raise ArgumentError, "unsupported array comparison operator #{inspect(comp_norm)}"
    end
  end

  defp _make_enum_filter(filter_key, filter, enum_values) do
    comp_norm = normalize_comp(filter, "=")

    case comp_norm do
      "NULL" ->
        {filter_key, nil}

      "IS_EMPTY" ->
        {filter_key, nil}

      "IS NULL" ->
        {filter_key, nil}

      "NOT_NULL" ->
        {filter_key, :not_null}

      "IS_NOT_EMPTY" ->
        {filter_key, :not_null}

      "IS NOT NULL" ->
        {filter_key, :not_null}

      "=" ->
        value = get_string_value(filter)
        validate_enum_value!(value, enum_values)
        {filter_key, value}

      "!=" ->
        value = get_string_value(filter)
        validate_enum_value!(value, enum_values)
        {filter_key, {"!=", value}}

      "IN" ->
        values = Map.get(filter, "value", "") |> parse_csv_values()
        if values == [], do: raise(ArgumentError, "IN requires at least one value")
        Enum.each(values, &validate_enum_value!(&1, enum_values))
        {filter_key, {:in, values}}

      "NOT IN" ->
        values = Map.get(filter, "value", "") |> parse_csv_values()
        if values == [], do: raise(ArgumentError, "NOT IN requires at least one value")
        Enum.each(values, &validate_enum_value!(&1, enum_values))
        {filter_key, {:not_in, values}}

      _ ->
        raise ArgumentError, "unsupported enum comparison operator #{inspect(comp_norm)}"
    end
  end

  defp validate_enum_value!(value, enum_values) do
    if to_string(value) in enum_values do
      :ok
    else
      raise ArgumentError,
            "Value '#{value}' is not a valid enum value. Allowed: #{Enum.join(enum_values, ", ")}"
    end
  end

  defp enum_values_for_filter(selecto, filter_key, column) do
    resolved = Selecto.field(selecto, filter_key) || column
    field = Map.get(resolved, :field)
    join_ref = Map.get(resolved, :requires_join)

    with {:ok, field_atom} <- to_existing_atom_safe(field),
         {:ok, schema_module} <- schema_module_for_join(join_ref, selecto),
         true <- function_exported?(schema_module, :__schema__, 2),
         {:parameterized, {Ecto.Enum, enum_conf}} <- schema_module.__schema__(:type, field_atom) do
      enum_values_from_config(enum_conf)
    else
      _ -> nil
    end
  end

  defp enum_values_from_config(enum_conf) do
    cond do
      is_map(enum_conf) and is_map(Map.get(enum_conf, :on_dump)) ->
        enum_conf
        |> Map.get(:on_dump)
        |> Map.values()
        |> Enum.map(&to_string/1)
        |> Enum.uniq()

      is_map(enum_conf) and is_list(Map.get(enum_conf, :mappings)) ->
        enum_conf
        |> Map.get(:mappings)
        |> Enum.map(fn
          {_k, v} -> to_string(v)
          v -> to_string(v)
        end)
        |> Enum.uniq()

      true ->
        nil
    end
  end

  defp schema_module_for_join(:selecto_root, selecto) do
    case get_in(Selecto.domain(selecto), [:source, :schema_module]) do
      module when is_atom(module) -> {:ok, module}
      _ -> :error
    end
  end

  defp schema_module_for_join(join_ref, selecto) when is_atom(join_ref) do
    case get_in(Selecto.domain(selecto), [:schemas, join_ref, :schema_module]) do
      module when is_atom(module) -> {:ok, module}
      _ -> :error
    end
  end

  defp schema_module_for_join(join_ref, selecto) when is_binary(join_ref) do
    case to_existing_atom_safe(join_ref) do
      {:ok, join_atom} -> schema_module_for_join(join_atom, selecto)
      :error -> :error
    end
  end

  defp schema_module_for_join(_, _), do: :error

  defp to_existing_atom_safe(value) when is_atom(value), do: {:ok, value}

  defp to_existing_atom_safe(value) when is_binary(value) do
    try do
      {:ok, String.to_existing_atom(value)}
    rescue
      ArgumentError -> :error
    end
  end

  defp to_existing_atom_safe(_), do: :error

  # Validate enum value against allowed mappings
  defp validate_enum_value(nil, _enum_conf), do: :ok
  defp validate_enum_value("", _enum_conf), do: :ok

  defp validate_enum_value(value, enum_conf) do
    # Extract mappings from enum configuration
    mappings =
      case enum_conf do
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
          {:error,
           "Value '#{value}' is not a valid enum value. Allowed: #{Enum.join(valid_keys, ", ")}"}
        end

      mappings when is_list(mappings) ->
        # List of allowed values
        valid_values =
          Enum.map(mappings, fn
            {k, _v} -> to_string(k)
            v -> to_string(v)
          end)

        if to_string(value) in valid_values do
          :ok
        else
          {:error,
           "Value '#{value}' is not a valid enum value. Allowed: #{Enum.join(valid_values, ", ")}"}
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
        selected_types =
          case Map.get(f, "selected_types") do
            json when is_binary(json) -> Jason.decode!(json)
            list when is_list(list) -> list
            _ -> []
          end

        poly_values = Map.get(f, "poly_values", %{})

        # Build OR conditions: (type='Product' AND id IN (1,2,3)) OR (type='Order' AND id IN (4,5))
        type_conditions =
          Enum.flat_map(selected_types, fn entity_type ->
            ids_str = Map.get(poly_values, entity_type, "")
            ids = parse_poly_ids(ids_str)

            if length(ids) > 0 do
              # Generate condition: type = 'Product' AND id IN (1,2,3)
              filter_name = Map.get(f, "filter")
              # e.g., "commentable_type"
              type_field = "#{filter_name}_type"
              # e.g., "commentable_id"
              id_field = "#{filter_name}_id"

              [
                {:and,
                 [
                   {type_field, entity_type},
                   {id_field, {:in, ids}}
                 ]}
              ]
            else
              []
            end
          end)

        if length(type_conditions) > 0 do
          [{:or, type_conditions}]
        else
          []
        end

      _ ->
        []
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
        {start_of_next_month, end_of_next_month} =
          if today.month == 12 do
            {Date.new!(today.year + 1, 1, 1), Date.new!(today.year + 1, 2, 1)}
          else
            start_month = Date.new!(today.year, today.month + 1, 1)
            # Handle month after next
            end_month =
              if today.month == 11 do
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

        {start_of_quarter, end_of_quarter} =
          if current_quarter == 0 do
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

        {start_of_quarter, end_of_quarter} =
          if current_quarter == 3 do
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
        same_day_last_year =
          try do
            Date.new!(today.year - 1, today.month, today.day)
          rescue
            _ -> Date.new!(today.year - 1, today.month, today.day - 1)
          end

        # Return OR condition with both date ranges
        {:or,
         [
           {:between, NaiveDateTime.new!(start_of_this_year, ~T[00:00:00]),
            NaiveDateTime.new!(tomorrow, ~T[00:00:00])},
           {:between, NaiveDateTime.new!(start_of_last_year, ~T[00:00:00]),
            NaiveDateTime.new!(Date.add(same_day_last_year, 1), ~T[00:00:00])}
         ]}

      "last_ytd" ->
        # Last year's YTD to the same day
        start_of_last_year = Date.new!(today.year - 1, 1, 1)
        # Handle leap year edge case for Feb 29
        same_day_last_year =
          try do
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
        same_day_last_year =
          try do
            Date.new!(today.year - 1, today.month, today.day)
          rescue
            _ -> Date.new!(today.year - 1, today.month, today.day - 1)
          end

        {:or,
         [
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
        {last_month_year, last_month_month} =
          if today.month == 1 do
            {today.year - 1, 12}
          else
            {today.year, today.month - 1}
          end

        last_month_start = Date.new!(last_month_year, last_month_month, 1)

        # Get same day last month (handle month-end edge cases)
        days_in_last_month = Date.days_in_month(Date.new!(last_month_year, last_month_month, 1))
        last_month_day = min(today.day, days_in_last_month)
        same_day_last_month = Date.new!(last_month_year, last_month_month, last_month_day)

        {:or,
         [
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
        same_day_last_year =
          try do
            Date.new!(today.year - 1, today.month, today.day)
          rescue
            _ -> Date.new!(today.year - 1, today.month, today.day - 1)
          end

        {:or,
         [
           {:between, NaiveDateTime.new!(start_of_month, ~T[00:00:00]),
            NaiveDateTime.new!(tomorrow, ~T[00:00:00])},
           {:between, NaiveDateTime.new!(last_year_month_start, ~T[00:00:00]),
            NaiveDateTime.new!(Date.add(same_day_last_year, 1), ~T[00:00:00])}
         ]}

      shortcut when shortcut in ~w(last_7_days last_30_days last_60_days last_90_days) ->
        num_days =
          shortcut
          |> String.replace("last_", "")
          |> String.replace("_days", "")
          |> String.to_integer()

        # "Last 7 days" means from 6 days ago through today (inclusive), which is 7 days total
        start_date = Date.add(today, -(num_days - 1))

        {:between, NaiveDateTime.new!(start_date, ~T[00:00:00]),
         NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])}

      shortcut when shortcut in ~w(next_7_days next_30_days) ->
        num_days =
          shortcut
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
      {:ok, datetime, _} ->
        datetime

      _ ->
        # Fallback to NaiveDateTime if DateTime parsing fails
        case NaiveDateTime.from_iso8601(datetime_str) do
          {:ok, datetime} ->
            datetime

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
