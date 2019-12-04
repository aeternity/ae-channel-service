defmodule Validator do
  require Logger
  alias SocketConnector.WsConnection
  alias SocketConnector.Update

  def get_state_hash(tx) do
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, tx)
    deserialized = :aetx_sign.deserialize_from_binary(signed_tx)
    # get aetx
    aetx = :aetx_sign.tx(deserialized)
    {module, instance} = :aetx.specialize_callback(aetx)
    # module is :aesc_offchain_tx or :aesc_create_tx
    apply(module, :state_hash, [instance])
  end

  def get_state_round(tx) do
    # signed_tx(aetx(off-chain_tx))
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, tx)
    deserialized = :aetx_sign.deserialize_from_binary(signed_tx)
    # get aetx
    aetx = :aetx_sign.tx(deserialized)
    {module, instance} = :aetx.specialize_callback(aetx)
    apply(module, :round, [instance])
  end

  # not used remove or, re-use inmplemetation
  defp channel_create_tx(tx, state) do
    # TODO make sure to verify that what we are signing matches according to the original request made.
    # module is: aesc_create_tx
    {module, tx_instance} = :aetx.specialize_callback(tx)
    initiator_pub_key = apply(module, :initiator_pubkey, [tx_instance])
    initiator_amount = apply(module, :initiator_amount, [tx_instance])
    responder_pub_key = apply(module, :responder_pubkey, [tx_instance])
    responder_amount = apply(module, :responder_amount, [tx_instance])

    case (_sign_map = %WsConnection{
            initiator_id: :aeser_api_encoder.encode(:account_pubkey, initiator_pub_key),
            responder_id: :aeser_api_encoder.encode(:account_pubkey, responder_pub_key),
            initiator_amount: initiator_amount,
            responder_amount: responder_amount
          }) == state.session.basic_configuration do
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

  defp send_approval_request(to_sign, round_initiator, method, auto_approval, state) do
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    # returns #aetx
    deserialized_signed_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    aetx = :aetx_sign.tx(deserialized_signed_tx)

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
            # round = apply(module, :nonce, [instance])
            sign_approve.(round_initiator, 0, auto_approval, method, to_sign, :aetx.serialize_for_client(aetx))

          :aesc_slash_tx ->
            # todo code missing there. we should get the round somehow.
            sign_approve.(round_initiator, 0, auto_approval, method, to_sign, :aetx.serialize_for_client(aetx))

          # apply(module, :for_client, [instance])
          :aesc_settle_tx ->
            # todo code missing there. we should get the round somehow.
            sign_approve.(round_initiator, 0, auto_approval, method, to_sign, :aetx.serialize_for_client(aetx))

          # apply(module, :for_client, [instance])

          trasaction_type when trasaction_type in [:aesc_close_solo_tx] ->
            %{"payload" => payload} = apply(module, :for_client, [instance])
            {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, payload)
            deserialized_signed_tx = :aetx_sign.deserialize_from_binary(signed_tx)
            aetx = :aetx_sign.tx(deserialized_signed_tx)
            {module, instance} = :aetx.specialize_callback(aetx)
            round = apply(module, :round, [instance])
            sign_approve.(round_initiator, round, auto_approval, method, to_sign, :aetx.serialize_for_client(aetx))

          _ ->
            round = apply(module, :round, [instance])
            sign_approve.(round_initiator, round, auto_approval, method, to_sign, :aetx.serialize_for_client(aetx))
        end
    end
  end

  def notify_sign_transaction(
        to_sign,
        method,
        state
      )

  def notify_sign_transaction(
        %Update{} = pending_update,
        method,
        state
      ) do
    %Update{tx: to_sign, round_initiator: round_initiator} = pending_update

    # The idea here is that if we initiated the round we can automatically confirm that the sign request contians what we intended. Grab code from inspect_sign_request
    auto_approval = :ok

    case send_approval_request(to_sign, round_initiator, method, auto_approval, state) do
      :ok -> :ok
      _ -> :unsecure
    end
  end

  def notify_sign_transaction(
        to_sign,
        method,
        state
      ) do
    notify_sign_transaction(
      %Update{tx: to_sign, round_initiator: :not_implemented},
      method,
      state
    )
  end

  # not used remove or, re-use inmplemetation
  def inspect_sign_request_poi(method, poi) do
    fn a, b, c -> inspect_sign_request(a, b, method, c, poi) end
  end

  # not used remove or, re-use inmplemetation
  def inspect_sign_request(aetx, round_initiator, method, state, poi \\ nil) do
    {module, _tx_instance} = :aetx.specialize_callback(aetx)

    # TODO if calls is initiated by us and contains what we submitted auto approval can be made
    auto_approval =
      case module do
        :aesc_create_tx ->
          channel_create_tx(aetx, state)

        :aesc_close_mutual_tx ->
          # TODO match_pot_aetx is currently doing the notify_sign_transactionsame checking...
          match_poi_aetx(
            {poi, [state.session.basic_configuration.initiator_id, state.session.basic_configuration.responder_id],
             []},
            aetx,
            state.round_and_updates
          )

        _other ->
          Logger.debug("Sign request Missing inspection!! default approved. Module is #{inspect(module)}")

          :ok
      end

    case send_approval_request(aetx, round_initiator, method, auto_approval, state) do
      :ok -> :ok
      _ -> :unsecure
    end
  end

  @ae_transaction_path "/v2/transactions/"
  # shot this curl to check wheater onchain is alright....
  def verify_on_chain(tx, ws_url) do
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, tx)
    deserialized_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    tx_hash = :aetx_sign.hash(deserialized_tx)
    serialized_hash = :aeser_api_encoder.encode(:tx_hash, tx_hash)

    %URI{host: host, authority: _authority} = URI.parse(ws_url)

    url_to_check =
      URI.to_string(%URI{
        host: host,
        port: 3013,
        scheme: "http",
        path: @ae_transaction_path <> URI.encode(serialized_hash)
      })

    Logger.debug("url to check: curl #{inspect(url_to_check)}")
  end

  def match_poi_aetx({poi, [initiator, responder], contracts}, to_sign, state_tx) do
    {poi_hash, accounts_and_values} = extract_poi_hash(poi, [initiator, responder], contracts)

    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)

    deserialized_signed_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    aetx = :aetx_sign.tx(deserialized_signed_tx)

    {module, instance} = :aetx.specialize_callback(aetx)

    case poi_hash == get_state_hash(state_tx) do
      true ->
        case module do
          :aesc_close_mutual_tx ->
            expected_after_fee = [
              {
                initiator,
                apply(module, :initiator_amount_final, [instance])
              },
              {
                responder,
                apply(module, :responder_amount_final, [instance])
              }
            ]

            Logger.debug("Values #{inspect(accounts_and_values)}")

            [fee_initiator, fee_responder] =
              Enum.map(expected_after_fee, fn {account, account_funds} ->
                Map.get(accounts_and_values, account) - account_funds
              end)

            correct_fee_and_funds =
              abs(fee_initiator - fee_responder) <= 1 &&
                fee_initiator + fee_responder == apply(module, :fee, [instance])

            case correct_fee_and_funds do
              true ->
                Logger.debug("Poi checked for module and matches well")
                :ok

              _ ->
                Logger.error(
                  "Poi missmatch, lets go slashing, #{inspect(fee_initiator)} #{inspect(fee_responder)} #{
                    inspect(apply(module, :fee, [instance]))
                  }"
                )

                :unsecure
            end

          module ->
            # TODO if we have a POI we could at least check the the root hashes mathes
            # poi_hash == get_state_hash(tx)
            Logger.debug("PoI detailed checking not implemented yet for #{inspect(module)}")
            :ok
        end

      false ->
        Logger.error("Poi hash missmatch, lets go slashing")
    end
  end

  defp extract_poi_hash(poi_encoded, accounts, _contracts) do
    # alternatively -spec fetch_amount_from_poi(aec_trees:poi(), aec_keys:pubkey()) -> amount().
    {:ok, poi_binary} = :aeser_api_encoder.safe_decode(:poi, poi_encoded)
    poi = :aec_trees.deserialize_poi(poi_binary)

    poi_hash = :aec_trees.poi_hash(poi)

    # alternative
    {:ok, accounts_in_poi} =
      :aesc_utils.accounts_in_poi(
        Enum.map(accounts, fn account ->
          {:account_pubkey, pub_key_binary} = :aeser_api_encoder.decode(account)
          pub_key_binary
        end),
        poi
      )

    accounts_with_values =
      Enum.reduce(accounts_in_poi, %{}, fn account, acc ->
        serialized_pubkey = :aeser_api_encoder.encode(:account_pubkey, :aec_accounts.pubkey(account))

        Map.put(acc, serialized_pubkey, :aec_accounts.balance(account))
      end)

    {poi_hash, accounts_with_values}
  end
end
