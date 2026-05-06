defmodule SelectoComponents.Form.ChoiceSourceLiveTest do
  use ExUnit.Case, async: true

  alias Selecto.Domain.Choices
  alias Selecto.Domain.Choices.{OptionsRequest, Request}

  defmodule TestLive do
    use Phoenix.LiveView
    use SelectoComponents.Form.EventHandlers.ChoiceSourceOperations
  end

  test "resolves options over LiveView with socket-owned scope and domain filters" do
    test_pid = self()
    actor = %{id: 7, email: "analyst@example.test"}
    doi_filters = [{"f1", "filters", %{"filter" => "status", "comp" => "=", "value" => "open"}}]

    options_resolver = fn %OptionsRequest{} = request ->
      send(test_pid, {:options_request, request})

      Choices.options_resolved([%{value: 42, label: "Acme Camps"}],
        metadata: %{source: :fixture}
      )
    end

    socket =
      socket(%{
        choice_source_domain: domain(),
        choice_source_options_resolver: options_resolver,
        choice_source_scope: %{
          actor: actor,
          tenant: "tenant-from-socket",
          context: %{scope: :trusted},
          metadata: %{scope: :trusted}
        },
        view_config: %{filters: doi_filters}
      })

    {:reply, reply, ^socket} =
      TestLive.handle_event(
        "selecto_choice_source_options",
        %{
          "choice_source" => "customer_choices",
          "search" => " acme ",
          "limit" => "5",
          "tenant" => "spoofed"
        },
        socket
      )

    assert reply["status"] == "resolved"
    assert [%{"value" => 42, "label" => "Acme Camps"}] = reply["options"]
    assert reply["metadata"] == %{"source" => "fixture"}

    assert_receive {:options_request, request}
    assert request.choice_source == "customer_choices"
    assert request.search == "acme"
    assert request.limit == 5
    assert request.tenant == "tenant-from-socket"
    assert request.actor == actor
    assert request.filters == doi_filters

    assert request.constraint_filters == %{
             source_relationship: [{:eq, "customers.active", true}],
             choice_source: [["eq", "customers.available", true]],
             domain_of_interest: doi_filters
           }

    assert request.context.scope == :trusted
    assert request.context.transport == :live_view
    assert request.metadata.scope == :trusted
    assert request.metadata.transport == :live_view
  end

  test "validates membership over LiveView with parser and field/source match" do
    test_pid = self()
    doi_filters = [{"f1", "filters", %{"filter" => "status", "comp" => "=", "value" => "open"}}]

    membership_resolver = fn %Request{} = request ->
      send(test_pid, {:membership_request, request})
      Choices.valid(:fixture_member, metadata: %{label: "Acme Camps"})
    end

    value_parser = fn value, _context ->
      {integer, ""} = Integer.parse(value)
      {:ok, integer}
    end

    socket =
      socket(%{
        choice_source_domain: domain(),
        choice_source_membership_resolver: membership_resolver,
        choice_source_value_parser: value_parser,
        choice_source_scope: %{tenant: "tenant-from-socket"},
        view_config: %{filters: doi_filters}
      })

    {:reply, reply, ^socket} =
      TestLive.handle_event(
        "selecto_choice_source_validate",
        %{
          "choice_source" => "customer_choices",
          "field" => "customer_id",
          "value" => "42"
        },
        socket
      )

    assert reply["status"] == "valid"
    assert reply["valid"] == true
    assert reply["label"] == "Acme Camps"

    assert_receive {:membership_request, request}
    assert request.choice_source == :customer_choices
    assert request.field == "customer_id"
    assert request.value == 42
    assert request.tenant == "tenant-from-socket"
    assert request.filters == doi_filters

    assert request.constraint_filters == %{
             source_relationship: [{:eq, "customers.active", true}],
             choice_source: [["eq", "customers.available", true]],
             domain_of_interest: doi_filters
           }
  end

  test "rejects membership validation when field is bound to a different choice source" do
    socket =
      socket(%{
        choice_source_domain: domain(),
        choice_source_membership_resolver: fn _request -> Choices.valid(:fixture_member) end
      })

    {:reply, reply, ^socket} =
      TestLive.handle_event(
        "selecto_choice_source_validate",
        %{
          "choice_source" => "other_choices",
          "field" => "customer_id",
          "value" => "42"
        },
        socket
      )

    assert reply["status"] == "error"
    assert reply["error"]["code"] == "choice_source_field_mismatch"
  end

  defp socket(assigns) do
    %Phoenix.LiveView.Socket{assigns: Map.put(assigns, :__changed__, %{})}
  end

  defp domain do
    %{
      schema_version: 1,
      name: :orders,
      source: valid_source(),
      schemas: %{
        customers: %{
          source_table: "customers",
          primary_key: :id,
          fields: [:id, :name],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        }
      },
      joins: %{customer: %{type: :left}},
      source_relationships: %{
        customer: %{
          target_domain: :customers,
          source_field: :customer_id,
          target_field: :id,
          filters: [{:eq, "customers.active", true}]
        }
      },
      choice_sources: %{
        customer_choices: %{
          domain: :customers,
          value_field: :id,
          label_field: :name,
          source_relationship: :customer,
          filters: [["eq", "customers.available", true]]
        },
        other_choices: %{
          domain: :customers,
          value_field: :id,
          label_field: :name
        }
      }
    }
  end

  defp valid_source do
    %{
      source_table: "orders",
      primary_key: :id,
      fields: [:id, :status, :customer_id, :customer_name],
      columns: %{
        id: %{type: :integer},
        status: %{type: :string},
        customer_id: %{
          type: :integer,
          reference: %{
            choice_source: :customer_choices,
            value_source: "customers.id",
            caption_source: "customers.name",
            caption_field: :customer_name
          }
        },
        customer_name: %{type: :string}
      },
      associations: %{
        customer: %{
          queryable: :customers,
          field: :customer,
          owner_key: :customer_id,
          related_key: :id
        }
      }
    }
  end
end
