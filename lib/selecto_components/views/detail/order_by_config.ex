defmodule SelectoComponents.Views.Detail.OrderByConfig do
  use Phoenix.LiveComponent
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  @impl true
  def update(assigns, socket) do
    # Process the config to extract dir value
    config = case assigns[:config] do
      nil -> %{}
      map when is_map(map) ->
        Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)
      _ -> %{}
    end

    dir_value = Map.get(config, "dir", "asc")

    # Update socket with all assigns and computed dir_value
    {:ok,
      socket
      |> assign(assigns)
      |> assign(:dir_value, dir_value)
      |> assign(:processed_config, config)
    }
  end

  @impl true
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

    # dir_value is already computed in update/2
    ~H"""
      <div class="relative">
        <div>
          <%= @display_name %>
        </div>
        <div class="pl-4">
          <label><input name={"#{@prefix}[dir]"} type="radio" value="asc" checked={@dir_value == "asc"}/>Ascending</label>
          <label><input name={"#{@prefix}[dir]"} type="radio" value="desc" checked={@dir_value == "desc"}/>Descending</label>
        </div>
      </div>
    """
  end
end
