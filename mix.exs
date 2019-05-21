defmodule AeChannelService.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      # apps: [:aetx, :aesocketconnector],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:poison, "~> 3.1"},
      {:websockex, "~> 0.4.0"},
      {:enacl, git: "https://github.com/aeternity/enacl.git", ref: "26180f4"},
      {:aeserialization, git: "https://github.com/aeternity/aeserialization.git"},
      # # {:aeminer, git: "https://github.com/aeternity/aeminer.git", manager: :drebar3},
      # # {:aeminer, git: "https://github.com/aeternity/aeminer.git", manager: :none, app: false, override: true, compile: false},
      # {:aeminer, path: "../aeminer", manager: :rebar3, override: true},
      # {:aeternity, git: "https://github.com/aeternity/aeternity"},
      # # {:aebytecode, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/aebytecode.git", ref: "2f4e188", manager: :rebar3, compile: false]},
      # {:aebytecode, path: "../aebytecode", manager: :rebar3, compile: false, override: true},
      # # {:aebytecode, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/aebytecode.git", ref: "2f4e188", manager: :rebar3]},
      # {:aeserialization, ">= 0.0.0", [env: :prod, override: true, git: "https://github.com/aeternity/aeserialization.git", ref: "3416ff5", manager: :rebar3]},
      # {:trace_runner, [env: :prod, override: true, git: "git://github.com/uwiger/trace_runner.git", ref: "303ef2f", manager: :rebar3]},
      # # {:trace_runner, ">= 0.0.0", [env: :prod, override: true, git: "git://github.com/uwiger/trace_runner.git", ref: "303ef2f", manager: :rebar3]},
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
