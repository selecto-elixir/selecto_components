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
      |> Map.put(:detail_prevent_denormalization, prevent_denormalization)
      |> Map.put(:detail_per_page_options, @detail_per_page_options)
      |> Map.put(:detail_max_rows_options, Options.max_rows_options())

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
        <:item_form :let={{id, item, config, index}}>
          <input name={"selected[#{id}][field]"} type="hidden" value={item} />
          <input name={"selected[#{id}][index]"} type="hidden" value={index} />
          <input name={"selected[#{id}][uuid]"} type="hidden" value={id} />
          <.live_component
            module={SelectoComponents.Views.Detail.ColumnConfig}
            id={"selected-#{id}"}
            col={Selecto.field(@selecto, item)}
            uuid={id}
            item={item}
            columns={@columns}
            fieldname="selected"
            prefix={ "selected[#{id}]" }
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
        <:item_form :let={{id, item, config, index}}>
          <input name={"order_by[#{id}][field]"} type="hidden" value={item} />
          <input name={"order_by[#{id}][index]"} type="hidden" value={index} />
          <input name={"order_by[#{id}][uuid]"} type="hidden" value={id} />
          <.live_component
            module={SelectoComponents.Views.Detail.OrderByConfig}
            id={"order_by-#{id}-#{:erlang.phash2(config)}"}
            col={Selecto.field(@selecto, item)}
            item={item}
            columns={@columns}
            fieldname="order_by"
            prefix={ "order_by[#{id}]" }
            config={config}
          />
        </:item_form>
      </.live_component>
      <div class="mt-4 rounded-md border border-gray-200 bg-gray-50 px-3 py-2">
        <div class="grid gap-3 md:grid-cols-2">
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
end
