defmodule SelectoComponents.Views.Detail.ColumnConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do

    ~H"""
      <div class="relative">
        <div class="p-2">
          <%= @col.name %>
        </div>
        <div class="p-2">
          <%= case @col.type do%>
            <% x when x in [:int, :id] -> %>
              <label><input name={"#{@prefix}[commas]"} type="checkbox" checked={Map.get(@config, "commas")}/>Commas</label>

            <% x when x in [:float, :decimal] -> %>
              <label><input name={"#{@prefix}[commas]"} type="checkbox" checked={Map.get(@config, "commas")}/>Commas</label>
              <label><.sc_select name={"#{@prefix}[decimal_places]"}
                options={Enum.map(~w(0 1 2 3), fn o -> {o, o} end )}
                value={Map.get(@config, "decimal_places")}/>
                Decimal Places</label>


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
          </div>
        <div class="p-2 absolute top-1 right-20">
          <.sc_input name={"#{@prefix}[alias]"} value={Map.get(@config, "alias", "")} placeholder="Alias"/>
        </div>

      </div>
    """
  end
end
