defmodule SelectoComponents.Components.TreeBuilder do
  use Phoenix.LiveComponent

  # available,
  # filters

  import SelectoComponents.Components.Common

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
    assigns = %{assigns | filters: Enum.with_index(assigns.filters)}

    ~H"""
      <div class="border-solid border rounded-md border-grey dark:border-grey  p-1 pb-8"
      x-on:drop=" event.preventDefault();
        PushEventHook.pushEvent('treedrop', {target: event.target.id, element: dragging});
        event.stopPropagation()"
      id={@section}>
        <%= @section %>: <%= @conjunction %>
        <div class="p-2 pl-6 border-solid border rounded-md border-grey dark:border-grey"

          :for={ {s, index} <- @filters } %>
          <%= case s do %>

          <% {uuid, section, fv} -> %>
          XXX
            <div class="p-2 pl-6 border-solid border rounded-md border-grey dark:border-grey">
              <%= render_slot(@filter_form, {uuid, index, section, fv}) %>
            </div>

          <% {:section, uuid, conj, filters} -> %>
            <div class="p-2 pl-6 border-solid border rounded-md border-grey dark:border-grey">
              <.input name={"filters[#{uuid}][is_section]"} value="Y"/>
              <.input name={"filters[#{uuid}][section]"} value={@section}/>
              <.input name={"filters[#{uuid}][conjunction]"} value={conj}/>
              <.input name={"filters[#{uuid}][name]"} value={uuid}/>


              <%= render_area(%{ available: @available, filters: filters,
                section: uuid, conjunction: conj, filter_form: @filter_form }) %>
            </div>
          <% end %>

          <div class="p-2 pl-6 border-solid border rounded-md border-grey dark:border-grey">
            <.input name={"filters[#{@section}new][is_section]"} value="Y"/>
            <.input name={"filters[#{@section}new][section]"} value={@section}/>
            <.input name={"filters[#{@section}new][conjunction]"} value="and"/>
            <.input name={"filters[#{@section}new][name]"} value="new"/>
            <%= render_area(%{ available: @available, filters: [],
              section: @section <> "new", conjunction: "and", filter_form: @filter_form }) %>
          </div>

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
