defmodule SelectoComponents.Views.Aggregate.Form do
  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common
  alias SelectoComponents.Views.Aggregate.Options
  alias SelectoComponents.Theme

  # Helper function to extract field from formatted date tuples
  defp get_field_for_item(selecto, item) do
    field_name =
      case item do
        # Handle formatted date tuple {:to_char, {"field_name", "format"}}
        {:to_char, {field, _format}} -> field
        # Handle other extraction tuples if any
        {_func, field} when is_binary(field) -> field
        # Regular field name
        field when is_binary(field) or is_atom(field) -> field
        # Fallback
        _ -> nil
      end

    if field_name do
      Selecto.field(selecto, field_name)
    else
      nil
    end
  end

  def render(assigns) do
    aggregate_view =
      assigns.view_config
      |> Map.get(:views, %{})
      |> Map.get(:aggregate, Map.get(Map.get(assigns.view_config, :views, %{}), "aggregate", %{}))

    aggregate_per_page = get_aggregate_per_page(assigns.view_config)
    aggregate_grid = get_aggregate_grid(assigns.view_config)
    aggregate_grid_colorize = get_aggregate_grid_colorize(assigns.view_config)
    aggregate_grid_color_scale = get_aggregate_grid_color_scale(assigns.view_config)

    assigns =
      assigns
      |> assign_new(:theme, fn -> Theme.default_theme(:light) end)
      |> assign(
        aggregate_view: aggregate_view,
        aggregate_per_page: aggregate_per_page,
        aggregate_grid: aggregate_grid,
        aggregate_grid_colorize: aggregate_grid_colorize,
        aggregate_grid_color_scale: aggregate_grid_color_scale,
        aggregate_grid_color_scale_options: Options.grid_color_scale_modes(),
        aggregate_per_page_options: Options.per_page_options()
      )

    ~H"""
    <div>
      <div class={Theme.slot(@theme, :panel) <> " mb-3 px-3 py-2"} style="background: var(--sc-surface-bg-alt);">
        <label for="aggregate_per_page" class="text-xs font-medium" style="color: var(--sc-text-secondary);">
          Aggregate Rows/Page
        </label>
        <.sc_select_with_slot theme={@theme} id="aggregate_per_page" name="aggregate_per_page" class="mt-1 w-36">
          <%= for option <- @aggregate_per_page_options do %>
            <option value={to_string(option)} selected={@aggregate_per_page == to_string(option)}>
              {if option == "all", do: "All", else: option}
            </option>
          <% end %>
        </.sc_select_with_slot>

        <label class="mt-3 inline-flex items-center gap-2 text-sm" style="color: var(--sc-text-secondary);">
          <input type="hidden" name="aggregate_grid" value="false" />
          <input
            type="checkbox"
            name="aggregate_grid"
            value="true"
            checked={@aggregate_grid}
            class="checkbox checkbox-sm"
            style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-accent);"
          />
          Grid view (2 group-by + 1 aggregate)
        </label>

        <label class="mt-3 inline-flex items-center gap-2 text-sm" style="color: var(--sc-text-secondary);">
          <input type="hidden" name="aggregate_grid_colorize" value="false" />
          <input
            type="checkbox"
            name="aggregate_grid_colorize"
            value="true"
            checked={@aggregate_grid_colorize}
            class="checkbox checkbox-sm"
            style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-accent);"
          />
          Colorize grid cells
        </label>

        <div class="mt-3 flex flex-wrap items-center gap-3">
          <label for="aggregate_grid_color_scale" class="text-xs font-medium" style="color: var(--sc-text-secondary);">
            Grid Color Scale
          </label>
          <.sc_select_with_slot theme={@theme} id="aggregate_grid_color_scale" name="aggregate_grid_color_scale" class="w-32">
            <%= for option <- @aggregate_grid_color_scale_options do %>
              <option value={option} selected={@aggregate_grid_color_scale == option}>
                {String.capitalize(option)}
              </option>
            <% end %>
          </.sc_select_with_slot>
        </div>
      </div>
      Group By
      <.live_component
        module={SelectoComponents.Components.ListPicker}
        id="group_by"
        theme={@theme}
        fieldname="group_by"
        view={@view}
        available={
          Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)
        }
        selected_items={Map.get(@aggregate_view, :group_by, Map.get(@aggregate_view, "group_by", []))}
      >
        <:item_summary :let={{_id, item, config, _index}}>
          <% col = get_field_for_item(@selecto, item) %>
          <% format_summary = group_by_format_summary(col, config) %>
          <span class="truncate">{summary_title(config, column_display_name(@columns, item, col))}</span>
          <span :if={present_summary?(format_summary)} class="truncate text-sm font-normal text-base-content/60">{format_summary}</span>
        </:item_summary>
        <:item_form :let={{id, item, config, index}}>
          <input name={"group_by[#{id}][field]"} type="hidden" value={item} />
          <input name={"group_by[#{id}][index]"} type="hidden" value={index} />
          <.live_component
            module={SelectoComponents.Views.Aggregate.GroupByConfig}
            id={id}
            col={get_field_for_item(@selecto, item)}
            uuid={id}
            item={item}
            columns={@columns}
            fieldname="group_by"
            prefix={ "group_by[#{id}]" }
            config={config}
            theme={@theme}
          />
        </:item_form>
      </.live_component>
      Aggregates:
      <.live_component
        module={SelectoComponents.Components.ListPicker}
        id="aggregate"
        theme={@theme}
        fieldname="aggregate"
        view={@view}
        available={@columns}
        selected_items={Map.get(@aggregate_view, :aggregate, Map.get(@aggregate_view, "aggregate", []))}
      >
        <:item_summary :let={{_id, item, config, _index}}>
          <% col = get_field_for_item(@selecto, item) %>
          <span class="truncate">{summary_title(config, column_display_name(@columns, item, col))}</span>
          <span class="truncate text-sm font-normal text-base-content/60">{aggregate_format_summary(col, config)}</span>
        </:item_summary>
        <:item_form :let={{id, item, config, index}}>
          <input name={"aggregate[#{id}][field]"} type="hidden" value={item} />
          <input name={"aggregate[#{id}][index]"} type="hidden" value={index} />
          <.live_component
            module={SelectoComponents.Views.Aggregate.Aggregate.Config}
            id={id}
            col={get_field_for_item(@selecto, item)}
            uuid={id}
            item={item}
            columns={@columns}
            fieldname="aggregate"
            prefix={ "aggregate[#{id}]" }
            config={config}
            theme={@theme}
          />
        </:item_form>
      </.live_component>
    </div>
    """
  end

  defp get_aggregate_per_page(view_config) do
    view_config
    |> Map.get(:views, %{})
    |> Map.get(:aggregate, %{})
    |> then(fn aggregate_cfg ->
      Map.get(
        aggregate_cfg,
        :per_page,
        Map.get(aggregate_cfg, "per_page", Options.default_per_page())
      )
    end)
    |> Options.normalize_per_page_param()
  end

  defp get_aggregate_grid(view_config) do
    view_config
    |> Map.get(:views, %{})
    |> Map.get(:aggregate, %{})
    |> then(fn aggregate_cfg ->
      Map.get(aggregate_cfg, :grid, Map.get(aggregate_cfg, "grid", false))
    end)
    |> normalize_checkbox()
  end

  defp get_aggregate_grid_colorize(view_config) do
    view_config
    |> Map.get(:views, %{})
    |> Map.get(:aggregate, %{})
    |> then(fn aggregate_cfg ->
      Map.get(aggregate_cfg, :grid_colorize, Map.get(aggregate_cfg, "grid_colorize", false))
    end)
    |> normalize_checkbox()
  end

  defp get_aggregate_grid_color_scale(view_config) do
    view_config
    |> Map.get(:views, %{})
    |> Map.get(:aggregate, %{})
    |> then(fn aggregate_cfg ->
      Map.get(
        aggregate_cfg,
        :grid_color_scale,
        Map.get(aggregate_cfg, "grid_color_scale", Options.default_grid_color_scale_mode())
      )
    end)
    |> Options.normalize_grid_color_scale_mode()
  end

  defp normalize_checkbox(value) when value in [true, "true", "on", "1", 1], do: true
  defp normalize_checkbox(_value), do: false

  defp column_display_name(columns, item, col) do
    item_str =
      case item do
        {:to_char, {field, _format}} -> to_string(field)
        {_func, field} when is_binary(field) -> field
        value -> to_string(value || "")
      end

    case Enum.find(columns || [], fn
           {id, _name, _type} -> to_string(id) == item_str
           {id, _name, _type, _metadata} -> to_string(id) == item_str
           _ -> false
         end) do
      {_id, name, _type} -> name
      {_id, name, _type, _metadata} -> name
      _ -> if(col && Map.get(col, :name), do: col.name, else: item_str)
    end
  end

  defp summary_title(config, field_name) do
    case Map.get(config || %{}, "alias", "") do
      value when value in [nil, ""] -> field_name
      value -> "#{value} / #{field_name}"
    end
  end

  defp group_by_format_summary(col, config) do
    case config_value(config, :format) do
      value when value in [nil, ""] ->
        case Map.get(col || %{}, :type, :string) do
          x
          when x in [
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
               ] ->
            nil

          _ ->
            "standard"
        end

      "default" ->
        nil

      "text_prefix" ->
        "text prefix"

      "age_buckets" ->
        "age buckets"

      "custom_buckets" ->
        "custom buckets"

      "year_buckets" ->
        "year buckets"

      value ->
        SelectoComponents.Helpers.datetime_grouping_format_label(value)
    end
  end

  defp aggregate_format_summary(col, config) do
    format =
      case config_value(config, :format) do
        value when value in [nil, ""] ->
          col
          |> aggregate_default_format()
          |> format_summary_label()

        value ->
          format_summary_label(value)
      end

    if config_value(config, :format) == "sum" and
         normalize_checkbox(config_value(config, :ignore_nulls_in_sum)) do
      "#{format}, null as 0"
    else
      format
    end
  end

  defp config_value(config, key) when is_map(config) and is_atom(key) do
    Map.get(config, Atom.to_string(key), Map.get(config, key))
  end

  defp config_value(_config, _key), do: nil

  defp aggregate_default_format(col) do
    case Map.get(col || %{}, :type, :string) do
      :float -> "avg"
      _ -> "count"
    end
  end

  defp format_summary_label(value) do
    SelectoComponents.Helpers.aggregate_datetime_format_label(value)
  end

  defp present_summary?(value), do: value not in [nil, ""]
end
