defmodule SelectoComponents.Filter.FilterSetsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Filter.FilterSets
  alias SelectoComponents.Theme

  test "decode_shared_filters/1 decodes valid payload" do
    filters = %{
      "f1" => %{"filter" => "id", "comp" => "=", "value" => "1"},
      "f2" => %{"filter" => "status", "comp" => "IN", "value" => "active"}
    }

    encoded = encode_shared_filters(filters)

    assert {:ok, ^filters} = FilterSets.decode_shared_filters(encoded)
  end

  test "decode_shared_filters/1 rejects oversized encoded payload" do
    encoded = String.duplicate("a", 40_000)

    assert {:error, {:decode_failed, :shared_filters_param_too_large}} =
             FilterSets.decode_shared_filters(encoded)
  end

  test "decode_shared_filters/1 rejects invalid decoded shape" do
    encoded =
      "not-a-filter-map"
      |> Jason.encode!()
      |> :zlib.compress()
      |> Base.url_encode64(padding: false)

    assert {:error, {:decode_failed, :invalid_filters_shape}} =
             FilterSets.decode_shared_filters(encoded)
  end

  test "renders themed save dialog controls" do
    html = render_component(FilterSets, base_assigns(%{show_save_dialog: true}))

    assert html =~ "Save Filter Set"
    assert html =~ "Set as default"
    assert html =~ "sc-panel"
    assert html =~ "sc-input"
    assert html =~ "sc-btn sc-btn-primary"
    assert html =~ "sc-btn sc-btn-secondary"
  end

  test "renders themed manage dialog rows" do
    html =
      render_component(
        FilterSets,
        base_assigns(%{
          show_manage_dialog: true,
          personal_sets: [
            %{id: "p1", name: "My Filters", description: "Private set", is_default: true}
          ],
          shared_sets: [
            %{id: "s1", name: "Shared Filters", description: "Shared set"}
          ]
        })
      )

    assert html =~ "Manage Filter Sets"
    assert html =~ "My Filters"
    assert html =~ "Shared Filters"
    assert html =~ "Import"
    assert html =~ "sc-panel"
    assert html =~ "sc-btn"
  end

  test "renders themed share dialog fields" do
    html =
      render_component(
        FilterSets,
        base_assigns(%{
          show_share_dialog: true,
          share_url: "https://example.test/filter-set/abc",
          share_json: ~s({"filters":[]})
        })
      )

    assert html =~ "Share Filter Set"
    assert html =~ "https://example.test/filter-set/abc"
    assert html =~ "Export as JSON"
    assert html =~ "sc-panel"
    assert html =~ "sc-input"
    assert html =~ "sc-btn sc-btn-secondary"
  end

  defp encode_shared_filters(filters) do
    filters
    |> Jason.encode!()
    |> :zlib.compress()
    |> Base.url_encode64(padding: false)
  end

  defp base_assigns(overrides) do
    Map.merge(
      %{
        id: "filter-sets-test",
        theme: Theme.default_theme(:light),
        user_id: 42,
        domain: "/orders",
        current_filters: [],
        current_set_id: nil,
        current_set: nil,
        filter_sets_loaded: true,
        personal_sets: [],
        shared_sets: [],
        system_sets: [],
        show_save_dialog: false,
        show_manage_dialog: false,
        show_share_dialog: false,
        show_import_dialog: false,
        share_url: "",
        share_json: "",
        import_json: "",
        save_form: %{
          name: "Quarterly Ops",
          description: "Ops filter set",
          is_default: false,
          is_shared: false
        }
      },
      overrides
    )
  end
end
