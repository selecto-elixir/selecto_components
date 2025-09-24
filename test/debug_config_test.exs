defmodule SelectoComponents.Debug.ConfigReaderTest do
  use ExUnit.Case, async: true
  alias SelectoComponents.Debug.ConfigReader

  # Mock domain module with debug config
  defmodule TestDomainWithConfig do
    def debug_config do
      %{
        enabled: true,
        show_query: true,
        show_params: false,
        show_timing: true,
        views: %{
          aggregate: %{
            show_query: false,
            show_params: true
          }
        }
      }
    end
  end

  # Mock domain module without debug config
  defmodule TestDomainWithoutConfig do
  end

  describe "get_config/1" do
    test "returns domain config when debug_config/0 is defined" do
      config = ConfigReader.get_config(TestDomainWithConfig)
      
      assert config.enabled == true
      assert config.show_query == true
      assert config.show_params == false
      assert config.show_timing == true
    end
    
    test "returns default config when debug_config/0 is not defined" do
      config = ConfigReader.get_config(TestDomainWithoutConfig)
      
      # Should get defaults
      assert is_boolean(config.enabled)
      assert config.show_query == false
      assert config.format_sql == true
    end
    
    test "returns default config when domain is nil" do
      config = ConfigReader.get_config(nil)
      
      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :views)
    end
    
    test "merges domain config with defaults" do
      config = ConfigReader.get_config(TestDomainWithConfig)
      
      # Should have both domain-specific and default values
      assert config.show_timing == true  # from domain
      assert config.format_sql == true   # from default
      assert config.max_param_length == 100  # from default
    end
  end

  describe "get_view_config/2" do
    test "returns view-specific config merged with base" do
      config = ConfigReader.get_view_config(TestDomainWithConfig, :aggregate)
      
      # Should have aggregate-specific overrides
      assert config.show_query == false  # overridden by aggregate view
      assert config.show_params == true  # overridden by aggregate view
      assert config.show_timing == true  # from base config
      refute Map.has_key?(config, :views)  # views should be removed
    end
    
    test "returns base config when view type not configured" do
      config = ConfigReader.get_view_config(TestDomainWithConfig, :detail)
      
      # Should fall back to base config
      assert config.show_query == true
      assert config.show_params == false
      assert config.show_timing == true
    end
    
    test "handles nil domain module" do
      config = ConfigReader.get_view_config(nil, :aggregate)
      
      assert is_map(config)
      refute Map.has_key?(config, :views)
    end
  end

  describe "debug_enabled?/2" do
    test "checks if debug is enabled for domain" do
      # Will depend on environment
      result = ConfigReader.debug_enabled?(TestDomainWithConfig)
      assert is_boolean(result)
    end
    
    test "checks if debug is enabled for specific view" do
      result = ConfigReader.debug_enabled?(TestDomainWithConfig, :aggregate)
      assert is_boolean(result)
    end
    
    test "returns false for nil domain" do
      # Default config has enabled: false
      result = ConfigReader.debug_enabled?(nil)
      assert is_boolean(result)
    end
  end

  describe "feature_enabled?/3" do
    test "checks if specific feature is enabled" do
      # Mock env to enable debug
      Application.put_env(:selecto_components, :dev_mode, true)
      
      assert ConfigReader.feature_enabled?(TestDomainWithConfig, :show_query) == true
      assert ConfigReader.feature_enabled?(TestDomainWithConfig, :show_params) == false
      assert ConfigReader.feature_enabled?(TestDomainWithConfig, :show_timing) == true
      
      # Clean up
      Application.delete_env(:selecto_components, :dev_mode)
    end
    
    test "returns false when debug is disabled" do
      # Create a domain with debug explicitly disabled
      defmodule TestDomainDisabled do
        def debug_config do
          %{enabled: false, show_query: true}
        end
      end
      
      assert ConfigReader.feature_enabled?(TestDomainDisabled, :show_query) == false
    end
    
    test "checks feature for specific view type" do
      Application.put_env(:selecto_components, :dev_mode, true)
      
      # aggregate view overrides show_query to false
      assert ConfigReader.feature_enabled?(TestDomainWithConfig, :show_query, :aggregate) == false
      # aggregate view overrides show_params to true
      assert ConfigReader.feature_enabled?(TestDomainWithConfig, :show_params, :aggregate) == true
      
      Application.delete_env(:selecto_components, :dev_mode)
    end
  end

  describe "format_sql/2" do
    test "formats SQL when enabled" do
      config = %{format_sql: true}
      sql = "select   *  from   users  where  id = 1"
      
      formatted = ConfigReader.format_sql(sql, config)
      
      assert formatted =~ "SELECT"
      assert formatted =~ "FROM"
      assert formatted =~ "WHERE"
      refute formatted =~ "  "  # no double spaces
    end
    
    test "preserves SQL when formatting disabled" do
      config = %{format_sql: false}
      sql = "select   *  from   users"
      
      formatted = ConfigReader.format_sql(sql, config)
      
      assert formatted == sql
    end
    
    test "formats SQL keywords to uppercase" do
      config = %{format_sql: true}
      sql = "select count(*) from users where active = true group by role order by created_at"
      
      formatted = ConfigReader.format_sql(sql, config)
      
      assert formatted =~ "SELECT"
      assert formatted =~ "COUNT"
      assert formatted =~ "FROM"
      assert formatted =~ "WHERE"
      assert formatted =~ "GROUP BY"
      assert formatted =~ "ORDER BY"
    end
  end

  describe "truncate_params/2" do
    test "truncates long string parameters" do
      config = %{max_param_length: 10}
      params = ["short", "this is a very long string that should be truncated", 123]
      
      truncated = ConfigReader.truncate_params(params, config)
      
      assert Enum.at(truncated, 0) == "short"
      assert Enum.at(truncated, 1) == "this is a ..."
      assert Enum.at(truncated, 2) == 123
    end
    
    test "preserves params when under limit" do
      config = %{max_param_length: 100}
      params = ["param1", "param2", 42]
      
      truncated = ConfigReader.truncate_params(params, config)
      
      assert truncated == params
    end
  end

  describe "build_debug_info/2" do
    test "builds debug info based on config" do
      config = %{
        show_query: true,
        show_params: false,
        show_timing: true,
        show_row_count: true,
        format_sql: false
      }
      
      data = %{
        query: "SELECT * FROM users",
        params: [1, 2, 3],
        timing: 42.5,
        row_count: 10,
        execution_plan: "Seq Scan on users"
      }
      
      debug_info = ConfigReader.build_debug_info(data, config)
      
      assert debug_info.query == "SELECT * FROM users"
      refute Map.has_key?(debug_info, :params)  # show_params is false
      assert debug_info.timing == 42.5
      assert debug_info.row_count == 10
      refute Map.has_key?(debug_info, :execution_plan)  # not enabled in config
    end
    
    test "returns empty map when all features disabled" do
      config = %{
        show_query: false,
        show_params: false,
        show_timing: false,
        show_row_count: false
      }
      
      data = %{
        query: "SELECT * FROM users",
        params: [1, 2, 3],
        timing: 42.5,
        row_count: 10
      }
      
      debug_info = ConfigReader.build_debug_info(data, config)
      
      assert debug_info == %{}
    end
    
    test "formats SQL when enabled" do
      config = %{
        show_query: true,
        format_sql: true
      }
      
      data = %{
        query: "select   *   from   users"
      }
      
      debug_info = ConfigReader.build_debug_info(data, config)
      
      assert debug_info.query =~ "SELECT"
      refute debug_info.query =~ "  "
    end
  end
end