defmodule SelectoComponents.Views.Aggregate.GroupByConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do
    assigns = Map.put(assigns, :prefix, "#{assigns.fieldname}[#{assigns.uuid}]")

    ~H"""
      <div>
        <%= case @col.type do%>
          <% x when x in [:int, :id, :decimal] -> %>
            <%= @col.name %>
          <% x when x in [:float] -> %>
            <%= @col.name %> (ranges)
          <% x when x in [:string] -> %>
            <%= @col.name %>
          <% :boolean -> %>
            <%= @col.name %><!--:Y_N :1_0 :yes_no :check_blank -->
          <% x when x in [:naive_datetime, :utc_datetime] -> %>
            <%= @col.name %>
            <label>Format
              <.select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                Enum.map(["Year", "Month", "Day", "Hour"], fn o -> {o, o} end)
              }/>
            </label>
          <% _ -> %>
            <%= @col.name %>
          <% end %>
      </div>


    """
  end
end
