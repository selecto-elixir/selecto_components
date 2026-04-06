defmodule SelectoComponents.Views.Aggregate.GroupByConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias SelectoComponents.Theme
  # slot :type, :atom
  # slot :uuid, :string
  # slot :field, :string
  # slog :config, :map

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
          :string,
          :text,
          :citext,
          :int,
          :id,
          :decimal,
          :float,
          :integer,
          :naive_datetime,
          :utc_datetime,
          :date
        ]
      }>
        <div class="text-sm font-medium" style="color: var(--sc-text-secondary);">Options:</div>
        <div class="space-y-2 pl-2" style="color: var(--sc-text-primary);">
          <%= case Map.get(@col, :type, :string) do %>
            <% x when x in [:int, :id, :decimal, :float, :integer] -> %>
              <label class="block text-sm" style="color: var(--sc-text-primary);">
                Format
                <.sc_select
                  theme={@theme}
                  name={"#{@prefix}[format]"}
                  value={Map.get(@config, "format")}
                  options={[{"default", "Default"}, {"buckets", "Buckets"}]}
                />
              </label>
              <%= if Map.get(@config, "format") == "buckets" do %>
                <label class="block text-sm" style="color: var(--sc-text-primary);">
                  Bucket Ranges
                  <.sc_input
                    theme={@theme}
                    name={"#{@prefix}[bucket_ranges]"}
                    value={Map.get(@config, "bucket_ranges", "")}
                    placeholder="e.g., 1, 2-5, 6-14, 15+ or */10"
                  />
                </label>
              <% end %>
            <% x when x in [:naive_datetime, :utc_datetime, :date] -> %>
              <label class="block text-sm" style="color: var(--sc-text-primary);">
                Format
                <.sc_select
                  theme={@theme}
                  name={"#{@prefix}[format]"}
                  value={Map.get(@config, "format")}
                  options={SelectoComponents.Helpers.datetime_grouping_format_options()}
                />
              </label>
              <%= if Map.get(@config, "format") in ["age_buckets", "custom_buckets", "year_buckets"] do %>
                <label class="block text-sm" style="color: var(--sc-text-primary);">
                  Bucket Ranges
                  <.sc_input
                    theme={@theme}
                    name={"#{@prefix}[bucket_ranges]"}
                    value={Map.get(@config, "bucket_ranges", "")}
                    placeholder={SelectoComponents.Helpers.datetime_bucket_placeholder(Map.get(@config, "format"))}
                  />
                </label>
              <% end %>
            <% x when x in [:string, :text, :citext] -> %>
              <label class="block text-sm" style="color: var(--sc-text-primary);">
                Format
                <.sc_select
                  theme={@theme}
                  name={"#{@prefix}[format]"}
                  value={Map.get(@config, "format")}
                  options={[
                    {"default", "Default"},
                    {"text_prefix", "Text Prefix"}
                  ]}
                />
              </label>

              <%= if Map.get(@config, "format") == "text_prefix" do %>
                <label class="block text-sm" style="color: var(--sc-text-primary);">
                  Prefix Length
                  <.sc_input
                    theme={@theme}
                    name={"#{@prefix}[prefix_length]"}
                    value={Map.get(@config, "prefix_length", "2")}
                    type="number"
                    min="1"
                    max="10"
                    placeholder="2"
                  />
                </label>

                <label class={Theme.slot(@theme, :checkbox_label) <> " mt-2 flex items-center gap-2 text-sm"}>
                  <input type="hidden" name={"#{@prefix}[exclude_articles]"} value="false" />
                  <input
                    type="checkbox"
                    name={"#{@prefix}[exclude_articles]"}
                    value="true"
                    checked={Map.get(@config, "exclude_articles", "true") in [true, "true", "on", "1"]}
                    class="h-4 w-4 rounded border"
                    style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); accent-color: var(--sc-accent);"
                  />
                  Exclude leading articles (a, an, the)
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
