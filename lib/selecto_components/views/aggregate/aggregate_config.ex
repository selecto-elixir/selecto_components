defmodule SelectoComponents.Views.Aggregate.Aggregate.Config do
  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common

  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slot :config, :map

  def render(assigns) do

    ~H"""
      <div class="relative">
        <div>
          <%= @col.name %>
        </div>
        <div class="pl-4">
          <%= case @col.type do%>
            <% x when x in [:integer, :id, :decimal] -> %>
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  Enum.map(~w(count avg sum min max), fn o -> {o, o} end)
                }/>
              </label>
            <% x when x in [:float] -> %>
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  Enum.map(~w(avg sum min max), fn o -> {o, o} end)
                }/>
              </label>
            <% x when x in [:string] -> %>
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  Enum.map(~w(min max), fn o -> {o, o} end)
                }/>
              </label>
            <% :boolean -> %>
<!--:Y_N :1_0 :yes_no :check_blank -->
              <label>Format
                #TODO
              </label>

            <% x when x in [:naive_datetime, :utc_datetime] -> %>
                agg types: age buckets?
              <label>Format
                #TODO
              </label>

            <% _ -> %>
              <%= @col.type %>

          <% end %>
        </div>
        <div class="absolute top-0 right-20">
          <.sc_input name={"#{@prefix}[alias]"} value={Map.get(@config, "alias", "")} placeholder="Alias"/>
        </div>
      </div>


    """
  end
end
