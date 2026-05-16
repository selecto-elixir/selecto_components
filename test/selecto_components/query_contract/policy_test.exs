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
