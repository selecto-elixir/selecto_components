defmodule SelectoComponents.Modal.ModalWrapper do
  @moduledoc """
  Provides a reusable modal wrapper component with animations and backdrop.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Modal wrapper component with backdrop and animations.
  """
  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={show_modal()}
      phx-remove={hide_modal()}
      phx-hook="ModalControl"
      data-cancel={JS.exec("data-cancel", to: "##{@id}")}
      class="relative z-50 hidden"
    >
      <%!-- Backdrop --%>
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
        aria-hidden="true"
        phx-click={@on_cancel}
      />
      
      <%!-- Modal container --%>
      <div
        class="fixed inset-0 z-50 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div
            id={"#{@id}-content"}
            class={"relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 #{size_classes(@size)}"}
            phx-click-away={@on_cancel}
            phx-window-keydown={@on_cancel}
            phx-key="escape"
          >
            <%!-- Modal header --%>
            <%= if @show_header do %>
              <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <%= if @icon do %>
                    <div class={"mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full sm:mx-0 sm:h-10 sm:w-10 #{icon_bg_class(@icon_type)}"}>
                      <%= render_slot(@icon) %>
                    </div>
                  <% end %>
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left flex-1">
                    <h3 class="text-lg font-medium leading-6 text-gray-900" id={"#{@id}-title"}>
                      <%= @title %>
                    </h3>
                    <%= if @subtitle do %>
                      <div class="mt-2">
                        <p class="text-sm text-gray-500" id={"#{@id}-description"}>
                          <%= @subtitle %>
                        </p>
                      </div>
                    <% end %>
                  </div>
                  <%!-- Close button --%>
                  <button
                    type="button"
                    class="ml-auto bg-white rounded-md text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                    phx-click={@on_cancel}
                  >
                    <span class="sr-only">Close</span>
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              </div>
            <% end %>
            
            <%!-- Modal body --%>
            <div class={"#{if @show_header, do: "px-4 pb-4 sm:px-6 sm:pb-4", else: "p-6"} max-h-[70vh] overflow-y-auto"}>
              <%= render_slot(@inner_block) %>
            </div>
            
            <%!-- Modal footer --%>
            <%= if @footer do %>
              <div class="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
                <%= render_slot(@footer) %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Show modal with animation.
  """
  def show_modal(js \\ %JS{}) do
    js
    |> JS.show(
      to: "#modal",
      transition: {
        "transition-all transform ease-out duration-300",
        "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
        "opacity-100 translate-y-0 sm:scale-100"
      }
    )
    |> JS.show(
      to: "#modal-bg",
      transition: {
        "transition-all transform ease-out duration-300",
        "opacity-0",
        "opacity-100"
      }
    )
    |> JS.show(
      to: "#modal-content",
      transition: {
        "transition-all transform ease-out duration-300",
        "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
        "opacity-100 translate-y-0 sm:scale-100"
      },
      time: 300
    )
    |> JS.focus_first(to: "#modal-content")
  end
  
  @doc """
  Hide modal with animation.
  """
  def hide_modal(js \\ %JS{}) do
    js
    |> JS.hide(
      to: "#modal-content",
      transition: {
        "transition-all transform ease-in duration-200",
        "opacity-100 translate-y-0 sm:scale-100",
        "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
      }
    )
    |> JS.hide(
      to: "#modal-bg",
      transition: {
        "transition-all transform ease-in duration-200",
        "opacity-100",
        "opacity-0"
      }
    )
    |> JS.hide(to: "#modal", time: 200)
    |> JS.pop_focus()
  end
  
  # Helper functions
  
  defp size_classes(:sm), do: "sm:w-full sm:max-w-sm"
  defp size_classes(:md), do: "sm:w-full sm:max-w-lg"
  defp size_classes(:lg), do: "sm:w-full sm:max-w-xl"
  defp size_classes(:xl), do: "sm:w-full sm:max-w-2xl"
  defp size_classes(:full), do: "sm:w-full sm:max-w-4xl"
  defp size_classes(_), do: "sm:w-full sm:max-w-lg"
  
  defp icon_bg_class(:info), do: "bg-blue-100"
  defp icon_bg_class(:success), do: "bg-green-100"
  defp icon_bg_class(:warning), do: "bg-yellow-100"
  defp icon_bg_class(:error), do: "bg-red-100"
  defp icon_bg_class(_), do: "bg-gray-100"
  
  @doc """
  JavaScript hooks for modal functionality.
  """
  def __hooks__() do
    %{
      "ModalControl" => %{
        mounted: """
        this.handleKeyPress = this.handleKeyPress.bind(this);
        this.handleClickOutside = this.handleClickOutside.bind(this);
        
        // Add keyboard event listener
        document.addEventListener('keydown', this.handleKeyPress);
        
        // Setup click outside handler
        const modalContent = this.el.querySelector('[id$="-content"]');
        if (modalContent) {
          document.addEventListener('click', this.handleClickOutside);
        }
        """,
        
        destroyed: """
        document.removeEventListener('keydown', this.handleKeyPress);
        document.removeEventListener('click', this.handleClickOutside);
        """,
        
        handleKeyPress: """
        function(e) {
          // Close on ESC
          if (e.key === 'Escape') {
            this.pushEvent('close_modal', {});
          }
          // Navigate with arrow keys
          else if (e.key === 'ArrowLeft') {
            this.pushEvent('navigate_record', {direction: 'prev'});
          }
          else if (e.key === 'ArrowRight') {
            this.pushEvent('navigate_record', {direction: 'next'});
          }
        }
        """,
        
        handleClickOutside: """
        function(e) {
          const modalContent = this.el.querySelector('[id$="-content"]');
          if (modalContent && !modalContent.contains(e.target)) {
            const backdrop = this.el.querySelector('[id$="-bg"]');
            if (backdrop && backdrop.contains(e.target)) {
              this.pushEvent('close_modal', {});
            }
          }
        }
        """
      }
    }
  end
end