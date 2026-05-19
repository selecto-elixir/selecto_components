defmodule SelectoComponents.QueryContract.PolicyTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.QueryContract.Policy

  test "keeps allowed fields and disables denied fields" do
    contract = contract()

    projected =
      Policy.apply(contract,
        actor: %{role: :analyst},
        capability_resolver: fn request ->
          case request.capability do
            "items.private_metric" ->
              Selecto.Capabilities.deny(:analyst_blocked,
                user_message: "Analysts cannot use private metrics."
              )

            _capability ->
              Selecto.Capabilities.allow()
          end
        end
      )

    assert field(projected, "name").detail_selectable == true

    assert %{
             detail_selectable: false,
             filterable: false,
             sortable: false,
             groupable: false,
             aggregatable: false,
             comparators: [],
             aggregate_functions: [],
             disabled: true,
             capability_decision: %{
               "status" => "disabled",
               "code" => :analyst_blocked,
               "reason" => "Analysts cannot use private metrics."
             }
           } = field(projected, "private_metric")

    assert projected.capability_policy.counts == %{
             "enabled" => 3,
             "disabled" => 1,
             "hidden" => 0
           }
  end

  test "disables string-keyed field and filter surfaces" do
    projected =
      Policy.apply(string_keyed_contract(),
        capability_resolver: fn _request ->
          Selecto.Capabilities.deny(:blocked, user_message: "Blocked")
        end
      )

    assert %{
             "detail_selectable" => false,
             "filterable" => false,
             "sortable" => false,
             "groupable" => false,
             "aggregatable" => false,
             "comparators" => [],
             "aggregate_functions" => [],
             "disabled" => true,
             "capability_decision" => %{"status" => "disabled"}
           } = field(projected, "private_metric")

    assert %{
             "comparators" => [],
             "disabled" => true,
             "capability_decision" => %{"status" => "disabled"}
           } = Enum.find(projected.filters, &(&1["id"] == "private_filter"))
  end

  test "removes hidden fields, filters, bindings, and defaults" do
    contract = contract()

    projected =
      Policy.apply(contract,
        capability_resolver: fn request ->
          case request.capability do
            "items.private_metric" -> Selecto.Capabilities.hidden(:not_visible)
            "items.private_filter" -> Selecto.Capabilities.hidden(:not_visible)
            _capability -> Selecto.Capabilities.allow()
          end
        end
      )

    refute field(projected, "private_metric")
    refute Enum.any?(projected.filters, &(&1.id == "private_filter"))
    refute Enum.any?(projected.field_choice_bindings, &(&1.field == "private_metric"))
    refute "private_metric" in projected.defaults.default_selected
    refute "private_filter" in projected.defaults.required_filters

    assert projected.capability_policy.counts == %{
             "enabled" => 2,
             "disabled" => 0,
             "hidden" => 2
           }
  end

  test "projects published views through capability policy" do
    projected =
      Policy.apply(
        %{
          fields: [],
          filters: [],
          published_views: [
            %{id: "public_rollup", kind: :view},
            %{id: "manager_rollup", kind: :view, capability: "items.analytics"}
          ],
          context: %{}
        },
        capability_resolver: fn request ->
          assert request.operation == :published_view
          assert request.target.kind == :published_view

          Selecto.Capabilities.deny(:manager_required,
            user_message: "Managers only."
          )
        end
      )

    assert Enum.find(projected.published_views, &(&1.id == "public_rollup"))

    assert %{
             disabled: true,
             capability_decision: %{
               "status" => "disabled",
               "code" => :manager_required,
               "reason" => "Managers only."
             }
           } = Enum.find(projected.published_views, &(&1.id == "manager_rollup"))

    assert projected.capability_policy.counts == %{
             "enabled" => 0,
             "disabled" => 1,
             "hidden" => 0
           }
  end

  test "disables fields whose choice source capability is denied" do
    projected =
      Policy.apply(
        %{
          fields: [
            %{
              id: "customer_id",
              detail_selectable: true,
              filterable: true,
              sortable: true,
              groupable: true,
              aggregatable: true,
              comparators: ["eq"],
              aggregate_functions: ["count"],
              choice_source: "customer_choices",
              choice_source_metadata: %{
                id: "customer_choices",
                field: "customer_id",
                capability: "customer.choose"
              }
            }
          ],
          choice_sources: [
            %{id: "customer_choices", capability: "customer.choose"}
          ],
          filters: [],
          field_choice_bindings: [
            %{field: "customer_id", choice_source: "customer_choices"}
          ],
          published_views: [],
          context: %{}
        },
        capability_resolver: fn request ->
          assert request.operation == :choice_source
          assert request.target.kind == :choice_source
          assert request.target.id == "customer_choices"

          Selecto.Capabilities.deny(:manager_required,
            user_message: "Managers choose customers."
          )
        end
      )

    assert %{
             disabled: true,
             detail_selectable: false,
             filterable: false,
             sortable: false,
             groupable: false,
             aggregatable: false,
             comparators: [],
             aggregate_functions: [],
             capability_decision: %{
               "kind" => "choice_source",
               "id" => "customer_choices",
               "capability" => "customer.choose",
               "status" => "disabled",
               "code" => :manager_required,
               "reason" => "Managers choose customers."
             },
             choice_source_metadata: %{
               disabled: true,
               capability_decision: %{
                 "kind" => "choice_source",
                 "id" => "customer_choices",
                 "status" => "disabled"
               }
             }
           } = field(projected, "customer_id")

    assert %{
             disabled: true,
             capability_decision: %{
               "kind" => "choice_source",
               "id" => "customer_choices",
               "status" => "disabled"
             }
           } = Enum.find(projected.choice_sources, &(&1.id == "customer_choices"))

    assert [%{field: "customer_id"}] = projected.field_choice_bindings

    assert projected.capability_policy.counts == %{
             "enabled" => 0,
             "disabled" => 1,
             "hidden" => 0
           }
  end

  test "removes fields and bindings whose choice source capability is hidden" do
    projected =
      Policy.apply(
        %{
          fields: [
            %{
              id: "customer_id",
              choice_source_metadata: %{
                id: "customer_choices",
                field: "customer_id",
                capability: "customer.choose"
              }
            }
          ],
          choice_sources: [
            %{id: "customer_choices", capability: "customer.choose"}
          ],
          filters: [],
          field_choice_bindings: [
            %{field: "customer_id", choice_source: "customer_choices"}
          ],
          defaults: %{default_selected: ["customer_id"]},
          published_views: [],
          context: %{}
        },
        capability_resolver: fn _request ->
          Selecto.Capabilities.hidden(:not_visible)
        end
      )

    refute field(projected, "customer_id")
    assert projected.choice_sources == []
    assert projected.field_choice_bindings == []
    assert projected.defaults.default_selected == []

    assert projected.capability_policy.counts == %{
             "enabled" => 0,
             "disabled" => 0,
             "hidden" => 1
           }
  end

  test "removes denied exports and disables denied share surfaces from context" do
    projected =
      Policy.apply(
        %{
          fields: [],
          filters: [],
          published_views: [],
          context: %{
            exports: [:csv, :xlsx],
            exported_views_enabled: true,
            scheduled_exports_enabled: true
          }
        },
        capability_resolver: fn request ->
          case {request.capability, request.target} do
            {"selecto.exports.download", %{format: "xlsx"}} ->
              Selecto.Capabilities.deny(:format_blocked,
                user_message: "XLSX exports are disabled."
              )

            {"selecto.scheduled_exports.manage", _target} ->
              Selecto.Capabilities.deny(:schedule_blocked,
                user_message: "Schedules are disabled."
              )

            _allowed ->
              Selecto.Capabilities.allow()
          end
        end
      )

    assert projected.context.exports == [:csv]
    assert projected.context.exported_views_enabled == true
    assert projected.context.scheduled_exports_enabled == false

    assert Enum.any?(
             projected.capability_policy.decisions,
             &match?(
               %{
                 "kind" => "exports",
                 "id" => "xlsx",
                 "capability" => "selecto.exports.download",
                 "status" => "disabled"
               },
               &1
             )
           )

    assert projected.capability_policy.counts == %{
             "enabled" => 2,
             "disabled" => 2,
             "hidden" => 0
           }
  end

  defp field(contract, id),
    do: Enum.find(contract.fields, &(Map.get(&1, :id, Map.get(&1, "id")) == id))

  defp contract do
    %{
      fields: [
        %{
          id: "name",
          capability: "items.read",
          detail_selectable: true,
          filterable: true,
          sortable: true,
          groupable: true,
          aggregatable: false,
          comparators: ["eq", "contains"],
          aggregate_functions: []
        },
        %{
          id: "private_metric",
          capability: "items.private_metric",
          detail_selectable: true,
          filterable: true,
          sortable: true,
          groupable: true,
          aggregatable: true,
          comparators: ["eq", "gt"],
          aggregate_functions: ["sum"]
        }
      ],
      filters: [
        %{id: "name", field: "name", capability: "items.read", comparators: ["eq"]},
        %{
          id: "private_filter",
          field: "private_metric",
          capability: "items.private_filter",
          comparators: ["eq"]
        }
      ],
      field_choice_bindings: [
        %{field: "private_metric", choice_source: "private_choices"}
      ],
      defaults: %{
        default_selected: ["name", "private_metric"],
        required_selected: ["private_metric"],
        required_group_by: ["private_metric"],
        required_order_by: [%{field: "private_metric", dir: "asc"}],
        required_filters: ["private_filter"]
      }
    }
  end

  defp string_keyed_contract do
    %{
      fields: [
        %{
          "id" => "private_metric",
          "capability" => "items.private_metric",
          "detail_selectable" => true,
          "filterable" => true,
          "sortable" => true,
          "groupable" => true,
          "aggregatable" => true,
          "comparators" => ["eq", "gt"],
          "aggregate_functions" => ["sum"]
        }
      ],
      filters: [
        %{
          "id" => "private_filter",
          "field" => "private_metric",
          "capability" => "items.private_filter",
          "comparators" => ["eq"]
        }
      ]
    }
  end
end
