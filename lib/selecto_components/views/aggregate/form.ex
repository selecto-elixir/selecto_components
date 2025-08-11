defmodule SelectoComponents.Views.Aggregate.Form do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
      <div>
        Group By
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id="group_by"
          fieldname="group_by"
          view={@view}
          available={Enum.filter( @columns, fn {_f, _n, format} -> format not in [:component, :link] end)}
          selected_items={@view_config.views.aggregate.group_by}>
          <:item_form :let={{id, item, config, index} }>
            <input name={"group_by[#{id}][field]"} type="hidden" value={item}/>
            <input name={"group_by[#{id}][index]"} type="hidden" value={index}/>
            <.live_component
              module={SelectoComponents.Views.Aggregate.GroupByConfig}
              id={id}
              col={Selecto.field(@selecto, item)}
              uuid={id}
              item={item}
              fieldname="group_by"
              prefix={ "group_by[#{id}]" }

              config={config}/>
          </:item_form>
        </.live_component>
        Aggregates:
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id="aggregate"
          fieldname="aggregate"
          view={@view}
          available={@columns}
          selected_items={@view_config.views.aggregate.aggregate}>
          <:item_form :let={{id, item, config, index}}>
            <input name={"aggregate[#{id}][field]"} type="hidden" value={item}/>
            <input name={"aggregate[#{id}][index]"} type="hidden" value={index}/>
            <.live_component
              module={SelectoComponents.Views.Aggregate.Aggregate.Config}
              id={id}
              col={Selecto.field(@selecto, item)}
              uuid={id}
              item={item}
              fieldname="aggregate"
              prefix={ "aggregate[#{id}]" }
              config={config}/>
          </:item_form>
        </.live_component>
      </div>
    """
  end
end
