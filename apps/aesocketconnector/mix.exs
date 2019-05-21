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
      {:websockex, "~> 0.4.0"},
      # {:enacl, git: "https://github.com/aeternity/enacl.git", ref: "26180f4"},
      # {:aeserialization, git: "https://github.com/aeternity/aeserialization.git"},
      {:poison, "~> 3.1"},
      {:enacl, git: "https://github.com/aeternity/enacl.git", ref: "26180f4"},
      {:aeserialization, git: "https://github.com/aeternity/aeserialization.git"},
      # {:rebar3custom, git: "https://github.com/aeternity/rebar3", ref: "abd3bec7722"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:aeternity, git: "https://github.com/aeternity/aeternity"}
      # {:dep_from_git, git: "https://github.com/dougal/base58.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true},
      # {:aeminer, git: "https://github.com/aeternity/aeminer.git", manager: :drebar3},
      # {:aeminer, git: "https://github.com/aeternity/aeminer.git", manager: :none, app: false, override: true, compile: false},
      # {:aeternity, git: "https://github.com/aeternity/aeternity", manager: :make, app: false},
      # {:aeternity, git: "https://github.com/aeternity/aeternity", manager: :make},
      # {:aeminer, path: "../../../aeminer", manager: :rebar3, override: true, app: false},
      # # # {:aebytecode, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/aebytecode.git", ref: "2f4e188", manager: :rebar3, compile: false]},
      # {:aebytecode, path: "../../../aebytecode", manager: :rebar3, compile: false, override: true, app: false},
      # # # {:aebytecode, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/aebytecode.git", ref: "2f4e188", manager: :rebar3]},
      # {:aeserialization, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/aeserialization.git", ref: "3416ff5", manager: :rebar3]},
      # # #{:trace_runner, [env: :prod, override: true, git: "git://github.com/uwiger/trace_runner.git", ref: "303ef2f"]},
      # {:trace_runner, [env: :prod, override: true, git: "git://github.com/uwiger/trace_runner.git", ref: "303ef2f", manager: :rebar3]},
      # # # {:trace_runner, ">= 0.0.0", [env: :prod, override: true, git: "git://github.com/uwiger/trace_runner.git", ref: "303ef2f", manager: :rebar3]},
      # {:sext, git: "https://github.com/uwiger/sext.git", ref: "07a4c2d66", override: true},
      # # {:sext, git: tag: "07d5d516", manager: :rebar, override: true},
      # # {:sext, "1.5.0", tag: "07d5d516", override: true, compile: false},
      # # # {:mnesia_leveled, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/mnesia_leveled.git", ref: "86e78b7", manager: :rebar3, compile: false]},
      # # # {:mnesia_rocksdb, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/mnesia_rocksdb.git", ref: "ad8e7b6", manager: :rebar3, compile: false]},
      # {:mnesia_leveled, [env: :prod, override: true, git: "https://github.com/aeternity/mnesia_leveled.git", ref: "86e78b7", manager: :rebar3]},
      # {:mnesia_rocksdb, [env: :prod, override: true, git: "https://github.com/aeternity/mnesia_rocksdb.git", ref: "ad8e7b6", manager: :rebar3]},
      # {:lz4, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/erlang-lz4.git", ref: "1ff9f36", manager: :rebar3]}

    ]
  end
end
