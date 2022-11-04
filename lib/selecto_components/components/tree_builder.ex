defmodule SelectoComponents.Components.TreeBuilder do
  use Phoenix.LiveComponent

  # available,
  # filters

  import SelectoComponents.Components.Common

  def render(assigns) do
    ~H"""
      <div class="">
        <div phx-hook="PushEventHook" id="relay" class="grid grid-cols-2 gap-1">

          <div>Available Filter Columns</div>
          <div>Build Area. All top level filters are AND'd together and AND'd with the required filters from the domain.</div>

          <div class="grid grid-cols-1 gap-1 border-solid border rounded-md border-grey dark:border-black overflow-auto p-1">

            <div :for={{id, name} <- @available}>
              <div class="border border-gray-100 hover:border-red-500 hover:bg-gray-600" draggable="true" x-on:drag=" dragging = event.srcElement.id; " id={id}><%= name %></div>
            </div>

          </div>
          <div class="grid grid-cols-1 gap-1 border-solid border rounded-md border-grey dark:border-black overflow-auto p-1">
            <%= render_area(%{ available: @available, filters: @filters, section: "filters", index: 1, conjunction: 'AND', filter_form: @filter_form }) %>

          </div>
        </div>
      </div>
    """
  end

  ### TODO figure ou tohw to do this recursive data structure easily...
  ###  ++ if Enum.count(@filters) > 0 do [{"#{@section}[#{Enum.count(@filters) +1}]", "AND", []}] else [] end}
  ### <%= render_area(%{ available: @available, filters: filters, conjunction: conj, section: section }) %>
  ### <%= {:subsection, section, conj, filters} when is_list(filters) -> %>

  defp render_area(assigns) do
    assigns = %{assigns | filters: Enum.with_index(assigns.filters)}
    assigns = Map.put(assigns, :new_uuid, UUID.uuid4())

    ~H"""
      <div class="border-solid border rounded-md border-grey dark:border-grey  p-1 pb-8"
      x-on:drop=" event.preventDefault();
        PushEventHook.pushEvent('treedrop', {target: event.target.id, element: dragging});
        event.stopPropagation()"
      id={@section}>

        <%= @section %>: <%= @conjunction %>
        <div class="p-2 pl-6 border-solid border rounded-md border-grey dark:border-grey"
          :for={ {s, index} <-
            Enum.filter( @filters, fn {{_uuid,section,_conf}, _i} = f -> section == @section end )
          } %>

          <%= case s do %>

            <% {uuid, section, fv} -> %>
              <div class="p-2 pl-6 border-solid border rounded-md border-grey dark:border-grey">
                <%= render_slot(@filter_form, {uuid, index, section, fv}) %>
              </div>

            <% {:section, uuid, conj} -> %>

              <div class="p-2 pl-6 border-solid border rounded-md border-grey dark:border-grey">
                <%= render_area(%{ available: @available, filters: @filters, index: @index,
                  parent_section: @section,
                  section: uuid, conjunction: conj, filter_form: @filter_form }) %>
              </div>

          <% end %>



<%!--
    New Section here..



          --%>

        </div>

      </div>
    """
  end

  # handle:
  # delete filter,
  # delete section
  # add section
  # change conjunction
end
