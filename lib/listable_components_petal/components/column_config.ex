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
              <label><input name={"#{@fieldname}[#{@uuid}][commas]"} type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>
          <% x when x in [:float] -> %>
            <%= @col.name %>
                <label>Precision
                  <select name={"#{@fieldname}[#{@uuid}][precision]"}
                    class="border-gray-300 focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:focus:border-primary-500  disabled:bg-gray-100 disabled:cursor-not-allowed pl-3 pr-10 py-2 text-base focus:outline-none sm:text-sm rounded-md dark:disabled:bg-gray-700 dark:focus:border-primary-500 dark:text-gray-300 dark:bg-gray-800" >
                    <option :for={i <- Enum.to_list(0 .. 5)} value={i} selected={Map.get(@config, "precision") == i} >
                      <%= i %></option></select></label>
                <label><input name={"#{@fieldname}[#{@uuid}][commas]"} type="checkbox" checked={Map.get(@config, "commas")}/> Commas</label>
          <% x when x in [:string] -> %>
            <%= @col.name %>
          <% :boolean -> %>
            <%= @col.name %><!--:Y_N :1_0 :yes_no :check_blank -->
          <% x when x in [:naive_datetime, :utc_datetime] -> %>
            <%= @col.name %>
            <label>Format <select name={"#{@fieldname}[#{@uuid}][format]"}
              class="border-gray-300 focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:focus:border-primary-500   disabled:bg-gray-100 disabled:cursor-not-allowed pl-3 pr-10 py-2 text-base focus:outline-none sm:text-sm rounded-md dark:disabled:bg-gray-700 dark:focus:border-primary-500 dark:text-gray-300 dark:bg-gray-800" >
              <option :for={i <-["MM-DD-YYYY HH:MM", "YYYY-MM-DD HH:MM",]} value={i}
                selected={Map.get(@config, "format") == i}><%= i %></option></select></label>
          <% _ -> %>
            <%= @col.name %>
          <% end %>
      </div>


    """
  end

end
