import Config


config :esbuild,
  version: "0.15.5",
  package: [
    args:
      ~w(js/PushEventHook.js --target=es2017 --minify --outfile=../priv/static/selecto_components.min.js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
