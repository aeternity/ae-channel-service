defmodule ChannelService.OnChain do
  require Logger

  def gethost(node_url) do
    %URI{host: host, authority: _authority} = URI.parse(node_url)
    host
  end

  def build_url(node_url, path) do
    URI.to_string(%URI{
      host: gethost(node_url),
      port: 3013,
      scheme: "http",
      path: path
    })
  end

  def current_height(node_url) do
    url = build_url(node_url, "/v2/key-blocks/current")
    %{"height" => height} = Poison.decode!(HTTPotion.get(url).body)
    height
  end

  def nonce(node_url, account) do
    url = build_url(node_url, "/v2/accounts/" <> account)
    %{"nonce" => nonce} = Poison.decode!(HTTPotion.get(url).body)
    nonce
  end

  def post_solo_close(node_url, solo_close_tx) do
    url = build_url(node_url, "/v2/transactions")

    header = [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
    body = Poison.encode!(%{"tx" => solo_close_tx})
    %{"tx_hash" => tx_hash} = Poison.decode!(HTTPotion.post(url, body: body, headers: header).body)
    Logger.debug("track transaction curl http://localhost:3013/v2/transactions/" <> tx_hash)
  end

  def get_channel_info(<<"ch_", _rest::binary>> = channel_id, node_url) do
    url = build_url(node_url, "/v2/channels/#{channel_id}")
    Poison.decode!(HTTPotion.get(url).body)
  end
end
