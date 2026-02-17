import Config

config :esbuild,
  version: "0.17.11",
  package: [
    args:
      ~w(js/hooks.js --bundle --target=es2017 --format=esm --outfile=../priv/static/selecto_components.min.js),
    cd: Path.expand("../assets", __DIR__)
  ]
