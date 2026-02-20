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
    attrs = assigns_to_attributes(assigns, [:class])
    custom_class = assigns[:class] || ""
    assigns = assign(assigns, attrs: attrs, custom_class: custom_class)

    ~H"""
      <button type="button" class={["inline-flex h-7 w-7 items-center justify-center rounded-md border border-base-300 bg-base-100 text-base-content transition hover:border-primary/40 hover:bg-base-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40", @custom_class]} title="Move up" {@attrs}>
        <svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" d="m15 11.25-3-3-3 3" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 8.25v7.5" />
        </svg>
      </button>
    """
  end

  def sc_down_button(assigns) do
    attrs = assigns_to_attributes(assigns, [:class])
    custom_class = assigns[:class] || ""
    assigns = assign(assigns, attrs: attrs, custom_class: custom_class)

    ~H"""
      <button type="button" class={["inline-flex h-7 w-7 items-center justify-center rounded-md border border-base-300 bg-base-100 text-base-content transition hover:border-primary/40 hover:bg-base-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40", @custom_class]} title="Move down" {@attrs}>
        <svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" d="m9 12.75 3 3 3-3" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 8.25v7.5" />
        </svg>
      </button>
    """
  end

  def sc_x_button(assigns) do
    attrs = assigns_to_attributes(assigns, [:class])
    custom_class = assigns[:class] || ""
    assigns = assign(assigns, attrs: attrs, custom_class: custom_class)

    ~H"""
      <button type="button" class={["inline-flex h-7 w-7 items-center justify-center rounded-md border border-error/40 bg-error/10 text-error transition hover:bg-error/20 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error/30", @custom_class]} title="Remove item" {@attrs}>
        <svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
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
