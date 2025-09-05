defmodule SelectoComponents.MixProject do
  use Mix.Project

  def project do
    [
      app: :selecto_components,
      version: "0.3.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: "LiveView Components for Selecto",
      aliases: aliases(),
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.8.0"},
      {:phoenix_live_view, "~> 1.1.4"},
      #{:phoenix_html_helpers, "~> 1.0"},
      {:selecto, path: "../selecto"},
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.29.1", only: :dev, runtime: false},
      {:heroicons, "~> 0.5"},
      #{:vega_lite, "~> 0.1.6"},
      {:timex, "~> 3.7.9"},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11"},


      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/selecto-elixir/selecto_components"},
      source_url: "https://github.com/selecto-elixir/selecto_components",
      files: ~w(mix.exs lib/selecto_components** package.json priv/static/selecto_components.min.js)
    ]
  end

  defp aliases do
    [
      "assets.package": ["esbuild package"],
    ]
  end

end
