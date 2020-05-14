# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# third-party users, it should be done in your "mix.exs" file.

config :ae_backend_service, :game,
  toss_mode: System.get_env("TOSS_MODE") || "random",
  game_mode: System.get_env("GAME_MODE") || "fair",
  force_progress_height: System.get_env("FORCE_PROGRESS_HEIGHT") || "15",
  mine_rate: System.get_env("MINE_RATE") || "180000"

# You can configure your application as:
#
#     config :ae_backend_service, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:ae_backend_service, :key)
#
# You can also configure a third-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"
