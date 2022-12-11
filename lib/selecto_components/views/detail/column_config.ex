defmodule SelectoComponents.Views.Detail.ColumnConfig do
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
              <!-- <label><input name={"#{@fieldname}[#{@uuid}][commas]"} type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>-->
          <% x when x in [:float] -> %>
            <%= @col.name %>
          <% x when x in [:string] -> %>
            <%= @col.name %>
          <% :boolean -> %>
            <%= @col.name %><!--:Y_N :1_0 :yes_no :check_blank -->
          <% x when x in [:naive_datetime, :utc_datetime] -> %>
            <%= @col.name %>
            <label>Format
              <.select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={ SelectoComponents.Helpers.date_formats() }/>
            </label>
          <% _ -> %>
            <%= case Map.get(@col, :configure_component) do %>
            <% x when is_function(x) -> %>
              <%= x.(%{
                col: @col,
                config: @config,
                prefix: @prefix
              }) %>
            <% nil -> %>
              <%= @col.name %>

            <% end %>

          <% end %>
      </div>


    """
  end
end
