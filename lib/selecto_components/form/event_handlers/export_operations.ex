defmodule SelectoComponents.Form.EventHandlers.ExportOperations do
  @moduledoc """
  Event handlers for exporting query results.

      Supports immediate download and one-off email delivery from the current query
      result set.
  """

  defmacro __using__(_opts) do
    quote do
      alias SelectoComponents.ErrorHandling.ErrorBuilder
      alias SelectoComponents.Exporter
      alias SelectoComponents.ScheduledExports.Service, as: ScheduledExportService
      import SelectoComponents.Form.ErrorHandling

      @max_export_payload_bytes 6_000_000

      @doc """
      Export current query results in supported formats.

      Supported formats:
      - `csv`
      - `tsv`
      - `json`
      - `xlsx`
      """
      def handle_event("export_data", %{"format" => format}, socket) do
        with_error_handling(socket, "export_data", fn ->
          query_results = socket.assigns[:query_results]
          view_mode = socket.assigns[:applied_view] || socket.assigns.view_config.view_mode

          case Exporter.build(format, query_results,
                 view_mode: view_mode,
                 view_config: socket.assigns[:view_config]
               ) do
            {:ok, export} ->
              if byte_size(export.content) > @max_export_payload_bytes do
                {:noreply,
                 put_flash(
                   socket,
                   :error,
                   "Export is too large for direct download. Narrow filters or lower result limits and try again."
                 )}
              else
                {:noreply,
                 socket
                 |> push_event("selecto_export_download", export)
                 |> put_flash(:info, "Export ready: #{export.filename}")}
              end

            {:error, :no_results} ->
              {:noreply, put_flash(socket, :error, export_error_message(:no_results))}

            {:error, :unsupported_format} ->
              {:noreply, put_flash(socket, :error, export_error_message(:unsupported_format))}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, export_error_message(reason))}
          end
        end)
      end

      @doc """
      Send current query results as an email attachment using the configured
      delivery adapter.
      """
      def handle_event("send_export_email", params, socket) do
        with_error_handling(socket, "send_export_email", fn ->
          query_results = socket.assigns[:query_results]
          view_mode = socket.assigns[:applied_view] || socket.assigns.view_config.view_mode

          case socket.assigns[:export_delivery_module] do
            nil ->
              {:noreply,
               put_flash(socket, :error, export_error_message(:missing_delivery_adapter))}

            false ->
              {:noreply,
               put_flash(socket, :error, export_error_message(:missing_delivery_adapter))}

            delivery_module ->
              delivery = %{
                channel: :email,
                email: %{
                  recipients: Map.get(params, "recipients"),
                  subject_template: Map.get(params, "subject"),
                  body_template: Map.get(params, "body")
                }
              }

              case ScheduledExportService.deliver_now(delivery_module, query_results, delivery,
                     format: Map.get(params, "format", "csv"),
                     view_mode: view_mode,
                     view_config: socket.assigns[:view_config],
                     path: Map.get(socket.assigns, :path) || Map.get(socket.assigns, :my_path),
                     delivery_opts: [
                       current_user_id: Map.get(socket.assigns, :current_user_id),
                       tenant_context: Map.get(socket.assigns, :tenant_context),
                       path: Map.get(socket.assigns, :path) || Map.get(socket.assigns, :my_path)
                     ]
                   ) do
                {:ok, result} ->
                  {:noreply,
                   put_flash(
                     socket,
                     :info,
                     "Email export sent: #{result.export.filename}"
                   )}

                {:error, reason} ->
                  {:noreply, put_flash(socket, :error, export_error_message(reason))}
              end
          end
        end)
      end

      defp export_error_message(:no_results) do
        error =
          ErrorBuilder.build("No query results to export yet.",
            stage: :export,
            category: :validation,
            code: :export_no_results,
            operation: "export_data"
          )

        error.summary <> ": " <> error.user_message
      end

      defp export_error_message(:unsupported_format) do
        error =
          ErrorBuilder.build("Unsupported export format.",
            stage: :export,
            category: :validation,
            code: :unsupported_export_format,
            operation: "export_data"
          )

        error.summary <> ": " <> error.user_message
      end

      defp export_error_message(:missing_delivery_adapter) do
        error =
          ErrorBuilder.build("Email export requires `export_delivery_module` to be assigned.",
            stage: :export,
            category: :configuration,
            code: :missing_export_delivery_adapter,
            operation: "send_export_email"
          )

        error.summary <> ": " <> error.user_message
      end

      defp export_error_message(:missing_recipients) do
        error =
          ErrorBuilder.build("Enter at least one email recipient.",
            stage: :export,
            category: :validation,
            code: :missing_export_recipients,
            operation: "send_export_email"
          )

        error.summary <> ": " <> error.user_message
      end

      defp export_error_message({:invalid_recipients, invalid_recipients}) do
        error =
          ErrorBuilder.build(
            "Invalid recipient email(s): #{Enum.join(invalid_recipients, ", ")}",
            stage: :export,
            category: :validation,
            code: :invalid_export_recipients,
            operation: "send_export_email"
          )

        error.summary <> ": " <> error.user_message
      end

      defp export_error_message(:payload_too_large) do
        error =
          ErrorBuilder.build("Email export is too large to attach directly.",
            stage: :export,
            category: :validation,
            code: :email_export_payload_too_large,
            operation: "send_export_email"
          )

        error.summary <> ": " <> error.user_message
      end

      defp export_error_message(reason) do
        error =
          ErrorBuilder.build(inspect(reason),
            stage: :export,
            category: :runtime,
            code: :export_failed,
            operation: "export_data"
          )

        error.summary <> ": " <> error.user_message
      end
    end
  end
end
