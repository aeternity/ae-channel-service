defmodule SessionHolderHelper do

  def ae_url() do
    Application.get_env(:ae_socket_connector, :node)[:ae_url]
  end

  def network_id() do
    Application.get_env(:ae_socket_connector, :node)[:network_id]
  end

  def connection_callback(callback_pid, color, logfun \\ &(&1)) when is_atom(color) do
    %SocketConnector.ConnectionCallbacks{
      sign_approve: fn round_initiator, round, auto_approval, method, to_sign, channel_id, human ->
        logfun.({:sign_approve, %{round_initator: round_initiator, round: round, auto_approval: auto_approval, method: method, to_sign: to_sign, channel_id: channel_id, human: human, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:sign_approve, round, round_initiator, method, channel_id}, to_sign})
        auto_approval
      end,
      channels_info: fn round_initiator, round, method ->
        logfun.({:channels_info, %{round_initiator: round_initiator, round: round, method: method, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:channels_info, round, round_initiator, method}, nil})
      end,
      channels_update: fn round_initiator, round, method ->
        logfun.({:channels_update, %{round_initiator: round_initiator, round: round, method: method, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:channels_update, round, round_initiator, method}, nil})
      end,
      on_chain: fn round_initiator, round, method ->
        logfun.({:on_chain, %{round_initiator: round_initiator, round: round, method: method, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:on_chain, round, round_initiator, method}, nil})
      end,
      connection_update: fn status, reason ->
        logfun.({:connection_update, %{status: status, reason: reason, color: color}})
        GenServer.cast(callback_pid, {:connection_update, {status, reason}})
      end
    }
  end

  def connection_callback_runner(callback_pid, color, logfun \\ &(&1)) when is_atom(color) do
    %SocketConnector.ConnectionCallbacks{
      sign_approve: fn round_initiator, round, auto_approval, method, to_sign, channel_id, human ->
        logfun.({:sign_approve, %{round_initator: round_initiator, round: round, auto_approval: auto_approval, method: method, to_sign: to_sign, channel_id: channel_id, human: human, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:sign_approve, round, method}, to_sign})
        auto_approval
      end,
      channels_info: fn round_initiator, round, method ->
        logfun.({:channels_info, %{round_initiator: round_initiator, round: round, method: method, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:channels_info, round, round_initiator, method}, nil})
      end,
      channels_update: fn round_initiator, round, method ->
        logfun.({:channels_update, %{round_initiator: round_initiator, round: round, method: method, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:channels_update, round, round_initiator, method}, nil})
      end,
      on_chain: fn round_initiator, round, method ->
        logfun.({:on_chain, %{round_initiator: round_initiator, round: round, method: method, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:on_chain, round, round_initiator, method}, nil})
      end,
      connection_update: fn status, reason ->
        logfun.({:connection_update, %{status: status, reason: reason, color: color}})
        GenServer.cast(callback_pid, {:connection_update, {status, reason}})
      end
    }
  end

  def custom_connection_setting(role, _host_url) do
    same = %{
      channel_reserve: "2",
      lock_period: "10",
      port: "1500",
      protocol: "json-rpc",
      push_amount: "1",
      minimum_depth: 0,
      role: role
    }

    role_map =
      case role do
        :initiator ->
          # %URI{host: host} = URI.parse(host_url)
          # TODO Worksound to be able to connect to testnet
          # %{host: host, role: "initiator"}
          %{host: "localhost"}

        _ ->
          %{}
      end

    Map.merge(same, role_map)
  end

  def default_configuration(initiator_pub, responder_pub) do
    %{
      basic_configuration: %SocketConnector.WsConnection{
        initiator_id: initiator_pub,
        initiator_amount: 7_000_000_000_000,
        responder_id: responder_pub,
        responder_amount: 4_000_000_000_000
      },
      custom_param_fun: &custom_connection_setting/2
    }
  end

  def custom_config(overide_basic_param, override_custom) do
    fn initator_pub, responder_pub ->
      %{
        basic_configuration: struct(SessionHolderHelper.default_configuration(initator_pub, responder_pub).basic_configuration, overide_basic_param),
        custom_param_fun: fn role, host_url ->
          Map.merge(SessionHolderHelper.custom_connection_setting(role, host_url), override_custom)
        end
      }
    end
  end

  def start_session_holder(role, config, {_channel_id, _reestablish_port} = reestablish, keypair_initiator, keypair_responder, connection_callback_handler) when role in [:initiator, :responder] do

    {pub_key, priv_key} =
      case role do
        :initiator -> keypair_initiator.()
        :responder -> keypair_responder.()
      end

    {initiator_pub_key, _responder_priv_key} = keypair_initiator.()
    {responder_pub_key, _responder_priv_key} = keypair_responder.()

    color =
      case role do
        :initiator -> :yellow
        :responder -> :blue
      end

    connect_map = %{
        socket_connector: %{
          pub_key: pub_key,
          session: config.(initiator_pub_key, responder_pub_key),
          role: role
        },
        log_config: %{file: Atom.to_string(role) <> "_" <> pub_key},
        ae_url: ae_url(),
        network_id: network_id(),
        priv_key: priv_key,
        connection_callbacks: connection_callback_handler,
        color: color
      }
    case (reestablish) do
      {"", _reestablish_port} ->
        SessionHolder.start_link(connect_map)
      {channel_id, reestablish_port} ->
        SessionHolder.start_link(Map.merge(connect_map, %{reestablish: %{channel_id: channel_id, port: reestablish_port}}))
    end
  end

end
