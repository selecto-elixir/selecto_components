defmodule SelectoComponents.Components.RadioTabs do
  @doc """
    Given a set of radio buttons and containers, display the container indicated by the selected radio button

  """
  use Phoenix.LiveComponent

  attr(:fieldname, :string, required: false)
  attr(:view_mode, :string, required: false)


  # slot :section, required: true do
  #   attr :id, :string
  #   attr :label, :string
  # end

  def render(assigns) do
    ~H"""
      <div>
        <div :for={{id, module, name} <- @options}>
          <label>
            <!--TODO use LiveView.JS? -->
            <input
              type="radio"
              name={@fieldname}
              value={id}
              checked={@view_mode == Atom.to_string(id)}
              phx-click="view_set"
              phx-target={@myself}/>
            <%= name %>
          </label>
          <div class={if @view_mode == Atom.to_string(id) do " pl-16" else "hidden" end}>
            <%= name %>
            <%= render_slot(@section, {id, module, name}) %>

          </div>
        </div>
      </div>
    """
  end

  def handle_event("view_set", params, socket) do
    send(self(), {:view_set, params["value"]})
    {:noreply, socket}
  end
end
