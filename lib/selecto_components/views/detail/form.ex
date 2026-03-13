defmodule SelectoComponents.Views.Detail.Form do
  use Phoenix.LiveComponent
  alias SelectoComponents.Views.Detail.Options
  alias SelectoComponents.Views.Detail.RowActions

  @detail_per_page_options [30, 60, 100]

  @impl true
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

    row_click_action = current_row_click_action(assigns, detail_config)

    prevent_denormalization =
      Map.get(
        detail_config,
        :prevent_denormalization,
        Map.get(detail_config, "prevent_denormalization", true)
      )

    row_action_options = RowActions.available_actions(assigns.selecto)

    selected_row_action =
      Enum.find(row_action_options, fn action -> action.id == row_click_action end)

    assigns =
      assigns
      |> Map.put(:selected_items_converted, selected_items)
      |> Map.put(:order_by_items_converted, order_by_items)
      |> Map.put(:detail_per_page, per_page)
      |> Map.put(:detail_max_rows, max_rows)
      |> Map.put(:detail_count_mode, count_mode)
      |> Map.put(:detail_row_click_action, row_click_action)
      |> Map.put(:detail_prevent_denormalization, prevent_denormalization)
      |> Map.put(:detail_per_page_options, @detail_per_page_options)
      |> Map.put(:detail_max_rows_options, Options.max_rows_options())
      |> Map.put(:detail_count_mode_options, Options.count_mode_options())
      |> Map.put(:row_action_options, row_action_options)
      |> Map.put(:selected_row_action, selected_row_action)
      |> Map.put(:detail_row_click_action_dom_id, row_click_action_dom_id(row_click_action))

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
      <div class="mt-4 rounded-md border border-base-300 bg-base-200 px-3 py-2">
        <div class="grid gap-3 md:grid-cols-3">
          <label class="block text-sm">
            <span class="text-xs font-medium text-base-content/80">Rows Per Page</span>
            <select
              name="per_page"
              class="mt-1 select select-bordered select-sm w-full border-base-300 bg-base-100 text-base-content"
            >
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
            <span class="text-xs font-medium text-base-content/80">Max Rows Returned</span>
            <select
              name="max_rows"
              class="mt-1 select select-bordered select-sm w-full border-base-300 bg-base-100 text-base-content"
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
            <span class="text-xs font-medium text-base-content/80">Count Strategy</span>
            <select
              name="count_mode"
              class="mt-1 select select-bordered select-sm w-full border-base-300 bg-base-100 text-base-content"
            >
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

      <div class="mt-4 rounded-md border border-base-300 bg-base-200 px-3 py-2">
        <label class="block text-sm">
          <span class="text-xs font-medium text-base-content/80">Row Click Action</span>
          <select
            id={@detail_row_click_action_dom_id}
            name="row_click_action"
            value={@detail_row_click_action}
            phx-change="set_row_click_action"
            phx-target={@myself}
            class="mt-1 select select-bordered select-sm w-full border-base-300 bg-base-100 text-base-content"
          >
            <option value="" selected={@detail_row_click_action == ""}>None</option>
            <option
              :for={action <- @row_action_options}
              value={action.id}
              selected={@detail_row_click_action == action.id}
            >
              {action.name}
            </option>
          </select>
        </label>

        <div :if={@selected_row_action} class="mt-3 space-y-1 text-xs text-base-content/70">
          <div>
            <span class="font-medium text-base-content/80">Type:</span>
            {row_action_type_label(@selected_row_action.type)}
          </div>
          <div :if={@selected_row_action.description}>
            <span class="font-medium text-base-content/80">Description:</span>
            {@selected_row_action.description}
          </div>
          <div>
            <span class="font-medium text-base-content/80">Required fields:</span>
            {required_fields_label(@selected_row_action.required_fields)}
          </div>
        </div>
      </div>

      <div class="mt-4">
        <label class="flex items-center space-x-2">
          <input
            type="checkbox"
            name="prevent_denormalization"
            checked={@detail_prevent_denormalization}
            class="rounded border-base-300 bg-base-100 text-primary"
          />
          <span class="text-sm text-base-content/80">
            Prevent Denormalization (show related data in nested tables)
          </span>
        </label>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_row_click_action", params, socket) do
    action_id =
      case params do
        %{"row_click_action" => action_id} -> action_id
        %{"value" => %{"row_click_action" => action_id}} -> action_id
        %{"value" => action_id} when is_binary(action_id) -> action_id
        _ -> ""
      end

    normalized_action_id = Options.normalize_row_click_action_param(action_id)

    updated_view_config =
      update_in(
        socket.assigns.view_config,
        [Access.key(:views, %{}), Access.key(:detail, %{})],
        fn detail_config ->
          Map.put(detail_config, :row_click_action, normalized_action_id)
        end
      )

    send(self(), {:update_view_config, updated_view_config})

    {:noreply, assign(socket, view_config: updated_view_config)}
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
          value -> format_summary_label(value)
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

  defp format_summary_label(value) do
    value
    |> SelectoComponents.Helpers.aggregate_datetime_format_label()
    |> String.downcase()
  end

  defp row_action_type_label(:modal), do: "Modal"
  defp row_action_type_label(:iframe_modal), do: "Iframe modal"
  defp row_action_type_label(:external_link), do: "Open link"
  defp row_action_type_label(:live_component), do: "Live component"
  defp row_action_type_label(_type), do: "Unknown"

  defp required_fields_label([]), do: "None"
  defp required_fields_label(fields), do: Enum.join(fields, ", ")

  defp current_row_click_action(_assigns, detail_config) do
    detail_config
    |> Map.get(:row_click_action, Map.get(detail_config, "row_click_action"))
    |> Options.normalize_row_click_action_param()
  end

  defp row_click_action_dom_id(""), do: "detail-row-click-action-none"
  defp row_click_action_dom_id(nil), do: "detail-row-click-action-none"
  defp row_click_action_dom_id(action_id), do: "detail-row-click-action-#{action_id}"
end
