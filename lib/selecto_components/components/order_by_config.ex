defmodule SelectoComponents.Components.OrderByConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do

    ~H"""
      <div>
        <%= @item %>
        <label><input name={"order_by[#{@id}][dir]"} type="radio" value="asc" checked={Map.get(@config, "dir")=="asc"}/>Ascending</label>
        <label><input name={"order_by[#{@id}][dir]"} type="radio" value="desc" checked={Map.get(@config, "dir")=="desc"}/>Descending</label>
      </div>
    """
  end
end
