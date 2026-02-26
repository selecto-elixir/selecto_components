defmodule SelectoComponents.Form.ParamsStateTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Form.ParamsState

  test "view_config_to_params includes detail max_rows and per_page" do
    view_config = %{
      view_mode: "detail",
      filters: [],
      views: %{
        detail: %{
          selected: [],
          order_by: [],
          per_page: "60",
          max_rows: "10000",
          prevent_denormalization: true
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "detail"
    assert params["per_page"] == "60"
    assert params["max_rows"] == "10000"
    assert params["prevent_denormalization"] == "true"
  end

  test "view_config_to_params includes aggregate per-page config" do
    view_config = %{
      view_mode: "aggregate",
      filters: [],
      views: %{
        aggregate: %{
          group_by: [],
          aggregate: [],
          per_page: "300"
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "aggregate"
    assert params["aggregate_per_page"] == "300"
    refute Map.has_key?(params, "max_rows")
  end
end
