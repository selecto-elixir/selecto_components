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
      <svg class="w-8 h-8 inline btn btn-outline btn-xs text-base-content" {@attrs} fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" width="100%" height="100%">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 10.5 12 3m0 0 7.5 7.5M12 3v18" />
      </svg>
    """
  end

  def sc_down_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <svg class="w-8 h-8 inline btn btn-outline btn-xs text-base-content" {@attrs} fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" width="100%" height="100%">
        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 13.5 12 21m0 0-7.5-7.5M12 21V3" />
      </svg>
    """
  end

  def sc_x_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <svg class="w-8 h-8 btn btn-outline btn-xs btn-error" {@attrs} fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" width="100%" height="100%">
        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
      </svg>
    """
  end

  def sc_x_button_small(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <svg class="w-4 h-4 cursor-pointer text-gray-500 hover:text-red-500" {@attrs} fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
      </svg>
    """
  end

  def sc_input(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :class])
    custom_class = assigns[:class] || ""
    assigns = assign(assigns, attrs: attrs, custom_class: custom_class)

    ~H"""
      <input {@attrs} class={["input input-bordered input-sm w-full", @custom_class]}/>
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
