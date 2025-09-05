defmodule Mix.Tasks.Selecto.Components.Setup do
  @moduledoc """
  Sets up selecto_components colocated JavaScript and hooks in the host project.

  This task:
  1. Configures esbuild to include selecto_components hooks
  2. Updates app.js to register colocated hooks  
  3. Ensures Phoenix LiveView colocated assets are properly configured
  4. Creates necessary configuration files

  ## Usage

      mix selecto.components.setup

  ## Options

    * `--force` - Force overwrite existing configuration
    * `--no-backup` - Skip backing up existing files
  """

  use Mix.Task

  @shortdoc "Set up selecto_components colocated assets in the host project"

  @requirements ["app.config"]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, 
      strict: [force: :boolean, no_backup: :boolean],
      aliases: [f: :force]
    )

    Mix.shell().info("Setting up selecto_components colocated assets...")

    with :ok <- ensure_phoenix_live_view_version(),
         :ok <- backup_files(opts),
         :ok <- update_esbuild_config(opts),
         :ok <- update_app_js(opts),
         :ok <- create_hooks_directory(opts),
         :ok <- compile_colocated_assets() do
      Mix.shell().info("""
      
      ✅ Selecto components colocated assets setup complete!
      
      Next steps:
      1. Run `mix compile` to extract colocated hooks
      2. Run `mix phx.server` to start your application
      3. The following hooks are now available:
         - SelectoComponents.Components.TreeBuilder
         - SelectoComponents.Views.Graph.Component
      
      Note: Colocated hooks are automatically extracted during compilation.
      """)
    else
      {:error, reason} ->
        Mix.shell().error("Setup failed: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp ensure_phoenix_live_view_version do
    case Application.spec(:phoenix_live_view, :vsn) do
      nil ->
        {:error, "Phoenix LiveView is not installed"}
      
      version ->
        version_string = to_string(version)
        if Version.match?(version_string, ">= 0.20.0") do
          :ok
        else
          {:error, "Phoenix LiveView #{version_string} is too old. Colocated assets require >= 0.20.0"}
        end
    end
  end

  defp backup_files(opts) do
    unless opts[:no_backup] do
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      
      files_to_backup = [
        "assets/js/app.js",
        "config/config.exs",
        "config/dev.exs"
      ]
      
      Enum.each(files_to_backup, fn file ->
        if File.exists?(file) do
          backup_file = "#{file}.backup.#{timestamp}"
          File.copy!(file, backup_file)
          Mix.shell().info("Backed up #{file} to #{backup_file}")
        end
      end)
    end
    
    :ok
  end

  defp update_esbuild_config(opts) do
    config_file = "config/config.exs"
    
    if !File.exists?(config_file) do
      {:error, "config/config.exs not found"}
    else
      content = File.read!(config_file)
      
      # Check if esbuild configuration exists
      if String.contains?(content, "config :esbuild") do
        # Update existing esbuild config
        if !String.contains?(content, "selecto_components") || opts[:force] do
          updated_content = update_existing_esbuild_config(content)
          File.write!(config_file, updated_content)
          Mix.shell().info("Updated esbuild configuration in config/config.exs")
        else
          Mix.shell().info("Esbuild configuration already includes selecto_components")
        end
      else
        # Add esbuild configuration
        esbuild_config = """
        
        # Configure esbuild (version pinned via package.json)
        config :esbuild,
          version: "0.17.11",
          selecto_northwind: [
            args:
              ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
            cd: Path.expand("../assets", __DIR__),
            env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
          ]
        """
        
        File.write!(config_file, content <> esbuild_config)
        Mix.shell().info("Added esbuild configuration to config/config.exs")
      end
      
      :ok
    end
  end

  defp update_existing_esbuild_config(content) do
    # This is a simplified version - you might need more sophisticated regex
    # to handle various formatting styles
    String.replace(content, ~r/config :esbuild,.*?\n(?=\nconfig|\z)/s, fn match ->
      if String.contains?(match, "NODE_PATH") do
        match
      else
        # Add NODE_PATH to existing config
        match
        |> String.replace(~r/\]$/, ~s|],
            env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
          ]|)
      end
    end)
  end

  defp update_app_js(_opts) do
    app_js_file = "assets/js/app.js"
    
    if !File.exists?(app_js_file) do
      {:error, "assets/js/app.js not found"}
    else
      content = File.read!(app_js_file)
      
      # Check if already configured
      if String.contains?(content, "selecto_components/hooks") do
        Mix.shell().info("app.js already configured for selecto_components hooks")
        :ok
      else
        # Find the hooks configuration section
        updated_content = if String.contains?(content, "hooks:") do
          # Update existing hooks
          add_selecto_hooks_to_existing(content)
        else
          # Add hooks configuration
          add_hooks_configuration(content)
        end
        
        File.write!(app_js_file, updated_content)
        Mix.shell().info("Updated assets/js/app.js with selecto_components hooks")
        :ok
      end
    end
  end

  defp add_selecto_hooks_to_existing(content) do
    # Import the auto-generated hooks
    import_statement = """
    // Auto-generated selecto_components hooks
    import * as SelectoHooks from "./selecto_components/hooks"
    """
    
    # Add import after other imports
    content = if String.contains?(content, "import") do
      String.replace(content, ~r/(import.*from.*\n)+/, "\\0#{import_statement}\n")
    else
      import_statement <> "\n" <> content
    end
    
    # Add hooks to the hooks object
    String.replace(content, ~r/hooks:\s*{([^}]*)}/s, fn match ->
      captured = String.replace(match, ~r/hooks:\s*{/, "")
      captured = String.replace(captured, ~r/}$/, "")
      
      if String.trim(captured) == "" do
        "hooks: { ...SelectoHooks }"
      else
        "hooks: {\n#{captured},\n  ...SelectoHooks\n}"
      end
    end)
  end

  defp add_hooks_configuration(content) do
    import_statement = """
    // Auto-generated selecto_components hooks
    import * as SelectoHooks from "./selecto_components/hooks"
    """
    
    # Add import
    content = if String.contains?(content, "import") do
      String.replace(content, ~r/(import.*from.*\n)+/, "\\0#{import_statement}\n")
    else
      import_statement <> "\n" <> content
    end
    
    # Add hooks to LiveSocket configuration
    String.replace(content, ~r/new LiveSocket\([^{]+{([^}]+)}/s, fn match, captured ->
      String.replace(match, captured, "#{captured},\n  hooks: { ...SelectoHooks }")
    end)
  end

  defp create_hooks_directory(_opts) do
    hooks_dir = "assets/js/selecto_components"
    
    unless File.exists?(hooks_dir) do
      File.mkdir_p!(hooks_dir)
      Mix.shell().info("Created directory: #{hooks_dir}")
    end
    
    # Create an index file that will be populated by Phoenix LiveView
    index_file = Path.join(hooks_dir, "hooks.js")
    unless File.exists?(index_file) do
      File.write!(index_file, """
      // This file is auto-generated by Phoenix LiveView
      // It will be populated with colocated hooks during compilation
      export {}
      """)
      Mix.shell().info("Created hooks index file: #{index_file}")
    end
    
    :ok
  end

  defp compile_colocated_assets do
    Mix.shell().info("Compiling to extract colocated assets...")
    
    # Force recompilation to extract hooks
    Mix.Task.run("compile", ["--force"])
    
    :ok
  end
end