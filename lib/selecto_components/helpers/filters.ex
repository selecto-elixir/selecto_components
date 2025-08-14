defmodule SelectoComponents.Helpers.Filters do

  import Ecto.Type ## For cast



  defp parse_num(type, num) do
    {:ok, v} = cast(type, num)
    v
  end


  defp _make_num_filter(type, filter)  do
    comp = filter["comp"]
    case comp do
      "=" ->
        parse_num(type, filter["value"])

      "null" ->
        nil

      "not_null" ->
        :not_null

      "between" ->
        {:between, parse_num(type, filter["value"]),parse_num(type, filter["value2"])}

      x when x in ~w( != <= >= < >) ->
        {x, parse_num(type, filter["value"])}
    end
  end

  defp make_text_search_filter(filter) do
    { filter["filter"], {:text_search, filter["value"]}}
  end

  defp _make_string_filter(filter) do
    comp = filter["comp"]

    case comp do
      "null" -> {filter["filter"], nil}
      "not_null" -> {filter["filter"], :not_null}
      _ ->
        ignore_case = filter["ignore_case"]

        {filpart, value} = if ignore_case == "Y" do
          {
            {:upper, filter["filter"]},
            String.upcase( filter["value"] )}
        else
          {filter["filter"], filter["value"]}
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
    {start, stop} = Selecto.Helpers.Date.val_to_dates(filter)
    {:between, start, stop}
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
        if get_in(Selecto.filters(selecto), [f["filter"], :apply]) do
          ## Change this to be called from Selecto instead, eg add a layer between FORM PROCESS and FILTER APPLY TODO???

          acc ++ [Selecto.filters(selecto)[f["filter"]].apply.(selecto, f)]

        else
          case Selecto.columns(selecto)[f["filter"]].type do
            x when x in [:id, :integer, :float, :decimal] ->
              acc ++ [{f["filter"], _make_num_filter(x, f)}]

            :tsvector ->
              acc ++ [ make_text_search_filter(f) ]

            :boolean ->
              acc ++
                [
                  {f["filter"],
                   case f["value"] do
                     "true" -> true
                     _ -> false
                   end}
                ]

            :string ->
              acc ++ [ _make_string_filter(f) ]

            x when x in [:naive_datetime, :utc_datetime] ->
              acc ++ [{f["filter"], _make_date_filter(f)}]

            {:parameterized, _, _enum_conf} ->
              # TODO check selected against enum_conf.mappings!
              acc ++ [{f["filter"], f["value"]}]
          end
        end
    end)
  end
end
