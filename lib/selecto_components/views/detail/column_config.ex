defmodule SelectoComponents.Views.Detail.ColumnConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias SelectoComponents.Theme
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do
    # Get the display name from the columns list FIRST
    item_str = to_string(assigns[:item] || "")

    # Find the name in the columns list
    display_name =
      case Enum.find(assigns[:columns] || [], fn
             {id, _name, _type} -> to_string(id) == item_str
             {id, _name, _type, _metadata} -> to_string(id) == item_str
             _ -> false
           end) do
        {_id, name, _type} ->
          name

        {_id, name, _type, _metadata} ->
          name

        nil ->
          # Try with atom if string didn't work
          item_atom =
            try do
              String.to_existing_atom(item_str)
            rescue
              _ -> nil
            end

          case item_atom &&
                 Enum.find(assigns[:columns] || [], fn
                   {id, _name, _type} -> id == item_atom
                   {id, _name, _type, _metadata} -> id == item_atom
                   _ -> false
                 end) do
            {_id, name, _type} ->
              name

            {_id, name, _type, _metadata} ->
              name

            _ ->
              # Last resort: use col.name if available, otherwise the item ID
              if assigns[:col] && assigns.col && assigns.col.name do
                assigns.col.name
              else
                assigns[:item] || "Unknown"
              end
          end
      end

    col_type =
      Selecto.Temporal.date_like_type(assigns[:col] || %{}) ||
        Map.get(assigns[:col] || %{}, :type, :string)

    configure_component = Map.get(assigns[:col] || %{}, :configure_component)

    show_options =
      col_type in [:int, :id, :float, :decimal, :naive_datetime, :utc_datetime, :date] or
        is_function(configure_component)

    assigns =
      assigns
      |> assign_new(:theme, fn -> Theme.default_theme(:light) end)
      |> Map.put(:display_name, display_name)
      |> Map.put(:show_options, show_options)

    ~H"""
      <div class="space-y-2">
        <div>
          <div class="text-sm font-medium" style="color: var(--sc-text-secondary);">Name:</div>
          <div class="pl-2" style="color: var(--sc-text-primary);"><%= @display_name %></div>
        </div>

        <div>
          <div class="text-sm font-medium" style="color: var(--sc-text-secondary);">Alias:</div>
          <div class="pl-2">
            <.sc_input theme={@theme} name={"#{@prefix}[alias]"} value={Map.get(@config, "alias", "")} placeholder="Enter alias"/>
          </div>
        </div>

        <div :if={@show_options}>
          <div class="text-sm font-medium" style="color: var(--sc-text-secondary);">Options:</div>
          <div class="space-y-2 pl-2" style="color: var(--sc-text-primary);">
            <%= case Selecto.Temporal.date_like_type(@col) || Map.get(@col, :type, :string) do%>
              <% x when x in [:int, :id] -> %>
                <label class={Theme.slot(@theme, :checkbox_label) <> " inline-flex items-center gap-2 text-sm"}><input name={"#{@prefix}[commas]"} type="checkbox" checked={Map.get(@config, "commas")} class="h-4 w-4 rounded border" style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); accent-color: var(--sc-accent);"/>Commas</label>

              <% x when x in [:float, :decimal] -> %>
                <label class={Theme.slot(@theme, :checkbox_label) <> " inline-flex items-center gap-2 text-sm"}><input name={"#{@prefix}[commas]"} type="checkbox" checked={Map.get(@config, "commas")} class="h-4 w-4 rounded border" style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); accent-color: var(--sc-accent);"/>Commas</label>
                <label class="block text-sm" style="color: var(--sc-text-primary);"><.sc_select theme={@theme} name={"#{@prefix}[decimal_places]"}
                  options={Enum.map(~w(0 1 2 3), fn o -> {o, o} end )}
                  value={Map.get(@config, "decimal_places")}/>
                  Decimal Places</label>

              <% x when x in [:naive_datetime, :utc_datetime, :date] -> %>
                <label class="block text-sm" style="color: var(--sc-text-primary);">Format
                  <.sc_select
                    theme={@theme}
                    name={"#{@prefix}[format]"}
                    value={Map.get(@config, "format")}
                    options={SelectoComponents.Helpers.datetime_grouping_format_options()}
                  />
                </label>

                <%= if Map.get(@config, "format") in ["age_buckets", "custom_buckets", "year_buckets"] do %>
                  <label class="block text-sm" style="color: var(--sc-text-primary);">
                    Bucket Ranges
                    <.sc_input
                      theme={@theme}
                      name={"#{@prefix}[bucket_ranges]"}
                      value={Map.get(@config, "bucket_ranges", "")}
                      placeholder={SelectoComponents.Helpers.datetime_bucket_placeholder(Map.get(@config, "format"))}
                    />
                  </label>
                <% end %>

              <% _ -> %>
                <%= case Map.get(@col, :configure_component) do %>
                  <% colconf when is_function(colconf) -> %>
                    <%= colconf.(%{
                      col: @col,
                      config: @config,
                      prefix: @prefix
                    }) %>
                  <% _ -> %>
                <% end %>
            <% end %>
          </div>
        </div>
      </div>
    """
  end
end
