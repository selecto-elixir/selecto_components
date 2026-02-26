defmodule SelectoComponents.ExtensionsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Extensions

  defmodule MarkerExtension do
    @behaviour Selecto.Extension

    @impl true
    def components_views(_selecto_or_domain, _opts) do
      [{:map, SelectoComponents.Views.Map, "Map View", %{drill_down: :detail}}]
    end
  end

  test "merge_views appends extension views" do
    views = [
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{drill_down: :detail}},
      {:detail, SelectoComponents.Views.Detail, "Detail View", %{}}
    ]

    merged = Extensions.merge_views(views, build_selecto())

    assert Enum.any?(merged, fn {id, _, _, _} -> id == :map end)
  end

  defp build_selecto do
    domain = %{
      name: "Spatial",
      source: %{
        source_table: "places",
        primary_key: :id,
        fields: [:id, :name, :location],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          name: %{type: :string},
          location: %{type: :geometry}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      extensions: [MarkerExtension]
    }

    Selecto.configure(domain, nil)
  end
end
