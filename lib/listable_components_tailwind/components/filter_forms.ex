defmodule ListableComponentsTailwind.Components.FilterForms do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
      <div>FILTER FORM!
        <%= @filter %>
      </div>
    """
  end

end
