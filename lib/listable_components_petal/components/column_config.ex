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
              <label><input name={"#{@fieldname}[#{@uuid}][commas]"} type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>
            </div>
          <% x when x in [:float] -> %>
            <%= @col.name %>
              <div>
                <label>Precision <select name={"#{@fieldname}[#{@uuid}][precision]"}><option :for={i <- Enum.to_list(0 .. 5)} value={i}
                  selected={Map.get(@config, "precision") == i}><%= i %></option></select></label>
                <label><input name={"#{@fieldname}[#{@uuid}][commas]"} type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>
              </div>
          <% x when x in [:string] -> %>
            <%= @col.name %>
          <% :boolean -> %>
            <%= @col.name %> :Y_N :1_0 :yes_no :check_blank
          <% x when x in [:naive_datetime, :utc_datetime] -> %>
            <%= @col.name %>
            <label>Format <select name={"#{@fieldname}[#{@uuid}][format]"}><option :for={i <-["MM-DD-YYYY HH:MM", "YYYY-MM-DD HH:MM", "ago", "days ago"]} value={i}
                  selected={Map.get(@config, "format") == i}><%= i %></option></select></label>
          <% _ -> %>
            <%= @col.name %>
          <% end %>
      </div>


    """
  end

end
