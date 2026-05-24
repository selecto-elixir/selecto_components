defmodule SelectoComponents.Components.NestedTable do
  @moduledoc """
  Component for rendering nested tables from subselect results.
  Provides expandable/collapsible sections for related data.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS
  alias SelectoComponents.Theme

  @doc """
  Renders a nested table for subselect results.

  ## Attributes
  - data: The subselect data (JSON array or list of maps)
  - config: Configuration for the nested table display
  - row_id: Unique identifier for this row (for expand/collapse)
  """
  attr(:data, :any, required: true)
  attr(:config, :map, required: true)
  attr(:row_id, :string, required: true)
  attr(:expanded, :boolean, default: false)
  attr(:theme, :any, default: nil)
  attr(:depth, :integer, default: 0)

  def nested_table(assigns) do
    assigns =
      assigns
      |> Map.put_new(:theme, Theme.default_theme(:light))
      |> Map.put(:parsed_data, parse_subselect_data(assigns.data, assigns.config))
      |> Map.put(:table_id, "nested_#{assigns.row_id}")
      |> Map.put(:column_headers, get_column_headers(assigns))

    ~H"""
    <div class="nested-table-container ml-4 mt-2" style="border-color: var(--sc-surface-border); color: var(--sc-text-primary);">
      <div class="flex items-center">
        <button
          type="button"
          class="flex items-center text-sm font-medium"
          style="color: var(--sc-text-secondary);"
          phx-click={toggle_nested_table(@table_id)}
        >
          <svg
            class={"h-4 w-4 mr-1 transition-transform #{if @expanded, do: "rotate-90", else: ""}"}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
          {@config.title} ({length(@parsed_data)} items)
        </button>
      </div>

      <div id={@table_id} class={if @expanded, do: "block", else: "hidden"}>
        <%= if length(@parsed_data) > 0 do %>
          <div class="mt-2 overflow-x-auto">
            <table class="min-w-full" style="border-color: var(--sc-surface-border);">
              <thead style="background: var(--sc-surface-bg-alt);">
                <tr>
                  <%= for header <- @column_headers do %>
                    <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider" style="color: var(--sc-text-muted);">
                      {header}
                    </th>
                  <% end %>
                </tr>
              </thead>
              <tbody style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border);">
                <%= for {item, idx} <- Enum.with_index(@parsed_data) do %>
                  <%= if idx < max_display_rows(@config) do %>
                    <tr style="border-color: var(--sc-surface-border);">
                      <%= for key <- get_data_keys(@parsed_data, @config) do %>
                        <td class="whitespace-nowrap px-3 py-2 text-sm" style="color: var(--sc-text-primary);">
                          <.nested_value
                            value={Map.get(item, key, "")}
                            config={child_config(@config, key)}
                            row_id={"#{@row_id}_#{idx}_#{safe_key(key)}"}
                            depth={@depth + 1}
                            theme={@theme}
                          />
                        </td>
                      <% end %>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>

            <%= if length(@parsed_data) > max_display_rows(@config) do %>
              <div class="px-3 py-2 text-sm" style="color: var(--sc-text-muted);">
                ... and {length(@parsed_data) - max_display_rows(@config)} more items
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="mt-2 px-3 py-2 text-sm italic" style="color: var(--sc-text-muted);">
            No related {String.downcase(@config.title)} found
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders multiple nested tables for a row with subselect data
  """
  attr(:row, :map, required: true)
  attr(:subselect_configs, :list, default: [])
  attr(:row_id, :string, required: true)
  attr(:theme, :any, default: nil)

  def nested_tables(assigns) do
    ~H"""
    <div class="nested-tables">
      <%= for config <- @subselect_configs do %>
        <.nested_table
          data={Map.get(@row, config.key, [])}
          config={config}
          row_id={@row_id}
          theme={@theme}
          expanded={Map.get(config, :initial_state, :collapsed) == :expanded}
        />
      <% end %>
    </div>
    """
  end

  # Helper functions (made public for inline rendering)

  def parse_subselect_data(data, config \\ %{})
  def parse_subselect_data(nil, _config), do: []

  def parse_subselect_data(data, config) when is_list(data) do
    normalize_subselect_rows(data, config)
  end

  def parse_subselect_data(data, config) when is_binary(data) do
    # Try to parse JSON string
    case Jason.decode(data) do
      {:ok, parsed} when is_list(parsed) -> normalize_subselect_rows(parsed, config)
      _ -> []
    end
  end

  def parse_subselect_data(_, _config), do: []

  defp max_display_rows(config) do
    Map.get(config, :max_rows, 10)
  end

  defp toggle_nested_table(table_id) do
    JS.toggle(to: "##{table_id}")
    |> JS.toggle_class("rotate-90", to: "[data-table='#{table_id}']")
  end

  defp get_column_headers(assigns) do
    case ordered_keys_from_config(assigns.config) do
      [] ->
        case parse_subselect_data(assigns.data, assigns.config) do
          [first | _] when is_map(first) ->
            Map.keys(first)
            |> Enum.map(&humanize_key/1)

          _ ->
            []
        end

      keys ->
        Enum.map(keys, &humanize_key/1)
    end
  end

  def get_data_keys(parsed_data, config \\ %{}) do
    case ordered_keys_from_config(config) do
      [] ->
        case parsed_data do
          [first | _] when is_map(first) -> Map.keys(first)
          _ -> []
        end

      keys ->
        keys
    end
  end

  def humanize_key(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def humanize_key(key), do: to_string(key)

  defp extract_field_name(field) when is_binary(field) do
    field
    |> String.split(".")
    |> List.last()
    |> String.trim()
  end

  defp normalize_subselect_rows([], _config), do: []

  defp normalize_subselect_rows([first | _] = rows, _config) when is_map(first), do: rows

  defp normalize_subselect_rows(rows, config) do
    scalar_key = infer_scalar_column_key(config)

    Enum.map(rows, fn
      item when is_map(item) -> item
      item -> %{scalar_key => item}
    end)
  end

  defp infer_scalar_column_key(config) when not is_map(config), do: "value"

  defp infer_scalar_column_key(config) do
    field_name =
      case Map.get(config, :columns, []) do
        [first_column | _] ->
          case first_column do
            {_, field, _} -> extract_field_name(field)
            %{field: field} -> extract_field_name(field)
            field when is_binary(field) -> extract_field_name(field)
            _ -> nil
          end

        _ ->
          nil
      end

    case field_name do
      name when is_binary(name) and name != "" -> name
      _ -> "value"
    end
  end

  defp ordered_keys_from_config(config) when is_map(config) do
    config
    |> Map.get(:columns, [])
    |> Enum.map(fn
      {_, field, _} -> extract_field_name(field)
      %{field: field} -> extract_field_name(field)
      field when is_binary(field) -> extract_field_name(field)
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp ordered_keys_from_config(_), do: []

  def format_value(value) when is_binary(value), do: value
  def format_value(value) when is_number(value), do: to_string(value)
  def format_value(value) when is_boolean(value), do: to_string(value)
  def format_value(nil), do: ""
  def format_value(value), do: inspect(value)

  @doc """
  Renders an inline nested table for subselect results.
  Designed to appear as part of the parent table column.
  """
  attr(:data, :any, required: true)
  attr(:config, :map, required: true)
  attr(:row_id, :string, required: true)
  attr(:theme, :any, default: nil)
  attr(:depth, :integer, default: 0)

  def inline_nested_table(assigns) do
    assigns =
      assigns
      |> Map.put_new(:theme, Theme.default_theme(:light))
      |> Map.put(:parsed_data, parse_subselect_data(assigns.data, assigns.config))

    ~H"""
    <div class="inline-nested-table">
      <%= if length(@parsed_data) > 0 do %>
        <table class="min-w-full rounded border" style="border-color: var(--sc-surface-border);">
          <thead>
            <tr style="background: var(--sc-surface-bg-alt);">
              <%= for key <- get_data_keys(@parsed_data, @config) do %>
                <th class="border-b px-2 py-1 text-xs font-medium" style="border-color: var(--sc-surface-border); color: var(--sc-text-secondary);">
                  {humanize_key(key)}
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for {item, idx} <- Enum.with_index(@parsed_data) do %>
              <tr class="last:border-b-0" style="border-color: var(--sc-surface-border);">
                <%= for key <- get_data_keys(@parsed_data, @config) do %>
                  <td class="px-2 py-1 text-xs" style="color: var(--sc-text-primary);">
                    <.nested_value
                      value={Map.get(item, key, "")}
                      config={child_config(@config, key)}
                      row_id={"#{@row_id}_#{idx}_#{safe_key(key)}"}
                      depth={@depth + 1}
                      theme={@theme}
                    />
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% else %>
        <div class="text-xs italic" style="color: var(--sc-text-muted);">No data</div>
      <% end %>
    </div>
    """
  end

  attr(:value, :any, required: true)
  attr(:config, :map, required: true)
  attr(:row_id, :string, required: true)
  attr(:depth, :integer, required: true)
  attr(:theme, :any, default: nil)

  defp nested_value(assigns) do
    assigns =
      assigns
      |> Map.put(:nested_data, parse_nested_value(assigns.value))
      |> Map.put(:max_depth_reached?, assigns.depth >= max_depth(assigns.config))

    ~H"""
    <%= cond do %>
      <% @nested_data == [] -> %>
        {format_value(@value)}
      <% @max_depth_reached? -> %>
        {format_value(@value)}
      <% true -> %>
        <.inline_nested_table
          data={@nested_data}
          config={@config}
          row_id={@row_id}
          depth={@depth}
          theme={@theme}
        />
    <% end %>
    """
  end

  defp parse_nested_value(value) when is_list(value) do
    parse_subselect_data(value, %{})
  end

  defp parse_nested_value(value) when is_map(value), do: [value]

  defp parse_nested_value(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} when is_list(decoded) -> parse_subselect_data(decoded, %{})
      {:ok, decoded} when is_map(decoded) -> [decoded]
      _ -> []
    end
  end

  defp parse_nested_value(_value), do: []

  defp child_config(config, key) do
    child =
      config
      |> Map.get(:children, %{})
      |> find_child_config(key)

    Map.merge(
      %{
        key: to_string(key),
        title: humanize_key(key),
        max_rows: max_display_rows(config),
        max_depth: max_depth(config)
      },
      child
    )
  end

  defp find_child_config(children, key) when is_map(children) do
    key_string = to_string(key)

    Map.get(children, key) ||
      Map.get(children, key_string) ||
      find_atom_child_config(children, key_string) ||
      %{}
  end

  defp find_child_config(children, key) when is_list(children) do
    Enum.find(children, %{}, fn child ->
      is_map(child) and
        to_string(Map.get(child, :key, Map.get(child, "key", ""))) == to_string(key)
    end)
  end

  defp find_child_config(_children, _key), do: %{}

  defp find_atom_child_config(children, key) do
    Enum.find_value(children, fn
      {child_key, child_config} when is_atom(child_key) ->
        if Atom.to_string(child_key) == key, do: child_config

      _ ->
        nil
    end)
  end

  defp max_depth(config) do
    case Map.get(config, :max_depth, Map.get(config, "max_depth", 6)) do
      value when is_integer(value) and value >= 0 ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, ""} when parsed >= 0 -> parsed
          _ -> 6
        end

      _ ->
        6
    end
  end

  defp safe_key(key) do
    key
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_-]+/, "_")
  end

  @doc """
  Generates JavaScript hooks for nested table interactions
  """
  def hooks do
    %{
      "NestedTable" => %{
        mounted: """
        this.handleToggle = (e) => {
          const tableId = e.currentTarget.dataset.table;
          const table = document.getElementById(tableId);
          const icon = e.currentTarget.querySelector('svg');
          
          if (table.classList.contains('hidden')) {
            table.classList.remove('hidden');
            icon.classList.add('rotate-90');
          } else {
            table.classList.add('hidden');
            icon.classList.remove('rotate-90');
          }
        };

        this.el.querySelectorAll('[data-toggle]').forEach(btn => {
          btn.addEventListener('click', this.handleToggle);
        });
        """,
        destroyed: """
        this.el.querySelectorAll('[data-toggle]').forEach(btn => {
          btn.removeEventListener('click', this.handleToggle);
        });
        """
      }
    }
  end

  @doc """
  CSS styles for nested tables
  """
  def styles do
    """
    .nested-table-container {
      border-left: 2px solid #e5e7eb;
      padding-left: 1rem;
      margin-bottom: 0.5rem;
    }

    .nested-table-container table {
      font-size: 0.875rem;
    }

    .nested-table-container .rotate-90 {
      transform: rotate(90deg);
    }

    .nested-tables {
      margin-top: 0.5rem;
    }
    """
  end
end
