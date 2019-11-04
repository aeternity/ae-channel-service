defmodule Signer do
  # TODO this is the only module which needs the pivate key, should be spawed as a seperate process.
  require Logger
  alias SocketConnector.Update

  # TODO merge this with sign_transaction
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
        network_id, priv_key,
        verify_hook
      ) do
    # %Update{tx: to_sign, round_initiator: round_initiator} = pending_update

    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    # returns #aetx
    deserialized_signed_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    aetx = :aetx_sign.tx(deserialized_signed_tx)

    case verify_hook.(aetx, :ignore, nil) do
      :unsecure ->
        ""

      :ok ->
        bin = :aetx.serialize_to_binary(aetx)
        # bin = signed_tx
        bin_for_network = <<network_id::binary, bin::binary>>
        result_signed = :enacl.sign_detached(bin_for_network, priv_key)
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
        state,
        verify_hook \\ fn _tx, _round_initiator, _state -> :unsecure end
      )

  # https://github.com/aeternity/aeternity/commit/e164fc4518263db9692c02a9b84e179d69bfcc13#diff-e14138de459cdd890333dfad3bd83f4c
  def sign_transaction(
        %Update{} = pending_update,
        state,
        verify_hook
      ) do
    %Update{tx: to_sign, round_initiator: round_initiator} = pending_update

    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    # returns #aetx
    deserialized_signed_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    aetx = :aetx_sign.tx(deserialized_signed_tx)

    case verify_hook.(aetx, round_initiator, state) do
      :unsecure ->
        ""

      :ok ->
        bin = :aetx.serialize_to_binary(aetx)
        # bin = signed_tx
        Logger.error "CRASH0 #{inspect state}"
        Logger.error "CRASH1 #{inspect bin} #{inspect aetx}"
        Logger.error "CRASH2 #{inspect state.network_id}"

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
        state,
        verify_hook
      ) do
    sign_transaction(
      %Update{tx: to_sign, round_initiator: :not_implemented},
      state,
      verify_hook
    )
  end
end
