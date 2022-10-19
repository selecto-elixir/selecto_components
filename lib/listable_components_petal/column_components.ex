defmodule ListableComponentsPetal.ColumnComponents do
  use Phoenix.LiveComponent

  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do
    ~H"""
      <div>
        <%= case @col.type do%>
          <% :string -> %>
            String: <%= @col.name %>
          <% x when x in [:int, :id] -> %>
            Int/ID: <%= @col.name %>
          <% :float -> %>
            Float: <%= @col.name %> (precision)
          <% :decimal -> %>
            Decimal: <%= @col.name %>
          <% :boolean -> %>
            Bool: <%= @col.name %> (config)
          <% :naive_datetime -> %>
            Datetime: <%= @col.name %> (Pick format!)
          <% _ -> %>
            Other: <%= @col.name %> (config)
          <% end %>
      </div>

    """
  end
end
