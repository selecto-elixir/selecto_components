defmodule SelectoComponents.SafeAtomTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.SafeAtom

  describe "to_view_mode/2" do
    test "returns atom for valid view mode strings" do
      assert SafeAtom.to_view_mode("detail") == :detail
      assert SafeAtom.to_view_mode("aggregate") == :aggregate
      assert SafeAtom.to_view_mode("graph") == :graph
      assert SafeAtom.to_view_mode("chart") == :chart
      assert SafeAtom.to_view_mode("table") == :table
    end

    test "returns default for invalid strings" do
      assert SafeAtom.to_view_mode("malicious") == :detail
      assert SafeAtom.to_view_mode("DROP TABLE users") == :detail
      assert SafeAtom.to_view_mode("<script>alert('xss')</script>") == :detail
    end

    test "returns custom default when specified" do
      assert SafeAtom.to_view_mode("invalid", :graph) == :graph
    end

    test "handles nil input" do
      assert SafeAtom.to_view_mode(nil) == :detail
      assert SafeAtom.to_view_mode(nil, :aggregate) == :aggregate
    end

    test "passes through valid atoms" do
      assert SafeAtom.to_view_mode(:detail) == :detail
      assert SafeAtom.to_view_mode(:aggregate) == :aggregate
    end

    test "returns default for invalid atoms" do
      assert SafeAtom.to_view_mode(:invalid_atom) == :detail
    end
  end

  describe "to_theme/2" do
    test "returns atom for valid theme strings" do
      assert SafeAtom.to_theme("light") == :light
      assert SafeAtom.to_theme("dark") == :dark
      assert SafeAtom.to_theme("high_contrast") == :high_contrast
      assert SafeAtom.to_theme("system") == :system
      assert SafeAtom.to_theme("auto") == :auto
    end

    test "returns default for invalid strings" do
      assert SafeAtom.to_theme("hacker_theme") == :light
      assert SafeAtom.to_theme("malicious") == :light
    end

    test "handles nil input" do
      assert SafeAtom.to_theme(nil) == :light
    end
  end

  describe "to_sort_direction/2" do
    test "returns atom for valid sort directions" do
      assert SafeAtom.to_sort_direction("asc") == :asc
      assert SafeAtom.to_sort_direction("desc") == :desc
    end

    test "returns default for invalid strings" do
      assert SafeAtom.to_sort_direction("DROP") == :asc
      assert SafeAtom.to_sort_direction("ascending") == :asc
    end

    test "handles nil input" do
      assert SafeAtom.to_sort_direction(nil) == :asc
    end
  end

  describe "to_form_mode/2" do
    test "returns atom for valid form modes" do
      assert SafeAtom.to_form_mode("collapsed") == :collapsed
      assert SafeAtom.to_form_mode("inline") == :inline
      assert SafeAtom.to_form_mode("modal") == :modal
      assert SafeAtom.to_form_mode("expanded") == :expanded
    end

    test "returns default for invalid strings" do
      assert SafeAtom.to_form_mode("evil") == :collapsed
    end

    test "handles nil input" do
      assert SafeAtom.to_form_mode(nil) == :collapsed
    end
  end

  describe "to_widget_type/2" do
    test "returns atom for valid widget types" do
      assert SafeAtom.to_widget_type("chart") == :chart
      assert SafeAtom.to_widget_type("table") == :table
      assert SafeAtom.to_widget_type("metric") == :metric
      assert SafeAtom.to_widget_type("kpi") == :kpi
    end

    test "returns default for invalid strings" do
      assert SafeAtom.to_widget_type("malware") == :table
    end

    test "handles nil input" do
      assert SafeAtom.to_widget_type(nil) == :table
    end
  end

  describe "to_aggregate_function/2" do
    test "returns atom for valid aggregate functions" do
      assert SafeAtom.to_aggregate_function("count") == :count
      assert SafeAtom.to_aggregate_function("sum") == :sum
      assert SafeAtom.to_aggregate_function("avg") == :avg
      assert SafeAtom.to_aggregate_function("min") == :min
      assert SafeAtom.to_aggregate_function("max") == :max
      assert SafeAtom.to_aggregate_function("array_agg") == :array_agg
    end

    test "returns default for invalid strings" do
      assert SafeAtom.to_aggregate_function("DROP") == :count
    end

    test "handles nil and empty string" do
      assert SafeAtom.to_aggregate_function(nil) == :count
      assert SafeAtom.to_aggregate_function("") == :count
    end
  end

  describe "to_list_name/2" do
    test "returns atom for valid list names" do
      assert SafeAtom.to_list_name("group_by") == :group_by
      assert SafeAtom.to_list_name("aggregate") == :aggregate
      assert SafeAtom.to_list_name("selected") == :selected
      assert SafeAtom.to_list_name("order_by") == :order_by
    end

    test "returns default for invalid strings" do
      assert SafeAtom.to_list_name("hacked") == :selected
    end

    test "handles nil input" do
      assert SafeAtom.to_list_name(nil) == :selected
    end
  end

  describe "to_theme_property/1" do
    test "returns atom for valid theme properties" do
      assert SafeAtom.to_theme_property("primary_500") == :primary_500
      assert SafeAtom.to_theme_property("background") == :background
      assert SafeAtom.to_theme_property("success") == :success
    end

    test "returns nil for invalid properties" do
      assert SafeAtom.to_theme_property("malicious_key") == nil
      assert SafeAtom.to_theme_property("__proto__") == nil
    end

    test "handles nil input" do
      assert SafeAtom.to_theme_property(nil) == nil
    end
  end

  describe "to_existing/1" do
    test "returns atom for existing atoms" do
      # These atoms exist because they're used in Elixir/Erlang
      assert SafeAtom.to_existing("id") == :id
      assert SafeAtom.to_existing("name") == :name
      assert SafeAtom.to_existing("ok") == :ok
    end

    test "returns nil for non-existing atoms" do
      # This string should not be an existing atom
      assert SafeAtom.to_existing("nonexistent_atom_xyz_#{:rand.uniform(1_000_000)}") == nil
    end

    test "handles nil input" do
      assert SafeAtom.to_existing(nil) == nil
    end

    test "passes through atoms" do
      assert SafeAtom.to_existing(:existing) == :existing
    end
  end

  describe "to_existing!/1" do
    test "returns atom for existing atoms" do
      assert SafeAtom.to_existing!("id") == :id
    end

    test "raises for non-existing atoms" do
      assert_raise ArgumentError, fn ->
        SafeAtom.to_existing!("nonexistent_atom_xyz_#{:rand.uniform(1_000_000)}")
      end
    end

    test "passes through atoms" do
      assert SafeAtom.to_existing!(:existing) == :existing
    end
  end

  describe "to_atom_if_allowed/3" do
    test "returns atom when in allowed list" do
      assert SafeAtom.to_atom_if_allowed("foo", [:foo, :bar], :default) == :foo
      assert SafeAtom.to_atom_if_allowed("bar", [:foo, :bar], :default) == :bar
    end

    test "returns default when not in allowed list" do
      assert SafeAtom.to_atom_if_allowed("baz", [:foo, :bar], :default) == :default
    end

    test "handles nil and empty string" do
      assert SafeAtom.to_atom_if_allowed(nil, [:foo], :default) == :default
      assert SafeAtom.to_atom_if_allowed("", [:foo], :default) == :default
    end
  end

  describe "atomize_keys/2" do
    test "atomizes valid keys and drops invalid ones" do
      input = %{
        "primary_500" => "#ffffff",
        "background" => "#000000",
        "malicious_key" => "bad_value",
        "__proto__" => "attack"
      }

      allowed = [:primary_500, :background, :success]
      result = SafeAtom.atomize_keys(input, allowed)

      assert result == %{primary_500: "#ffffff", background: "#000000"}
      refute Map.has_key?(result, :malicious_key)
      refute Map.has_key?(result, :__proto__)
    end

    test "returns empty map when no keys match" do
      input = %{"evil" => "value", "malicious" => "data"}
      allowed = [:good, :safe]

      assert SafeAtom.atomize_keys(input, allowed) == %{}
    end

    test "handles empty input" do
      assert SafeAtom.atomize_keys(%{}, [:foo]) == %{}
    end
  end

  describe "security: atom table exhaustion prevention" do
    test "invalid inputs do NOT create new atoms" do
      # Get current atom count (approximate via memory)
      initial_atom_count = :erlang.system_info(:atom_count)

      # Try to create many "malicious" atoms through our safe functions
      for i <- 1..100 do
        SafeAtom.to_view_mode("malicious_atom_#{i}")
        SafeAtom.to_theme("evil_theme_#{i}")
        SafeAtom.to_widget_type("bad_widget_#{i}")
      end

      final_atom_count = :erlang.system_info(:atom_count)

      # The atom count should not have increased significantly
      # (some small increase is possible due to test infrastructure)
      assert final_atom_count - initial_atom_count < 10
    end
  end
end
