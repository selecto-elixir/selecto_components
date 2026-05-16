defmodule SelectoComponents.EnhancedTable.BulkActions do
  @moduledoc """
  Bulk actions interface for performing operations on multiple selected records.

  Bulk actions should come from domain action contracts and render as generated
  `ActionFormModal` entries. Passing explicit `:actions` is a deprecated
  pre-1.0 compatibility path kept only while the remaining callers move to
  domain actions; do not add new behavior there.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.Actions
  alias SelectoComponents.EnhancedTable.RowSelection
  alias Phoenix.LiveView.JS

  @export_icon_svg ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>)

  @delete_icon_svg ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>)

  @trusted_icons MapSet.new([@export_icon_svg, @delete_icon_svg])

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> RowSelection.init_selection()
     |> assign(
       bulk_action: nil,
       processing: false,
       processed_count: 0,
       total_to_process: 0,
       errors: [],
       show_confirmation: false,
       confirmation_message: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    actions =
      (assigns[:actions] || [])
      |> Kernel.++(generated_action_forms(assigns))
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
    <div id={@id} class="bulk-actions-container" phx-hook=".BulkActions" data-selected-count={@selection_count}>
      <%!-- Bulk Actions Toolbar --%>
      <div class="flex items-center justify-between px-4 py-2 bg-gray-50 border-b">
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

        <%!-- Quick Actions --%>
        <div class="flex items-center space-x-2">
          <%= for action <- Enum.filter(@actions, & &1.quick_action) do %>
            <button
              type="button"
              class={"px-3 py-1.5 text-sm rounded-lg flex items-center space-x-1 #{action_button_class(action, @selection_count)}"}
              disabled={@selection_count == 0 || @processing}
              phx-click="execute_action"
              phx-value-action={action.id}
              phx-target={@myself}
            >
              <%= if icon = safe_icon(action.icon) do %>
                {icon}
              <% end %>
              <span>{action.label}</span>
            </button>
          <% end %>
        </div>
      </div>

      <%!-- Progress Bar --%>
      <%= if @processing do %>
        <div class="px-4 py-2 bg-blue-50 border-b border-blue-200">
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-blue-900">
              Processing {@processed_count} of {@total_to_process} items...
            </span>
            <button
              type="button"
              class="text-sm text-blue-600 hover:text-blue-800"
              phx-click="cancel_processing"
              phx-target={@myself}
            >
              Cancel
            </button>
          </div>
          <div class="w-full bg-blue-200 rounded-full h-2">
            <div
              class="bg-blue-600 h-2 rounded-full transition-all duration-300"
              style={"width: #{progress_percentage(@processed_count, @total_to_process)}%"}
            >
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Error Display --%>
      <%= if length(@errors) > 0 do %>
        <div class="px-4 py-2 bg-red-50 border-b border-red-200">
          <div class="flex items-start">
            <svg
              class="w-5 h-5 text-red-600 mr-2 flex-shrink-0"
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                clip-rule="evenodd"
              />
            </svg>
            <div class="flex-1">
              <p class="text-sm font-medium text-red-900">
                {length(@errors)} {if length(@errors) == 1, do: "error", else: "errors"} occurred
              </p>
              <ul class="mt-1 text-sm text-red-700">
                <%= for error <- Enum.take(@errors, 3) do %>
                  <li>• {error}</li>
                <% end %>
                <%= if length(@errors) > 3 do %>
                  <li class="text-red-600">...and {length(@errors) - 3} more</li>
                <% end %>
              </ul>
            </div>
            <button
              type="button"
              class="text-red-600 hover:text-red-800"
              phx-click="dismiss_errors"
              phx-target={@myself}
            >
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
          </div>
        </div>
      <% end %>

      <%!-- Confirmation Dialog --%>
      <%= if @show_confirmation do %>
        <div
          id="confirmation-dialog"
          class="fixed inset-0 z-50 overflow-y-auto"
          phx-hook=".ConfirmationDialog"
        >
          <div class="flex items-center justify-center min-h-screen px-4">
            <div
              class="fixed inset-0 bg-gray-500 bg-opacity-75"
              phx-click="cancel_action"
              phx-target={@myself}
            >
            </div>

            <div class="relative bg-white rounded-lg shadow-xl max-w-md w-full">
              <div class="px-6 py-4">
                <div class="flex items-start">
                  <div class="flex-shrink-0">
                    <svg
                      class="w-6 h-6 text-yellow-600"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                      />
                    </svg>
                  </div>
                  <div class="ml-3 flex-1">
                    <h3 class="text-lg font-medium text-gray-900">Confirm Bulk Action</h3>
                    <p class="mt-2 text-sm text-gray-500">
                      {@confirmation_message}
                    </p>
                    <p class="mt-2 text-sm font-medium text-gray-700">
                      This will affect {@selection_count} {if @selection_count == 1,
                        do: "item",
                        else: "items"}.
                    </p>
                  </div>
                </div>
              </div>

              <div class="px-6 py-4 bg-gray-50 flex justify-end space-x-2">
                <button
                  type="button"
                  class="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-100"
                  phx-click="cancel_action"
                  phx-target={@myself}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  class="px-4 py-2 bg-red-600 text-white rounded-lg text-sm font-medium hover:bg-red-700"
                  phx-click="confirm_action"
                  phx-target={@myself}
                >
                  Confirm
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".BulkActions">
        export default {
          mounted() {
            this.handleKeydown = (event) => {
              if (event.key === 'Delete' && !event.target.matches('input, textarea')) {
                const selectedCount = parseInt(this.el.dataset.selectedCount || '0', 10);
                if (selectedCount > 0) {
                  event.preventDefault();
                  this.pushEventTo(this.el, 'execute_action', {action: 'delete'});
                }
              }
            };

            document.addEventListener('keydown', this.handleKeydown);
          },

          destroyed() {
            document.removeEventListener('keydown', this.handleKeydown);
          }
        };
      </script>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".ConfirmationDialog">
        export default {
          mounted() {
            const confirmBtn = this.el.querySelector('button[phx-click="confirm_action"]');
            if (confirmBtn) {
              confirmBtn.focus();
            }

            this.handleKeydown = (event) => {
              if (event.key === 'Escape') {
                this.pushEventTo(this.el, 'cancel_action', {});
              }
            };

            document.addEventListener('keydown', this.handleKeydown);
          },

          destroyed() {
            document.removeEventListener('keydown', this.handleKeydown);
          }
        };
      </script>
    </div>
    """
  end

  defp render_action_item(assigns, action) do
    assigns = assign(assigns, :action, action)

    ~H"""
    <div class={if @action.divider, do: "border-t border-gray-200", else: ""}>
      <button
        type="button"
        class="w-full text-left px-4 py-2 text-sm hover:bg-gray-100 flex items-center space-x-2"
        phx-click={execute_action_click(@menu_id, @action.id, @myself)}
        data-bulk-action-id={@action.id}
        data-bulk-action-source={Map.get(@action, :source)}
        data-bulk-action-scope={Map.get(@action, :scope)}
      >
        <%= if icon = safe_icon(@action.icon) do %>
          <span class={@action.icon_class || "text-gray-500"}>
            {icon}
          </span>
        <% end %>
        <span class={@action.text_class || "text-gray-700"}>{@action.label}</span>
        <%= if @action.badge do %>
          <span class="ml-auto px-2 py-0.5 text-xs bg-gray-200 rounded-full">
            {@action.badge}
          </span>
        <% end %>
      </button>
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

    cond do
      generated_action_form?(action) ->
        {:noreply, open_generated_action_form(socket, action)}

      action && action.requires_confirmation ->
        {:noreply,
         socket
         |> assign(
           show_confirmation: true,
           confirmation_message:
             action.confirmation_message || "Are you sure you want to perform this action?",
           bulk_action: action
         )}

      true ->
        {:noreply, execute_bulk_action(socket, action)}
    end
  end

  def handle_event("confirm_action", _params, socket) do
    {:noreply,
     socket
     |> assign(show_confirmation: false)
     |> execute_bulk_action(socket.assigns.bulk_action)}
  end

  def handle_event("cancel_action", _params, socket) do
    {:noreply, assign(socket, show_confirmation: false, bulk_action: nil)}
  end

  def handle_event("cancel_processing", _params, socket) do
    {:noreply, assign(socket, processing: false)}
  end

  def handle_event("dismiss_errors", _params, socket) do
    {:noreply, assign(socket, errors: [])}
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

  # Deprecated explicit-action execution path.
  #
  # Domain actions should render generated action-form menu items and run through
  # `ActionFormModal` + `ActionFormHost`. Keep this small and removable; it is
  # only present to keep explicit `actions:` assigns parent-safe until it is
  # deleted before 1.0.

  defp execute_bulk_action(socket, nil), do: socket

  defp execute_bulk_action(socket, action) do
    selected_ids = RowSelection.get_selected_ids(socket)

    if length(selected_ids) > 0 do
      socket
      |> assign(
        processing: true,
        processed_count: 0,
        total_to_process: length(selected_ids),
        errors: []
      )
      |> process_selected_batches(action, selected_ids)
    else
      socket
    end
  end

  defp process_selected_batches(socket, action, selected_ids) do
    batch_size = action[:batch_size] || 10
    batches = Enum.chunk_every(selected_ids, batch_size)

    Enum.reduce_while(batches, socket, fn batch, batch_socket ->
      case process_batch(action, batch) do
        {:ok, _results} ->
          {:cont,
           assign(batch_socket,
             processed_count: batch_socket.assigns.processed_count + length(batch)
           )}

        {:error, errors} ->
          {:halt,
           batch_socket
           |> assign(errors: batch_socket.assigns.errors ++ List.wrap(errors))
           |> assign(processing: false)}
      end
    end)
    |> finish_batch_processing()
  end

  # Helper functions

  defp finish_batch_processing(%{assigns: %{processing: false}} = socket), do: socket

  defp finish_batch_processing(socket) do
    socket
    |> assign(processing: false)
    |> RowSelection.clear_selection()
  end

  defp process_batch(action, batch_ids) do
    case action do
      %{handler: handler} when is_function(handler, 1) ->
        handler.(batch_ids)

      %{handler: {module, function}} when is_atom(module) and is_atom(function) ->
        apply(module, function, [batch_ids])

      %{id: action_id} ->
        {:error, ["No handler configured for bulk action #{action_id}."]}

      _ ->
        {:error, ["No handler configured for this bulk action."]}
    end
  end

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

  defp safe_icon(icon) when is_binary(icon) do
    if MapSet.member?(@trusted_icons, icon) do
      Phoenix.HTML.raw(icon)
    else
      nil
    end
  end

  defp safe_icon(_icon), do: nil

  defp generated_action_forms(assigns) do
    assigns
    |> generated_action_contract()
    |> Actions.bulk_actions(id_prefix: "domain_bulk_action_form_")
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

    %{
      id: id,
      label: Map.get(config, :name) || map_value(action, :label) || id,
      description: Map.get(config, :description),
      source: :generated_bulk_action_form,
      scope: "bulk",
      type: :live_component,
      payload: payload,
      quick_action: false,
      requires_confirmation: false,
      confirmation_message: map_value(action, :confirmation_message)
    }
  end

  defp generated_action_form_menu_item(_id, _config), do: nil

  defp normalize_action_item(action) when is_map(action) do
    %{
      id: map_value(action, :id),
      label: map_value(action, :label),
      description: map_value(action, :description),
      icon: map_value(action, :icon),
      icon_class: map_value(action, :icon_class),
      text_class: map_value(action, :text_class),
      badge: map_value(action, :badge),
      divider: truthy?(map_value(action, :divider)),
      quick_action: truthy?(map_value(action, :quick_action)),
      requires_confirmation: truthy?(map_value(action, :requires_confirmation)),
      confirmation_message: map_value(action, :confirmation_message),
      source: map_value(action, :source) || :deprecated_explicit_bulk_action,
      scope: map_value(action, :scope),
      type: map_value(action, :type),
      payload: map_value(action, :payload, %{}),
      batch_size: map_value(action, :batch_size),
      handler: map_value(action, :handler)
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

  defp action_button_class(action, selection_count) do
    base = "transition-colors"

    disabled =
      if selection_count == 0 do
        "opacity-50 cursor-not-allowed"
      else
        ""
      end

    color =
      case action.id do
        "delete" -> "bg-red-100 text-red-700 hover:bg-red-200"
        "export" -> "bg-green-100 text-green-700 hover:bg-green-200"
        _ -> "bg-gray-100 text-gray-700 hover:bg-gray-200"
      end

    "#{base} #{color} #{disabled}"
  end

  defp progress_percentage(0, 0), do: 0

  defp progress_percentage(processed, total) do
    round(processed / total * 100)
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
