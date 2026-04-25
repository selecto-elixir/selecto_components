defmodule SelectoComponents.Keyboard.Shortcuts do
  @moduledoc """
  Normalizes Selecto root keyboard shortcut configuration and help metadata.
  """

  @default_enabled true
  @default_show_hints true
  @default_preset :default
  @default_sequence_timeout_ms 900

  @actions [
    %{
      id: "help",
      group: "General",
      label: "Open keyboard shortcuts",
      keys: ["?"]
    },
    %{
      id: "apply",
      group: "General",
      label: "Apply configuration",
      keys: ["mod+enter"]
    },
    %{
      id: "detail_view",
      group: "Views",
      label: "Switch to Detail view",
      keys: ["g d"],
      view: "detail"
    },
    %{
      id: "aggregate_view",
      group: "Views",
      label: "Switch to Aggregate view",
      keys: ["g a"],
      view: "aggregate"
    },
    %{
      id: "graph_view",
      group: "Views",
      label: "Switch to Graph view",
      keys: ["g g"],
      view: "graph"
    },
    %{
      id: "export_tab",
      group: "Navigation",
      label: "Open Export tab",
      keys: ["e"]
    },
    %{
      id: "saved_views_tab",
      group: "Navigation",
      label: "Open Save View tab",
      keys: ["s"],
      feature: :saved_views
    }
  ]

  @doc """
  Returns the default keyboard shortcut config.
  """
  def default_config do
    %{
      enabled: @default_enabled,
      show_hints: @default_show_hints,
      preset: @default_preset,
      sequence_timeout_ms: @default_sequence_timeout_ms,
      overrides: %{}
    }
  end

  @doc """
  Normalizes assign/config values accepted by the root Selecto form.
  """
  def normalize(value \\ true)

  def normalize(false), do: %{default_config() | enabled: false}

  def normalize(nil), do: default_config()

  def normalize(true), do: default_config()

  def normalize(value) when is_list(value), do: value |> Map.new() |> normalize()

  def normalize(%{} = value) do
    %{
      enabled: truthy?(get_option(value, :enabled, @default_enabled)),
      show_hints: truthy?(get_option(value, :show_hints, @default_show_hints)),
      preset: normalize_preset(get_option(value, :preset, @default_preset)),
      sequence_timeout_ms:
        normalize_timeout(get_option(value, :sequence_timeout_ms, @default_sequence_timeout_ms)),
      overrides: normalize_overrides(get_option(value, :overrides, %{}))
    }
  end

  def normalize(_value), do: default_config()

  def enabled?(%{enabled: enabled}), do: enabled == true
  def enabled?(_config), do: @default_enabled

  def show_hints?(%{show_hints: show_hints}), do: show_hints == true
  def show_hints?(_config), do: @default_show_hints

  def sequence_timeout_ms(%{sequence_timeout_ms: timeout}) when is_integer(timeout), do: timeout
  def sequence_timeout_ms(_config), do: @default_sequence_timeout_ms

  @doc """
  Returns the active keymap as `%{"action_id" => ["key sequence"]}`.
  """
  def keymap(config, opts \\ []) do
    config = normalize(config)

    if enabled?(config) and config.preset != :none do
      config
      |> active_actions(opts)
      |> Map.new(fn action -> {action.id, action_keys(action, config.overrides)} end)
      |> Enum.reject(fn {_id, keys} -> keys == [] end)
      |> Map.new()
    else
      %{}
    end
  end

  @doc """
  Returns grouped shortcut metadata for the help surface.
  """
  def shortcut_groups(config, opts \\ []) do
    config = normalize(config)

    if enabled?(config) and show_hints?(config) and config.preset != :none do
      config
      |> active_actions(opts)
      |> Enum.map(fn action ->
        keys = action_keys(action, config.overrides)

        action
        |> Map.take([:id, :group, :label])
        |> Map.put(:keys, keys)
        |> Map.put(:key_label, keys |> Enum.map(&format_key_binding/1) |> Enum.join(", "))
      end)
      |> Enum.reject(&(Enum.empty?(&1.keys) or &1.key_label == ""))
      |> Enum.group_by(& &1.group)
      |> Enum.map(fn {group, shortcuts} -> %{group: group, shortcuts: shortcuts} end)
      |> Enum.sort_by(&group_order/1)
    else
      []
    end
  end

  @doc """
  Extracts stable view ids from the configured view list.
  """
  def available_view_ids(views) when is_list(views) do
    views
    |> Enum.map(&view_id/1)
    |> Enum.reject(&is_nil/1)
  end

  def available_view_ids(_views), do: []

  defp active_actions(config, opts) do
    available_views = opts |> Keyword.get(:views, []) |> available_view_ids()
    use_saved_views = opts |> Keyword.get(:use_saved_views, false) |> truthy?()

    Enum.filter(@actions, fn action ->
      cond do
        Map.get(action, :view) -> Map.get(action, :view) in available_views
        Map.get(action, :feature) == :saved_views -> use_saved_views
        true -> config.preset == :default
      end
    end)
  end

  defp action_keys(action, overrides) do
    case Map.fetch(overrides, action.id) do
      {:ok, false} -> []
      {:ok, keys} -> keys
      :error -> action.keys
    end
  end

  defp get_option(map, key, default) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp truthy?(value) when value in [false, "false", "FALSE", "0", 0, nil], do: false
  defp truthy?(_value), do: true

  defp normalize_preset(value) when value in [false, "none", :none, "disabled", :disabled],
    do: :none

  defp normalize_preset(_value), do: :default

  defp normalize_timeout(value) when is_integer(value) and value >= 250, do: value

  defp normalize_timeout(value) when is_binary(value) do
    case Integer.parse(value) do
      {timeout, ""} -> normalize_timeout(timeout)
      _ -> @default_sequence_timeout_ms
    end
  end

  defp normalize_timeout(_value), do: @default_sequence_timeout_ms

  defp normalize_overrides(nil), do: %{}

  defp normalize_overrides(overrides) when is_list(overrides) do
    overrides
    |> Map.new()
    |> normalize_overrides()
  end

  defp normalize_overrides(%{} = overrides) do
    Map.new(overrides, fn {action_id, keys} ->
      {normalize_action_id(action_id), normalize_keys(keys)}
    end)
  end

  defp normalize_overrides(_overrides), do: %{}

  defp normalize_action_id(action_id) when is_atom(action_id), do: Atom.to_string(action_id)
  defp normalize_action_id(action_id) when is_binary(action_id), do: action_id
  defp normalize_action_id(action_id), do: to_string(action_id)

  defp normalize_keys(false), do: false
  defp normalize_keys(nil), do: []

  defp normalize_keys(key) when is_binary(key), do: [normalize_key_binding(key)]

  defp normalize_keys(keys) when is_list(keys) do
    keys
    |> Enum.map(&normalize_key_binding/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_keys(_keys), do: []

  defp normalize_key_binding(key) do
    key
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s*\+\s*/, "+")
    |> String.replace(~r/\s+/, " ")
  end

  defp format_key_binding(binding) do
    binding
    |> String.split(" ", trim: true)
    |> Enum.map(&format_key_combo/1)
    |> Enum.join(" then ")
  end

  defp format_key_combo(combo) do
    combo
    |> String.split("+", trim: true)
    |> Enum.map(&format_key_part/1)
    |> Enum.join(" + ")
  end

  defp format_key_part("mod"), do: "Cmd/Ctrl"
  defp format_key_part("enter"), do: "Enter"
  defp format_key_part("escape"), do: "Escape"
  defp format_key_part("shift"), do: "Shift"
  defp format_key_part("alt"), do: "Alt"
  defp format_key_part("?"), do: "?"
  defp format_key_part(key), do: String.upcase(key)

  defp view_id({id, _module, _name, _opts}) when is_atom(id), do: Atom.to_string(id)
  defp view_id({id, _module, _name, _opts}) when is_binary(id), do: id
  defp view_id(%{id: id}) when is_atom(id), do: Atom.to_string(id)
  defp view_id(%{id: id}) when is_binary(id), do: id
  defp view_id(_view), do: nil

  defp group_order(%{group: "General"}), do: {0, "General"}
  defp group_order(%{group: "Views"}), do: {1, "Views"}
  defp group_order(%{group: "Navigation"}), do: {2, "Navigation"}
  defp group_order(%{group: group}), do: {9, group}
end
