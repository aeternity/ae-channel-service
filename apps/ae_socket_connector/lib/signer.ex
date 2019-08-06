defmodule Signer do
  # TODO this is the only module which needs the pivate key, should be spawed as a seperate process.
  require Logger

  def sign_transaction(to_sign, authenticator, state, method: method, logstring: logstring) do
    {enc_signed_create_tx} = sign_transaction_perform(to_sign, state, authenticator)
    response = %{jsonrpc: "2.0", method: method, params: %{signed_tx: enc_signed_create_tx}}
    Logger.debug("=>#{inspect(logstring)} : #{inspect(response)} #{inspect(self())}", state.color)
    {response}
  end

  # https://github.com/aeternity/aeternity/commit/e164fc4518263db9692c02a9b84e179d69bfcc13#diff-e14138de459cdd890333dfad3bd83f4c
  defp sign_transaction_perform(
         to_sign,
         state,
         verify_hook \\ fn _tx, _state -> :unsecure end
       ) do
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    # returns #aetx
    deserialized_signed_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    aetx = :aetx_sign.tx(deserialized_signed_tx)

    case verify_hook.(aetx, state) do
      :unsecure ->
        {""}

      :ok ->
        bin = :aetx.serialize_to_binary(aetx)
        # bin = signed_tx
        bin_for_network = <<state.network_id::binary, bin::binary>>
        result_signed = :enacl.sign_detached(bin_for_network, state.priv_key)
        # if there are signatures already make sure to preserve them.
        # signed_create_tx = :aetx_sign.new(aetx, [result_signed])
        signed_create_tx = :aetx_sign.add_signatures(deserialized_signed_tx, [result_signed])

        {:aeser_api_encoder.encode(
           :transaction,
           :aetx_sign.serialize_to_binary(signed_create_tx)
         )}
    end
  end
end
