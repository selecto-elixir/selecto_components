defmodule ListableComponentsPetal.Components.RadioTabs do
  @doc """
    Given a set of radio buttons and containers, display the container indicated by the selected radio button

  """
  use Phoenix.LiveComponent

  attr :fieldname, :string, required: false
  attr :view_sel, :string, required: false


  # slot :section, required: true do
  #   attr :id, :string
  #   attr :label, :string
  # end

  def render(assigns) do

    ~H"""
      <div>
        <div :for={s <- @section}>
          <label>
            <input
              type="radio"
              name="@fieldname"
              value={s.id}
              checked={@view_sel == s.id}
              phx-click={:view_set}
              phx-target={@myself}/>
              <%= s.label %>
          </label>
          <div :if={@view_sel == s.id}>
            <%= render_slot(s) %>
          </div>
        </div>
      </div>
    """

  end

  def handle_event("view_set", params, socket) do
    send self(), {:view_set, params["value"]}
    {:noreply, socket}
  end


end
