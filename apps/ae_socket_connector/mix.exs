defmodule SocketConnector.MixProject do
  use Mix.Project

  def project do
    [
      app: :ae_socket_connector,
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
      applications: [:httpotion],
      mod: {SocketConnector.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:aesophia, git: "https://github.com/aeternity/aesophia.git", manager: :rebar, tag: "v4.2.0"},
      {:httpotion, "~> 3.1.0"},
      {:websockex, "~> 0.4.2"},
      {:poison, "~> 3.1"}
    ]
  end
end
