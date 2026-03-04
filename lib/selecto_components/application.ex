defmodule SelectoComponents.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: SelectoComponents.TaskSupervisor},
      {SelectoComponents.Performance.MetricsCollector, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: SelectoComponents.Supervisor)
  end
end
