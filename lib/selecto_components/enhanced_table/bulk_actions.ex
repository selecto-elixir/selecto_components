defmodule SelectoComponents.EnhancedTable.BulkActions do
  @moduledoc """
  Bulk actions interface for performing operations on multiple selected records.

  Bulk actions should come from domain action contracts and render as generated
  `ActionFormModal` entries.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.Actions
  alias SelectoComponents.EnhancedTable.RowSelection
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, RowSelection.init_selection(socket)}
  end

  @impl true
  def update(assigns, socket) do
    actions =
      assigns
      |> generated_action_forms()
      |> Enum.map(&normalize_action_item/1)
      |> Enum.reject(&is_nil/1)

    socket =
      socket
      |> assign(assigns)
      |> assign(actions: actions)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, menu_id: "#{assigns.id}-menu")

    ~H"""
    <div id={@id} class="bulk-actions-container" data-selected-count={@selection_count}>
      <%!-- Bulk Actions Toolbar --%>
      <div class="flex items-center px-4 py-2 bg-gray-50 border-b">
        <div class="flex items-center space-x-4">
          <%!-- Selection Info --%>
          <%= if @selection_count > 0 do %>
            <div class="flex items-center space-x-2">
              <span class="text-sm font-medium text-gray-700">
                {@selection_count} selected
              </span>
              <button
                type="button"
                class="text-sm text-blue-600 hover:text-blue-800"
                phx-click="clear_selection"
                phx-target={assigns[:selection_target] || @myself}
              >
                Clear
              </button>
            </div>
          <% end %>

          <%!-- Actions Dropdown --%>
          <div class="relative">
            <button
              type="button"
              class={"px-4 py-2 bg-white border rounded-lg flex items-center space-x-2 #{if @selection_count == 0, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"}"}
              disabled={@selection_count == 0}
              phx-click={toggle_actions_menu(@menu_id)}
            >
              <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
                />
              </svg>
              <span class="text-sm font-medium">Bulk Actions</span>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </button>

            <div
              id={@menu_id}
              class="hidden absolute left-0 mt-2 w-56 bg-white rounded-lg shadow-lg border border-gray-200 z-20"
            >
              <%= if @actions == [] do %>
                <div class="px-4 py-3 text-sm text-gray-500" data-bulk-actions-empty>
                  No bulk actions available
                </div>
              <% else %>
                <%= for action <- @actions do %>
                  {render_action_item(assigns, action)}
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

      </div>
    </div>
    """
  end

  defp render_action_item(assigns, action) do
    assigns = assign(assigns, :action, action)

    ~H"""
    <div class={if @action.divider, do: "border-t border-gray-200", else: ""}>
      <button
        type="button"
        class={
          "w-full text-left px-4 py-2 text-sm flex items-center space-x-2 " <>
            if(@action.disabled?,
              do: "cursor-not-allowed text-gray-400",
              else: "hover:bg-gray-100"
            )
        }
        disabled={@action.disabled?}
        phx-click={!@action.disabled? && execute_action_click(@menu_id, @action.id, @myself)}
        data-bulk-action-id={@action.id}
        data-bulk-action-source={Map.get(@action, :source)}
        data-bulk-action-scope={Map.get(@action, :scope)}
        data-bulk-action-status={Map.get(@action, :status)}
      >
        <span class={if @action.disabled?, do: "text-gray-400", else: "text-gray-700"}>{@action.label}</span>
      </button>
      <p :if={@action.disabled? && @action.reason} class="px-4 pb-2 text-xs text-amber-700">
        {@action.reason}
      </p>
      <%= if @action.description do %>
        <p class="px-4 pb-2 text-xs text-gray-500">{@action.description}</p>
      <% end %>
    </div>
    """
  end

  # Event handlers

  @impl true
  def handle_event("execute_action", %{"action" => action_id}, socket) do
    action = Enum.find(socket.assigns.actions, &(&1.id == action_id))

    if generated_action_form?(action) do
      {:noreply, open_generated_action_form(socket, action)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_row_selection", %{"id" => row_id}, socket) do
    {:noreply, RowSelection.toggle_row_selection(socket, row_id)}
  end

  def handle_event("select_all", _params, socket) do
    all_ids = get_all_row_ids(socket)
    {:noreply, RowSelection.select_all_rows(socket, all_ids)}
  end

  def handle_event("select_none", _params, socket) do
    {:noreply, RowSelection.clear_selection(socket)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, RowSelection.clear_selection(socket)}
  end

  def handle_event("invert_selection", _params, socket) do
    all_ids = get_all_row_ids(socket)
    {:noreply, RowSelection.invert_selection(socket, all_ids)}
  end

  def handle_event("select_range", %{"from" => from_id, "to" => to_id}, socket) do
    all_ids = get_all_row_ids(socket)
    {:noreply, RowSelection.select_range(socket, from_id, to_id, all_ids)}
  end

  defp open_generated_action_form(socket, action) do
    selected_ids = RowSelection.get_selected_ids(socket)

    if selected_ids == [] do
      socket
    else
      payload = Map.get(action, :payload, %{})
      component_assigns_template = Map.get(payload, :assigns, %{})
      selection_context = %{"ids" => selected_ids, "count" => length(selected_ids)}
      component_assigns = resolve_selection_assigns(component_assigns_template, selection_context)

      send(
        self(),
        {:show_detail_modal,
         %{
           action_id: action.id,
           action_source: :generated_bulk_action_form,
           action_type: :live_component,
           record: selection_context,
           current_index: 0,
           total_records: length(selected_ids),
           records: [selection_context],
           fields: ["ids", "count"],
           related_data: %{},
           title: Map.get(payload, :title, action.label),
           title_template: Map.get(payload, :title),
           size: Map.get(payload, :size, :lg),
           navigation_enabled: false,
           edit_enabled: false,
           component_module: Map.get(payload, :module),
           component_assigns_template: component_assigns_template,
           component_assigns: component_assigns
         }}
      )

      assign(socket, bulk_action: action)
    end
  end

  defp generated_action_form?(%{source: :generated_bulk_action_form}), do: true
  defp generated_action_form?(_action), do: false

  defp resolve_selection_assigns(assigns_template, selection_context)
       when is_map(assigns_template) do
    Map.new(assigns_template, fn {key, value} ->
      {key, resolve_selection_value(value, selection_context)}
    end)
  end

  defp resolve_selection_assigns(_assigns_template, _selection_context), do: %{}

  defp resolve_selection_value({:selection, key}, selection_context) do
    Map.get(selection_context, to_string(key))
  end

  defp resolve_selection_value(%{selection: key}, selection_context) do
    resolve_selection_value({:selection, key}, selection_context)
  end

  defp resolve_selection_value(%{"selection" => key}, selection_context) do
    resolve_selection_value({:selection, key}, selection_context)
  end

  defp resolve_selection_value(value, selection_context) when is_list(value) do
    Enum.map(value, &resolve_selection_value(&1, selection_context))
  end

  defp resolve_selection_value(value, selection_context) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {key, resolve_selection_value(nested_value, selection_context)}
    end)
  end

  defp resolve_selection_value(value, _selection_context), do: value

  defp get_all_row_ids(socket) do
    # Get row IDs from various possible sources
    cond do
      # Explicitly provided all_row_ids
      is_list(socket.assigns[:all_row_ids]) and length(socket.assigns[:all_row_ids]) > 0 ->
        socket.assigns[:all_row_ids]

      # Extract from rows data (list of maps with id field)
      is_list(socket.assigns[:rows]) ->
        extract_ids_from_rows(socket.assigns[:rows])

      # Extract from query results (Selecto format)
      is_map(socket.assigns[:query_results]) ->
        extract_ids_from_query_results(socket.assigns[:query_results])

      # Extract from stream data
      is_map(socket.assigns[:streams]) and is_map(socket.assigns[:streams][:rows]) ->
        # Streams store data differently, try to extract
        extract_ids_from_stream(socket.assigns[:streams][:rows])

      # Ask parent component for IDs
      true ->
        send(self(), {:request_all_row_ids, self()})
        # Return empty list, parent will send back the IDs
        []
    end
  end

  defp extract_ids_from_rows(rows) when is_list(rows) do
    rows
    |> Enum.map(fn
      %{id: id} ->
        id

      %{"id" => id} ->
        id

      row when is_map(row) ->
        Map.get(row, :id) || Map.get(row, "id") || Map.get(row, :_id) || Map.get(row, "_id")

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_ids_from_rows(_), do: []

  defp extract_ids_from_query_results(%{rows: rows, columns: columns}) do
    # Find id column index
    id_index =
      Enum.find_index(columns, fn col ->
        col_str = to_string(col)
        col_str in ["id", "_id", "pk", "primary_key"]
      end) || 0

    rows
    |> Enum.map(fn row ->
      case row do
        row when is_list(row) -> Enum.at(row, id_index)
        row when is_tuple(row) -> elem(row, id_index)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_ids_from_query_results(_), do: []

  defp extract_ids_from_stream(stream_data) when is_map(stream_data) do
    # Phoenix streams store items with DOM IDs as keys
    stream_data
    |> Map.values()
    |> Enum.map(fn
      %{id: id} -> id
      %{"id" => id} -> id
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_ids_from_stream(_), do: []

  @doc """
  Set all row IDs for selection operations.

  Call this from the parent component to provide IDs for select all functionality.

  ## Example

      def handle_info({:request_all_row_ids, pid}, socket) do
        ids = Enum.map(socket.assigns.rows, & &1.id)
        send_update(SelectoComponents.EnhancedTable.BulkActions,
          id: "bulk-actions",
          all_row_ids: ids
        )
        {:noreply, socket}
      end
  """
  def set_all_row_ids(component_id, row_ids) do
    Phoenix.LiveView.send_update(__MODULE__, id: component_id, all_row_ids: row_ids)
  end

  defp generated_action_forms(assigns) do
    selected_ids =
      assigns
      |> selected_ids()
      |> Enum.map(&to_string/1)

    availability_opts =
      assigns
      |> Map.get(:row_action_availability_opts, [])
      |> Keyword.put_new(:target, %{ids: selected_ids})
      |> Keyword.put_new(:surface, :selecto_components_bulk_actions)

    assigns
    |> generated_action_contract()
    |> Actions.bulk_actions(
      Keyword.put(availability_opts, :id_prefix, "domain_bulk_action_form_")
    )
    |> Enum.map(fn {id, config} -> generated_action_form_menu_item(id, config) end)
    |> Enum.reject(&is_nil/1)
  end

  defp generated_action_contract(assigns) do
    assigns[:action_contract] ||
      assigns[:write_contract] ||
      assigns[:domain] ||
      case assigns[:selecto] do
        nil -> %{}
        selecto -> Selecto.domain(selecto)
      end
  end

  defp generated_action_form_menu_item(id, config) when is_map(config) do
    payload = Map.get(config, :payload, %{})
    action = get_in(payload, [:assigns, :action]) || %{}
    disabled? = truthy?(map_value(action, :disabled?))

    %{
      id: id,
      label: Map.get(config, :name) || map_value(action, :label) || id,
      description: Map.get(config, :description),
      disabled?: disabled?,
      status: map_value(action, :status, if(disabled?, do: "disabled", else: "enabled")),
      reason: map_value(action, :reason),
      source: :generated_bulk_action_form,
      scope: "bulk",
      type: :live_component,
      payload: payload,
      confirmation_message: map_value(action, :confirmation_message)
    }
  end

  defp generated_action_form_menu_item(_id, _config), do: nil

  defp normalize_action_item(action) when is_map(action) do
    %{
      id: map_value(action, :id),
      label: map_value(action, :label),
      description: map_value(action, :description),
      divider: truthy?(map_value(action, :divider)),
      confirmation_message: map_value(action, :confirmation_message),
      disabled?: truthy?(map_value(action, :disabled?)),
      status: map_value(action, :status),
      reason: map_value(action, :reason),
      source: map_value(action, :source),
      scope: map_value(action, :scope),
      type: map_value(action, :type),
      payload: map_value(action, :payload, %{})
    }
  end

  defp normalize_action_item(_action), do: nil

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map) and is_atom(key),
    do: Map.get(map, key, Map.get(map, Atom.to_string(key), default))

  defp map_value(map, key, default) when is_map(map) and is_binary(key),
    do: Map.get(map, key, default)

  defp map_value(_map, _key, default), do: default

  defp truthy?(value) when value in [true, "true", "1", 1, :yes], do: true
  defp truthy?(_value), do: false

  defp selected_ids(assigns) do
    assigns
    |> Map.get(:selected_rows, MapSet.new())
    |> MapSet.to_list()
  end

  defp toggle_actions_menu(menu_id) do
    JS.toggle(
      to: "##{menu_id}",
      in: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
      out: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
  end

  defp execute_action_click(menu_id, action_id, target) do
    JS.hide(to: "##{menu_id}")
    |> JS.push("execute_action", value: %{action: action_id}, target: target)
  end
end
