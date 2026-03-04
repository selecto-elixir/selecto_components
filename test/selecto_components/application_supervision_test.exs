defmodule SelectoComponents.ApplicationSupervisionTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Performance.MetricsCollector

  test "application boots supervised runtime children" do
    assert is_pid(Process.whereis(SelectoComponents.Supervisor))
    assert is_pid(Process.whereis(SelectoComponents.TaskSupervisor))
    assert is_pid(Process.whereis(MetricsCollector))
  end

  test "metrics collector remains callable when started by application" do
    MetricsCollector.clear_metrics()
    MetricsCollector.record_query("select 1", 10)

    metrics = MetricsCollector.get_metrics("1h")
    assert metrics.total_queries == 1
  end
end
