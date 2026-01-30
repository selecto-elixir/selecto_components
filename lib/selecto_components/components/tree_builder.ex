defmodule SelectoComponents.Components.TreeBuilder do
  use Phoenix.LiveComponent

  # available,
  # filters

  import SelectoComponents.Components.Common

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # When the component ID changes, Phoenix will remount the component entirely
    # This ensures all form fields are properly recreated
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="tree-builder-component">
      <div class="">
        <div phx-hook="TreeBuilder" id={"tree-builder-#{@id}"} class="grid grid-cols-2 gap-1 h-80" x-data="{ filter: '' }">

          <div class="text-base-content">Available Filter Columns. Double Click or Drag to build area.
            <div class="flex items-center gap-1">
              <input x-model="filter" x-on:keydown.escape="filter = ''" placeholder="Filter Available Items" class="sc-input flex-1" />
              <button x-on:click="filter = ''" x-show="filter != ''" class="sc-x-button" type="button">×</button>
            </div>
          </div>
          <div class="text-base-content">Build Area. All top level filters are AND'd together and AND'd with the required filters from the domain.</div>

          <div class="flex flex-col gap-1 border-solid border rounded-md border-base-300 overflow-auto p-1 bg-base-100" id={"available-items-#{@id}"}>



            <div class="max-w-100 bg-base-200 border-solid border rounded-md border-base-300 p-1 hover:bg-base-300 min-h-10 text-base-content cursor-pointer"
              draggable="true" data-item-id="__AND__" id={"#{@id}-__AND__"}
              x-show="filter == '' || 'and group'.includes(filter.toLowerCase())"
              x-transition>AND group</div>
            <div class="max-w-100 bg-base-200 border-solid border rounded-md border-base-300 p-1 hover:bg-base-300 min-h-10 text-base-content cursor-pointer"
              draggable="true" data-item-id="__OR__" id={"#{@id}-__OR__"}
              x-show="filter == '' || 'or group'.includes(filter.toLowerCase())"
              x-transition>OR group</div>


            <div :for={{{id, name}, idx} <- Enum.with_index(@available)}
              class="max-w-100 bg-base-200 border-solid border rounded-md border-base-300 p-1 hover:bg-base-300 min-h-10 text-base-content cursor-pointer"
              draggable="true" data-item-id={id}
              id={"#{@id}-available-#{id}-#{idx}"}
              x-show={"filter == '' || '#{String.downcase(name)}'.includes(filter.toLowerCase())"}
              x-transition><%= name %></div>

          </div>
          <div class="grid grid-cols-1 gap-1 border-solid border rounded-md border-base-300 overflow-auto p-1 bg-base-100 drop-zone" data-drop-zone="filters">
            <%= render_area(%{ available: @available, filters: Enum.with_index(@filters), section: "filters", index: 0, conjunction: "AND", filter_form: @filter_form, component_id: @id }) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_filter_name(available, filter_id) do
    case Enum.find(available, fn {id, _name} -> id == filter_id end) do
      {_id, name} -> name
      nil -> filter_id || "Unknown Filter"
    end
  end

  defp render_area(assigns) do
    assigns = Map.put(assigns, :new_uuid, UUID.uuid4())
    # Create a unique key based on component ID and filter UUIDs to force proper re-rendering
    component_id = Map.get(assigns, :component_id, "")
    filter_key = assigns.filters
      |> Enum.map(fn {{uuid, _, _}, _} -> uuid end)
      |> Enum.join("-")
      |> then(fn key -> "#{component_id}-#{assigns.section}-#{key}" end)

    assigns = Map.put(assigns, :filter_key, filter_key)

    ~H"""
      <div class="border-solid border border-4 rounded-xl border-primary p-1 pb-8 bg-base-100 drop-zone"
      data-drop-zone={@section}
      id={@filter_key}>

        <span class="text-base-content font-medium"><%= @conjunction %></span>
        <%= for {{uuid, s_section, config} = s, index} <-
              Enum.filter(@filters, fn
                {{_uuid, section, _conf}, _i} -> section == @section
              end) do %>
          <div class="p-2 pl-6 pr-10 border-solid border border-base-300 bg-base-100 text-base-content relative"
               id={uuid}>

            <%= case {uuid, s_section, config} do %>
              <% {uuid, _section, conjunction} when is_binary(conjunction) -> %>
                <input name={"filters[#{uuid}][uuid]"} type="hidden" value={uuid}/>
                <input name={"filters[#{uuid}][section]"} type="hidden" value={@section}/>
                <input name={"filters[#{uuid}][index]"} type="hidden" value={@index}/>
                <input name={"filters[#{uuid}][conjunction]"} type="hidden" value={conjunction}/>
                <input name={"filters[#{uuid}][is_section]"} type="hidden" value="Y"/>
                <%= render_area(%{ available: @available, filters: @filters, section: uuid, index: index, conjunction: conjunction, filter_form: @filter_form, component_id: @component_id }) %>
                <div class="absolute top-1 right-1 flex">
                  <.sc_x_button phx-click="filter_remove" phx-value-uuid={uuid}/>
                </div>

              <% {uuid, section, fv} -> %>
                <div class="p-2 pl-6 border-solid border rounded-md border-base-300 bg-base-100">
                  <div class="text-sm font-medium text-gray-600 mb-1">
                    <%= get_filter_name(@available, fv["filter"]) %>
                  </div>
                  <div id={"filter-form-#{uuid}"}>
                    <%= render_slot(@filter_form, {uuid, index, section, fv}) %>
                  </div>
                </div>
                <div class="absolute top-1 right-1 flex">
                  <.sc_x_button phx-click="filter_remove" phx-value-uuid={uuid}/>
                </div>

            <% end %>
            <!-- new section -->

          </div>
        <% end %>

      </div>
    """
  end
end