defmodule SelectoComponents.ScheduledExportsServiceTest do
  use ExUnit.Case, async: false

  @export_store SelectoComponents.ScheduledExportsServiceTest.ExportStore
  @run_store SelectoComponents.ScheduledExportsServiceTest.RunStore

  alias SelectoComponents.ScheduledExports
  alias SelectoComponents.ScheduledExports.Service

  defmodule Adapter do
    @behaviour SelectoComponents.ScheduledExports

    def list_scheduled_exports(context, _opts) do
      store()
      |> Agent.get(&Map.values(&1))
      |> Enum.filter(fn export -> ScheduledExports.field(export, :context) == context end)
    end

    def get_scheduled_export_by_public_id(public_id, _opts) do
      Agent.get(store(), &Map.get(&1, public_id))
    end

    def create_scheduled_export(attrs, _opts) do
      export = Map.put_new(attrs, :id, System.unique_integer([:positive]))
      Agent.update(store(), &Map.put(&1, attrs.public_id, export))
      {:ok, export}
    end

    def update_scheduled_export(export, attrs, _opts) do
      updated = Map.merge(export, attrs)
      Agent.update(store(), &Map.put(&1, ScheduledExports.field(updated, :public_id), updated))
      {:ok, updated}
    end

    def delete_scheduled_export(export, _opts) do
      Agent.update(store(), &Map.delete(&1, ScheduledExports.field(export, :public_id)))
      {:ok, export}
    end

    def create_scheduled_export_run(attrs, _opts) do
      run = Map.put_new(attrs, :id, System.unique_integer([:positive]))
      Agent.update(run_store(), &Map.put(&1, run.id, run))
      {:ok, run}
    end

    def update_scheduled_export_run(run, attrs, _opts) do
      updated = Map.merge(run, attrs)
      Agent.update(run_store(), &Map.put(&1, updated.id, updated))
      {:ok, updated}
    end

    def due_scheduled_exports(now, _opts) do
      store()
      |> Agent.get(&Map.values(&1))
      |> Enum.filter(fn export ->
        case ScheduledExports.field(export, :next_run_at) do
          %DateTime{} = next_run -> DateTime.compare(next_run, now) != :gt
          _ -> false
        end
      end)
    end

    defp store, do: SelectoComponents.ScheduledExportsServiceTest.ExportStore
    defp run_store, do: SelectoComponents.ScheduledExportsServiceTest.RunStore
  end

  defmodule DeliveryAdapter do
    @behaviour SelectoComponents.ExportDelivery

    def deliver_email(export_payload, delivery_config, opts) do
      if notify = Keyword.get(opts, :notify) do
        send(notify, {:deliver_email, export_payload, delivery_config})
      end

      {:ok, %{message_id: "msg_123"}}
    end
  end

  defmodule SnapshotRunner do
    def render_snapshot(snapshot, _opts) do
      send(self(), {:render_snapshot, snapshot})

      {:ok,
       %{
         selecto: %{},
         views: [],
         query_results: {
           [["Order A", 10], ["Order B", 12]],
           ["title", "quantity"],
           []
         },
         view_meta: %{},
         applied_view: Map.get(snapshot.params, "view_mode", "detail"),
         executed: true,
         execution_error: nil,
         last_query_info: %{timing: 25},
         params: snapshot.params,
         used_params: snapshot.params
       }, %{row_count: 2, payload_bytes: 512, execution_time_ms: 25}}
    end
  end

  defmodule FailingSnapshotRunner do
    def render_snapshot(_snapshot, _opts), do: {:error, :query_failed}
  end

  setup do
    start_supervised!(%{
      id: @export_store,
      start: {Agent, :start_link, [fn -> %{} end, [name: @export_store]]}
    })

    start_supervised!(%{
      id: @run_store,
      start: {Agent, :start_link, [fn -> %{} end, [name: @run_store]]}
    })

    :ok
  end

  test "create list due and create_run use the scheduled export adapter" do
    assigns = %{
      selecto: %{domain: %{name: "orders"}, postgrex_opts: [], adapter: Selecto.DB.PostgreSQL},
      view_config: %{view_mode: "detail", filters: [], views: %{detail: %{selected: []}}},
      views: [{:detail, SelectoComponents.Views.Detail, "Detail", %{}}],
      path: "/orders",
      saved_view_context: "tenant:1:/orders",
      current_user_id: "9",
      tenant_context: %{tenant_id: 1}
    }

    {:ok, export} =
      Service.create(Adapter, assigns, %{
        "name" => "Morning orders",
        "recipients" => ["ops@example.com"],
        "schedule" => %{
          "enabled" => true,
          "kind" => "daily",
          "time" => "06:00",
          "timezone" => "Etc/UTC"
        }
      })

    assert [listed] = Service.list(Adapter, "tenant:1:/orders")
    assert listed.public_id == export.public_id

    due_now = DateTime.add(export.next_run_at, 60, :second)
    assert [due_export] = Service.due(Adapter, due_now)
    assert due_export.public_id == export.public_id

    assert {:ok, run} = Service.create_run(Adapter, export, :scheduled, %{status: :running})
    assert run.scheduled_export_public_id == export.public_id
    assert run.status == :running
  end

  test "deliver_now builds an export attachment and calls the delivery adapter" do
    query_results = {
      [["Order A", 10], ["Order B", 12]],
      ["title", "quantity"],
      []
    }

    delivery = %{
      channel: :email,
      email: %{
        recipients: ["ops@example.com", "finance@example.com"],
        subject_template: "Daily orders",
        body_template: "Attached."
      }
    }

    assert {:ok, result} =
             Service.deliver_now(DeliveryAdapter, query_results, delivery,
               format: "csv",
               view_mode: "detail",
               path: "/orders",
               export_name: "Daily Orders",
               delivery_opts: [notify: self()]
             )

    assert result.export.mime_type == "text/csv;charset=utf-8"
    assert result.payload_bytes > 0

    assert_receive {:deliver_email, export_payload, delivery_config}
    assert export_payload.attachment.filename =~ ".csv"
    assert export_payload.path == "/orders"
    assert delivery_config.email.recipients == ["ops@example.com", "finance@example.com"]
  end

  test "deliver_now rejects invalid recipients and oversized payloads" do
    query_results = {[[String.duplicate("a", 64)]], ["value"], []}

    assert {:error, {:invalid_recipients, ["not-an-email"]}} =
             Service.deliver_now(DeliveryAdapter, query_results, %{
               channel: :email,
               email: %{recipients: ["not-an-email"]}
             })

    assert {:error, :payload_too_large} =
             Service.deliver_now(
               DeliveryAdapter,
               query_results,
               %{
                 channel: :email,
                 email: %{recipients: ["ops@example.com"]}
               },
               max_attachment_bytes: 8
             )
  end

  test "run_scheduled_export executes a saved snapshot and records run metadata" do
    assigns = %{
      selecto: %{domain: %{name: "orders"}, postgrex_opts: [], adapter: Selecto.DB.PostgreSQL},
      view_config: %{view_mode: "detail", filters: [], views: %{detail: %{selected: []}}},
      views: [{:detail, SelectoComponents.Views.Detail, "Detail", %{}}],
      path: "/orders",
      scheduled_export_context: "tenant:1:/orders",
      current_user_id: "9",
      tenant_context: %{tenant_id: 1}
    }

    {:ok, scheduled_export} =
      Service.create(Adapter, assigns, %{
        "name" => "Daily Orders",
        "export_format" => "csv",
        "recipients" => ["ops@example.com", "finance@example.com"],
        "schedule" => %{
          "enabled" => true,
          "kind" => "daily",
          "time" => "06:00",
          "timezone" => "Etc/UTC"
        }
      })

    assert {:ok, result} =
             Service.run_scheduled_export(Adapter, scheduled_export.public_id,
               delivery_adapter: DeliveryAdapter,
               snapshot_runner: SnapshotRunner,
               delivery_opts: [notify: self()]
             )

    assert_receive {:render_snapshot, snapshot}
    assert snapshot.context == "tenant:1:/orders"
    assert_receive {:deliver_email, export_payload, _delivery_config}
    assert export_payload.attachment.filename =~ ".csv"

    assert result.payload_bytes > 0
    assert result.row_count == 2
    assert result.execution_time_ms == 25
    assert result.run.status == :ok

    updated_export = Adapter.get_scheduled_export_by_public_id(scheduled_export.public_id, [])
    assert updated_export.last_status == :ok
    assert is_nil(updated_export.last_error)
    assert %DateTime{} = updated_export.last_run_at
    assert %DateTime{} = updated_export.next_run_at

    runs = Agent.get(@run_store, &Map.values(&1))
    assert length(runs) == 1
    [run] = runs
    assert run.status == :ok
    assert run.delivery_count == 2
    assert run.row_count == 2
  end

  test "run_scheduled_export records failures on the run and definition" do
    assigns = %{
      selecto: %{domain: %{name: "orders"}, postgrex_opts: [], adapter: Selecto.DB.PostgreSQL},
      view_config: %{view_mode: "detail", filters: [], views: %{detail: %{selected: []}}},
      views: [{:detail, SelectoComponents.Views.Detail, "Detail", %{}}],
      path: "/orders",
      scheduled_export_context: "tenant:1:/orders",
      current_user_id: "9",
      tenant_context: %{tenant_id: 1}
    }

    {:ok, scheduled_export} =
      Service.create(Adapter, assigns, %{
        "name" => "Broken Orders",
        "export_format" => "csv",
        "recipients" => ["ops@example.com"],
        "schedule" => %{
          "enabled" => true,
          "kind" => "daily",
          "time" => "06:00",
          "timezone" => "Etc/UTC"
        }
      })

    assert {:error, :query_failed} =
             Service.run_scheduled_export(Adapter, scheduled_export,
               delivery_adapter: DeliveryAdapter,
               snapshot_runner: FailingSnapshotRunner
             )

    updated_export = Adapter.get_scheduled_export_by_public_id(scheduled_export.public_id, [])
    assert updated_export.last_status == :failed
    assert updated_export.last_error == ":query_failed"

    runs = Agent.get(@run_store, &Map.values(&1)) |> Enum.sort_by(& &1.id)
    assert length(runs) == 1
    [run] = runs
    assert run.status == :failed
    assert run.error_message == ":query_failed"
  end
end
