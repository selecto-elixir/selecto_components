defmodule ListableComponentsPetal.Components.ColumnConfig do
  use Phoenix.LiveComponent

  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do
    ~H"""
      <div>
        <%= case @col.type do%>
          <% x when x in [:int, :id, :decimal] -> %>
            <%= @col.name %>
            <div>
              <label><input type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>
            </div>
          <% x when x in [:float] -> %>
            <%= @col.name %>
              <div>
                <label>Precision <select><option :for={i <- Enum.to_list(0 .. 5)} value={i}
                  selected={Map.get(@config, "precision") == i}><%= i %></option></select></label>
                <label><input type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>
              </div>
          <% x when x in [:string] -> %>
            <%= @col.name %>
          <% :boolean -> %>
            <%= @col.name %> :Y_N :1_0 :yes_no :check_blank
          <% x when x in [:naive_datetime, :utc_datetime] -> %>
            Datetime: <%= @col.name %>
            Pick Format: MM-DD-YYYY HH:MM YYYY-MM-DD HH:MM :ago :daysago
          <% _ -> %>
            <%= @col.name %>
          <% end %>
      </div>


    """
  end

end
