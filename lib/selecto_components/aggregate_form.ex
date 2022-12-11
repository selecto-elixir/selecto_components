defmodule SelectoComponents.AggregateForm do

  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common

  def render(assigns) do

    ~H"""
      <div>
        Group By
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id="group_by"
          fieldname="group_by"
          available={Enum.filter( @columns, fn {_f, _n, format} -> format not in [:component, :link] end)}
          selected_items={@view_config.group_by}>
          <:item_form :let={{id, item, config, index} }>
            <input name={"group_by[#{id}][field]"} type="hidden" value={item}/>
            <input name={"group_by[#{id}][index]"} type="hidden" value={index}/>
            <.live_component
              module={SelectoComponents.Components.GroupByConfig}
              id={id}
              col={@selecto.config.columns[item]}
              uuid={id}
              item={item}
              fieldname="group_by"
              config={config}/>
          </:item_form>
        </.live_component>
        Aggregates:
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id="aggregate"
          fieldname="aggregate"
          available={@columns}
          selected_items={@view_config.aggregate}>
          <:item_form :let={{id, item, config, index}}>
            <input name={"aggregate[#{id}][field]"} type="hidden" value={item}/>
            <input name={"aggregate[#{id}][index]"} type="hidden" value={index}/>
            <.live_component
              module={SelectoComponents.Components.AggregateConfig}
              id={id}
              col={@selecto.config.columns[item]}
              uuid={id}
              item={item}
              fieldname="aggregate"
              config={config}/>
          </:item_form>
        </.live_component>
      </div>
    """

  end

end
