defmodule SelectoComponents.Views.Detail.Form do
  use Phoenix.LiveComponent

  def render(assigns) do
    # Convert arrays to tuples for ListPicker compatibility
    selected_items = Map.get(assigns.view_config.views.detail || %{}, :selected, [])
    |> Enum.map(fn
      [uuid, field, config] -> {uuid, field, config}
      {uuid, field, config} -> {uuid, field, config}
      other -> other
    end)

    # Similarly for order_by
    order_by_items = Map.get(assigns.view_config.views.detail || %{}, :order_by, [])
    |> Enum.map(fn
      [uuid, field, config] -> {uuid, field, config}
      {uuid, field, config} -> {uuid, field, config}
      other -> other
    end)

    assigns = assigns
    |> Map.put(:selected_items_converted, selected_items)
    |> Map.put(:order_by_items_converted, order_by_items)

    ~H"""
      <div>
        Columns
        <.live_component
            module={SelectoComponents.Components.ListPicker}
            id="selected"
            fieldname="selected"
            available={@columns}
            view={@view}
            selected_items={@selected_items_converted}>
          <:item_form :let={{id, item, config, index} }>
            <input name={"selected[#{id}][field]"} type="hidden" value={item}/>
            <input name={"selected[#{id}][index]"} type="hidden" value={index}/>
            <input name={"selected[#{id}][uuid]"} type="hidden" value={id}/>
            <.live_component
              module={SelectoComponents.Views.Detail.ColumnConfig}
              id={"selected-#{id}"}
              col={Selecto.field(@selecto, item)}
              uuid={id}
              item={item}
              fieldname="selected"
              prefix={ "selected[#{id}]" }

              config={config}/>
          </:item_form>
        </.live_component>
        Order by
        <.live_component
            module={SelectoComponents.Components.ListPicker}
            id="order_by"
            fieldname="order_by"
            available={@columns}
            view={@view}
            selected_items={@order_by_items_converted}>
          <:item_form :let={{id, item, config, index} }>
            <input name={"order_by[#{id}][field]"} type="hidden" value={item}/>
            <input name={"order_by[#{id}][index]"} type="hidden" value={index}/>
            <input name={"order_by[#{id}][uuid]"} type="hidden" value={id}/>
            <.live_component
              module={SelectoComponents.Views.Detail.OrderByConfig}
              id={"order_by-#{id}-#{:erlang.phash2(config)}"}
              col={Selecto.field(@selecto, item)}
              item={item}
              fieldname="order_by"
              prefix={ "order_by[#{id}]" }
              config={config}/>
          </:item_form>
        </.live_component>
        Pagination
        Per Page:
        <select name="per_page">
          <option :for={i <- [30, 60, 100]} selected={Map.get(@view_config.views.detail || %{}, :per_page, "30") == to_string(i)} value={i}><%= i %></option>
        </select>
        
        <div class="mt-4">
          <label class="flex items-center space-x-2">
            <input
              type="checkbox"
              name="prevent_denormalization"
              checked={Map.get(@view_config.views.detail, :prevent_denormalization, true)}
              class="rounded border-gray-300"
            />
            <span class="text-sm">Prevent Denormalization (show related data in nested tables)</span>
          </label>
        </div>
      </div>


    """
  end
end
