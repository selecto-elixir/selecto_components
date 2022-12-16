defmodule SelectoComponents.Helpers.Filters do
  defp _make_num_filter(filter) do
    comp = filter["comp"]

    case comp do
      "=" ->
        String.to_integer(filter["value"])

      "null" ->
        nil

      "not_null" ->
        :not_null

      "between" ->
        {:between, String.to_integer(filter["value"]), String.to_integer(filter["value2"])}

      x when x in ~w( != <= >= < >) ->
        {x, String.to_integer(filter["value"])}
    end
  end

  defp _make_string_filter(filter) do
    comp = filter["comp"]
    ## TODO
    # ignore_case = filter["ignore_case"]
    value = filter["value"]

    case comp do
      "=" -> value
      "null" -> nil
      "not_null" -> :not_null
      x when x in ~w( != <= >= < >) -> {x, value}
      ### TODO sanitize like value
      "starts" -> {:like, value <> "%"}
      "ends" -> {:like, "%" <> value}
      "contains" -> {:like, "%" <> value <> "%"}
    end
  end

  defp _make_date_filter(filter) do
    IO.inspect(filter)
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
        if selecto.config.filters[f["filter"]] do
          ## Change this to be called from Selecto instead, eg add a layer between FORM PROCESS and FILTER APPLY TODO???
          acc ++ [selecto.config.filters[f["filter"]].apply.(selecto, f)]
        else
          case selecto.config.columns[f["filter"]].type do
            x when x in [:id, :integer, :float, :decimal] ->
              acc ++ [{f["filter"], _make_num_filter(f)}]

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
              acc ++ [{f["filter"], _make_string_filter(f)}]

            x when x in [:naive_datetime, :utc_datetime] ->
              acc ++ [{f["filter"], _make_date_filter(f)}]

            {:parameterized, _, _enum_conf} ->
              # TODO check selected against enum_conf.mappings!
              acc ++ [{f["filter"], f["selected"]}]
          end
        end
    end)
  end
end
