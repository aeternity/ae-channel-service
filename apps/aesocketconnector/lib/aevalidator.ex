defmodule AeValidator do

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
  alias AeSocketConnector.WsConnection

  def inspect_sign_request(tx, state) do
    # TODO make sure to verify that what we are signing matches according to the original request made.
    {module, tx_instance} = :aetx.specialize_callback(tx)
    # modeule is: aesc_create_tx
    initiator_pub_key = apply(module, :initiator_pubkey, [tx_instance])
    initiator_amount = apply(module, :initiator_amount, [tx_instance])
    responder_pub_key = apply(module, :responder_pubkey, [tx_instance])
    responder_amount = apply(module, :responder_amount, [tx_instance])

    # TODO, redo above without specialize callback

    # Logger.info "for client 1: #{inspect :aesc_create_tx.for_client(tx_instance)}"
    # Logger.info "for client 2: #{inspect :aetx.serialize_for_client(tx)}"
    # Logger.info "pubkey: #{inspect responder_pub_key} #{inspect responder_amount}", state.color

    # initiator_id = :aeser_api_encoder.encode(:account_pubkey, initiator_pub_key)
    # responder_id = :aeser_api_encoder.encode(:account_pubkey, responder_pub_key)

    case (sign_map = %WsConnection{initiator: initiator_pub_key, responder: responder_pub_key, initiator_amount: initiator_amount, responder_amount: responder_amount}) == state.session do
      true ->
        Logger.info "OK to sign!", state.color
        :ok
      false ->
        Logger.error "NOK to sign #{inspect state.role} #{inspect sign_map} #{inspect state.session}"
        :unsecure
    end
  end

  def inspect_transfer_request(tx, _state) do
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
    :aetx.serialize_for_client(tx)
    :ok
  end
end
