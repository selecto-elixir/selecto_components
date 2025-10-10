defmodule SelectoComponents.Filter.MultiSelectFilter do
  @moduledoc """
  Multi-select filter component for join mode fields (lookup, star, tag).

  Loads ID+name pairs from the database and displays:
  - Checkbox list for lookup mode (<50 items)
  - Searchable dropdown for star/tag modes

  Users select by name, but IDs are stored for efficient filtering.
  """

  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok, assign(socket, options: [], selected_ids: [], loading: true, search: "")}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Load options on first mount or when field changes
    socket = if socket.assigns.loading or should_reload?(socket, assigns) do
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
        Select <%= get_in(@field_config, [:display_field]) || "options" %>:
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
            <span class="text-sm text-gray-900 flex-1"><%= opt.name %></span>
          </label>
        <% end %>
      </div>

      <div class="text-xs text-gray-500 mt-1">
        <%= length(@selected_ids) %> of <%= length(@options) %> selected
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
            <span class="text-sm text-gray-900 flex-1"><%= opt.name %></span>
          </label>
        <% end %>
      </div>

      <div class="text-xs text-gray-500">
        <%= length(@selected_ids) %> selected
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
    id = String.to_integer(id_str)
    selected_ids = socket.assigns.selected_ids

    selected_ids = if id in selected_ids do
      List.delete(selected_ids, id)
    else
      [id | selected_ids]
    end

    # Update parent component with new value (comma-separated IDs)
    value = Enum.join(selected_ids, ",")
    send(self(), {:multi_select_changed, socket.assigns.filter_id, value})

    {:noreply, assign(socket, selected_ids: selected_ids)}
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
    repo = socket.assigns[:repo]

    # Parse field name to get schema and field
    if is_binary(field) && String.contains?(field, ".") do
      [schema_name, _field_name] = String.split(field, ".", parts: 2)

      # Get schema configuration from domain
      domain = Selecto.domain(selecto)

      schema_atom = try do
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
          limit = case join_mode do
            :lookup -> 100
            :star -> 500
            :tag -> 100
          end

          # Query options
          options = query_table_options(repo, table, id_field, display_field, limit)

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
  defp query_table_options(repo, table, id_field, display_field, limit) do
    query = """
    SELECT #{id_field} as id, #{display_field} as name
    FROM #{table}
    WHERE #{display_field} IS NOT NULL
    ORDER BY #{display_field}
    LIMIT $1
    """

    case repo.query(query, [limit]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name] ->
          %{id: id, name: to_string(name)}
        end)

      {:error, error} ->
        require Logger
        Logger.warning("Query error loading options: #{inspect(error)}")
        []
    end
  end

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
