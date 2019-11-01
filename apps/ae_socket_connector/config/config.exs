# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :ae_socket_connector, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:ae_socket_connector, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info

config :logger,
  compile_time_purge_matching: [
    # [application: :foo],
    [module: SocketConnector, level_lower_than: :error]
  ]

config :ae_socket_connector, :node,
  ae_url: System.get_env("AE_NODE_URL", "ws://localhost:3014/channel"),
  network_id: System.get_env("AE_NODE_NETWORK_ID", "my_test")

# config :ae_socket_connector, :urls,
#   ae_url: "wss://testnet.demo.aeternity.io/channel",
#   network_id: "ae_uat"

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"
