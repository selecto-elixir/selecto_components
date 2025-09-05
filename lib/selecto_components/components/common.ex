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
      <Heroicons.arrow_down solid class="w-6 h-6 inline border border-2 border-black dark:border-gray-400 rounded-md text-black dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700" {@attrs}/>
    """
  end

  def sc_x_button(assigns) do
    attrs = assigns_to_attributes(assigns, [])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <Heroicons.x_mark solid class="w-6 h-6 text-red-800 dark:text-red-400 inline border border-2 border-red-800 dark:border-red-400 rounded-md hover:bg-red-50 dark:hover:bg-red-900/20" {@attrs}/>
    """
  end

  def sc_input(assigns) do
    attrs = assigns_to_attributes(assigns, [:label])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <input {@attrs} class="border focus:border-gray-500 focus:ring-gray-500 sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed shadow-sm rounded-md focus:outline-none focus:ring-gray-500 focus:border-gray-500 bg-white dark:bg-gray-800 dark:border-gray-600 dark:text-gray-200 dark:focus:border-gray-400 dark:focus:ring-gray-400 dark:disabled:bg-gray-700"/>
    """
  end

  def sc_select_with_slot(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <select {@attrs} class="border-gray-300 focus:border-primary-500 focus:ring-primary-500 disabled:bg-gray-100 disabled:cursor-not-allowed pl-3 pr-10 py-2 text-base focus:outline-none sm:text-sm rounded-md bg-white dark:bg-gray-800 dark:border-gray-600 dark:text-gray-200 dark:focus:border-gray-400 dark:focus:ring-gray-400 dark:disabled:bg-gray-700" >
        <%= render_slot(@inner_block) %>
      </select>
    """
  end

  def sc_select(assigns) do
    attrs = assigns_to_attributes(assigns, [:label, :options, :value])
    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <select {@attrs} class="border-gray-300 focus:border-primary-500 focus:ring-primary-500 disabled:bg-gray-100 disabled:cursor-not-allowed text-base focus:outline-none sm:text-sm rounded-md bg-white dark:bg-gray-800 dark:border-gray-600 dark:text-gray-200 dark:focus:border-gray-400 dark:focus:ring-gray-400 dark:disabled:bg-gray-700" >
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
