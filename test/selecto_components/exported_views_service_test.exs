defmodule SelectoComponents.ExportedViewsServiceTest do
  use ExUnit.Case, async: false

  @store SelectoComponents.ExportedViewsServiceTest.Store

  alias SelectoComponents.ExportedViews
  alias SelectoComponents.ExportedViews.Service
  alias SelectoComponents.ExportedViews.Token

  defmodule TestEndpoint do
    def config(:secret_key_base), do: String.duplicate("b", 64)
    def url, do: "https://example.test"
  end

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
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      view = Map.merge(%{inserted_at: now, updated_at: now}, attrs)
      Agent.update(store(), &Map.put(&1, attrs.public_id, view))
      {:ok, view}
    end

    def update_exported_view(view, attrs, _opts) do
      updated =
        Map.merge(
          view,
          Map.put(attrs, :updated_at, DateTime.utc_now() |> DateTime.truncate(:second))
        )

      Agent.update(store(), &Map.put(&1, ExportedViews.field(updated, :public_id), updated))
      {:ok, updated}
    end

    def delete_exported_view(view, _opts) do
      Agent.update(store(), &Map.delete(&1, ExportedViews.field(view, :public_id)))
      {:ok, view}
    end

    defp store, do: SelectoComponents.ExportedViewsServiceTest.Store
  end

  setup do
    start_supervised!(%{
      id: @store,
      start: {Agent, :start_link, [fn -> %{} end, [name: @store]]}
    })

    :ok
  end

  test "resolve_for_embed serves fresh cached payloads" do
    render_payload = %{
      selecto: %{},
      views: [],
      query_results: {[], [], []},
      view_meta: %{},
      applied_view: "detail",
      executed: true,
      execution_error: nil,
      last_query_info: %{},
      params: %{"view_mode" => "detail"},
      used_params: %{"view_mode" => "detail"}
    }

    {:ok, view} =
      Adapter.create_exported_view(
        %{
          public_id: "pub_fresh",
          name: "Fresh export",
          context: "/orders",
          signature_version: 1,
          cache_ttl_hours: 3,
          snapshot_blob: ExportedViews.encode_term(%{params: %{"view_mode" => "detail"}}),
          cache_blob: ExportedViews.encode_term(render_payload),
          cache_generated_at: ~U[2026-03-16 08:00:00Z],
          cache_expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second),
          access_count: 0,
          ip_allowlist_text: nil
        },
        []
      )

    token = Token.sign(view, endpoint: TestEndpoint)

    assert {:ok, updated_view, payload, :fresh} =
             Service.resolve_for_embed(Adapter, "pub_fresh", token, {127, 0, 0, 1},
               endpoint: TestEndpoint
             )

    assert payload.applied_view == "detail"
    assert ExportedViews.field(updated_view, :access_count) == 1
  end

  test "resolve_for_embed rejects disallowed IPs" do
    {:ok, view} =
      Adapter.create_exported_view(
        %{
          public_id: "pub_locked",
          name: "Locked export",
          context: "/orders",
          signature_version: 1,
          cache_ttl_hours: 3,
          snapshot_blob: ExportedViews.encode_term(%{params: %{"view_mode" => "detail"}}),
          cache_blob: ExportedViews.encode_term(%{}),
          cache_generated_at: ~U[2026-03-16 08:00:00Z],
          cache_expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second),
          access_count: 0,
          ip_allowlist_text: "10.0.0.0/24"
        },
        []
      )

    token = Token.sign(view, endpoint: TestEndpoint)

    assert {:error, :forbidden} =
             Service.resolve_for_embed(Adapter, "pub_locked", token, {127, 0, 0, 1},
               endpoint: TestEndpoint
             )
  end

  test "rotate_signature increments the stored version" do
    {:ok, view} =
      Adapter.create_exported_view(
        %{
          public_id: "pub_rotate",
          name: "Rotate export",
          context: "/orders",
          signature_version: 1,
          cache_ttl_hours: 3,
          snapshot_blob: ExportedViews.encode_term(%{params: %{"view_mode" => "detail"}}),
          cache_blob: nil
        },
        []
      )

    assert {:ok, updated_view} = Service.rotate_signature(Adapter, view)
    assert ExportedViews.field(updated_view, :signature_version) == 2
  end
end
