defmodule Signer do
  # TODO this is the only module which needs the pivate key, should be spawed as a seperate process.
  require Logger
  alias SocketConnector.Update

  def sign_aetx(aetx, state) do
    bin = :aetx.serialize_to_binary(aetx)
    bin_for_network = <<state.network_id::binary, bin::binary>>
    result_signed = :enacl.sign_detached(bin_for_network, state.priv_key)
    signed_create_tx = :aetx_sign.new(aetx, [result_signed])

    :aeser_api_encoder.encode(
      :transaction,
      :aetx_sign.serialize_to_binary(signed_create_tx)
    )
  end

  def sign_transaction(
        to_sign,
        poi,
        state,
        verify_hook \\ fn _tx, _round_initiator, _state -> :unsecure end
      )

  # https://github.com/aeternity/aeternity/commit/e164fc4518263db9692c02a9b84e179d69bfcc13#diff-e14138de459cdd890333dfad3bd83f4c
  def sign_transaction(
        %Update{} = pending_update,
        poi_encoded,
        state,
        verify_hook
      ) do
    %Update{tx: to_sign, round_initiator: round_initiator} = pending_update
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    # returns #aetx
    deserialized_signed_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    aetx = :aetx_sign.tx(deserialized_signed_tx)

    case poi_encoded do
      nil ->
        :ok

      _ ->
        # -spec fetch_amount_from_poi(aec_trees:poi(), aec_keys:pubkey()) -> amount().
        # we could alos consider aesc_utils:accounts_in_poi(Peers, PoI)
        {:ok, poi_binary} = :aeser_api_encoder.safe_decode(:poi, poi_encoded)
        poi = :aec_trees.deserialize_poi(poi_binary)

        {:account_pubkey, puk_key_binary} = :aeser_api_encoder.decode(state.session.initiator)
        {:ok, account} = :aec_trees.lookup_poi(:accounts, puk_key_binary, poi)

        Logger.debug("Accounts is#{inspect(account)}")
        balance = :aec_accounts.balance(account)
        Logger.debug("balance is #{inspect(balance)}")

        poi_hash = :aec_trees.poi_hash(poi)
        Logger.debug("poi hash is #{inspect(poi_hash)}")

        # aeu_mp_trees
    end

    case verify_hook.(aetx, round_initiator, state) do
      :unsecure ->
        ""

      :ok ->
        bin = :aetx.serialize_to_binary(aetx)
        # bin = signed_tx
        bin_for_network = <<state.network_id::binary, bin::binary>>
        result_signed = :enacl.sign_detached(bin_for_network, state.priv_key)
        # if there are signatures already make sure to preserve them.
        # signed_create_tx = :aetx_sign.new(aetx, [result_signed])
        signed_create_tx = :aetx_sign.add_signatures(deserialized_signed_tx, [result_signed])

        :aeser_api_encoder.encode(
          :transaction,
          :aetx_sign.serialize_to_binary(signed_create_tx)
        )
    end
  end

  def sign_transaction(
        to_sign,
        poi,
        state,
        verify_hook
      ) do
    sign_transaction(
      %Update{tx: to_sign, round_initiator: :not_implemented},
      poi,
      state,
      verify_hook
    )
  end
end
