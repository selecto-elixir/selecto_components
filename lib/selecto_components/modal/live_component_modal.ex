defmodule SelectoComponents.Modal.LiveComponentModal do
  @moduledoc false

  use Phoenix.LiveComponent

  import SelectoComponents.Modal.ModalWrapper

  alias Phoenix.LiveView.JS
  alias SelectoComponents.Views.Detail.RowActions

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       component_module: nil,
       component_assigns: %{},
       component_assigns_template: %{},
       record: nil,
       records: [],
       current_index: 0,
       total_records: 0,
       navigation_enabled: true,
       title: nil,
       title_template: nil,
       size: :xl
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id={@id}
        title={build_title(assigns)}
        subtitle={nil}
        size={@size || :xl}
        show_header={true}
        on_cancel={JS.push("close_modal", target: @myself)}
        on_prev={modal_navigation_event(assigns, "prev", @myself)}
        on_next={modal_navigation_event(assigns, "next", @myself)}
      >
        <div class="space-y-4">
          <div :if={@navigation_enabled} class="flex items-center justify-between border-b pb-2">
            <div class="flex space-x-2">
              <button
                type="button"
                class="rounded-md bg-gray-100 px-3 py-1 text-sm hover:bg-gray-200 disabled:cursor-not-allowed disabled:opacity-50"
                phx-click="navigate_record"
                phx-value-direction="prev"
                phx-target={@myself}
                disabled={!has_prev_record?(assigns)}
              >
                Previous
              </button>
              <button
                type="button"
                class="rounded-md bg-gray-100 px-3 py-1 text-sm hover:bg-gray-200 disabled:cursor-not-allowed disabled:opacity-50"
                phx-click="navigate_record"
                phx-value-direction="next"
                phx-target={@myself}
                disabled={!has_next_record?(assigns)}
              >
                Next
              </button>
            </div>

            <div class="text-sm text-gray-500">
              Record {@current_index + 1} of {@total_records}
            </div>
          </div>

          <div :if={@component_module} class="rounded-lg border border-gray-200 bg-white p-4">
            <.live_component {embedded_component_assigns(assigns)} />
          </div>

          <div :if={!@component_module} class="rounded-md border border-dashed border-gray-300 p-6 text-sm text-gray-500">
            No LiveComponent module is configured for this action.
          </div>
        </div>

        <:footer>
          <div class="flex justify-end w-full">
            <button
              type="button"
              class="rounded-md bg-gray-300 px-4 py-2 text-gray-700 hover:bg-gray-400"
              phx-click={JS.push("close_modal", target: @myself)}
            >
              Close
            </button>
          </div>
        </:footer>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), {:close_detail_modal, socket.assigns.id})
    {:noreply, socket}
  end

  def handle_event("navigate_record", %{"direction" => direction}, socket) do
    new_index =
      case direction do
        "prev" -> max(0, socket.assigns.current_index - 1)
        "next" -> min(socket.assigns.total_records - 1, socket.assigns.current_index + 1)
      end

    {:noreply, load_record_at_index(socket, new_index)}
  end

  defp load_record_at_index(socket, index) do
    record = Enum.at(socket.assigns.records, index)

    socket
    |> assign(current_index: index, record: record)
    |> maybe_assign_title(record)
    |> assign(
      component_assigns:
        RowActions.resolve_component_assigns(socket.assigns.component_assigns_template, record)
    )
  end

  defp embedded_component_assigns(assigns) do
    Map.merge(
      %{
        module: assigns.component_module,
        id: "#{assigns.id}-embedded",
        record: assigns.record,
        records: assigns.records,
        current_index: assigns.current_index,
        total_records: assigns.total_records
      },
      assigns.component_assigns || %{}
    )
  end

  defp maybe_assign_title(socket, record) do
    if is_binary(socket.assigns[:title_template]) do
      assign(socket, title: RowActions.resolve_template(socket.assigns.title_template, record))
    else
      socket
    end
  end

  defp build_title(assigns) do
    cond do
      is_binary(assigns[:title_template]) and assigns[:record] ->
        RowActions.resolve_template(assigns.title_template, assigns.record)

      is_binary(assigns[:title]) and assigns.title != "" ->
        assigns.title

      true ->
        "Detail Component"
    end
  end

  defp modal_navigation_event(assigns, direction, target) do
    if assigns[:navigation_enabled] do
      JS.push("navigate_record", target: target, value: %{direction: direction})
    else
      nil
    end
  end

  defp has_prev_record?(assigns), do: assigns[:current_index] && assigns.current_index > 0

  defp has_next_record?(assigns) do
    assigns[:current_index] && assigns[:total_records] &&
      assigns.current_index < assigns.total_records - 1
  end
end
