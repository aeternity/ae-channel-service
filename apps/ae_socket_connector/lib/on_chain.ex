defmodule OnChain do
  require ClientRunner
  require Logger

  def gethost() do
    %URI{host: host, authority: _authority} = URI.parse(ClientRunner.ae_url())
    host
  end

  def build_url(path) do
    URI.to_string(%URI{
      host: gethost(),
      port: 3013,
      scheme: "http",
      path: path
    })
  end

  def current_height() do
    url = build_url("/v2/key-blocks/current")
    %{"height" => height} = Poison.decode!(HTTPotion.get(url).body)
    height
  end

  def nonce(account) do
    url = build_url("/v2/accounts/" <> account)
    %{"nonce" => nonce} = Poison.decode!(HTTPotion.get(url).body)
    nonce
  end

  def post_solo_close(solo_close_tx) do
    url = build_url("/v2/transactions")

    header = [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
    body = Poison.encode!(%{"tx" => solo_close_tx})
    %{"tx_hash" => tx_hash} = Poison.decode!(HTTPotion.post(url, body: body, headers: header).body)
    Logger.debug("track transaction curl http://localhost:3013/v2/transactions/" <> tx_hash)
  end
end
