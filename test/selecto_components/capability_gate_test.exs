defmodule SelectoComponents.CapabilityGateTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.CapabilityGate

  defmodule ModuleResolver do
    @behaviour Selecto.Capabilities.Resolver

    @impl true
    def decide(request, %{test_pid: test_pid}) do
      send(test_pid, {:module_gate_request, request})

      Selecto.Capabilities.deny(:module_gate_denied,
        user_message: "Module gate denied the operation."
      )
    end
  end

  test "authorizes through a module capability resolver" do
    socket = %{
      assigns: %{
        capability_actor: %{id: 7},
        capability_tenant: "tenant-1",
        capability_domain: :orders,
        capability_context: %{role: :analyst},
        path: "/orders",
        view_config: %{view_mode: "detail"}
      }
    }

    assert {:error, {:capability_denied, "Module gate denied the operation.", details}} =
             CapabilityGate.authorize(socket, "selecto.exports.csv", :export,
               resolver: ModuleResolver,
               resolver_context: %{test_pid: self()},
               target: %{format: "csv"}
             )

    assert_receive {:module_gate_request, request}
    assert request.actor == %{id: 7}
    assert request.tenant == "tenant-1"
    assert request.domain == :orders
    assert request.capability == "selecto.exports.csv"
    assert request.operation == :export
    assert request.target == %{format: "csv"}
    assert request.context.role == :analyst
    assert request.context.path == "/orders"
    assert request.context.view_mode == "detail"
    assert details["code"] == "module_gate_denied"
  end
end
