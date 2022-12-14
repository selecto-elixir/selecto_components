defmodule SelectoComponents.Views.Detail.OrderByConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do
    ~H"""
      <div class="relative">
        <div>
          <%= @col.name %>
        </div>
        <div class="pl-4">
          <label><input name={"#{@prefix}[dir]"} type="radio" value="asc" checked={Map.get(@config, "dir", "asc")=="asc"}/>Ascending</label>
          <label><input name={"#{@prefix}[dir]"} type="radio" value="desc" checked={Map.get(@config, "dir")=="desc"}/>Descending</label>
        </div>
      </div>
    """
  end
end
