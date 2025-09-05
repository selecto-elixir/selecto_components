defmodule SelectoComponents.Components.Common do
  use Phoenix.Component

  def sc_button(assigns) do
    attrs = assigns_to_attributes(assigns, [:label])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <button {@attrs} class="btn btn-outline btn-sm">
        <%= render_slot(@inner_block) %>
      </button>
    """
  end

  def sc_up_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <Heroicons.arrow_up solid class="w-6 h-6 inline btn btn-outline btn-xs text-base-content" {@attrs}/>
    """
  end

  def sc_down_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <Heroicons.arrow_down solid class="w-6 h-6 inline btn btn-outline btn-xs text-base-content" {@attrs}/>
    """
  end

  def sc_x_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <Heroicons.x_mark solid class="w-6 h-6 btn btn-outline btn-xs btn-error" {@attrs}/>
    """
  end

  def sc_input(assigns) do
    attrs = assigns_to_attributes(assigns, [:label])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <input {@attrs} class="input input-bordered input-sm w-full"/>
    """
  end

  def sc_select_with_slot(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <select {@attrs} class="select select-bordered select-sm w-full" >
        <%= render_slot(@inner_block) %>
      </select>
    """
  end

  def sc_select(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <select {@attrs} class="select select-bordered select-sm w-full" >
        <option :for={{val, lab} <- @options} value={val} selected={val == @value}><%= lab %></option>
      </select>
    """
  end

  def sc_checkbox(assigns) do
  attrs = assigns_to_attributes(assigns, [:label, :options, :value])
  assigns = assign(assigns, attrs: attrs)

  ~H"""
    <label>
      <input type="checkbox" {@attrs}/>
      <%= render_slot(@inner_block) %>
    </label>
  """
  end



end
