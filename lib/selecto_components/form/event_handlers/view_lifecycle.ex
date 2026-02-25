defmodule SelectoComponents.Form.EventHandlers.ViewLifecycle do
  @moduledoc """
  Event handlers for view lifecycle operations.

  This module handles the core lifecycle events of a SelectoComponents view:
  - Active tab switching (view, filter, save tabs)
  - View validation (form changes without execution)
  - View application (form submission and query execution)
  - Saved view loading

  ## Imported by

  This module is automatically imported when using `SelectoComponents.Form`.

  ## Events Handled

  - `set_active_tab` - Switch between view configuration tabs
  - `view-validate` - Validate form changes without executing query
  - `view-apply` - Apply view configuration and execute query
  - `load_view_config` - Load a saved view configuration
  """

  defmacro __using__(_opts) do
    quote do
      alias SelectoComponents.Form.ParamsState
      import SelectoComponents.Form.ErrorHandling

      @doc """
      Handles switching between active tabs (view, filter, save).

      ## Parameters
      - params: Map containing "tab" key with the tab name
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated active_tab assign
      """
      def handle_event("set_active_tab", params, socket) do
        {:noreply, assign(socket, active_tab: Map.get(params, "tab"))}
      end

      @doc """
      Handles form validation events without executing the query.

      This allows users to configure aggregates, filters, and other view settings
      without triggering immediate query execution. Respects skip_next_validation
      flag to prevent validation after filter add/remove operations.

      ## Parameters
      - params: Form parameters from phx-change event
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated view_config
      """
      def handle_event("view-validate", params, socket) do
        # Check if we should skip this validation (e.g., after filter add/remove)
        if socket.assigns[:skip_next_validation] do
          # Clear the flag and skip processing
          {:noreply, assign(socket, skip_next_validation: false)}
        else
          with_error_handling(socket, "view-validate", fn ->
            # Process all parameters including view-specific configs (aggregates, group_by, etc.)
            socket = ParamsState.params_to_state(params, socket)

            # Don't execute view on validation - only on submit
            # This allows users to configure aggregates without immediate updates
            {:noreply, socket}
          end)
        end
      end

      @doc """
      Handles view application when on the "save" tab.

      Saves the current view configuration with the provided name and redirects
      to the saved view URL.

      ## Parameters
      - params: Map containing "save_as" key with the view name
      - socket: LiveView socket with active_tab: "save"

      ## Returns
      `{:noreply, socket}` with URL updated to saved view
      """
      def handle_event("view-apply", params, %{assigns: %{active_tab: "save"}} = socket) do
        with_error_handling(socket, "save_view", fn ->
          save_as = String.trim(Map.get(params, "save_as", ""))

          cond do
            save_as == "" ->
              {:noreply, put_flash(socket, :error, "Enter a view name before saving")}

            String.match?(save_as, ~r/[^a-zA-Z0-9_ ]/) ->
              {:noreply,
               put_flash(
                 socket,
                 :error,
                 "View name can only include letters, numbers, spaces, and underscore"
               )}

            true ->
              Selecto.Helpers.check_safe_phrase(save_as)

              view =
                socket.assigns.saved_view_module.save_view(
                  save_as,
                  socket.assigns.saved_view_context,
                  params
                )

              params = %{"saved_view" => view.name}
              socket = assign(socket, :current_detail_page, 0)
              {:noreply, ParamsState.state_to_url(params, socket)}
          end
        end)
      end

      @doc """
      Handles standard view application (form submission).

      Executes the query with current parameters and updates the URL.
      Uses execute-then-update-URL pattern to prevent race conditions.

      ## Parameters
      - params: Form parameters from phx-submit event
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with executed query results and updated URL
      """
      def handle_event("view-apply", params, socket) do
        with_error_handling(socket, "view-apply", fn ->
          socket = assign(socket, :current_detail_page, 0)
          # Execute query first, THEN update URL to prevent race condition
          socket = ParamsState.view_from_params(params, socket)
          {:noreply, ParamsState.state_to_url(params, socket)}
        end)
      end

      @doc """
      Handles loading a saved view configuration.

      Loads a previously saved view configuration for the current view type
      (detail/aggregate/graph) and applies it to the current view.

      ## Parameters
      - params: Map containing "name" key with the configuration name
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with loaded configuration applied
      """
      def handle_event("load_view_config", %{"name" => config_name}, socket) do
        with_error_handling(socket, "load_view_config", fn ->
          view_type = socket.assigns.view_config.view_mode || "detail"

          case socket.assigns.saved_view_config_module.get_view_config(
                 config_name,
                 socket.assigns.saved_view_context,
                 view_type,
                 user_id: Map.get(socket.assigns, :current_user_id)
               ) do
            nil ->
              {:noreply, put_flash(socket, :error, "View configuration not found")}

            config ->
              # Decode the saved configuration
              saved_params = socket.assigns.saved_view_config_module.decode_view_config(config)

              # The saved params only contain the view-specific configuration
              # We need to convert it to full params format
              params = ParamsState.convert_saved_config_to_full_params(saved_params, view_type)

              # First update the view_config state from params
              socket = ParamsState.params_to_state(params, socket)

              # Then apply the view
              socket = ParamsState.view_from_params(params, socket)
              {:noreply, put_flash(socket, :info, "View configuration loaded: #{config.name}")}
          end
        end)
      end
    end
  end
end
