defmodule AeChannelService.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      # apps: [:aesocketconnector],
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
    ]
  end
end
