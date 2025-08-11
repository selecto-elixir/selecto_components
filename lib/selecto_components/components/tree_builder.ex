defmodule SelectoComponents.Components.TreeBuilder do
  use Phoenix.LiveComponent

  # available,
  # filters

  import SelectoComponents.Components.Common

  def render(assigns) do
    ~H"""
      <div class="">
        <div phx-hook="PushEventHook" id="relay" class="grid grid-cols-2 gap-1 h-80" x-data="{ filter: ''}">

          <div>Available Filter Columns. Double Click or Drag to build area.
            <.sc_input x-model="filter" placeholder="Filter Available Items"/>
            <.sc_x_button x-on:click="filter = ''" x-show="filter != ''"/>
          </div>
          <div>Build Area. All top level filters are AND'd together and AND'd with the required filters from the domain.</div>

          <div class="flex flex-col gap-1 border-solid border rounded-md border-grey  overflow-auto p-1">



            <div class="max-w-100 bg-slate-100  border-solid border rounded-md border-grey-900  p-1 hover:bg-slate-200  min-h-10"
              x-show="filter == '' || $el.innerHTML.toUpperCase().includes(filter.toUpperCase())"
              x-transition
              draggable="true" x-on:drag=" dragging = event.srcElement.id; " id="__AND__">AND group</div>
            <div class="max-w-100 bg-slate-100  border-solid border rounded-md border-grey-900  p-1 hover:bg-slate-200  min-h-10"
              x-show="filter == '' || $el.innerHTML.toUpperCase().includes(filter.toUpperCase())"
              x-transition
              draggable="true" x-on:drag=" dragging = event.srcElement.id; " id="__OR__">OR group</div>


            <div :for={{id, name} <- @available}>
              <div
                x-show="filter == '' || $el.innerHTML.toUpperCase().includes(filter.toUpperCase())"
                x-on:dblclick="PushEventHook.pushEvent('treedrop', {target: 'filters', element: event.srcElement.id});"
                x-transition
                class="max-w-100 bg-slate-100	 border-solid border rounded-md border-grey-900  p-1 hover:bg-slate-200  min-h-10"
                draggable="true" x-on:drag=" dragging = event.srcElement.id; "
                id={id}><%= name %></div>
            </div>

          </div>
          <div class="grid grid-cols-1 gap-1 border-solid border rounded-md border-grey  overflow-auto p-1">
            <%= render_area(%{ available: @available, filters: Enum.with_index(@filters), section: "filters", index: 0, conjunction: "AND", filter_form: @filter_form }) %>

          </div>
        </div>
      </div>
    """
  end

  defp render_area(assigns) do
    assigns = Map.put(assigns, :new_uuid, UUID.uuid4())

    ~H"""
      <div class="border-solid border border-4 rounded-xl border-black   p-1 pb-8"
      x-on:drop=" event.preventDefault();
        PushEventHook.pushEvent('treedrop', {target: event.target.id, element: dragging});
        event.stopPropagation()"
      id={@section}>

        <%= @conjunction %>
        <div class="p-2 pl-6 border-solid border  border-black  relative"
          :for={ {s, index} <-
            Enum.filter( @filters, fn
            {{_uuid,section,_conf}, _i} -> section == @section
            end )
          } %>

          <%= case s do %>
            <% {uuid, _section, conjunction} when is_binary(conjunction) -> %>
              <input name={"filters[#{uuid}][uuid]"} type="hidden" value={uuid}/>
              <input name={"filters[#{uuid}][section]"} type="hidden" value={@section}/>
              <input name={"filters[#{uuid}][index]"} type="hidden" value={@index}/>
              <input name={"filters[#{uuid}][conjunction]"} type="hidden" value={conjunction}/>
              <input name={"filters[#{uuid}][is_section]"} type="hidden" value="Y"/>
              <%= render_area(%{ available: @available, filters: @filters, section: uuid, index: index, conjunction: conjunction, filter_form: @filter_form  }) %>
              <div class="absolute top-1 right-1">
                <.sc_x_button phx-click="filter_remove" phx-value-uuid={uuid}/>
              </div>

            <% {uuid, section, fv} -> %>
              <div class="p-2 pl-6 border-solid border rounded-md border-grey ">
                <%= render_slot(@filter_form, {uuid, index, section, fv}) %>
              </div>
              <div class="absolute top-1 right-1">
                <.sc_x_button phx-click="filter_remove" phx-value-uuid={uuid}/>
              </div>

          <% end %>
            <!-- new section -->

        </div>

      </div>
    """
  end
end
