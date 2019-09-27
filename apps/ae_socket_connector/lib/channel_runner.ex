defmodule ChannelRunner do
  require Logger

  @ae_url "ws://localhost:3014/channel"
  @network_id "my_test"

  # @ae_url "wss://testnet.demo.aeternity.io/channel"
  # @network_id "ae_uat"

  defmacro ae_url, do: @ae_url
  defmacro network_id, do: @network_id

  def start_channel_helper(),
    do: ClientRunner.start_helper(@ae_url, @network_id)
end
