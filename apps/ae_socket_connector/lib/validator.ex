defmodule Validator do
  # erlang inspiration
  # erlang test code reference
  # channel_sign_tx(ConnPid, Privkey, Tag, Config) ->
  #     {ok, Tag, #{<<"tx">> := EncCreateTx}} = wait_for_channel_event(ConnPid, sign, Config),
  #     {ok, CreateBinTx} = aeser_api_encoder:safe_decode(transaction, EncCreateTx),
  #     Tx = aetx:deserialize_from_binary(CreateBinTx),
  #     SignedCreateTx = aec_test_utils:sign_tx(Tx, Privkey),
  #     EncSignedCreateTx = aeser_api_encoder:encode(transaction,
  #                                   aetx_sign:serialize_to_binary(SignedCreateTx)),
  #     ws_send(ConnPid, Tag,  #{tx => EncSignedCreateTx}, Config),
  #     Tx.

  # sign_tx(Tx, PrivKeys) when is_list(PrivKeys) ->
  #     Bin = aetx:serialize_to_binary(Tx),
  #     BinForNetwork = aec_governance:add_network_id(Bin),
  #     case lists:filter(fun(PrivKey) -> not (?VALID_PRIVK(PrivKey)) end, PrivKeys) of
  #         [_|_]=BrokenKeys -> erlang:error({invalid_priv_key, BrokenKeys});
  #         [] -> pass
  #     end,
  #     Signatures = [ enacl:sign_detached(BinForNetwork, PrivKey) || PrivKey <- PrivKeys ],
  #     aetx_sign:new(Tx, Signatures).

  # defp reference() do
  #   {:ok, pubkey} = :aeser_api_encoder.safe_decode(:account_pubkey, <<@initiator_id>>)
  #   re_encoded_pub_key = :aeser_api_encoder.encode(:account_pubkey, pubkey)
  #   <<@initiator_id>> == re_encoded_pub_key
  #
  #   id = :erlang.unique_integer([:monotonic])
  # end
  require Logger
  alias SocketConnector.WsConnection

  def get_state_round(tx) do
    # signed_tx(aetx(off-chain_tx))
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, tx)
    deserialized = :aetx_sign.deserialize_from_binary(signed_tx)
    # get aetx
    aetx = :aetx_sign.tx(deserialized)
    # :aetx.specialize_type(aetx)
    {module, instance} = :aetx.specialize_callback(aetx)
    # modele is :aesc_offchain_tx or :aesc_create_tx
    # nonce = apply(module, :nonce, [instance])
    apply(module, :round, [instance])
  end

  def channel_create_tx(tx, state) do
    # TODO make sure to verify that what we are signing matches according to the original request made.
    {module, tx_instance} = :aetx.specialize_callback(tx)
    # modeule is: aesc_create_tx
    initiator_pub_key = apply(module, :initiator_pubkey, [tx_instance])
    initiator_amount = apply(module, :initiator_amount, [tx_instance])
    responder_pub_key = apply(module, :responder_pubkey, [tx_instance])
    responder_amount = apply(module, :responder_amount, [tx_instance])

    # TODO, redo above without specialized callback

    tx_client = :aesc_create_tx.for_client(tx_instance)
    Logger.info("sign request, human readable: #{inspect(tx_client)}", state.color)

    # Logger.info "pubkey: #{inspect responder_pub_key} #{inspect responder_amount}", state.color

    # initiator_id = :aeser_api_encoder.encode(:account_pubkey, initiator_pub_key)
    # responder_id = :aeser_api_encoder.encode(:account_pubkey, responder_pub_key)

    case (_sign_map = %WsConnection{
            initiator: initiator_pub_key,
            responder: responder_pub_key,
            initiator_amount: initiator_amount,
            responder_amount: responder_amount
          }) == state.session do
      true ->
        response = :ok
        Logger.info("OK to sign! #{inspect(response)}", state.color)
        response

      # :ok
      false ->
        response = :unsecure
        Logger.error("NOK to sign #{inspect(response)}", state.color)
        response
    end
  end

  # def get_contract_identifier({pub_key, compiled_contract}) do
  #   :aec_hash.blake2b_256_hash(<<pub_key::binary, compiled_contract::binary>>)
  # end

  def inspect_transfer_request(tx, state) do
    # sample code on how various way on how to chech context of tx message
    # {module, tx_instance} = :aetx.specialize_callback(tx)
    # gas = apply(module, :gas, [tx_instance])
    # fee = apply(module, :fee, [tx_instance])
    # updates = apply(module, :updates, [tx_instance])
    # fee_alt = :aetx.fee(tx)
    # stuff = :aesc_offchain_update.extract_amounts(updates)
    # [update | _] = updates
    # map_for_client = :aesc_offchain_update.for_client(update)
    # channel_pubkey = apply(module, :channel_pubkey, [tx_instance])
    # Logger.info "nonce is #{inspect tx_instance}"
    # Logger.info "module is: #{inspect module} gas is: #{inspect gas} fee_alt is: #{inspect fee_alt} fee: #{inspect fee} pub_key #{inspect channel_pubkey}"
    # Logger.info "updates is #{inspect updates}"
    # Logger.info "stuff is #{inspect stuff}"
    # Logger.info "for client 1 #{inspect map_for_client}"
    # Logger.info "for client 2 #{inspect :aetx.serialize_for_client(tx)}"
    tx_client = :aetx.serialize_for_client(tx)
    Logger.info("sign request (transfer), human readable: #{inspect(tx_client)}")
    response = :ok
    Logger.info("sign result: #{inspect(response)}", state.color)
    response
  end

  @ae_http_url "http://localhost:3013"

  # shot this curl to check wheater onchain is alright....
  def verify_on_chain(tx) do
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, tx)
    deserialized_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    tx_hash = :aetx_sign.hash(deserialized_tx)
    serialized_hash = :aeser_api_encoder.encode(:tx_hash, tx_hash)
    url_to_check = "http://localhost:3013/v2/transactions/" <> URI.encode(serialized_hash)
    Logger.debug("url to check: curl #{inspect(url_to_check)}")
  end
end
