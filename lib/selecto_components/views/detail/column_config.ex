defmodule SelectoComponents.Views.Detail.ColumnConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do
    # Get the display name from the columns list FIRST
    item_str = to_string(assigns[:item] || "")

    # Find the name in the columns list
    display_name = case Enum.find(assigns[:columns] || [], fn
      {id, _name, _type} -> to_string(id) == item_str
      {id, _name, _type, _metadata} -> to_string(id) == item_str
      _ -> false
    end) do
      {_id, name, _type} -> name
      {_id, name, _type, _metadata} -> name
      nil ->
        # Try with atom if string didn't work
        item_atom = try do
          String.to_existing_atom(item_str)
        rescue
          _ -> nil
        end

        case item_atom && Enum.find(assigns[:columns] || [], fn
          {id, _name, _type} -> id == item_atom
          {id, _name, _type, _metadata} -> id == item_atom
          _ -> false
        end) do
          {_id, name, _type} -> name
          {_id, name, _type, _metadata} -> name
          _ ->
            # Last resort: use col.name if available, otherwise the item ID
            if assigns[:col] && assigns.col && assigns.col.name do
              assigns.col.name
            else
              assigns[:item] || "Unknown"
            end
        end
    end

    assigns = Map.put(assigns, :display_name, display_name)

    ~H"""
      <div class="space-y-2">
        <div>
          <div class="font-medium text-sm text-gray-700">Name:</div>
          <div class="pl-2"><%= @display_name %></div>
        </div>

        <div>
          <div class="font-medium text-sm text-gray-700">Alias:</div>
          <div class="pl-2">
            <.sc_input name={"#{@prefix}[alias]"} value={Map.get(@config, "alias", "")} placeholder="Enter alias"/>
          </div>
        </div>

        <div>
          <div class="font-medium text-sm text-gray-700">Options:</div>
          <div class="pl-2">
            <%= case Map.get(@col, :type, :string) do%>
              <% x when x in [:int, :id] -> %>
                <label><input name={"#{@prefix}[commas]"} type="checkbox" checked={Map.get(@config, "commas")}/>Commas</label>

              <% x when x in [:float, :decimal] -> %>
                <label><input name={"#{@prefix}[commas]"} type="checkbox" checked={Map.get(@config, "commas")}/>Commas</label>
                <label><.sc_select name={"#{@prefix}[decimal_places]"}
                  options={Enum.map(~w(0 1 2 3), fn o -> {o, o} end )}
                  value={Map.get(@config, "decimal_places")}/>
                  Decimal Places</label>

              <% x when x in [:string] -> %>
                <span class="text-sm text-gray-500">No additional options</span>

              <% :boolean -> %>
                <!--:Y_N :1_0 :yes_no :check_blank -->
                <span class="text-sm text-gray-500">Boolean display options coming soon</span>

              <% x when x in [:naive_datetime, :utc_datetime] -> %>
                <label>Format
                  <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={ SelectoComponents.Helpers.date_formats() }/>
                </label>

              <% _ -> %>
                <%= case Map.get(@col, :configure_component) do %>
                  <% colconf when is_function(colconf) -> %>
                    <%= colconf.(%{
                      col: @col,
                      config: @config,
                      prefix: @prefix
                    }) %>
                  <% nil -> %>
                    <span class="text-sm text-gray-500">No additional options</span>
                <% end %>
            <% end %>
          </div>
        </div>
      </div>
    """
  end
end
