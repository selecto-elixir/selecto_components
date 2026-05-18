defmodule SelectoComponents.ScheduledExports.ManagerTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  @store SelectoComponents.ScheduledExports.ManagerTest.Store
  @run_store SelectoComponents.ScheduledExports.ManagerTest.RunStore

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

    def create_scheduled_export_run(attrs, _opts) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      run =
        attrs
        |> Map.put_new(:id, System.unique_integer([:positive]))
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)

      Agent.update(run_store(), &Map.put(&1, run.id, run))
      {:ok, run}
    end

    def update_scheduled_export_run(run, attrs, _opts) do
      updated =
        run
        |> Map.merge(attrs)
        |> Map.put(:updated_at, DateTime.utc_now() |> DateTime.truncate(:second))

      Agent.update(run_store(), &Map.put(&1, ScheduledExports.field(updated, :id), updated))
      {:ok, updated}
    end

    def list_scheduled_export_runs(public_id, _opts) do
      run_store()
      |> Agent.get(&Map.values(&1))
      |> Enum.filter(fn run ->
        ScheduledExports.field(run, :scheduled_export_public_id) == public_id
      end)
    end

    def due_scheduled_exports(_now, _opts) do
      []
    end

    defp store, do: SelectoComponents.ScheduledExports.ManagerTest.Store
    defp run_store, do: SelectoComponents.ScheduledExports.ManagerTest.RunStore
  end

  defmodule DeliveryAdapter do
    @behaviour SelectoComponents.ExportDelivery

    def deliver_email(export_payload, delivery_config, opts) do
      if notify = Keyword.get(opts, :notify) do
        send(notify, {:scheduled_export_delivery, export_payload, delivery_config})
      end

      {:ok, %{message_id: "msg_123"}}
    end
  end

  defmodule SnapshotRunner do
    def render_snapshot(snapshot, _opts) do
      {:ok,
       %{
         query_results: {
           [["Order A", 10], ["Order B", 12]],
           ["title", "quantity"],
           []
         },
         applied_view: Map.get(snapshot.params, "view_mode", "detail")
       }, %{row_count: 2, execution_time_ms: 18}}
    end
  end

  setup do
    start_supervised!(%{
      id: @store,
      start: {Agent, :start_link, [fn -> %{} end, [name: @store]]}
    })

    start_supervised!(%{
      id: @run_store,
      start: {Agent, :start_link, [fn -> %{} end, [name: @run_store]]}
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
    assert html =~ "sc-panel"
    assert html =~ "sc-input"
    assert html =~ "sc-btn"
  end

  test "renders recent scheduled export runs" do
    {:ok, _scheduled_export} =
      Adapter.create_scheduled_export(
        scheduled_export_fixture(%{
          id: 1,
          public_id: "sched_runs",
          name: "Run History"
        }),
        []
      )

    {:ok, _run} =
      Adapter.create_scheduled_export_run(
        %{
          scheduled_export_id: 1,
          scheduled_export_public_id: "sched_runs",
          trigger_type: :manual_email,
          started_at: ~U[2026-04-01 07:00:00Z],
          finished_at: ~U[2026-04-01 07:00:02Z],
          status: :ok,
          row_count: 2,
          payload_bytes: 128,
          delivery_count: 1
        },
        []
      )

    html = render_component(Manager, base_assigns())

    assert html =~ "Recent Runs"
    assert html =~ "2 rows / 128 bytes"
    assert html =~ "Run Now"
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

  test "create_scheduled_export stops before persistence when capability is denied" do
    socket = deny_capabilities_socket("Schedule management is disabled.")

    assert {:noreply, updated_socket} =
             Manager.handle_event(
               "create_scheduled_export",
               %{
                 "name" => "Morning Orders",
                 "export_format" => "json",
                 "recipients" => "ops@example.com",
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

    assert Adapter.list_scheduled_exports("tenant:1:/orders", []) == []
    assert_receive {:capability_request, request}
    assert request.capability == "selecto.scheduled_exports.manage"
    assert request.operation == :create

    assert Phoenix.Flash.get(updated_socket.assigns.flash, :error) =~
             "Schedule management is disabled."
  end

  test "toggle_scheduled_export_disabled stops before persistence when capability is denied" do
    {:ok, scheduled_export} =
      Adapter.create_scheduled_export(
        %{
          id: 1,
          public_id: "sched_denied_toggle",
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

    deny_socket = deny_capabilities_socket("Schedule management is disabled.")

    socket = %{
      deny_socket
      | assigns: Map.put(deny_socket.assigns, :scheduled_exports, [scheduled_export])
    }

    assert {:noreply, updated_socket} =
             Manager.handle_event(
               "toggle_scheduled_export_disabled",
               %{"id" => "sched_denied_toggle"},
               socket
             )

    unchanged = Adapter.get_scheduled_export_by_public_id("sched_denied_toggle", [])
    assert unchanged.disabled_at == nil
    assert unchanged.schedule.enabled == true
    assert_receive {:capability_request, request}
    assert request.capability == "selecto.scheduled_exports.manage"
    assert request.operation == :toggle_disabled

    assert Phoenix.Flash.get(updated_socket.assigns.flash, :error) =~
             "Schedule management is disabled."
  end

  test "edit_scheduled_export loads the selected schedule into the form" do
    {:ok, scheduled_export} =
      Adapter.create_scheduled_export(
        %{
          id: 1,
          public_id: "sched_edit",
          name: "Weekly Orders",
          context: "tenant:1:/orders",
          view_type: "detail",
          export_format: "xlsx",
          delivery: %{
            email: %{
              recipients: ["ops@example.com", "finance@example.com"],
              subject_template: "Weekly export",
              body_template: "Attached."
            }
          },
          schedule: %{
            enabled: true,
            kind: :weekly,
            day_of_week: 5,
            day_of_month: 1,
            time: "08:15",
            timezone: "America/New_York"
          },
          next_run_at: ~U[2026-04-03 12:15:00Z],
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
             Manager.handle_event("edit_scheduled_export", %{"id" => "sched_edit"}, socket)

    assert updated_socket.assigns.editing_public_id == "sched_edit"
    assert updated_socket.assigns.form.name == "Weekly Orders"
    assert updated_socket.assigns.form.export_format == "xlsx"
    assert updated_socket.assigns.form.recipients_text == "ops@example.com\nfinance@example.com"
    assert updated_socket.assigns.form.subject_template == "Weekly export"
    assert updated_socket.assigns.form.body_template == "Attached."
    assert updated_socket.assigns.form.kind == "weekly"
    assert updated_socket.assigns.form.day_of_week == "5"
    assert updated_socket.assigns.form.time == "08:15"
    assert updated_socket.assigns.form.timezone == "America/New_York"
  end

  test "create_scheduled_export updates an existing schedule when public_id is present" do
    {:ok, scheduled_export} =
      Adapter.create_scheduled_export(
        %{
          id: 1,
          public_id: "sched_update",
          name: "Old Name",
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
               "create_scheduled_export",
               %{
                 "public_id" => "sched_update",
                 "name" => "Updated Name",
                 "export_format" => "tsv",
                 "recipients" => "ops@example.com\nfinance@example.com",
                 "subject_template" => "Updated export",
                 "body_template" => "Updated body.",
                 "schedule" => %{
                   "enabled" => true,
                   "kind" => "weekly",
                   "time" => "06:45",
                   "timezone" => "Etc/UTC",
                   "day_of_week" => "2",
                   "day_of_month" => "1"
                 }
               },
               socket
             )

    assert Phoenix.Flash.get(updated_socket.assigns.flash, :info) == "Scheduled export updated"
    assert updated_socket.assigns.editing_public_id == nil

    assert updated_socket.assigns.form == %{
             name: "",
             export_format: "csv",
             recipients_text: "",
             subject_template: "",
             body_template: "",
             kind: "daily",
             time: "07:00",
             timezone: "Etc/UTC",
             day_of_week: "1",
             day_of_month: "1",
             enabled: true
           }

    updated = Adapter.get_scheduled_export_by_public_id("sched_update", [])
    assert updated.name == "Updated Name"
    assert updated.export_format == "tsv"
    assert updated.delivery.email.recipients == ["ops@example.com", "finance@example.com"]
    assert updated.delivery.email.subject_template == "Updated export"
    assert updated.schedule.kind == :weekly
    assert updated.schedule.day_of_week == 2
    assert updated.schedule.time == "06:45"
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

  test "run_scheduled_export_now executes and reloads run history" do
    {:ok, scheduled_export} =
      Adapter.create_scheduled_export(
        scheduled_export_fixture(%{
          id: 1,
          public_id: "sched_run_now",
          name: "Run Now",
          snapshot_blob: snapshot_blob()
        }),
        []
      )

    socket = %{
      base_socket()
      | assigns: Map.put(base_socket().assigns, :scheduled_exports, [scheduled_export])
    }

    assert {:noreply, updated_socket} =
             Manager.handle_event(
               "run_scheduled_export_now",
               %{"id" => "sched_run_now"},
               socket
             )

    assert Phoenix.Flash.get(updated_socket.assigns.flash, :info) ==
             "Scheduled export run completed"

    assert_receive {:scheduled_export_delivery, export_payload, delivery_config}
    assert export_payload.format == "csv"
    assert delivery_config.email.recipients == ["ops@example.com"]

    updated = Adapter.get_scheduled_export_by_public_id("sched_run_now", [])
    assert updated.last_status == :ok
    assert %DateTime{} = updated.last_run_at

    assert [%{status: :ok, row_count: 2, delivery_count: 1}] =
             Adapter.list_scheduled_export_runs("sched_run_now", [])

    assert [%{status: :ok}] = updated_socket.assigns.scheduled_export_runs["sched_run_now"]

    assert %{row_count: 2, payload_bytes: payload_bytes} =
             updated_socket.assigns.run_results["sched_run_now"]

    assert is_integer(payload_bytes)
  end

  test "run_scheduled_export_now surfaces skipped capability results" do
    {:ok, scheduled_export} =
      Adapter.create_scheduled_export(
        scheduled_export_fixture(%{
          id: 1,
          public_id: "sched_run_denied",
          name: "Run Denied",
          snapshot_blob: snapshot_blob()
        }),
        []
      )

    socket = deny_capabilities_socket("Schedule runs are disabled.")

    socket = %{
      socket
      | assigns: Map.put(socket.assigns, :scheduled_exports, [scheduled_export])
    }

    assert {:noreply, updated_socket} =
             Manager.handle_event(
               "run_scheduled_export_now",
               %{"id" => "sched_run_denied"},
               socket
             )

    assert Phoenix.Flash.get(updated_socket.assigns.flash, :info) == "Scheduled export skipped"

    assert [%{status: :skipped, error_message: error_message}] =
             Adapter.list_scheduled_export_runs("sched_run_denied", [])

    assert error_message =~ "Schedule runs are disabled."
    assert updated_socket.assigns.run_results["sched_run_denied"].export == nil
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
      scheduled_export_delivery_adapter: DeliveryAdapter,
      scheduled_export_run_opts: [
        snapshot_runner: SnapshotRunner,
        delivery_opts: [notify: self()]
      ],
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

  defp deny_capabilities_socket(message) do
    %{
      base_socket()
      | assigns:
          Map.put(base_socket().assigns, :capability_resolver, fn request ->
            send(self(), {:capability_request, request})
            Selecto.Capabilities.deny(:scheduled_exports_disabled, user_message: message)
          end)
    }
  end

  defp scheduled_export_fixture(overrides) do
    %{
      id: 1,
      public_id: "sched_fixture",
      name: "Fixture Schedule",
      context: "tenant:1:/orders",
      view_type: "detail",
      export_format: "csv",
      snapshot_blob: snapshot_blob(),
      delivery: %{email: %{recipients: ["ops@example.com"]}},
      schedule: %{enabled: true, kind: :daily, time: "07:00", timezone: "Etc/UTC"},
      next_run_at: ~U[2026-04-02 07:00:00Z],
      last_status: :never,
      disabled_at: nil
    }
    |> Map.merge(overrides)
  end

  defp snapshot_blob do
    :erlang.term_to_binary(%{
      params: %{"view_mode" => "detail"},
      path: "/orders"
    })
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
