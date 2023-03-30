defmodule SelectoComponents.Components.Common do
  use Phoenix.Component

  def sc_button(assigns) do
    attrs = assigns_to_attributes(assigns, [:label])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <button {@attrs} class="text-sm leading-5 px-4 py-2 font-medium rounded-md inline-flex items-center justify-center border focus:outline-none transition duration-150 ease-in-out">
        <%= render_slot(@inner_block) %>
      </button>
    """
  end

  def sc_up_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <Heroicons.arrow_up solid class="w-6 h-6 inline border border-2 border-black rounded-md" {@attrs}/>
    """
  end

  def sc_down_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <Heroicons.arrow_down solid class="w-6 h-6 inline border border-2 border-black rounded-md" {@attrs}/>
    """
  end

  def sc_x_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <Heroicons.x_mark solid class="w-6 h-6 text-red-800 inline border border-2 border-red-800 rounded-md" {@attrs}/>
    """
  end

  def sc_input(assigns) do
    attrs = assigns_to_attributes(assigns, [:label])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <input {@attrs} class="border focus:border-gray-500 focus:ring-gray-500   sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed shadow-sm rounded-md    focus:outline-none focus:ring-gray-500 focus:border-gray-500"/>
    """
  end

  def sc_select_with_slot(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <select {@attrs} class="border-gray-300 focus:border-primary-500 focus:ring-primary-500     disabled:bg-gray-100 disabled:cursor-not-allowed pl-3 pr-10 py-2 text-base focus:outline-none sm:text-sm rounded-md    " >
        <%= render_slot(@inner_block) %>
      </select>
    """
  end

  def sc_select(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <select {@attrs} class="border-gray-300 focus:border-primary-500 focus:ring-primary-500     disabled:bg-gray-100 disabled:cursor-not-allowed text-base focus:outline-none sm:text-sm rounded-md    " >
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
