defmodule SelectoComponents.Views.Graph.XAxisConfig do
  use Phoenix.LiveComponent

  def render(assigns) do
    col =
      case Map.get(assigns, :col) do
        %{} = col -> col
        _ -> %{name: Map.get(assigns, :item, "Unknown field"), type: :string}
      end

    config =
      case Map.get(assigns, :config) do
        %{} = config -> config
        _ -> %{}
      end

    assigns = assign(assigns, :col, col)
    assigns = assign(assigns, :config, config)
    assigns = assign(assigns, :col_type_label, format_type(Map.get(col, :type, :string)))

    ~H"""
    <div class="border border-gray-200 rounded-lg p-3 bg-gray-50">
      <div class="flex items-center justify-between mb-2">
        <span class="font-medium text-sm text-gray-700"><%= @col.name %></span>
        <span class="text-xs text-gray-500"><%= @col_type_label %></span>
      </div>
      
      <div class="grid grid-cols-1 gap-3">
        <!-- Custom Alias -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Label</label>
          <input 
            name={"#{@prefix}[alias]"}
            type="text" 
            value={Map.get(@config, "alias", "")}
            placeholder={@col.name}
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"/>
        </div>

        <!-- Datetime Formatting (if applicable) -->
        <div :if={Map.get(@col, :type, :string) in [:naive_datetime, :utc_datetime, :date]}>
          <label class="block text-xs font-medium text-gray-600 mb-1">Date Format</label>
          <select
            name={"#{@prefix}[format]"}
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
          >
            <option value="" selected={Map.get(@config, "format", "") == ""}>Default</option>
            <%= for {value, label} <- SelectoComponents.Helpers.datetime_grouping_format_options() do %>
              <option value={value} selected={Map.get(@config, "format") == value}>{label}</option>
            <% end %>
          </select>
        </div>

        <div :if={Map.get(@config, "format") in ["age_buckets", "custom_buckets", "year_buckets"]}>
          <label class="block text-xs font-medium text-gray-600 mb-1">Bucket Ranges</label>
          <input
            name={"#{@prefix}[bucket_ranges]"}
            type="text"
            value={Map.get(@config, "bucket_ranges", "")}
            placeholder={SelectoComponents.Helpers.datetime_bucket_placeholder(Map.get(@config, "format"))}
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>

        <!-- String truncation (if applicable) -->
        <div :if={Map.get(@col, :type, :string) in [:string, :text]}>
          <label class="block text-xs font-medium text-gray-600 mb-1">Max Length</label>
          <input 
            name={"#{@prefix}[max_length]"}
            type="number" 
            value={Map.get(@config, "max_length", "")}
            placeholder="No limit"
            min="1"
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"/>
        </div>

        <!-- Sorting -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Sort Order</label>
          <select name={"#{@prefix}[sort]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="" selected={Map.get(@config, "sort", "") == ""}>Default</option>
            <option value="asc" selected={Map.get(@config, "sort") == "asc"}>Ascending</option>
            <option value="desc" selected={Map.get(@config, "sort") == "desc"}>Descending</option>
          </select>
        </div>
      </div>
    </div>
    """
  end

  defp format_type(type) when is_atom(type), do: Atom.to_string(type)
  defp format_type(type), do: inspect(type)
end
