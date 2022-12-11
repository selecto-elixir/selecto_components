defmodule SelectoComponents.Helpers do
  def date_formats() do
    %{
      "MM-DD-YYYY HH:MM" => "MM-DD-YYYY HH:MM",
      "YYYY-MM-DD HH:MM" => "YYYY-MM-DD HH:MM"
    }
  end

  def view_param_process(params, item_name, section) do
    Map.get(params, item_name, %{})
    |> Enum.reduce([], fn {u, f}, acc -> acc ++ [{u, f[section], f}] end)
    |> Enum.sort(fn {_u, _s, %{"index" => index}}, {_u2, _s2, %{"index" => index2}} ->
      String.to_integer(index) <= String.to_integer(index2)
    end)
  end


  def build_initial_state(list) do
    list
    |> Enum.map(fn
      i when is_bitstring(i) -> {UUID.uuid4(), i, %{}}
      {i, conf} -> {UUID.uuid4(), i, conf}
    end)
  end

end
