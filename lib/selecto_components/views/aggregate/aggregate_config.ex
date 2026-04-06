defmodule SelectoComponents.Views.Aggregate.Aggregate.Config do
  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common
  alias SelectoComponents.Theme

  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slot :config, :map

  def render(assigns) do
    # Get the display name from the columns list FIRST
    # Handle formatted date tuples
    item_str =
      case assigns[:item] do
        {:to_char, {field, _format}} -> to_string(field)
        {_func, field} when is_binary(field) -> to_string(field)
        item -> to_string(item || "")
      end

    # Find the name in the columns list
    display_name =
      case Enum.find(assigns[:columns] || [], fn
             {id, _name, _type} -> to_string(id) == item_str
             {id, _name, _type, _metadata} -> to_string(id) == item_str
             _ -> false
           end) do
        {_id, name, _type} ->
          name

        {_id, name, _type, _metadata} ->
          name

        nil ->
          # Try with atom if string didn't work
          item_atom =
            try do
              String.to_existing_atom(item_str)
            rescue
              _ -> nil
            end

          case item_atom &&
                 Enum.find(assigns[:columns] || [], fn
                   {id, _name, _type} -> id == item_atom
                   {id, _name, _type, _metadata} -> id == item_atom
                   _ -> false
                 end) do
            {_id, name, _type} ->
              name

            {_id, name, _type, _metadata} ->
              name

            _ ->
              # Last resort: use col.name if available, otherwise the item ID
              if assigns[:col] && assigns.col && assigns.col.name do
                assigns.col.name
              else
                assigns[:item] || "Unknown"
              end
          end
      end

    assigns =
      assigns
      |> Map.put_new(:theme, Theme.default_theme(:light))
      |> Map.put(:display_name, display_name)

    ~H"""
    <div class="space-y-2">
      <div>
        <div class="text-sm font-medium" style="color: var(--sc-text-secondary);">Name:</div>
        <div class="pl-2" style="color: var(--sc-text-primary);">{@display_name}</div>
      </div>

      <div>
        <div class="text-sm font-medium" style="color: var(--sc-text-secondary);">Alias:</div>
        <div class="pl-2">
          <.sc_input
            theme={@theme}
            name={"#{@prefix}[alias]"}
            value={Map.get(@config, "alias", "")}
            placeholder="Alias"
          />
        </div>
      </div>

      <div :if={
        Map.get(@col || %{}, :type, :string) in [
          :integer,
          :id,
          :decimal,
          :float,
          :string,
          :boolean,
          :naive_datetime,
          :utc_datetime,
          :date
        ]
      }>
        <div class="text-sm font-medium" style="color: var(--sc-text-secondary);">Options:</div>
        <div class="space-y-2 pl-2" style="color: var(--sc-text-primary);">
          <%= case Map.get(@col, :type, :string) do %>
            <% x when x in [:integer, :id, :decimal] -> %>
              <label class="block text-sm" style="color: var(--sc-text-primary);">
                Format
                <.sc_select
                  theme={@theme}
                  name={"#{@prefix}[format]"}
                  value={Map.get(@config, "format")}
                  options={[
                    {"count", "Count"},
                    {"count_distinct", "Count Distinct"},
                    {"avg", "Average"},
                    {"sum", "Sum"},
                    {"min", "Min"},
                    {"max", "Max"},
                    {"buckets", "Buckets"}
                  ]}
                />
              </label>
              <%= if Map.get(@config, "format") == "sum" do %>
                <label class={Theme.slot(@theme, :checkbox_label) <> " inline-flex items-center gap-2 text-sm"}>
                  <input type="hidden" name={"#{@prefix}[ignore_nulls_in_sum]"} value="false" />
                  <input
                    type="checkbox"
                    name={"#{@prefix}[ignore_nulls_in_sum]"}
                    value="true"
                    checked={Map.get(@config, "ignore_nulls_in_sum") in [true, "true", "on", "1", 1]}
                    class="h-4 w-4 rounded border"
                    style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); accent-color: var(--sc-accent);"
                  />
                  Treat NULL as 0 in Sum
                </label>
              <% end %>
              <%= if Map.get(@config, "format") == "buckets" do %>
                <label class="block text-sm" style="color: var(--sc-text-primary);">
                  Bucket Ranges
                  <.sc_input
                    theme={@theme}
                    name={"#{@prefix}[bucket_ranges]"}
                    value={Map.get(@config, "bucket_ranges", "")}
                    placeholder="e.g., 0-10, 11-50, 51-100, 101+ or */10"
                  />
                </label>
              <% end %>
            <% x when x in [:float] -> %>
              <label class="block text-sm" style="color: var(--sc-text-primary);">
                Format
                <.sc_select
                  theme={@theme}
                  name={"#{@prefix}[format]"}
                  value={Map.get(@config, "format")}
                  options={[
                    {"avg", "Average"},
                    {"sum", "Sum"},
                    {"min", "Min"},
                    {"max", "Max"},
                    {"buckets", "Buckets"}
                  ]}
                />
              </label>
              <%= if Map.get(@config, "format") == "sum" do %>
                <label class={Theme.slot(@theme, :checkbox_label) <> " inline-flex items-center gap-2 text-sm"}>
                  <input type="hidden" name={"#{@prefix}[ignore_nulls_in_sum]"} value="false" />
                  <input
                    type="checkbox"
                    name={"#{@prefix}[ignore_nulls_in_sum]"}
                    value="true"
                    checked={Map.get(@config, "ignore_nulls_in_sum") in [true, "true", "on", "1", 1]}
                    class="h-4 w-4 rounded border"
                    style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); accent-color: var(--sc-accent);"
                  />
                  Treat NULL as 0 in Sum
                </label>
              <% end %>
              <%= if Map.get(@config, "format") == "buckets" do %>
                <label class="block text-sm" style="color: var(--sc-text-primary);">
                  Bucket Ranges
                  <.sc_input
                    theme={@theme}
                    name={"#{@prefix}[bucket_ranges]"}
                    value={Map.get(@config, "bucket_ranges", "")}
                    placeholder="e.g., 0-10, 11-50, 51-100, 101+ or */10"
                  />
                </label>
              <% end %>
            <% x when x in [:string] -> %>
              <label class="block text-sm" style="color: var(--sc-text-primary);">
                Format
                <.sc_select
                  theme={@theme}
                  name={"#{@prefix}[format]"}
                  value={Map.get(@config, "format")}
                  options={[
                    {"count", "Count"},
                    {"count_distinct", "Count Distinct"},
                    {"min", "Min"},
                    {"max", "Max"}
                  ]}
                />
              </label>
            <% :boolean -> %>
              <label class="block text-sm" style="color: var(--sc-text-primary);">
                Format
                <.sc_select
                  theme={@theme}
                  name={"#{@prefix}[format]"}
                  value={Map.get(@config, "format")}
                  options={[
                    {"count", "Count"},
                    {"true_count", "True Count"},
                    {"false_count", "False Count"}
                  ]}
                />
              </label>
            <% x when x in [:naive_datetime, :utc_datetime, :date] -> %>
              <label class="block text-sm" style="color: var(--sc-text-primary);">
                Format
                <.sc_select
                  theme={@theme}
                  name={"#{@prefix}[format]"}
                  value={Map.get(@config, "format")}
                  options={[
                    {"count", "Count"},
                    {"count_distinct", "Count Distinct"},
                    {"min", "Min"},
                    {"max", "Max"},
                    {"age_buckets", "Age Buckets"}
                  ]}
                />
              </label>
              <%= if Map.get(@config, "format") == "age_buckets" do %>
                <label class="block text-sm" style="color: var(--sc-text-primary);">
                  Bucket Ranges (days)
                  <.sc_input
                    theme={@theme}
                    name={"#{@prefix}[bucket_ranges]"}
                    value={Map.get(@config, "bucket_ranges", "")}
                    placeholder="e.g., 0, 1-7, 8-30, 31-90, 91+"
                  />
                </label>
              <% end %>
            <% _ -> %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
