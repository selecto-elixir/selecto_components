defmodule SelectoComponents.Form.EventHandlers.ExportOperations do
  @moduledoc """
  Event handlers for exporting query results.

  Supports immediate download for JSON and CSV exports from the current query
  result set.
  """

  defmacro __using__(_opts) do
    quote do
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

          case Exporter.build(format, query_results, view_mode: view_mode) do
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
              {:noreply, put_flash(socket, :error, "No query results to export yet.")}

            {:error, :unsupported_format} ->
              {:noreply, put_flash(socket, :error, "Unsupported export format.")}

            {:error, _reason} ->
              {:noreply, put_flash(socket, :error, "Export failed. Please try again.")}
          end
        end)
      end
    end
  end
end
