defmodule SelectoComponents.Views.Map.Form do
  use Phoenix.LiveComponent

  alias SelectoComponents.Views.Map.Process

  def render(assigns) do
    config =
      get_in(assigns, [:view_config, :views, :map]) ||
        get_in(assigns, [:view_config, :views, "map"]) ||
        %{}

    assigns =
      assign(assigns,
        map_config: Process.normalize_config(config),
        spatial_columns: spatial_columns(assigns.selecto),
        popup_columns: popup_columns(assigns.selecto)
      )

    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Geometry Field</label>
          <select
            name="geometry_field"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option
              :for={{field, label} <- @spatial_columns}
              value={field}
              selected={map_value(@map_config, :geometry_field) == field}
            >
              {label}
            </option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Popup Field</label>
          <select
            name="popup_field"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option
              value=""
              selected={
                is_nil(map_value(@map_config, :popup_field)) or
                  map_value(@map_config, :popup_field) == ""
              }
            >
              None
            </option>
            <option
              :for={{field, label} <- @popup_columns}
              value={field}
              selected={map_value(@map_config, :popup_field) == field}
            >
              {label}
            </option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Color Field (Optional)</label>
          <select
            name="color_field"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option
              value=""
              selected={
                is_nil(map_value(@map_config, :color_field)) or
                  map_value(@map_config, :color_field) == ""
              }
            >
              None
            </option>
            <option
              :for={{field, label} <- @popup_columns}
              value={field}
              selected={map_value(@map_config, :color_field) == field}
            >
              {label}
            </option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Zoom</label>
          <input
            name="default_zoom"
            type="number"
            min="1"
            max="20"
            value={map_value(@map_config, :default_zoom, 3)}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Center Latitude</label>
          <input
            name="center_lat"
            type="number"
            step="0.000001"
            value={map_value(@map_config, :center_lat, 0.0)}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Center Longitude</label>
          <input
            name="center_lng"
            type="number"
            step="0.000001"
            value={map_value(@map_config, :center_lng, 0.0)}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Max Points</label>
          <input
            name="max_points"
            type="number"
            min="1"
            value={map_value(@map_config, :max_points, 2000)}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Tile URL</label>
          <input
            name="tile_url"
            type="text"
            value={
              map_value(@map_config, :tile_url, "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png")
            }
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Attribution</label>
          <input
            name="attribution"
            type="text"
            value={map_value(@map_config, :attribution, "&copy; OpenStreetMap contributors")}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-6">
        <label class="inline-flex items-center gap-2 text-sm text-gray-700">
          <input type="hidden" name="fit_bounds" value="false" />
          <input
            name="fit_bounds"
            type="checkbox"
            value="true"
            checked={map_bool(@map_config, :fit_bounds, true)}
            class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500"
          /> Fit map to query bounds
        </label>

        <label class="inline-flex items-center gap-2 text-sm text-gray-700">
          <input type="hidden" name="cluster" value="false" />
          <input
            name="cluster"
            type="checkbox"
            value="true"
            checked={map_bool(@map_config, :cluster, false)}
            class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500"
          /> Enable point clustering
        </label>
      </div>
    </div>
    """
  end

  defp map_value(config, key, default \\ nil)

  defp map_value(config, key, default) when is_map(config) and is_atom(key) do
    Map.get(config, key, Map.get(config, Atom.to_string(key), default))
  end

  defp map_value(_config, _key, default), do: default

  defp map_bool(config, key, default) do
    case map_value(config, key, nil) do
      value when value in [true, "true", "on", "1", 1] -> true
      value when value in [false, "false", "off", "0", 0] -> false
      _ -> default
    end
  end

  defp spatial_columns(selecto) do
    selecto
    |> Selecto.columns()
    |> Enum.filter(fn {_field, col} -> spatial_type?(Map.get(col, :type)) end)
    |> Enum.map(fn {field, col} -> {to_string(field), col.name} end)
  end

  defp popup_columns(selecto) do
    selecto
    |> Selecto.columns()
    |> Enum.filter(fn {_field, col} ->
      format = Map.get(col, :format)
      format not in [:component, :link]
    end)
    |> Enum.map(fn {field, col} -> {to_string(field), col.name} end)
  end

  defp spatial_type?(type) when is_atom(type) do
    Selecto.TypeSystem.type_category(type) == :spatial
  end

  defp spatial_type?(type) when is_binary(type) do
    type
    |> Selecto.TypeSystem.parse_sql_type()
    |> Selecto.TypeSystem.type_category()
    |> Kernel.==(:spatial)
  end

  defp spatial_type?(_), do: false
end
