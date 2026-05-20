defmodule SelectoComponents.QueryContract.PolicyTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.QueryContract.Policy

  defmodule BatchPolicy do
    @behaviour Selecto.Capabilities.Resolver

    @impl true
    def decide(_request, _context), do: Selecto.Capabilities.allow(:single_path)

    @impl true
    def decide_many(requests, _context) do
      Enum.map(requests, fn request ->
        Selecto.Capabilities.deny(:batch_path,
          user_message: "Denied by batch for #{request.capability}."
        )
      end)
    end
  end

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

  test "merges field capability_target into capability request targets" do
    contract =
      update_in(contract().fields, fn fields ->
        Enum.map(fields, fn
          %{id: "private_metric"} = field ->
            Map.put(field, :capability_target, %{ash_resource: Example.Post, ash_action: :read})

          field ->
            field
        end)
      end)

    projected =
      Policy.apply(contract,
        capability_resolver: fn request ->
          if request.capability == "items.private_metric" do
            assert request.target.ash_resource == Example.Post
            assert request.target.ash_action == :read
          end

          Selecto.Capabilities.allow()
        end
      )

    assert field(projected, "private_metric").capability_decision["status"] == "enabled"
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
          functions: [],
          query_members: %{},
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

  test "projects functions and query members through capability policy" do
    projected =
      Policy.apply(
        %{
          fields: [],
          filters: [],
          functions: [
            %{id: "public_label", allowed_in: [:select]},
            %{
              id: "private_score",
              allowed_in: [:select, :order_by],
              capability: "items.analytics"
            },
            %{
              id: "internal_rank",
              allowed_in: [:select],
              capability: "items.internal_rank"
            }
          ],
          query_members: %{
            ctes: [
              %{id: "public_items", columns: [:id]},
              %{id: "private_items", columns: [:id], capability: "items.analytics"}
            ],
            values: [
              %{id: "internal_values", columns: [:id], capability: "items.internal_rank"}
            ]
          },
          published_views: [],
          context: %{}
        },
        capability_resolver: fn request ->
          case request.capability do
            "items.analytics" ->
              assert request.operation in [:query_function, :query_member]
              assert request.target.kind in [:function, :query_member]

              Selecto.Capabilities.deny(:manager_required,
                user_message: "Managers only."
              )

            "items.internal_rank" ->
              Selecto.Capabilities.hidden(:not_visible)

            _capability ->
              Selecto.Capabilities.allow()
          end
        end
      )

    assert Enum.find(projected.functions, &(&1.id == "public_label"))
    refute Enum.find(projected.functions, &(&1.id == "internal_rank"))

    assert %{
             disabled: true,
             allowed_in: [],
             capability_decision: %{
               "kind" => "function",
               "id" => "private_score",
               "capability" => "items.analytics",
               "status" => "disabled",
               "code" => :manager_required,
               "reason" => "Managers only."
             }
           } = Enum.find(projected.functions, &(&1.id == "private_score"))

    assert Enum.find(projected.query_members.ctes, &(&1.id == "public_items"))
    refute Enum.any?(projected.query_members.values, &(&1.id == "internal_values"))

    assert %{
             disabled: true,
             capability_decision: %{
               "kind" => "query_member",
               "group" => "ctes",
               "id" => "private_items",
               "capability" => "items.analytics",
               "status" => "disabled"
             }
           } = Enum.find(projected.query_members.ctes, &(&1.id == "private_items"))

    assert projected.capability_policy.counts == %{
             "enabled" => 0,
             "disabled" => 2,
             "hidden" => 2
           }
  end

  test "uses module batch resolvers for projected entries" do
    projected =
      Policy.apply(
        %{
          fields: [
            %{
              id: "private_metric",
              capability: "items.private_metric",
              detail_selectable: true,
              filterable: true,
              sortable: true,
              groupable: true,
              aggregatable: true,
              comparators: ["eq"],
              aggregate_functions: ["sum"]
            }
          ],
          filters: [],
          published_views: [],
          context: %{}
        },
        capability_resolver: BatchPolicy
      )

    assert %{
             disabled: true,
             capability_decision: %{
               "status" => "disabled",
               "code" => :batch_path,
               "reason" => "Denied by batch for items.private_metric."
             }
           } = field(projected, "private_metric")
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

  test "applies top-level choice source decisions to bound fields without form metadata" do
    projected =
      Policy.apply(
        %{
          fields: [
            %{
              id: "customer_id",
              choice_source: "customer_choices",
              detail_selectable: true,
              filterable: true,
              sortable: true,
              groupable: true,
              aggregatable: true,
              comparators: ["eq"],
              aggregate_functions: ["count"]
            }
          ],
          choice_sources: [
            %{id: "customer_choices", capability: "customer.choose"}
          ],
          filters: [],
          published_views: [],
          context: %{}
        },
        capability_resolver: fn _request ->
          Selecto.Capabilities.deny(:manager_required,
            user_message: "Managers choose customers."
          )
        end
      )

    assert %{
             disabled: true,
             detail_selectable: false,
             filterable: false,
             comparators: [],
             capability_decision: %{
               "kind" => "choice_source",
               "id" => "customer_choices",
               "status" => "disabled",
               "reason" => "Managers choose customers."
             }
           } = field(projected, "customer_id")
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
