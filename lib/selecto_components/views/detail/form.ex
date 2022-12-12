defmodule SelectoComponents.Views.Detail.Form do

  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common

  def render(assigns) do

    ~H"""
      <div>
        Columns
        <.live_component
            module={SelectoComponents.Components.ListPicker}
            id="selected"
            fieldname="selected"
            available={@columns}
            selected_items={@view_config.views.detail.selected}>
          <:item_form :let={{id, item, config, index} }>
            <input name={"selected[#{id}][field]"} type="hidden" value={item}/>
            <input name={"selected[#{id}][index]"} type="hidden" value={index}/>
            <input name={"selected[#{id}][uuid]"} type="hidden" value={id}/>
            <.live_component
              module={SelectoComponents.Views.Detail.ColumnConfig}
              id={id}
              col={@selecto.config.columns[item]}
              uuid={id}
              item={item}
              fieldname="selected"
              config={config}/>
          </:item_form>
        </.live_component>
        Order by
        <.live_component
            module={SelectoComponents.Components.ListPicker}
            id="order_by"
            fieldname="order_by"
            available={@columns}
            selected_items={@view_config.views.detail.order_by}>
          <:item_form :let={{id, item, config, index} }>
            <input name={"order_by[#{id}][field]"} type="hidden" value={item}/>
            <input name={"order_by[#{id}][index]"} type="hidden" value={index}/>
            <.live_component
              module={SelectoComponents.Views.Detail.OrderByConfig}
              id={id}
              col={@selecto.config.columns[item]}
              item={item}
              fieldname="order_by"
              config={config}/>
          </:item_form>
        </.live_component>
        Pagination
        Per Page:
        <select name="per_page">
          <option :for={i <- [30, 60, 100]} selected={@view_config.views.detail.per_page == i} value={i}><%= i %></option>
        </select>
      </div>


    """

  end

end
