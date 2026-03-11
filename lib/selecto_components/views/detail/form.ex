defmodule SelectoComponents.Views.Detail.Form do
  use Phoenix.LiveComponent
  alias SelectoComponents.Views.Detail.Options

  @detail_per_page_options [30, 60, 100]

  def render(assigns) do
    detail_config =
      assigns.view_config
      |> Map.get(:views, %{})
      |> Map.get(:detail, %{})

    # Convert arrays to tuples for ListPicker compatibility
    selected_items =
      Map.get(detail_config, :selected, Map.get(detail_config, "selected", []))
      |> Enum.map(fn
        [uuid, field, config] -> {uuid, field, config}
        {uuid, field, config} -> {uuid, field, config}
        other -> other
      end)

    # Similarly for order_by
    order_by_items =
      Map.get(detail_config, :order_by, Map.get(detail_config, "order_by", []))
      |> Enum.map(fn
        [uuid, field, config] -> {uuid, field, config}
        {uuid, field, config} -> {uuid, field, config}
        other -> other
      end)

    per_page =
      detail_config
      |> Map.get(:per_page, Map.get(detail_config, "per_page", "30"))
      |> to_string()

    max_rows =
      detail_config
      |> Map.get(:max_rows, Map.get(detail_config, "max_rows", "1000"))
      |> to_string()

    count_mode =
      detail_config
      |> Map.get(:count_mode, Map.get(detail_config, "count_mode", Options.default_count_mode()))
      |> to_string()

    prevent_denormalization =
      Map.get(
        detail_config,
        :prevent_denormalization,
        Map.get(detail_config, "prevent_denormalization", true)
      )

    assigns =
      assigns
      |> Map.put(:selected_items_converted, selected_items)
      |> Map.put(:order_by_items_converted, order_by_items)
      |> Map.put(:detail_per_page, per_page)
      |> Map.put(:detail_max_rows, max_rows)
      |> Map.put(:detail_count_mode, count_mode)
      |> Map.put(:detail_prevent_denormalization, prevent_denormalization)
      |> Map.put(:detail_per_page_options, @detail_per_page_options)
      |> Map.put(:detail_max_rows_options, Options.max_rows_options())
      |> Map.put(:detail_count_mode_options, Options.count_mode_options())

    ~H"""
    <div>
      Columns
      <.live_component
        module={SelectoComponents.Components.ListPicker}
        id="selected"
        fieldname="selected"
        available={@columns}
        view={@view}
        selected_items={@selected_items_converted}
      >
        <:item_summary :let={{_id, item, config, _index}}>
          <% col = Selecto.field(@selecto, item) %>
          <span class="truncate"><%= summary_title(config, column_display_name(@columns, item, col)) %></span>
          <span class="truncate text-sm font-normal text-base-content/60"><%= detail_format_summary(col, config) %></span>
        </:item_summary>
        <:item_form :let={{id, item, config, index}}>
          <% param_key = compact_param_key(index) %>
          <input name={"selected[#{param_key}][field]"} type="hidden" value={item} />
          <input name={"selected[#{param_key}][index]"} type="hidden" value={index} />
          <input name={"selected[#{param_key}][uuid]"} type="hidden" value={id} />
          <.live_component
            module={SelectoComponents.Views.Detail.ColumnConfig}
            id={"selected-#{id}"}
            col={Selecto.field(@selecto, item)}
            uuid={id}
            item={item}
            columns={@columns}
            fieldname="selected"
            prefix={"selected[#{param_key}]"}
            config={config}
          />
        </:item_form>
      </.live_component>
      Order by
      <.live_component
        module={SelectoComponents.Components.ListPicker}
        id="order_by"
        fieldname="order_by"
        available={@columns}
        view={@view}
        selected_items={@order_by_items_converted}
      >
        <:item_summary :let={{_id, item, config, _index}}>
          <span class="truncate"><%= summary_title(config, column_display_name(@columns, item, Selecto.field(@selecto, item))) %></span>
          <span class="truncate text-sm font-normal text-base-content/60"><%= order_direction_summary(config) %></span>
        </:item_summary>
        <:item_form :let={{id, item, config, index}}>
          <% param_key = compact_param_key(index) %>
          <input name={"order_by[#{param_key}][field]"} type="hidden" value={item} />
          <input name={"order_by[#{param_key}][index]"} type="hidden" value={index} />
          <input name={"order_by[#{param_key}][uuid]"} type="hidden" value={id} />
          <.live_component
            module={SelectoComponents.Views.Detail.OrderByConfig}
            id={"order_by-#{id}-#{:erlang.phash2(config)}"}
            col={Selecto.field(@selecto, item)}
            item={item}
            columns={@columns}
            fieldname="order_by"
            prefix={"order_by[#{param_key}]"}
            config={config}
          />
        </:item_form>
      </.live_component>
      <div class="mt-4 rounded-md border border-gray-200 bg-gray-50 px-3 py-2">
        <div class="grid gap-3 md:grid-cols-3">
          <label class="block text-sm">
            <span class="text-xs font-medium text-gray-700">Rows Per Page</span>
            <select name="per_page" class="mt-1 select select-bordered select-sm w-full bg-white">
              <option
                :for={i <- @detail_per_page_options}
                selected={@detail_per_page == to_string(i)}
                value={i}
              >
                {i}
              </option>
            </select>
          </label>

          <label class="block text-sm">
            <span class="text-xs font-medium text-gray-700">Max Rows Returned</span>
            <select
              name="max_rows"
              class="mt-1 select select-bordered select-sm w-full bg-white"
            >
              <option
                :for={option <- @detail_max_rows_options}
                selected={@detail_max_rows == to_string(option)}
                value={to_string(option)}
              >
                {if option == "all", do: "All", else: option}
              </option>
            </select>
          </label>

          <label class="block text-sm">
            <span class="text-xs font-medium text-gray-700">Count Strategy</span>
            <select name="count_mode" class="mt-1 select select-bordered select-sm w-full bg-white">
              <option
                :for={option <- @detail_count_mode_options}
                selected={@detail_count_mode == to_string(option)}
                value={to_string(option)}
              >
                {case option do
                  "exact" -> "Exact"
                  "bounded" -> "Bounded"
                  "none" -> "None"
                  other -> other
                end}
              </option>
            </select>
          </label>
        </div>
      </div>

      <div class="mt-4">
        <label class="flex items-center space-x-2">
          <input
            type="checkbox"
            name="prevent_denormalization"
            checked={@detail_prevent_denormalization}
            class="rounded border-gray-300"
          />
          <span class="text-sm">Prevent Denormalization (show related data in nested tables)</span>
        </label>
      </div>
    </div>
    """
  end

  defp compact_param_key(index) when is_integer(index), do: "k" <> Integer.to_string(index, 36)

  defp column_display_name(columns, item, col) do
    item_str = to_string(item || "")

    case Enum.find(columns || [], fn
           {id, _name, _type} -> to_string(id) == item_str
           {id, _name, _type, _metadata} -> to_string(id) == item_str
           _ -> false
         end) do
      {_id, name, _type} -> name
      {_id, name, _type, _metadata} -> name
      _ -> if(col && Map.get(col, :name), do: col.name, else: item_str)
    end
  end

  defp summary_title(config, field_name) do
    case Map.get(config || %{}, "alias", "") do
      value when value in [nil, ""] -> field_name
      value -> "#{value} / #{field_name}"
    end
  end

  defp detail_format_summary(col, config) do
    type = Map.get(col || %{}, :type, :string)

    case type do
      x when x in [:int, :id] ->
        if Map.get(config, "commas"), do: "commas", else: "default"

      x when x in [:float, :decimal] ->
        commas = if(Map.get(config, "commas"), do: "commas, ", else: "")
        decimals = Map.get(config, "decimal_places", "default decimals")
        commas <> to_string(decimals)

      x when x in [:naive_datetime, :utc_datetime, :date] ->
        case Map.get(config, "format") do
          value when value in [nil, ""] -> "default"
          "age_buckets" -> "age buckets"
          "custom_buckets" -> "custom buckets"
          value -> to_string(value)
        end

      _ ->
        if is_function(Map.get(col || %{}, :configure_component)) do
          "custom options"
        else
          "default"
        end
    end
  end

  defp order_direction_summary(config) do
    case Map.get(config || %{}, "dir", "asc") do
      "desc" -> "descending"
      _ -> "ascending"
    end
  end
end
