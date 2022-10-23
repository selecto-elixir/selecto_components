defmodule ListableComponentsTailwind.Components.TreeBuilder do
  use Phoenix.LiveComponent

  #available,
  #filters


  def render(assigns) do
    ~H"""
      <div>
        <div phx-hook="PushEventHook" id="relay" class="grid grid-cols-2 gap-1">

          <div>Available Filter Columns</div>
          <div>Build Area. All top level filters are AND'd together and AND'd with the required filters from the domain.</div>

          <div class="grid grid-cols-1 gap-1 border-solid border rounded-md border-grey dark:border-black max-h-120 overflow-auto p-1">

            <div :for={{id, name} <- @available}>
              <div draggable="true" x-on:drag=" dragging = event.srcElement.id; " id={id}><%= name %></div>
            </div>

          </div>
          <div class="grid grid-cols-1 gap-1 border-solid border rounded-md border-grey dark:border-black max-h-120 overflow-auto p-1">
            <%= render_area(%{ available: @available, filters: @filters, section: "filters[main]", conjunction: 'AND', filter_form: @filter_form }) %>

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
    ~H"""
      <div class="border-solid border rounded-md border-grey dark:border-black  p-1"
      x-on:drop=" event.preventDefault(); PushEventHook.pushEvent('treedrop', {target: event.target.id, element: dragging});"
      id={@section}>
        <%= @section %>
        <div class="pl-4"

          :for={ s <- @filters } %>
          <%= case s do %>

            <% {uuid, section, filter, value} -> %>
              <div>
                <%= render_slot(@filter_form, {uuid, section, filter, value}) %>
              </div>
          <% end %>
        </div>

      </div>
    """
  end

  #handle:
  #delete filter,
  #delete section
  #add section
  #change conjunction



end
