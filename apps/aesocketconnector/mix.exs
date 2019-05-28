defmodule AeSocketConnector.MixProject do
  use Mix.Project

  def project do
    [
      app: :aesocketconnector,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {AeSocketConnector.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:aebytecode, path: "../aebytecode", manager: :rebar3},
      # {:aebytecode, path: "../../aebytecode", manager: :rebar3, compile: false, override: true, app: false},
      # {:aebytecode, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/aebytecode.git", ref: "241a96e"]},
      {:aesophia, git: "https://github.com/aeternity/aesophia.git", manager: :rebar},
      # {:aeserialization, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/aeserialization.git", ref: "816bf99", manager: :rebar3]},
      {:websockex, "~> 0.4.0"},
      {:poison, "~> 3.1"},
      {:enacl, git: "https://github.com/aeternity/enacl.git", ref: "26180f4"},
      # {:aebytecode, path: "../../aebytecode", manager: :rebar3, override: true, manager: :make},
      # {:aeserialization, git: "https://github.com/aeternity/aeserialization.git"},
    ]
  end
end
