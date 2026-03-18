defmodule SelectoComponents.DBSupport do
  @moduledoc false

  alias Selecto.Executor

  @database_error_module_suffixes [
    "Postgrex.Error",
    "MyXQL.Error",
    "Tds.Error",
    "Exqlite.Error",
    "Duckdbex.Error"
  ]

  @postgres_recoverable_codes ["23505", "23503", "23502"]

  def adapter(selecto) when is_map(selecto) do
    Map.get(selecto, :adapter) || Selecto.AdapterSupport.default_adapter()
  end

  def supports_feature?(selecto, feature) when is_atom(feature) do
    Selecto.AdapterSupport.supports_feature?(adapter(selecto), feature)
  end

  def bounded_count_uses_top?(selecto) do
    supports_feature?(selecto, :bounded_count_top) or adapter_name(selecto) == :mssql
  end

  def requires_derived_table_column_aliases?(selecto) do
    supports_feature?(selecto, :derived_table_column_aliases) or adapter_name(selecto) == :mssql
  end

  def execute_raw_query(selecto, query, params, aliases \\ []) do
    current_adapter = adapter(selecto)
    connection = Map.get(selecto, :connection, Map.get(selecto, :postgrex_opts))

    cond do
      Selecto.AdapterSupport.callback_available?(current_adapter, :execute_raw, 3) ->
        execute_with_adapter_raw(current_adapter, connection, query, params, aliases)

      not is_nil(Map.get(selecto, :adapter)) ->
        Executor.execute_with_adapter(current_adapter, connection, query, params, aliases)

      ecto_repo?(Map.get(selecto, :postgrex_opts)) ->
        Executor.execute_with_ecto_repo(Map.get(selecto, :postgrex_opts), query, params, aliases)

      true ->
        Executor.execute_with_postgrex(Map.get(selecto, :postgrex_opts), query, params, aliases)
    end
  end

  def database_error?(error) do
    is_map(error) and
      (is_map(Map.get(error, :postgres)) or is_map(Map.get(error, :mysql)) or
         database_error_module?(Map.get(error, :__struct__)))
  end

  def database_error_details(error) do
    cond do
      is_map(Map.get(error, :postgres)) -> Map.get(error, :postgres)
      is_binary(Map.get(error, :message)) -> %{message: Map.get(error, :message)}
      true -> nil
    end
  end

  def database_error_recoverable?(error) do
    case database_error_code(error) do
      code when code in @postgres_recoverable_codes -> true
      _ -> false
    end
  end

  def format_database_error(error) do
    details = database_error_details(error) || %{}

    cond do
      details[:code] == "23505" and is_binary(details[:constraint]) ->
        "Duplicate value violates uniqueness constraint: #{details.constraint}"

      details[:code] == "23503" and is_binary(details[:constraint]) ->
        "Foreign key constraint violation: #{details.constraint}"

      details[:code] == "23502" and is_binary(details[:column]) ->
        "Required field '#{details.column}' cannot be empty"

      is_binary(details[:message]) ->
        "Database error: #{details.message}"

      is_binary(Map.get(error, :message)) ->
        "Database error: #{Map.get(error, :message)}"

      true ->
        "Database error"
    end
  end

  defp adapter_name(selecto) do
    selecto
    |> adapter()
    |> Selecto.AdapterSupport.adapter_name()
  end

  defp execute_with_adapter_raw(adapter, connection, query, params, aliases) do
    case adapter.execute_raw(connection, query, params) do
      {:ok, result} ->
        {:ok, {Map.get(result, :rows, []), Map.get(result, :columns, []), aliases}}

      {:error, %Selecto.Error{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error, Selecto.Error.from_reason(reason)}
    end
  rescue
    error ->
      {:error,
       Selecto.Error.connection_error("Adapter raw execution failed", %{
         adapter: adapter,
         connection: inspect(connection),
         error: inspect(error)
       })}
  catch
    :exit, reason ->
      {:error,
       Selecto.Error.connection_error("Adapter raw connection failed", %{
         adapter: adapter,
         exit_reason: reason
       })}
  end

  defp ecto_repo?(repo) when is_atom(repo) do
    Code.ensure_loaded?(repo) and function_exported?(repo, :__adapter__, 0)
  end

  defp ecto_repo?(_repo), do: false

  defp database_error_module?(module) when is_atom(module) do
    rendered = inspect(module)
    Enum.any?(@database_error_module_suffixes, &String.ends_with?(rendered, &1))
  end

  defp database_error_module?(_module), do: false

  defp database_error_code(error) do
    case database_error_details(error) do
      %{code: code} when is_binary(code) -> code
      _ -> nil
    end
  end
end
