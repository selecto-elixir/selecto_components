defmodule ListableComponentsTailwind.Components.Common do

  use Phoenix.Component

  def button(assigns) do
    attrs = assigns_to_attributes(assigns, [:label])

    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <button {@attrs} class="text-sm leading-5 px-4 py-2 font-medium rounded-md inline-flex items-center justify-center border focus:outline-none transition duration-150 ease-in-out">
        <%= render_slot(@inner_block) %>
      </button>
    """

  end

  def input(assigns) do
    attrs = assigns_to_attributes(assigns, [:label])

    assigns = assign(assigns, attrs: attrs)

    ~H"""
      <input {@attrs} class="border border-red-300 focus:border-gray-500 focus:ring-gray-500 dark:border-gray-600 dark:focus:border-gray-500 sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed shadow-sm rounded-md dark:bg-gray-800 dark:text-gray-300 dark:disabled:bg-gray-700 focus:outline-none focus:ring-gray-500 focus:border-gray-500"/>
    """

  end

  def select(assigns) do

  end

  def checkbox(assigns) do

  end



end
