defmodule SelectoComponents.Helpers.Filters do

  import Ecto.Type ## For cast



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

      "not_null" ->
        :not_null

      "between" ->
        {:between, parse_num(type, Map.get(filter, "value")),parse_num(type, Map.get(filter, "value2"))}

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
      "not_null" -> {Map.get(filter, "filter"), :not_null}
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
          "not_null" -> :not_null
          x when x in ~w( != <= >= < >) -> {x, value}
          ### TODO sanitize like value
          "starts" -> {:like, value <> "%"}
          "ends" -> {:like, "%" <> value}
          "contains" -> {:like, "%" <> value <> "%"}
        end

        {filpart, valpart}
    end
  end

  defp _make_date_filter(filter) do
    comp = Map.get(filter, "comp", "=")

    case comp do
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

      "DATE_BETWEEN" ->
        # For DATE_BETWEEN, use the start and end dates
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
        # Ensure we have value2 key for val_to_dates
        filter_with_value2 = Map.put_new(filter, "value2", "")
        {start, stop} = Selecto.Helpers.Date.val_to_dates(filter_with_value2)

        # Handle different comparison operators
        case comp do
          "=" -> {:between, start, stop}
          "!=" -> {:not, {:between, start, stop}}
          ">" -> {:>, stop}
          ">=" -> {:>=, start}
          "<" -> {:<, start}
          "<=" -> {:<=, stop}
          "IS NULL" -> :is_null
          "IS NOT NULL" -> :is_not_null
          _ -> {:between, start, stop}
        end
    end
  end

  ## Build filters that can be sent to the selecto
  def filter_recurse(selecto, filters, section) do
    #### TODO handle errors
    Enum.reduce(Map.get(filters, section, []), [], fn
      %{"is_section" => "Y", "uuid" => uuid, "conjunction" => conj}, acc ->
        acc ++
          [
            {case conj do
               "AND" -> :and
               "OR" -> :or
             end, filter_recurse(selecto, filters, uuid)}
          ]

      f, acc ->
        if get_in(Selecto.filters(selecto), [Map.get(f, "filter"), :apply]) do
          ## Change this to be called from Selecto instead, eg add a layer between FORM PROCESS and FILTER APPLY TODO???

          acc ++ [Selecto.filters(selecto)[Map.get(f, "filter")].apply.(selecto, f)]

        else
          # Check if column exists before accessing its type
          # Try to find the column - it might be under an alias or original name
          filter_key = Map.get(f, "filter")
          column = Selecto.columns(selecto)[filter_key]
          
          # If not found by direct key, try to find by matching colid or name
          column = if column == nil do
            Selecto.columns(selecto)
            |> Enum.find(fn {_key, col} -> 
              col.colid == filter_key || col.name == filter_key
            end)
            |> case do
              {_key, col} -> col
              nil -> nil
            end
          else
            column
          end
          
          if column == nil do
            # Skip this filter if column not found
            acc
          else
            case column.type do
            x when x in [:id, :integer, :float, :decimal] ->
              acc ++ [{Map.get(f, "filter"), _make_num_filter(x, f)}]

            :tsvector ->
              acc ++ [ make_text_search_filter(f) ]

            :boolean ->
              acc ++
                [
                  {Map.get(f, "filter"),
                   case Map.get(f, "value") do
                     "true" -> true
                     _ -> false
                   end}
                ]

            :string ->
              acc ++ [ _make_string_filter(f) ]
            
            :custom_column ->
              # Custom columns should be treated as strings for filtering purposes
              acc ++ [ _make_string_filter(f) ]

            x when x in [:naive_datetime, :utc_datetime, :date] ->
              acc ++ [{Map.get(f, "filter"), _make_date_filter(f)}]

            {:parameterized, _, _enum_conf} ->
              # TODO check selected against enum_conf.mappings!
              acc ++ [{Map.get(f, "filter"), Map.get(f, "value")}]
            end
          end
        end
    end)
  end
end
