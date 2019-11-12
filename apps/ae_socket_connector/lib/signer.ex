defmodule Signer do
  # TODO this is the only module which needs the pivate key, should be spawed as a seperate process.
  require Logger

  # TODO merge this with sign_transaction
  def sign_aetx(aetx, network_id, priv_key) do
    Logger.debug "signing decoded transaction"
    bin = :aetx.serialize_to_binary(aetx)
    bin_for_network = <<network_id::binary, bin::binary>>
    result_signed = :enacl.sign_detached(bin_for_network, priv_key)
    signed_create_tx = :aetx_sign.new(aetx, [result_signed])

    :aeser_api_encoder.encode(
      :transaction,
      :aetx_sign.serialize_to_binary(signed_create_tx)
    )
  end

  # TODO clean up.. remove verify hook from here
  def sign_transaction(
        to_sign,
        network_id,
        priv_key,
        verify_hook
      ) do
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    # returns #aetx
    Logger.debug "signing transaction"
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
end
