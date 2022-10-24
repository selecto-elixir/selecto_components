defmodule ListableComponentsTailwind.Components.AggregateConfig do
  use Phoenix.LiveComponent
  import ListableComponentsTailwind.Components.Common

  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slot :config, :map

  def render(assigns) do

    assigns = Map.put(assigns, prefix: "#{@fieldname}[#{@uuid}]" )

    ~H"""
      <div>
        <%= case @col.type do%>
          <% x when x in [:int, :id, :decimal] -> %>
          agg: avg, sum, min, max, all those stats aggs...
            <%= @col.name %>
              <!-- <label><input name={"#{@fieldname}[#{@uuid}][commas]"} type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>-->
          <% x when x in [:float] -> %>
          agg: avg, sum, min, max, all those stats aggs...
            <%= @col.name %>
          <% x when x in [:string] -> %>
          agg: string_agg, min, max,
            <%= @col.name %>
          <% :boolean -> %>
              agg types: count(true), %true
            <%= @col.name %><!--:Y_N :1_0 :yes_no :check_blank -->
          <% x when x in [:naive_datetime, :utc_datetime] -> %>
              agg types: age buckets?
            <%= @col.name %>
            <label>Format
              <.select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                Enum.map(["MM-DD-YYYY HH:MM", "YYYY-MM-DD HH:MM"], fn o -> {o, o} end)
              }/>
            </label>

          <% _ -> %>
            <%= @col.name %>
          <% end %>
      </div>


    """
  end

end
