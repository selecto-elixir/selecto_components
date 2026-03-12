defmodule SelectoComponents.Views.Detail.RowActions do
  @moduledoc false

  @default_modal_action_id "__default_modal__"
  @modal_sizes [:sm, :md, :lg, :xl, :full]

  def default_modal_action_id, do: @default_modal_action_id

  def available_actions(selecto) do
    [default_modal_action() | registered_actions(selecto)]
  end

  def current_action(selecto, row_click_action, opts \\ []) do
    action_id = normalize_optional_string(row_click_action)
    legacy_modal_enabled = Keyword.get(opts, :legacy_modal_enabled, false)

    cond do
      legacy_modal_enabled and is_nil(action_id) ->
        Map.put(default_modal_action(), :source, :legacy)

      action_id in [nil, ""] ->
        nil

      action_id == @default_modal_action_id ->
        Map.put(default_modal_action(), :source, :configured)

      true ->
        registered_actions(selecto)
        |> Enum.find(fn action -> action.id == action_id end)
        |> case do
          nil -> nil
          action -> Map.put(action, :source, :configured)
        end
    end
  end

  def missing_required_fields(nil, _selected_items), do: []

  def missing_required_fields(action, selected_items) when is_map(action) do
    additional_required_fields(action, selected_items)
  end

  def additional_required_fields(nil, _selected_items), do: []

  def additional_required_fields(action, selected_items) when is_map(action) do
    selected_fields =
      selected_items
      |> List.wrap()
      |> Enum.map(&selected_field/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    action
    |> Map.get(:required_fields, [])
    |> Enum.reject(&MapSet.member?(selected_fields, &1))
  end

  def resolve_external_link(%{type: :external_link, payload: payload}, row_context)
      when is_map(payload) and is_map(row_context) do
    url_template = map_get(payload, :url_template)
    url = resolve_template(url_template, row_context)
    target = normalize_optional_string(map_get(payload, :target)) || "_blank"

    if is_binary(url) and String.trim(url) != "" do
      %{url: url, target: target}
    else
      nil
    end
  end

  def resolve_external_link(_action, _row_context), do: nil

  def resolve_modal_options(action, row_context) when is_map(action) and is_map(row_context) do
    payload = Map.get(action, :payload, %{})

    %{}
    |> maybe_put(:title, resolve_template(map_get(payload, :title), row_context))
    |> maybe_put(:subtitle_field, normalize_optional_string(map_get(payload, :subtitle_field)))
    |> maybe_put(:size, normalize_modal_size(map_get(payload, :size)))
    |> Map.put(
      :navigation_enabled,
      normalize_boolean(map_get(payload, :navigation_enabled), true)
    )
    |> Map.put(:edit_enabled, normalize_boolean(map_get(payload, :edit_enabled), false))
  end

  defp registered_actions(selecto) do
    selecto
    |> Selecto.domain()
    |> Map.get(:detail_actions, %{})
    |> Enum.map(&normalize_action/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  defp normalize_action({action_id, action_config}) when is_map(action_config) do
    type = normalize_action_type(map_get(action_config, :type))

    if is_nil(type) do
      nil
    else
      %{
        id: to_string(action_id),
        source_id: action_id,
        name: normalize_optional_string(map_get(action_config, :name)) || humanize_id(action_id),
        description: normalize_optional_string(map_get(action_config, :description)),
        type: type,
        required_fields:
          action_config
          |> map_get(:required_fields, [])
          |> normalize_required_fields(),
        payload:
          action_config
          |> map_get(:payload, %{})
          |> normalize_payload()
      }
    end
  end

  defp normalize_action(_), do: nil

  defp default_modal_action do
    %{
      id: @default_modal_action_id,
      source_id: :__default_modal__,
      name: "Built-in detail modal",
      description: "Open the clicked row in the standard detail modal.",
      type: :modal,
      required_fields: [],
      payload: %{}
    }
  end

  defp selected_field({_, field, _}), do: normalize_optional_string(field)
  defp selected_field([_uuid, field, _config]), do: normalize_optional_string(field)
  defp selected_field(field) when is_binary(field), do: normalize_optional_string(field)

  defp selected_field(field) when is_atom(field),
    do: field |> Atom.to_string() |> normalize_optional_string()

  defp selected_field(item) when is_map(item) do
    item
    |> map_get(:field)
    |> normalize_optional_string()
  end

  defp selected_field(_item), do: nil

  defp normalize_required_fields(required_fields) when is_list(required_fields) do
    required_fields
    |> Enum.map(&normalize_optional_string/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_required_fields(_required_fields), do: []

  defp normalize_payload(payload) when is_map(payload), do: payload
  defp normalize_payload(_payload), do: %{}

  defp normalize_action_type(value) when value in [:modal, :external_link], do: value

  defp normalize_action_type(value) when is_binary(value) do
    case String.trim(value) do
      "modal" -> :modal
      "external_link" -> :external_link
      _ -> nil
    end
  end

  defp normalize_action_type(_value), do: nil

  defp normalize_modal_size(size) when size in @modal_sizes, do: size

  defp normalize_modal_size(size) when is_binary(size) do
    case String.trim(size) do
      "sm" -> :sm
      "md" -> :md
      "lg" -> :lg
      "xl" -> :xl
      "full" -> :full
      _ -> nil
    end
  end

  defp normalize_modal_size(_size), do: nil

  defp resolve_template(template, row_context) when is_binary(template) do
    context = template_context(row_context)

    Regex.replace(~r/\{\{\s*([^}]+?)\s*\}\}/, template, fn _, key ->
      key
      |> String.trim()
      |> then(&Map.get(context, &1, ""))
      |> stringify_value()
    end)
  end

  defp resolve_template(nil, _row_context), do: nil
  defp resolve_template(template, _row_context), do: template

  defp template_context(row_context) do
    row_context
    |> Map.get(:display_record, %{})
    |> stringify_keys()
    |> Map.merge(row_context |> Map.get(:field_values, %{}) |> stringify_keys())
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} when is_binary(key) -> {key, value}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp stringify_keys(_map), do: %{}

  defp stringify_value(nil), do: ""
  defp stringify_value(value) when is_binary(value), do: value
  defp stringify_value(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_value(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp stringify_value(value) when is_boolean(value), do: to_string(value)
  defp stringify_value(%Date{} = value), do: Date.to_string(value)

  defp stringify_value(%DateTime{} = value) do
    Calendar.strftime(value, "%Y-%m-%d %H:%M:%S")
  end

  defp stringify_value(value) do
    to_string(value)
  rescue
    _ -> inspect(value)
  end

  defp normalize_boolean(value, _default) when value in [true, false], do: value

  defp normalize_boolean(value, default) when is_binary(value) do
    case String.trim(String.downcase(value)) do
      "true" -> true
      "false" -> false
      _ -> default
    end
  end

  defp normalize_boolean(_value, default), do: default

  defp normalize_optional_string(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_optional_string(nil), do: nil

  defp normalize_optional_string(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_optional_string()
  end

  defp normalize_optional_string(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_optional_string(value) when is_float(value), do: to_string(value)
  defp normalize_optional_string(_value), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp map_get(map, key, default \\ nil)

  defp map_get(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp map_get(_map, _key, default), do: default

  defp humanize_id(action_id) do
    action_id
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
