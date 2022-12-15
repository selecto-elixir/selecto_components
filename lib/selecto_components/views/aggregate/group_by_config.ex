defmodule SelectoComponents.Views.Aggregate.GroupByConfig do
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
          <%= case @col.type do%>
            <% x when x in [:int, :id, :decimal] -> %>

            <% x when x in [:float] -> %>
              (buckets / ranges?)
            <% x when x in [:string] -> %>

            <% :boolean -> %>
              <!--:Y_N :1_0 :yes_no :check_blank -->
            <% x when x in [:naive_datetime, :utc_datetime] -> %>
              (buckets)
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  Enum.map(["Year", "Month", "Day", "Hour", "YYYY-MM-DD", "YYYY-MM"], fn o -> {o, o} end)
                }/>
              </label>
            <% _ -> %>
                  ???
            <% end %>
          </div>
          <div class="absolute top-0 right-20">
            <.sc_input name={"#{@prefix}[alias]"} value={Map.get(@config, "alias", "")} placeholder="Alias"/>
          </div>

      </div>


    """
  end
end
