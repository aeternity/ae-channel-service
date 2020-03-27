use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ae_channel_interface, AeChannelInterfaceWeb.Endpoint,
  http: [port: 4002],
  server: false,
  signing_salt: "37O4Mnmk",
  cookie_key: "_ae_channel_interface_key"

# Print only warnings and errors during test
# config :logger, level: :warn
