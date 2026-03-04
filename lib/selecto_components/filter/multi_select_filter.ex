defmodule SelectoComponents.Filter.MultiSelectFilter do
  @moduledoc """
  Multi-select filter component for join mode fields (lookup, star, tag).

  Loads ID+name pairs from the database and displays:
  - Checkbox list for lookup mode (<50 items)
  - Searchable dropdown for star/tag modes

  Users select by name, but IDs are stored for efficient filtering.
  """

  use Phoenix.LiveComponent

  @identifier_regex ~r/^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*$/

  @impl true
  def mount(socket) do
    {:ok, assign(socket, options: [], selected_ids: [], loading: true, search: "")}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Load options on first mount or when field changes
    socket =
      if socket.assigns.loading or should_reload?(socket, assigns) do
        load_options(socket)
      else
        socket
      end

    {:ok, socket}
  end

  defp should_reload?(socket, new_assigns) do
    # Reload if field or filter_id changed
    Map.get(socket.assigns, :field) != Map.get(new_assigns, :field)
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :join_mode, get_in(assigns, [:field_config, :join_mode]) || :lookup)

    ~H"""
    <div class="multi-select-filter">
      <%= if @loading do %>
        <div class="text-sm text-gray-400 italic p-2">
          Loading options...
        </div>
      <% else %>
        <%= if @join_mode == :lookup and length(@options) < 20 do %>
          <.checkbox_list {assigns} />
        <% else %>
          <.searchable_dropdown {assigns} />
        <% end %>
      <% end %>
    </div>
    """
  end

  # Checkbox list for small datasets
  defp checkbox_list(assigns) do
    ~H"""
    <div class="space-y-1">
      <div class="text-xs text-gray-600 mb-2">
        Select {get_in(@field_config, [:display_field]) || "options"}:
      </div>

      <div class="max-h-48 overflow-y-auto border border-gray-200 rounded-md p-2 bg-white space-y-1">
        <%= for opt <- @options do %>
          <label class="flex items-center space-x-2 hover:bg-blue-50 px-2 py-1 rounded cursor-pointer transition-colors">
            <input
              type="checkbox"
              phx-click="toggle"
              phx-value-id={opt.id}
              phx-target={@myself}
              checked={opt.id in @selected_ids}
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500 h-4 w-4"
            />
            <span class="text-sm text-gray-900 flex-1">{opt.name}</span>
          </label>
        <% end %>
      </div>

      <div class="text-xs text-gray-500 mt-1">
        {length(@selected_ids)} of {length(@options)} selected
      </div>
    </div>
    """
  end

  # Searchable dropdown for larger datasets
  defp searchable_dropdown(assigns) do
    ~H"""
    <div class="space-y-2">
      <input
        type="text"
        phx-keyup="search"
        phx-target={@myself}
        phx-debounce="300"
        value={@search}
        placeholder="Search..."
        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
      />

      <div class="max-h-48 overflow-y-auto border border-gray-200 rounded-md p-2 bg-white space-y-1">
        <%= for opt <- filtered_options(@options, @search) do %>
          <label class="flex items-center space-x-2 hover:bg-blue-50 px-2 py-1 rounded cursor-pointer transition-colors">
            <input
              type="checkbox"
              phx-click="toggle"
              phx-value-id={opt.id}
              phx-target={@myself}
              checked={opt.id in @selected_ids}
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500 h-4 w-4"
            />
            <span class="text-sm text-gray-900 flex-1">{opt.name}</span>
          </label>
        <% end %>
      </div>

      <div class="text-xs text-gray-500">
        {length(@selected_ids)} selected
      </div>
    </div>
    """
  end

  defp filtered_options(options, ""), do: options

  defp filtered_options(options, search) when is_binary(search) do
    search_lower = String.downcase(search)

    Enum.filter(options, fn opt ->
      String.contains?(String.downcase(to_string(opt.name)), search_lower)
    end)
  end

  @impl true
  def handle_event("toggle", %{"id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, ""} ->
        selected_ids = socket.assigns.selected_ids

        selected_ids =
          if id in selected_ids do
            List.delete(selected_ids, id)
          else
            [id | selected_ids]
          end

        # Update parent component with new value (comma-separated IDs)
        value = Enum.join(selected_ids, ",")
        send(self(), {:multi_select_changed, socket.assigns.filter_id, value})

        {:noreply, assign(socket, selected_ids: selected_ids)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"value" => search}, socket) do
    {:noreply, assign(socket, search: search)}
  end

  # Load options from database
  defp load_options(socket) do
    field_config = socket.assigns[:field_config] || %{}
    field = socket.assigns[:field]
    selecto = socket.assigns[:selecto]
    connection = socket.assigns[:repo] || selecto.connection

    # Parse field name to get schema and field
    if is_binary(field) && String.contains?(field, ".") do
      [schema_name, _field_name] = String.split(field, ".", parts: 2)

      # Get schema configuration from domain
      domain = Selecto.domain(selecto)

      schema_atom =
        try do
          String.to_existing_atom(schema_name)
        rescue
          ArgumentError -> nil
        end

      if schema_atom do
        schema_config = get_in(domain, [:schemas, schema_atom])

        if schema_config do
          # Get table and field info
          table = schema_config[:source_table]
          id_field = field_config[:id_field] || :id
          display_field = field_config[:display_field] || :name
          join_mode = field_config[:join_mode] || :lookup

          # Determine limit based on join mode
          limit =
            case join_mode do
              :lookup -> 100
              :star -> 500
              :tag -> 100
            end

          # Query options
          options = query_table_options(connection, table, id_field, display_field, limit)

          # Parse currently selected IDs from value
          current_value = socket.assigns[:value] || ""
          selected_ids = parse_ids(current_value)

          assign(socket, options: options, selected_ids: selected_ids, loading: false)
        else
          assign(socket, options: [], selected_ids: [], loading: false)
        end
      else
        assign(socket, options: [], selected_ids: [], loading: false)
      end
    else
      assign(socket, options: [], selected_ids: [], loading: false)
    end
  rescue
    error ->
      require Logger
      Logger.warning("Error loading multi-select options: #{inspect(error)}")
      assign(socket, options: [], selected_ids: [], loading: false)
  end

  # Query database for ID+name pairs
  defp query_table_options(connection, table, id_field, display_field, limit) do
    require Logger

    with {:ok, safe_table} <- safe_sql_identifier(table),
         {:ok, safe_id_field} <- safe_sql_identifier(id_field),
         {:ok, safe_display_field} <- safe_sql_identifier(display_field) do
      query = """
      SELECT #{safe_id_field} as id, #{safe_display_field} as name
      FROM #{safe_table}
      WHERE #{safe_display_field} IS NOT NULL
      ORDER BY #{safe_display_field}
      LIMIT $1
      """

      case execute_options_query(connection, query, [limit]) do
        {:ok, %{rows: rows}} ->
          Enum.map(rows, fn [id, name] ->
            %{id: id, name: to_string(name)}
          end)

        {:error, error} ->
          Logger.warning("Query error loading options: #{inspect(error)}")
          []
      end
    else
      {:error, :invalid_identifier} ->
        Logger.warning("Query skipped for multi-select options due to invalid identifier")
        []
    end
  end

  defp execute_options_query(connection, query, params) when is_atom(connection) do
    cond do
      function_exported?(connection, :query, 2) ->
        connection.query(query, params)

      function_exported?(connection, :query, 3) ->
        connection.query(query, params, [])

      true ->
        do_postgrex_query(connection, query, params)
    end
  end

  defp execute_options_query(connection, query, params) when is_pid(connection) do
    do_postgrex_query(connection, query, params)
  end

  defp execute_options_query(_connection, _query, _params), do: {:error, :invalid_connection}

  defp do_postgrex_query(connection, query, params) do
    if Code.ensure_loaded?(Postgrex) do
      apply(Postgrex, :query, [connection, query, params])
    else
      {:error, :postgrex_not_available}
    end
  end

  defp safe_sql_identifier(value) when is_atom(value),
    do: safe_sql_identifier(Atom.to_string(value))

  defp safe_sql_identifier(value) when is_binary(value) do
    trimmed = String.trim(value)

    if Regex.match?(@identifier_regex, trimmed) do
      {:ok, trimmed}
    else
      {:error, :invalid_identifier}
    end
  end

  defp safe_sql_identifier(_value), do: {:error, :invalid_identifier}

  # Parse comma-separated IDs from value string
  defp parse_ids(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn id_str ->
      case Integer.parse(id_str) do
        {id, _} -> id
        :error -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_ids(_), do: []
end
