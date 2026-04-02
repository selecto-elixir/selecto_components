defmodule SelectoComponents.Components.Common do
  use Phoenix.Component

  alias SelectoComponents.Theme

  def sc_button(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :class, :variant])
    custom_class = assigns[:class] || ""
    variant = assigns[:variant] || :secondary

    assigns =
      assign(assigns,
        attrs: attrs,
        custom_class: custom_class,
        variant_class: button_variant_class(variant)
      )

    ~H"""
      <button {@attrs} class={[@variant_class, @custom_class]}>
        <%= render_slot(@inner_block) %>
      </button>
    """
  end

  def sc_up_button(assigns) do
    attrs = assigns_to_attributes(assigns, [:class])
    custom_class = assigns[:class] || ""
    assigns = assign(assigns, attrs: attrs, custom_class: custom_class)

    ~H"""
      <button type="button" class={[Theme.slot(Theme.default_theme(:light), :button_icon), "h-7 w-7", @custom_class]} title="Move up" {@attrs}>
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
      <button type="button" class={[Theme.slot(Theme.default_theme(:light), :button_icon), "h-7 w-7", @custom_class]} title="Move down" {@attrs}>
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
      <button type="button" class={[Theme.slot(Theme.default_theme(:light), :button_danger), "h-7 w-7", @custom_class]} title="Remove item" {@attrs}>
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
      <input {@attrs} class={[Theme.slot(Theme.default_theme(:light), :input), @custom_class]}/>
    """
  end

  def sc_select_with_slot(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <select {@attrs} class={Theme.slot(Theme.default_theme(:light), :select)} >
        <%= render_slot(@inner_block) %>
      </select>
    """
  end

  def sc_select(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <select {@attrs} class={Theme.slot(Theme.default_theme(:light), :select)} >
        <option :for={{val, lab} <- @options} value={val} selected={val == @value}><%= lab %></option>
      </select>
    """
  end

  def sc_checkbox(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <label class={Theme.slot(Theme.default_theme(:light), :checkbox_label)}>
        <input type="checkbox" {@attrs}/>
        <%= render_slot(@inner_block) %>
      </label>
    """
  end

  defp button_variant_class(:primary),
    do: Theme.slot(Theme.default_theme(:light), :button_primary)

  defp button_variant_class("primary"),
    do: Theme.slot(Theme.default_theme(:light), :button_primary)

  defp button_variant_class(_), do: Theme.slot(Theme.default_theme(:light), :button_secondary)
end
