defmodule SelectoComponents.Form.EventHandlers.ExportOperations do
  @moduledoc """
  Event handlers for exporting query results.

  Supports immediate download for JSON and CSV exports from the current query
  result set.
  """

  defmacro __using__(_opts) do
    quote do
      alias SelectoComponents.ErrorHandling.ErrorBuilder
      alias SelectoComponents.Exporter
      import SelectoComponents.Form.ErrorHandling

      @max_export_payload_bytes 6_000_000

      @doc """
      Export current query results in supported formats.

      Supported formats:
      - `csv`
      - `json`
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
