defmodule SelectoComponents.Views.Detail.RowActions do
  @moduledoc false

  @default_modal_action_id "__default_modal__"
  @modal_sizes [:sm, :md, :lg, :xl, :full, :third, :fullscreen]

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
    url = url_template |> resolve_template(row_context) |> sanitize_url()
    target = normalize_optional_string(map_get(payload, :target)) || "_blank"

    if is_binary(url) and String.trim(url) != "" do
      %{url: url, target: target}
    else
      nil
    end
  end

  def resolve_external_link(_action, _row_context), do: nil

  def resolve_iframe_modal(%{type: :iframe_modal, payload: payload}, row_context)
      when is_map(payload) do
    url_template = map_get(payload, :url_template)
    iframe_url = url_template |> resolve_template(row_context) |> sanitize_url()

    if is_binary(iframe_url) and String.trim(iframe_url) != "" do
      %{
        iframe_url: iframe_url,
        url_template: url_template,
        iframe_allow: normalize_optional_string(map_get(payload, :allow)),
        iframe_referrer_policy:
          normalize_optional_string(map_get(payload, :referrer_policy)) ||
            "strict-origin-when-cross-origin",
        iframe_sandbox:
          normalize_optional_string(map_get(payload, :sandbox)) ||
            "allow-scripts allow-same-origin"
      }
    else
      nil
    end
  end

  def resolve_iframe_modal(_action, _row_context), do: nil

  def sanitize_url(url) when is_binary(url) do
    trimmed = String.trim(url)
    lower = String.downcase(trimmed)
    uri = URI.parse(trimmed)

    cond do
      trimmed == "" ->
        nil

      String.contains?(trimmed, <<0>>) ->
        nil

      uri.scheme in ["http", "https"] ->
        trimmed

      is_nil(uri.scheme) and not String.starts_with?(trimmed, "//") and
          not String.starts_with?(lower, ["javascript:", "data:", "vbscript:"]) ->
        trimmed

      true ->
        nil
    end
  end

  def sanitize_url(_url), do: nil

  def resolve_live_component(%{type: :live_component, payload: payload}, row_context)
      when is_map(payload) do
    component_module = map_get(payload, :module)
    component_assigns_template = map_get(payload, :assigns, %{})

    if is_atom(component_module) do
      %{
        component_module: component_module,
        component_assigns_template: component_assigns_template,
        component_assigns: resolve_component_assigns(component_assigns_template, row_context)
      }
    else
      nil
    end
  end

  def resolve_live_component(_action, _row_context), do: nil

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

  def resolve_component_assigns(assigns_template, source) when is_map(assigns_template) do
    context = template_context(source)

    Map.new(assigns_template, fn {key, value} ->
      {normalize_assign_key(key), resolve_component_assign_value(value, context, source)}
    end)
  end

  def resolve_component_assigns(_assigns_template, _source), do: %{}

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

  defp normalize_action_type(value)
       when value in [:modal, :iframe_modal, :external_link, :live_component],
       do: value

  defp normalize_action_type(value) when is_binary(value) do
    case String.trim(value) do
      "modal" -> :modal
      "iframe_modal" -> :iframe_modal
      "external_link" -> :external_link
      "live_component" -> :live_component
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
      "third" -> :third
      "fullscreen" -> :fullscreen
      "full_screen" -> :fullscreen
      "full screen" -> :fullscreen
      "1/3 screen" -> :third
      "1/3_screen" -> :third
      "one_third" -> :third
      _ -> nil
    end
  end

  defp normalize_modal_size(_size), do: nil

  def resolve_template(template, row_context) when is_binary(template) do
    context = template_context(row_context)

    Regex.replace(~r/\{\{\s*([^}]+?)\s*\}\}/, template, fn _, key ->
      key
      |> String.trim()
      |> then(&Map.get(context, &1, ""))
      |> stringify_value()
    end)
  end

  def resolve_template(nil, _row_context), do: nil
  def resolve_template(template, _row_context), do: template

  defp template_context(%{display_record: display_record, field_values: field_values}) do
    display_record
    |> stringify_keys()
    |> Map.merge(stringify_keys(field_values))
  end

  defp template_context(record) when is_map(record), do: stringify_keys(record)

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

  defp normalize_assign_key(key) when is_atom(key), do: key

  defp normalize_assign_key(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> String.to_atom(key)
    end
  end

  defp normalize_assign_key(key), do: key

  defp resolve_component_assign_value({:field, field_name}, context, _source) do
    field_name
    |> normalize_optional_string()
    |> then(&Map.get(context, &1))
  end

  defp resolve_component_assign_value(%{field: field_name}, context, _source) do
    resolve_component_assign_value({:field, field_name}, context, %{})
  end

  defp resolve_component_assign_value(%{"field" => field_name}, context, _source) do
    resolve_component_assign_value({:field, field_name}, context, %{})
  end

  defp resolve_component_assign_value(value, _context, source) when is_binary(value) do
    if String.contains?(value, "{{") do
      resolve_template(value, source)
    else
      value
    end
  end

  defp resolve_component_assign_value(value, context, source) when is_list(value) do
    Enum.map(value, &resolve_component_assign_value(&1, context, source))
  end

  defp resolve_component_assign_value(value, context, source) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {normalize_assign_key(key), resolve_component_assign_value(nested_value, context, source)}
    end)
  end

  defp resolve_component_assign_value(value, _context, _source), do: value

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
