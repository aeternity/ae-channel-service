use Mix.Config

config :logger,
  compile_time_purge_matching: [
    [module: SocketConnector, level_lower_than: :error]
  ]

config :ae_socket_connector, :node,
  ae_url: System.get_env("AE_NODE_URL") || "ws://localhost:3014/channel",
  network_id: System.get_env("AE_NODE_NETWORK_ID") || "my_test"

import_config "../test/accounts_test.exs"

config :ae_socket_connector, :accounts,
  initiator: {TestAccounts.initiatorPubkeyEncoded(), TestAccounts.initiatorPrivkey()},
  responder: {TestAccounts.responderPubkeyEncoded(), TestAccounts.responderPrivkey()}

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
