defmodule SelectoComponents.ExportedViews.ManagerTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  @store SelectoComponents.ExportedViews.ManagerTest.Store

  alias SelectoComponents.ExportedViews
  alias SelectoComponents.ExportedViews.Manager
  alias SelectoComponents.Theme

  defmodule Adapter do
    @behaviour SelectoComponents.ExportedViews

    def list_exported_views(context, _opts) do
      store()
      |> Agent.get(&Map.values(&1))
      |> Enum.filter(fn view -> ExportedViews.field(view, :context) == context end)
    end

    def get_exported_view_by_public_id(public_id, _opts) do
      Agent.get(store(), &Map.get(&1, public_id))
    end

    def create_exported_view(attrs, _opts) do
      send(self(), {:create_exported_view, attrs})
      Agent.update(store(), &Map.put(&1, attrs.public_id, attrs))
      {:ok, attrs}
    end

    def update_exported_view(view, attrs, _opts) do
      updated = Map.merge(view, attrs)
      Agent.update(store(), &Map.put(&1, ExportedViews.field(updated, :public_id), updated))
      {:ok, updated}
    end

    def delete_exported_view(view, _opts) do
      Agent.update(store(), &Map.delete(&1, ExportedViews.field(view, :public_id)))
      {:ok, view}
    end

    defp store, do: SelectoComponents.ExportedViews.ManagerTest.Store
  end

  setup do
    start_supervised!(%{
      id: @store,
      start: {Agent, :start_link, [fn -> %{} end, [name: @store]]}
    })

    :ok
  end

  test "renders themed exported view form controls" do
    html =
      render_component(Manager, base_assigns())

    assert html =~ "Exported Views"
    assert html =~ "Create Exported View"
    assert html =~ "No exported views yet."
    assert html =~ "sc-panel"
    assert html =~ "sc-input"
    assert html =~ "sc-btn sc-btn-primary"
  end

  test "create_exported_view stops before persistence when capability is denied" do
    socket = %Phoenix.LiveView.Socket{
      assigns:
        base_assigns()
        |> Map.merge(%{
          __changed__: %{},
          flash: %{},
          exported_views: [],
          loaded_context: "/orders",
          form: %{name: "", cache_ttl_hours: 3, ip_allowlist_text: ""},
          capability_resolver: fn request ->
            send(self(), {:capability_request, request})

            Selecto.Capabilities.deny(:exported_views_disabled,
              user_message: "Published views are disabled."
            )
          end
        })
    }

    assert {:noreply, updated_socket} =
             Manager.handle_event(
               "create_exported_view",
               %{
                 "name" => "Executive Snapshot",
                 "cache_ttl_hours" => "3",
                 "ip_allowlist_text" => ""
               },
               socket
             )

    assert_receive {:capability_request, request}
    assert request.capability == "selecto.exported_views.manage"
    assert request.operation == :create
    refute_receive {:create_exported_view, _attrs}
    assert Adapter.list_exported_views("/orders", []) == []

    assert Phoenix.Flash.get(updated_socket.assigns.flash, :error) =~
             "Published views are disabled."
  end

  defp base_assigns do
    %{
      id: "exported-views-manager",
      theme: Theme.default_theme(:light),
      exported_view_module: Adapter,
      exported_view_context: "/orders",
      exported_view_endpoint: nil,
      exported_view_base_url: nil,
      current_user_id: 42,
      selecto: %{},
      views: [],
      view_config: %{view_mode: "detail", filters: [], views: %{}},
      path: "/orders",
      tenant_context: nil
    }
  end
end
