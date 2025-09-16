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
    # dir_value is already computed in update/2
    ~H"""
      <div class="relative">
        <div>
          <%= @col.name %>
        </div>
        <div class="pl-4">
          <label><input name={"#{@prefix}[dir]"} type="radio" value="asc" checked={@dir_value == "asc"}/>Ascending</label>
          <label><input name={"#{@prefix}[dir]"} type="radio" value="desc" checked={@dir_value == "desc"}/>Descending</label>
        </div>
      </div>
    """
  end
end
