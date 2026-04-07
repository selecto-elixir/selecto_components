defmodule SelectoComponents.ScheduledExportsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.ExportSnapshots
  alias SelectoComponents.ScheduledExports

  test "build_create_attrs snapshots current view state and normalizes delivery and schedule" do
    assigns = %{
      selecto: %{
        domain: %{name: "orders"},
        postgrex_opts: [hostname: "db", username: "demo", password: "secret"],
        adapter: Selecto.DB.PostgreSQL
      },
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        views: %{aggregate: %{selected: []}}
      },
      views: [{:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", %{}}],
      path: "/orders",
      saved_view_context: "tenant:1:/orders",
      current_user_id: "7",
      tenant_context: %{tenant_id: 1}
    }

    attrs =
      ScheduledExports.build_create_attrs(assigns, %{
        "name" => "Weekly Orders",
        "export_format" => "xlsx",
        "recipients" => "ops@example.com, finance@example.com\nops@example.com",
        "subject_template" => "Weekly order export",
        "body_template" => "Attached is the latest weekly export.",
        "schedule" => %{
          "enabled" => "true",
          "kind" => "weekly",
          "day_of_week" => "1",
          "time" => "07:00",
          "timezone" => "Etc/UTC"
        }
      })

    assert attrs.name == "Weekly Orders"
    assert attrs.context == "tenant:1:/orders"
    assert attrs.path == "/orders"
    assert attrs.view_type == "aggregate"
    assert attrs.export_format == "xlsx"
    assert attrs.last_status == :never
    assert attrs.user_id == "7"
    assert attrs.tenant_context == %{tenant_id: 1}
    assert is_binary(attrs.public_id)
    assert %DateTime{} = attrs.next_run_at

    assert attrs.delivery == %{
             channel: :email,
             email: %{
               recipients: ["ops@example.com", "finance@example.com"],
               cc: [],
               bcc: [],
               subject_template: "Weekly order export",
               body_template: "Attached is the latest weekly export."
             }
           }

    assert attrs.schedule == %{
             enabled: true,
             kind: :weekly,
             timezone: "Etc/UTC",
             time: "07:00",
             day_of_week: 1,
             day_of_month: 1
           }

    assert {:ok, snapshot} = ExportSnapshots.decode_term(attrs.snapshot_blob)
    assert snapshot.params["view_mode"] == "aggregate"
    assert snapshot.context == "tenant:1:/orders"
    assert snapshot.tenant_context == %{tenant_id: 1}
    refute Keyword.has_key?(snapshot.postgrex_opts, :password)
  end

  test "build_run_attrs normalizes run metadata" do
    scheduled_export = %{id: 42, public_id: "pub_123"}

    attrs =
      ScheduledExports.build_run_attrs(scheduled_export, :manual_email, %{
        status: :ok,
        row_count: 120,
        payload_bytes: 2048,
        execution_time_ms: 88,
        delivery_count: 2,
        error_message: ""
      })

    assert attrs.scheduled_export_id == 42
    assert attrs.scheduled_export_public_id == "pub_123"
    assert attrs.trigger_type == :manual_email
    assert attrs.status == :ok
    assert attrs.row_count == 120
    assert attrs.payload_bytes == 2048
    assert attrs.execution_time_ms == 88
    assert attrs.delivery_count == 2
    assert is_nil(attrs.error_message)
    assert %DateTime{} = attrs.started_at
  end

  test "next_run_at computes daily weekly and monthly UTC schedules" do
    now = ~U[2026-04-01 08:30:00Z]

    assert ScheduledExports.next_run_at(
             %{enabled: true, kind: :daily, time: "09:00", timezone: "Etc/UTC"},
             now
           ) ==
             ~U[2026-04-01 09:00:00Z]

    assert ScheduledExports.next_run_at(
             %{enabled: true, kind: :weekly, day_of_week: 5, time: "07:00", timezone: "Etc/UTC"},
             now
           ) ==
             ~U[2026-04-03 07:00:00Z]

    assert ScheduledExports.next_run_at(
             %{
               enabled: true,
               kind: :monthly,
               day_of_month: 15,
               time: "07:00",
               timezone: "Etc/UTC"
             },
             now
           ) ==
             ~U[2026-04-15 07:00:00Z]
  end
end
