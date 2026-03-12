defmodule SelectoComponents.Views.Aggregate.Form do
  use Phoenix.LiveComponent
  alias SelectoComponents.Views.Aggregate.Options

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
    aggregate_per_page = get_aggregate_per_page(assigns.view_config)
    aggregate_grid = get_aggregate_grid(assigns.view_config)

    assigns =
      assign(assigns,
        aggregate_per_page: aggregate_per_page,
        aggregate_grid: aggregate_grid,
        aggregate_per_page_options: Options.per_page_options()
      )

    ~H"""
    <div>
      <div class="mb-3 rounded-md border border-gray-200 bg-gray-50 px-3 py-2">
        <label for="aggregate_per_page" class="text-xs font-medium text-gray-700">
          Aggregate Rows/Page
        </label>
        <select
          id="aggregate_per_page"
          name="aggregate_per_page"
          class="mt-1 select select-bordered select-sm w-36 bg-white"
        >
          <%= for option <- @aggregate_per_page_options do %>
            <option value={to_string(option)} selected={@aggregate_per_page == to_string(option)}>
              {if option == "all", do: "All", else: option}
            </option>
          <% end %>
        </select>

        <label class="mt-3 inline-flex items-center gap-2 text-sm text-gray-700">
          <input type="hidden" name="aggregate_grid" value="false" />
          <input
            type="checkbox"
            name="aggregate_grid"
            value="true"
            checked={@aggregate_grid}
            class="checkbox checkbox-sm"
          />
          Grid view (2 group-by + 1 aggregate)
        </label>
      </div>
      Group By
      <.live_component
        module={SelectoComponents.Components.ListPicker}
        id="group_by"
        fieldname="group_by"
        view={@view}
        available={
          Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)
        }
        selected_items={@view_config.views.aggregate.group_by}
      >
        <:item_summary :let={{_id, item, config, _index}}>
          <% col = get_field_for_item(@selecto, item) %>
          <span class="truncate">{summary_title(config, column_display_name(@columns, item, col))}</span>
          <span class="truncate text-sm font-normal text-base-content/60">{group_by_format_summary(col, config)}</span>
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
          />
        </:item_form>
      </.live_component>
      Aggregates:
      <.live_component
        module={SelectoComponents.Components.ListPicker}
        id="aggregate"
        fieldname="aggregate"
        view={@view}
        available={@columns}
        selected_items={@view_config.views.aggregate.aggregate}
      >
        <:item_summary :let={{_id, item, config, _index}}>
          <% col = get_field_for_item(@selecto, item) %>
          <span class="truncate">{summary_title(config, column_display_name(@columns, item, col))}</span>
          <span class="truncate text-sm font-normal text-base-content/60">{aggregate_format_summary(config)}</span>
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
    case Map.get(config || %{}, "format") do
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
            "default"

          _ ->
            "standard"
        end

      "text_prefix" ->
        "text prefix"

      "age_buckets" ->
        "age buckets"

      "custom_buckets" ->
        "custom buckets"

      value ->
        format_summary_label(value)
    end
  end

  defp aggregate_format_summary(config) do
    case Map.get(config || %{}, "format") do
      value when value in [nil, ""] -> "default"
      value -> format_summary_label(value)
    end
  end

  defp format_summary_label(value) do
    value
    |> SelectoComponents.Helpers.aggregate_datetime_format_label()
    |> String.downcase()
  end
end
