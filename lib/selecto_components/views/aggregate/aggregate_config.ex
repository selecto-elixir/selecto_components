defmodule SelectoComponents.Views.Aggregate.Aggregate.Config do
  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common

  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slot :config, :map

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
      <div class="relative">
        <div>
          <%= @display_name %>
        </div>
        <div class="pl-4">
          <%= case Map.get(@col, :type, :string) do%>
            <% x when x in [:integer, :id, :decimal] -> %>
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  Enum.map(~w(count avg sum min max), fn o -> {o, o} end)
                }/>
              </label>
            <% x when x in [:float] -> %>
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  Enum.map(~w(avg sum min max), fn o -> {o, o} end)
                }/>
              </label>
            <% x when x in [:string] -> %>
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  Enum.map(~w(min max), fn o -> {o, o} end)
                }/>
              </label>
            <% :boolean -> %>
    <!--:Y_N :1_0 :yes_no :check_blank -->
              <label>Format
                #TODO
              </label>

            <% x when x in [:naive_datetime, :utc_datetime] -> %>
                agg types: age buckets?
              <label>Format
                #TODO
              </label>

            <% _ -> %>
              <%= Map.get(@col, :type, :string) %>

          <% end %>
        </div>
        <div class="absolute top-0 right-20">
          <.sc_input name={"#{@prefix}[alias]"} value={Map.get(@config, "alias", "")} placeholder="Alias"/>
        </div>
      </div>


    """
  end
end
