defmodule SelectoComponents.Views.Aggregate.Aggregate.Config do
  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common

  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slot :config, :map

  def render(assigns) do
    assigns = Map.put(assigns, :prefix, "#{assigns.fieldname}[#{assigns.uuid}]")

    ~H"""
      <div>
        <%= case @col.type do%>
          <% x when x in [:integer, :id, :decimal] -> %>
            <%= @col.name %>
            <label>Format
              <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                Enum.map(~w(count avg sum min max), fn o -> {o, o} end)
              }/>
            </label>
          <% x when x in [:float] -> %>
            <%= @col.name %>
            <label>Format
              <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                Enum.map(~w(avg sum min max), fn o -> {o, o} end)
              }/>
            </label>
          <% x when x in [:string] -> %>
            <%= @col.name %>
            <label>Format
              <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                Enum.map(~w(min max), fn o -> {o, o} end)
              }/>
            </label>
          <% :boolean -> %>
            <%= @col.name %><!--:Y_N :1_0 :yes_no :check_blank -->
            <label>Format
              #TODO
            </label>

          <% x when x in [:naive_datetime, :utc_datetime] -> %>
              agg types: age buckets?
            <%= @col.name %>
            <label>Format
              #TODO
            </label>

          <% _ -> %>
            <%= @col.name %> /       <%= @col.type %>

          <% end %>
      </div>


    """
  end
end
