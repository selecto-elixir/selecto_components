defmodule SelectoComponents.Views.Aggregate.Form do
  use Phoenix.LiveComponent
  alias SelectoComponents.Views.Aggregate.Options

  # Helper function to extract field from formatted date tuples
  defp get_field_for_item(selecto, item) do
    field_name =
      case item do
        # Handle formatted date tuple {:to_char, {"field_name", "format"}}
        {:to_char, {field, _format}} -> field
        # Handle other extraction tuples if any
        {_func, field} when is_binary(field) -> field
        # Regular field name
        field when is_binary(field) or is_atom(field) -> field
        # Fallback
        _ -> nil
      end

    if field_name do
      Selecto.field(selecto, field_name)
    else
      nil
    end
  end

  def render(assigns) do
    aggregate_per_page = get_aggregate_per_page(assigns.view_config)

    assigns =
      assign(assigns,
        aggregate_per_page: aggregate_per_page,
        aggregate_per_page_options: Options.per_page_options()
      )

    ~H"""
    <div>
      <div class="mb-3 rounded-md border border-gray-200 bg-gray-50 px-3 py-2">
        <label for="aggregate_per_page" class="text-xs font-medium text-gray-700">
          Aggregate Rows/Page
        </label>
        <select
          id="aggregate_per_page"
          name="aggregate_per_page"
          class="mt-1 select select-bordered select-sm w-36 bg-white"
        >
          <%= for option <- @aggregate_per_page_options do %>
            <option value={to_string(option)} selected={@aggregate_per_page == to_string(option)}>
              {if option == "all", do: "All", else: option}
            </option>
          <% end %>
        </select>
      </div>
      Group By
      <.live_component
        module={SelectoComponents.Components.ListPicker}
        id="group_by"
        fieldname="group_by"
        view={@view}
        available={
          Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)
        }
        selected_items={@view_config.views.aggregate.group_by}
      >
        <:item_form :let={{id, item, config, index}}>
          <input name={"group_by[#{id}][field]"} type="hidden" value={item} />
          <input name={"group_by[#{id}][index]"} type="hidden" value={index} />
          <.live_component
            module={SelectoComponents.Views.Aggregate.GroupByConfig}
            id={id}
            col={get_field_for_item(@selecto, item)}
            uuid={id}
            item={item}
            columns={@columns}
            fieldname="group_by"
            prefix={ "group_by[#{id}]" }
            config={config}
          />
        </:item_form>
      </.live_component>
      Aggregates:
      <.live_component
        module={SelectoComponents.Components.ListPicker}
        id="aggregate"
        fieldname="aggregate"
        view={@view}
        available={@columns}
        selected_items={@view_config.views.aggregate.aggregate}
      >
        <:item_form :let={{id, item, config, index}}>
          <input name={"aggregate[#{id}][field]"} type="hidden" value={item} />
          <input name={"aggregate[#{id}][index]"} type="hidden" value={index} />
          <.live_component
            module={SelectoComponents.Views.Aggregate.Aggregate.Config}
            id={id}
            col={get_field_for_item(@selecto, item)}
            uuid={id}
            item={item}
            columns={@columns}
            fieldname="aggregate"
            prefix={ "aggregate[#{id}]" }
            config={config}
          />
        </:item_form>
      </.live_component>
    </div>
    """
  end

  defp get_aggregate_per_page(view_config) do
    view_config
    |> Map.get(:views, %{})
    |> Map.get(:aggregate, %{})
    |> then(fn aggregate_cfg ->
      Map.get(
        aggregate_cfg,
        :per_page,
        Map.get(aggregate_cfg, "per_page", Options.default_per_page())
      )
    end)
    |> Options.normalize_per_page_param()
  end
end
