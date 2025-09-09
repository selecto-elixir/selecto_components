defmodule SelectoComponents.Debug.ConfigReader do
  @moduledoc """
  Reads and manages debug configuration from domain modules.
  Provides a centralized way to control debug information display.
  """

  @default_config %{
    enabled: false,
    show_query: false,
    show_params: false,
    show_timing: false,
    show_row_count: false,
    show_execution_plan: false,
    format_sql: true,
    max_param_length: 100,
    views: %{
      aggregate: %{
        show_query: true,
        show_timing: true
      },
      detail: %{
        show_query: true,
        show_row_count: true
      },
      graph: %{
        show_query: false,
        show_timing: true
      }
    }
  }

  @doc """
  Gets the debug configuration for a domain.
  Falls back to defaults if domain doesn't implement debug_config/0.
  """
  @spec get_config(module() | nil) :: map()
  def get_config(nil), do: get_default_config()
  
  def get_config(domain_module) when is_atom(domain_module) do
    if function_exported?(domain_module, :debug_config, 0) do
      domain_config = domain_module.debug_config()
      merge_with_defaults(domain_config)
    else
      get_default_config()
    end
  rescue
    _ -> get_default_config()
  end

  @doc """
  Gets configuration for a specific view type.
  """
  @spec get_view_config(module() | nil, atom()) :: map()
  def get_view_config(domain_module, view_type) do
    config = get_config(domain_module)
    view_config = get_in(config, [:views, view_type]) || %{}
    
    # Merge view-specific config with base config
    Map.merge(config, view_config)
    |> Map.delete(:views)
  end

  @doc """
  Checks if debug is enabled for a domain and optional view type.
  """
  @spec debug_enabled?(module() | nil, atom() | nil) :: boolean()
  def debug_enabled?(domain_module, view_type \\ nil) do
    config = if view_type do
      get_view_config(domain_module, view_type)
    else
      get_config(domain_module)
    end
    
    Map.get(config, :enabled, false) && dev_mode?()
  end

  @doc """
  Checks if a specific debug feature is enabled.
  """
  @spec feature_enabled?(module() | nil, atom(), atom() | nil) :: boolean()
  def feature_enabled?(domain_module, feature, view_type \\ nil) do
    if not debug_enabled?(domain_module, view_type) do
      false
    else
      config = if view_type do
        get_view_config(domain_module, view_type)
      else
        get_config(domain_module)
      end
      
      Map.get(config, feature, false)
    end
  end

  @doc """
  Gets the default debug configuration.
  Can be overridden via application config.
  """
  @spec get_default_config() :: map()
  def get_default_config do
    app_config = Application.get_env(:selecto_components, :debug_config, %{})
    
    # Only enable debug in dev/test environments by default
    env_enabled = dev_mode?()
    
    @default_config
    |> Map.put(:enabled, env_enabled)
    |> merge_with_defaults(app_config)
  end

  @doc """
  Formats SQL query based on configuration.
  """
  @spec format_sql(String.t(), map()) :: String.t()
  def format_sql(sql, config) do
    if Map.get(config, :format_sql, true) do
      sql
      |> String.replace(~r/\s+/, " ")
      |> String.replace(~r/,\s*/, ", ")
      |> String.replace(~r/\(\s+/, "(")
      |> String.replace(~r/\s+\)/, ")")
      |> format_sql_keywords()
    else
      sql
    end
  end

  @doc """
  Truncates parameters based on configuration.
  """
  @spec truncate_params(list(), map()) :: list()
  def truncate_params(params, config) do
    max_length = Map.get(config, :max_param_length, 100)
    
    Enum.map(params, fn param ->
      case param do
        str when is_binary(str) and byte_size(str) > max_length ->
          String.slice(str, 0, max_length) <> "..."
        _ ->
          param
      end
    end)
  end

  @doc """
  Creates a debug info map based on configuration.
  """
  @spec build_debug_info(map(), map()) :: map()
  def build_debug_info(data, config) do
    debug_info = %{}
    
    debug_info = if Map.get(config, :show_query, false) && data[:query] do
      Map.put(debug_info, :query, format_sql(data.query, config))
    else
      debug_info
    end
    
    debug_info = if Map.get(config, :show_params, false) && data[:params] do
      Map.put(debug_info, :params, truncate_params(data.params, config))
    else
      debug_info
    end
    
    debug_info = if Map.get(config, :show_timing, false) && data[:timing] do
      Map.put(debug_info, :timing, data.timing)
    else
      debug_info
    end
    
    debug_info = if Map.get(config, :show_row_count, false) && data[:row_count] do
      Map.put(debug_info, :row_count, data.row_count)
    else
      debug_info
    end
    
    debug_info = if Map.get(config, :show_execution_plan, false) && data[:execution_plan] do
      Map.put(debug_info, :execution_plan, data.execution_plan)
    else
      debug_info
    end
    
    debug_info
  end

  # Private functions

  defp merge_with_defaults(config, override \\ %{}) do
    deep_merge(@default_config, config)
    |> deep_merge(override)
  end

  defp deep_merge(map1, map2) do
    Map.merge(map1, map2, fn
      _key, v1, v2 when is_map(v1) and is_map(v2) ->
        deep_merge(v1, v2)
      _key, _v1, v2 ->
        v2
    end)
  end

  defp format_sql_keywords(sql) do
    keywords = ~w[
      SELECT FROM WHERE GROUP BY ORDER BY HAVING LIMIT OFFSET
      JOIN LEFT RIGHT INNER OUTER FULL ON AND OR NOT IN EXISTS
      AS WITH DISTINCT COUNT SUM AVG MIN MAX CASE WHEN THEN ELSE END
      INSERT UPDATE DELETE INTO VALUES SET CREATE ALTER DROP TABLE
      INDEX PRIMARY KEY FOREIGN REFERENCES CASCADE RESTRICT
    ]
    
    Enum.reduce(keywords, sql, fn keyword, acc ->
      # Replace keyword with uppercase version, preserving word boundaries
      String.replace(acc, ~r/\b#{keyword}\b/i, keyword)
    end)
  end

  defp dev_mode? do
    Application.get_env(:selecto_components, :dev_mode, false) ||
      Application.get_env(:selecto_components, :env) == :dev ||
      System.get_env("DEV_MODE") == "true" ||
      Mix.env() in [:dev, :test]
  end
end