defmodule SelectoComponents.Keyboard.ShortcutsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Keyboard.Shortcuts

  @views [
    {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
    {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{}},
    {:graph, SelectoComponents.Views.Graph, "Graph View", %{}}
  ]

  test "normalizes default shortcut config" do
    config = Shortcuts.normalize(nil)

    assert Shortcuts.enabled?(config)
    assert Shortcuts.show_hints?(config)
    assert Shortcuts.sequence_timeout_ms(config) == 900
  end

  test "disabled shortcut config removes keymap and help groups" do
    config = Shortcuts.normalize(false)

    refute Shortcuts.enabled?(config)
    assert Shortcuts.keymap(config, views: @views) == %{}
    assert Shortcuts.shortcut_groups(config, views: @views) == []
  end

  test "keymap is filtered by available views and saved view support" do
    keymap =
      Shortcuts.keymap(true,
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{}}
        ],
        use_saved_views: false
      )

    assert keymap["detail_view"] == ["g d"]
    assert keymap["aggregate_view"] == ["g a"]
    assert keymap["focus_filters"] == ["/"]
    assert keymap["next_tab"] == ["]"]
    assert keymap["previous_tab"] == ["["]
    assert keymap["export_csv"] == ["x c"]
    refute Map.has_key?(keymap, "filter_picker_add")
    refute Map.has_key?(keymap, "graph_view")
    refute Map.has_key?(keymap, "saved_views_tab")
  end

  test "shortcut overrides can replace or disable bindings" do
    keymap =
      %{overrides: %{apply: ["Mod + Enter"], export_csv: ["X Y"], export_tab: false}}
      |> Shortcuts.normalize()
      |> Shortcuts.keymap(views: @views)

    assert keymap["apply"] == ["mod+enter"]
    assert keymap["export_csv"] == ["x y"]
    refute Map.has_key?(keymap, "export_tab")
  end

  test "shortcut groups include display metadata" do
    groups = Shortcuts.shortcut_groups(true, views: @views, use_saved_views: true)

    assert Enum.any?(groups, &(&1.group == "General"))

    filters = Enum.find(groups, &(&1.group == "Filters"))
    assert Enum.any?(filters.shortcuts, &(&1.id == "filter_picker_add"))
    assert Enum.any?(filters.shortcuts, &(&1.key_label == "Arrow Down"))

    views = Enum.find(groups, &(&1.group == "Views"))
    assert Enum.any?(views.shortcuts, &(&1.id == "graph_view"))

    navigation = Enum.find(groups, &(&1.group == "Navigation"))
    assert Enum.any?(navigation.shortcuts, &(&1.id == "saved_views_tab"))

    export = Enum.find(groups, &(&1.group == "Export"))
    assert Enum.any?(export.shortcuts, &(&1.id == "export_xlsx"))
  end
end
