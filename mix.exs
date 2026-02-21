defmodule SelectoComponents.MixProject do
  use Mix.Project

  def project do
    [
      app: :selecto_components,
      version: "0.3.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: "ALPHA: LiveView components for Selecto",
      aliases: aliases(),
      package: package(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      deps: deps(),

      # Test coverage
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
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
      # {:phoenix_html_helpers, "~> 1.0"},
      selecto_dep(),
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.29.1", only: :dev, runtime: false},
      # {:vega_lite, "~> 0.1.6"},
      {:timex, "~> 3.7.9"},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:ecto, ">= 3.9.1 and < 4.0.0"},
      {:ecto_sql, ">= 3.9.1 and < 4.0.0"},
      {:makeup, "~> 1.1"},
      {:makeup_sql, "~> 0.1.0"},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp selecto_dep do
    if Mix.env() == :test do
      {:selecto, path: "../selecto"}
    else
      {:selecto, ">= 0.2.6 and < 0.4.0"}
    end
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/selecto-elixir/selecto_components"},
      source_url: "https://github.com/selecto-elixir/selecto_components",
      files:
        ~w(mix.exs README.md LICENSE lib/selecto_components** package.json priv/static/selecto_components.min.js)
    ]
  end

  defp aliases do
    [
      "assets.package": [
        "cmd mkdir -p priv/static",
        "esbuild.install --if-missing",
        "esbuild package --minify"
      ]
    ]
  end
end
