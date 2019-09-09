defmodule Validator do
  require Logger
  alias SocketConnector.WsConnection

  def get_state_hash(tx) do
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, tx)
    deserialized = :aetx_sign.deserialize_from_binary(signed_tx)
    # get aetx
    aetx = :aetx_sign.tx(deserialized)
    {module, instance} = :aetx.specialize_callback(aetx)
    # module is :aesc_offchain_tx or :aesc_create_tx
    hash = apply(module, :state_hash, [instance])
    Logger.debug("state hash is : #{inspect(hash)}")
  end

  def get_state_round(tx) do
    # signed_tx(aetx(off-chain_tx))
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, tx)
    deserialized = :aetx_sign.deserialize_from_binary(signed_tx)
    # get aetx
    aetx = :aetx_sign.tx(deserialized)
    {module, instance} = :aetx.specialize_callback(aetx)
    round = apply(module, :round, [instance])
    get_state_hash(tx)
    round
  end

  defp channel_create_tx(tx, state) do
    # TODO make sure to verify that what we are signing matches according to the original request made.
    # module is: aesc_create_tx
    {module, tx_instance} = :aetx.specialize_callback(tx)
    initiator_pub_key = apply(module, :initiator_pubkey, [tx_instance])
    initiator_amount = apply(module, :initiator_amount, [tx_instance])
    responder_pub_key = apply(module, :responder_pubkey, [tx_instance])
    responder_amount = apply(module, :responder_amount, [tx_instance])

    case (_sign_map = %WsConnection{
            initiator: :aeser_api_encoder.encode(:account_pubkey, initiator_pub_key),
            responder: :aeser_api_encoder.encode(:account_pubkey, responder_pub_key),
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

  defp send_approval_request(aetx, round_initiator, auto_approval, state) do
    case state.connection_callbacks do
      nil ->
        :unsecure

      %SocketConnector.ConnectionCallbacks{
        sign_approve: sign_approve,
        channels_update: _channels_update
      } ->
        # TODO this is not pretty
        {module, instance} = :aetx.specialize_callback(aetx)

        case module do
          # TODO we need to know at which round we are closing here...
          :aesc_close_mutual_tx ->
            Logger.debug("Close mutual #{inspect(instance)}", state.color)
            round = apply(module, :nonce, [instance])
            sign_approve.(round_initiator, round, auto_approval, :aetx.serialize_for_client(aetx))

          # apply(module, :for_client, [instance])

          tranaction_type when tranaction_type in [:aesc_close_solo_tx] ->
            %{"payload" => payload} = apply(module, :for_client, [instance])
            {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, payload)
            deserialized_signed_tx = :aetx_sign.deserialize_from_binary(signed_tx)
            aetx = :aetx_sign.tx(deserialized_signed_tx)
            {module, instance} = :aetx.specialize_callback(aetx)
            round = apply(module, :round, [instance])
            sign_approve.(round_initiator, round, auto_approval, :aetx.serialize_for_client(aetx))

          _ ->
            round = apply(module, :round, [instance])
            sign_approve.(round_initiator, round, auto_approval, :aetx.serialize_for_client(aetx))
        end
    end
  end

  def inspect_transfer_request(aetx, round_initiator, state) do
    {module, _tx_instance} = :aetx.specialize_callback(aetx)

    # TODO if calls is initiated by us and contains what we submitted auto approval can be made
    auto_approval =
      case module do
        :aesc_create_tx ->
          channel_create_tx(aetx, state)

        _other ->
          Logger.debug(
            "Sign request Missing inspection!! default approved. Module is #{inspect(module)}"
          )

          :ok
      end

    case send_approval_request(aetx, round_initiator, auto_approval, state) do
      :ok -> :ok
      _ -> :unsecure
    end
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
