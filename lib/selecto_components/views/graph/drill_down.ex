defmodule SelectoComponents.Views.Graph.DrillDown do
  @moduledoc false

  alias SelectoComponents.Form.ParamsState
  alias SelectoComponents.SafeAtom

  @drill_down_error_message "Could not drill down for that chart value. Try a different slice or bar."

  def apply(socket, params) do
    label = Map.get(params, "label")
    graph_config = socket.assigns.view_config.views[:graph] || %{}

    field_name = extract_chart_filter_field(socket, graph_config)
    field_type = lookup_column_type(socket, field_name)
    {filter_value, comp} = build_chart_filter_value(label, field_type)

    if is_nil(filter_value) do
      {:error, @drill_down_error_message}
    else
      current_view_mode = socket.assigns.view_config.view_mode
      new_filter = build_filter_tuple(field_name, filter_value, comp)
      updated_filters = socket.assigns.view_config.filters ++ [new_filter]
      new_view_mode = determine_drill_down_view(socket, current_view_mode)

      filters_map = build_filters_map(updated_filters)
      view_mode_param = normalize_view_mode_param(new_view_mode)

      current_params = socket.assigns[:used_params] || %{}

      view_params =
        current_params
        |> Map.put("view_mode", view_mode_param)
        |> Map.put("filters", filters_map)
        |> Map.put_new("aggregate", %{})
        |> Map.put_new("detail", %{})
        |> Map.put_new("graph", %{})

      updated_socket =
        socket
        |> Phoenix.Component.assign(
          :view_config,
          %{socket.assigns.view_config | view_mode: view_mode_param, filters: updated_filters}
        )
        |> ParamsState.view_from_params(view_params)

      {:ok, updated_socket, view_params}
    end
  end

  defp determine_drill_down_view(socket, current_view_mode) do
    selected_view = SafeAtom.to_view_mode(current_view_mode)

    {_, _, _, opt} =
      Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end) ||
        {:detail, nil, nil, %{}}

    Map.get(opt, :drill_down, :detail)
  end

  defp normalize_view_mode_param(view_mode) when is_atom(view_mode), do: Atom.to_string(view_mode)
  defp normalize_view_mode_param(view_mode) when is_binary(view_mode), do: view_mode
  defp normalize_view_mode_param(_view_mode), do: "detail"

  defp build_filter_tuple(field_name, filter_value, comp) do
    new_filter_id = UUID.uuid4()

    new_filter_map = %{
      "filter" => field_name,
      "value" => filter_value,
      "comp" => comp,
      "section" => "filters"
    }

    {new_filter_id, "filters", new_filter_map}
  end

  defp build_filters_map(updated_filters) do
    Enum.reduce(updated_filters, %{}, fn
      {id, "filters", filter_map}, acc ->
        filter_with_defaults =
          filter_map
          |> Map.put_new("section", "filters")
          |> Map.put_new("comp", "=")

        Map.put(acc, id, filter_with_defaults)

      _, acc ->
        acc
    end)
  end

  defp extract_chart_filter_field(socket, graph_config) do
    case get_in(socket.assigns, [:selecto, :set, :x_axis_groups]) || [] do
      [{_, {:field, field, _alias}} | _] when is_binary(field) -> field
      [{_, {:field, field}} | _] when is_binary(field) -> field
      [{_, field, _} | _] when is_binary(field) -> field
      _ -> extract_graph_config_field(graph_config)
    end
  end

  defp extract_graph_config_field(graph_config) do
    case graph_config[:x_axis] || [] do
      [{_id, field, _config} | _] when is_binary(field) -> field
      [{_id, field, _config} | _] -> inspect(field)
      _ -> "id"
    end
  end

  defp lookup_column_type(socket, field_name) do
    Enum.find_value(socket.assigns.columns, fn
      {^field_name, _label, type} -> type
      _ -> nil
    end)
  end

  defp build_chart_filter_value(label, {:array, _}) do
    value =
      cond do
        is_binary(label) and label != "" -> label
        is_list(label) and Enum.all?(label, &is_binary/1) and label != [] -> hd(label)
        true -> nil
      end

    {value, "contains"}
  end

  defp build_chart_filter_value(label, _field_type) do
    {normalize_chart_label(label), "="}
  end

  defp normalize_chart_label(label) when is_binary(label), do: label
  defp normalize_chart_label(label) when is_number(label), do: to_string(label)
  defp normalize_chart_label(label) when is_atom(label), do: Atom.to_string(label)

  defp normalize_chart_label(label) when is_list(label) do
    cond do
      label == [] -> ""
      Enum.all?(label, &is_binary/1) -> Enum.join(label, ", ")
      true -> inspect(label)
    end
  end

  defp normalize_chart_label(label), do: inspect(label)
end
