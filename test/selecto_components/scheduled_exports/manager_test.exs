defmodule SelectoComponents.ScheduledExports.ManagerTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  @store SelectoComponents.ScheduledExports.ManagerTest.Store

  alias SelectoComponents.ScheduledExports
  alias SelectoComponents.ScheduledExports.Manager

  defmodule Adapter do
    @behaviour SelectoComponents.ScheduledExports

    def list_scheduled_exports(context, _opts) do
      store()
      |> Agent.get(&Map.values(&1))
      |> Enum.filter(fn scheduled_export ->
        ScheduledExports.field(scheduled_export, :context) == context
      end)
    end

    def get_scheduled_export_by_public_id(public_id, _opts) do
      Agent.get(store(), &Map.get(&1, public_id))
    end

    def create_scheduled_export(attrs, _opts) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      scheduled_export =
        attrs
        |> Map.put_new(:id, System.unique_integer([:positive]))
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)

      Agent.update(store(), &Map.put(&1, attrs.public_id, scheduled_export))
      {:ok, scheduled_export}
    end

    def update_scheduled_export(scheduled_export, attrs, _opts) do
      updated =
        scheduled_export
        |> Map.merge(attrs)
        |> Map.put(:updated_at, DateTime.utc_now() |> DateTime.truncate(:second))

      Agent.update(store(), &Map.put(&1, ScheduledExports.field(updated, :public_id), updated))
      {:ok, updated}
    end

    def delete_scheduled_export(scheduled_export, _opts) do
      Agent.update(store(), &Map.delete(&1, ScheduledExports.field(scheduled_export, :public_id)))
      {:ok, scheduled_export}
    end

    def create_scheduled_export_run(_attrs, _opts), do: {:error, :not_implemented}
    def update_scheduled_export_run(_run, _attrs, _opts), do: {:error, :not_implemented}

    def due_scheduled_exports(_now, _opts) do
      []
    end

    defp store, do: SelectoComponents.ScheduledExports.ManagerTest.Store
  end

  setup do
    start_supervised!(%{
      id: @store,
      start: {Agent, :start_link, [fn -> %{} end, [name: @store]]}
    })

    :ok
  end

  test "renders existing scheduled exports" do
    {:ok, _scheduled_export} =
      Adapter.create_scheduled_export(
        %{
          id: 1,
          public_id: "sched_1",
          name: "Weekly Orders",
          context: "tenant:1:/orders",
          view_type: "detail",
          export_format: "csv",
          delivery: %{email: %{recipients: ["ops@example.com"]}},
          schedule: %{
            enabled: true,
            kind: :weekly,
            day_of_week: 1,
            time: "07:00",
            timezone: "Etc/UTC"
          },
          next_run_at: ~U[2026-04-06 07:00:00Z],
          last_run_at: ~U[2026-04-01 07:00:00Z],
          last_status: :ok,
          disabled_at: nil
        },
        []
      )

    html = render_component(Manager, base_assigns())

    assert html =~ "Scheduled Exports"
    assert html =~ "Weekly Orders"
    assert html =~ "ops@example.com"
    assert html =~ "Weekly on Monday at 07:00 Etc/UTC"
  end

  test "create_scheduled_export persists a new schedule" do
    socket = base_socket()

    assert {:noreply, updated_socket} =
             Manager.handle_event(
               "create_scheduled_export",
               %{
                 "name" => "Morning Orders",
                 "export_format" => "json",
                 "recipients" => "ops@example.com, finance@example.com",
                 "subject_template" => "Morning export",
                 "body_template" => "Attached.",
                 "schedule" => %{
                   "enabled" => true,
                   "kind" => "daily",
                   "time" => "06:30",
                   "timezone" => "Etc/UTC",
                   "day_of_week" => "1",
                   "day_of_month" => "1"
                 }
               },
               socket
             )

    assert Phoenix.Flash.get(updated_socket.assigns.flash, :info) == "Scheduled export created"

    [scheduled_export] = Adapter.list_scheduled_exports("tenant:1:/orders", [])
    assert scheduled_export.name == "Morning Orders"
    assert scheduled_export.export_format == "json"

    assert scheduled_export.delivery.email.recipients == [
             "ops@example.com",
             "finance@example.com"
           ]

    assert scheduled_export.schedule.kind == :daily
  end

  test "toggle_scheduled_export_disabled pauses and resumes a schedule" do
    {:ok, scheduled_export} =
      Adapter.create_scheduled_export(
        %{
          id: 1,
          public_id: "sched_toggle",
          name: "Toggle Me",
          context: "tenant:1:/orders",
          view_type: "detail",
          export_format: "csv",
          delivery: %{email: %{recipients: ["ops@example.com"]}},
          schedule: %{enabled: true, kind: :daily, time: "07:00", timezone: "Etc/UTC"},
          next_run_at: ~U[2026-04-02 07:00:00Z],
          last_status: :never,
          disabled_at: nil
        },
        []
      )

    socket = %{
      base_socket()
      | assigns: Map.put(base_socket().assigns, :scheduled_exports, [scheduled_export])
    }

    assert {:noreply, paused_socket} =
             Manager.handle_event(
               "toggle_scheduled_export_disabled",
               %{"id" => "sched_toggle"},
               socket
             )

    paused = Adapter.get_scheduled_export_by_public_id("sched_toggle", [])
    refute is_nil(paused.disabled_at)
    assert paused.schedule.enabled == false
    assert is_nil(paused.next_run_at)
    assert Phoenix.Flash.get(paused_socket.assigns.flash, :info) == "Scheduled export updated"

    resumed_socket = %{
      paused_socket
      | assigns: Map.put(paused_socket.assigns, :scheduled_exports, [paused])
    }

    assert {:noreply, _resumed_socket} =
             Manager.handle_event(
               "toggle_scheduled_export_disabled",
               %{"id" => "sched_toggle"},
               resumed_socket
             )

    resumed = Adapter.get_scheduled_export_by_public_id("sched_toggle", [])
    assert is_nil(resumed.disabled_at)
    assert resumed.schedule.enabled == true
    assert %DateTime{} = resumed.next_run_at
  end

  test "delete_scheduled_export removes the schedule" do
    {:ok, scheduled_export} =
      Adapter.create_scheduled_export(
        %{
          id: 1,
          public_id: "sched_delete",
          name: "Delete Me",
          context: "tenant:1:/orders",
          view_type: "detail",
          export_format: "csv",
          delivery: %{email: %{recipients: ["ops@example.com"]}},
          schedule: %{enabled: true, kind: :daily, time: "07:00", timezone: "Etc/UTC"},
          next_run_at: ~U[2026-04-02 07:00:00Z],
          last_status: :never,
          disabled_at: nil
        },
        []
      )

    socket = %{
      base_socket()
      | assigns: Map.put(base_socket().assigns, :scheduled_exports, [scheduled_export])
    }

    assert {:noreply, updated_socket} =
             Manager.handle_event(
               "delete_scheduled_export",
               %{"id" => "sched_delete"},
               socket
             )

    assert Adapter.get_scheduled_export_by_public_id("sched_delete", []) == nil
    assert Phoenix.Flash.get(updated_socket.assigns.flash, :info) == "Scheduled export deleted"
  end

  defp base_assigns do
    %{
      id: "scheduled-exports-manager",
      scheduled_export_module: Adapter,
      scheduled_export_context: "tenant:1:/orders",
      current_user_id: "42",
      selecto: Selecto.configure(domain(), nil),
      views: [{:detail, SelectoComponents.Views.Detail, "Detail", %{}}],
      view_config: %{view_mode: "detail", views: %{detail: %{selected: []}}, filters: []},
      path: "/orders",
      tenant_context: %{tenant_id: 1}
    }
  end

  defp base_socket do
    %Phoenix.LiveView.Socket{
      assigns:
        base_assigns()
        |> Map.merge(%{
          __changed__: %{},
          flash: %{},
          scheduled_exports: [],
          loaded_context: "tenant:1:/orders"
        })
    }
  end

  defp domain do
    %{
      name: "ManagerTestDomain",
      source: %{
        source_table: "orders",
        primary_key: :id,
        fields: [:id, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          title: %{type: :string, name: "Title", colid: :title}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }
  end
end
