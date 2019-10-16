defmodule OnChain do
  require ClientRunner
  require Logger

  def testget() do
    HTTPotion.get("https://httpbin.org/get")
  end

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

  def get_nonce() do
    url = build_url("/v2/accounts" <> "/ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh")
    %{"nonce" => nonce} = Poison.decode!(HTTPotion.get(url).body)
    nonce
  end

  def initiatorPrivkey() do
    :binary.encode_unsigned(
      0x5245D200D51B048C825280578EDDA2160F48859D49DCFC3510D87CC46758C97C39E09993C3D5B1147F002925270F7E7E112425ABA0137A6E8A929846A3DFD871
    )
  end

  def post_solo_close(solo_close_tx) do
    url = build_url("/v2/transactions")

    header = [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
    body = Poison.encode!(%{"tx" => solo_close_tx})
    %{"tx_hash" => tx_hash} = Poison.decode!(HTTPotion.post(url, body: body, headers: header).body)
    Logger.debug("track transaction curl http://localhost:3013/v2/transactions/" <> tx_hash)
  end
end


# curl "http://localhost:3013/v2/transactions//th_VsKRF2Qh9DhZNNZQ4DpnEG2Y5K31BQSckJjQEag5uFBZxarXg"
