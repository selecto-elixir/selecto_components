defmodule SelectoComponents.Views.Aggregate.GroupByConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

  def render(assigns) do
    # Get the display name from the columns list FIRST
    # Handle formatted date tuples
    item_str = case assigns[:item] do
      {:to_char, {field, _format}} -> to_string(field)
      {_func, field} when is_binary(field) -> to_string(field)
      item -> to_string(item || "")
    end

    # Find the name in the columns list
    display_name = case Enum.find(assigns[:columns] || [], fn
      {id, _name, _type} -> to_string(id) == item_str
      {id, _name, _type, _metadata} -> to_string(id) == item_str
      _ -> false
    end) do
      {_id, name, _type} -> name
      {_id, name, _type, _metadata} -> name
      nil ->
        # Try with atom if string didn't work
        item_atom = try do
          String.to_existing_atom(item_str)
        rescue
          _ -> nil
        end

        case item_atom && Enum.find(assigns[:columns] || [], fn
          {id, _name, _type} -> id == item_atom
          {id, _name, _type, _metadata} -> id == item_atom
          _ -> false
        end) do
          {_id, name, _type} -> name
          {_id, name, _type, _metadata} -> name
          _ ->
            # Last resort: use col.name if available, otherwise the item ID
            if assigns[:col] && assigns.col && assigns.col.name do
              assigns.col.name
            else
              assigns[:item] || "Unknown"
            end
        end
    end

    assigns = Map.put(assigns, :display_name, display_name)

    ~H"""
      <div class="relative">
        <div>
          <%= @display_name %>
        </div>
        <div class="pl-4">
          <%= case Map.get(@col, :type, :string) do%>
            <% x when x in [:int, :id, :decimal, :float, :integer] -> %>
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  [{"default", "Default"}, {"buckets", "Buckets"}]
                }/>
              </label>
              <%= if Map.get(@config, "format") == "buckets" do %>
                <label>Bucket Ranges
                  <.sc_input name={"#{@prefix}[bucket_ranges]"}
                           value={Map.get(@config, "bucket_ranges", "")}
                           placeholder="e.g., 1, 2-5, 6-14, 15+"/>
                </label>
              <% end %>
            <% x when x in [:string] -> %>

            <% :boolean -> %>
              <!--:Y_N :1_0 :yes_no :check_blank -->
            <% x when x in [:naive_datetime, :utc_datetime, :date] -> %>
              <label>Format
                <.sc_select name={"#{@prefix}[format]"} value={Map.get(@config, "format")} options={
                  [
                    {"YYYY-MM-DD", "Day"},
                    {"YYYY-WW", "Week"},
                    {"YYYY-MM", "Month"},
                    {"YYYY-Q", "Quarter"},
                    {"YYYY", "Year"},
                    {"MM", "Month of Year"},
                    {"DD", "Day of Month"},
                    {"D", "Day of Week"},
                    {"HH24", "Hour of Day"},
                    {"age_buckets", "Age Buckets"},
                    {"custom_buckets", "Custom Date Buckets"}
                  ]
                }/>
              </label>
              <%= if Map.get(@config, "format") in ["age_buckets", "custom_buckets"] do %>
                <label>Bucket Ranges
                  <.sc_input name={"#{@prefix}[bucket_ranges]"}
                           value={Map.get(@config, "bucket_ranges", "")}
                           placeholder={if Map.get(@config, "format") == "age_buckets",
                                      do: "e.g., 0, 1-7, 8-30, 31-90, 91+",
                                      else: "e.g., today, yesterday, 2-7, 8+"}/>
                </label>
              <% end %>
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
