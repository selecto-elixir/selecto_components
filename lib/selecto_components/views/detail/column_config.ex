defmodule SelectoComponents.Views.Detail.ColumnConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do

    ~H"""
      <div>
        <%= @col.name %>

        <%= case @col.type do%>
          <% x when x in [:int, :id, :decimal] -> %>
              <!-- <label><input name={"#{@fieldname}[#{@uuid}][commas]"} type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>-->

          <% x when x in [:float] -> %>

          <% x when x in [:string] -> %>

          <% :boolean -> %>
            <!--:Y_N :1_0 :yes_no :check_blank -->

          <% x when x in [:naive_datetime, :utc_datetime] -> %>
            <label>Format
              <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={ SelectoComponents.Helpers.date_formats() }/>
            </label>

          <% _ -> %>
            <%= case Map.get(@col, :configure_component) do %>
              <% colconf when is_function(colconf) -> %>
                <%= colconf.(%{
                  col: @col,
                  config: @config,
                  prefix: @prefix
                }) %>
              <% nil -> %>

            <% end %>
          <% end %>

          <.sc_input name={"#{@prefix}[alias]"} value={Map.get(@config, "alias", "")} placeholder="Alias"/>

      </div>


    """
  end
end
