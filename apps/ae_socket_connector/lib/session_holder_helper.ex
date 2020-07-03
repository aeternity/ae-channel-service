defmodule SessionHolderHelper do
  def ae_url_ws(), do: Application.get_env(:ae_socket_connector, :node)[:ae_url_ws]
  def ae_url_http(), do: Application.get_env(:ae_socket_connector, :node)[:ae_url_http]

  def network_id() do
    Application.get_env(:ae_socket_connector, :node)[:network_id]
  end

  def connection_callback(callback_pid, color, logfun \\ & &1) when is_atom(color) do
    %SocketConnector.ConnectionCallbacks{
      sign_approve: fn round_initiator, round, auto_approval, method, to_sign, updates, channel_id, human ->
        logfun.(
          {:sign_approve,
           %{
             round_initator: round_initiator,
             round: round,
             auto_approval: auto_approval,
             method: method,
             to_sign: to_sign,
             updates: updates,
             channel_id: channel_id,
             human: human,
             color: color
           }}
        )

        GenServer.cast(
          callback_pid,
          {{:sign_approve, round, round_initiator, method, updates, human, channel_id}, to_sign}
        )

        auto_approval
      end,
      channels_info: fn method, channel_id ->
        logfun.({:channels_info, %{method: method, channel_id: channel_id, color: color}})
        GenServer.cast(callback_pid, {:channels_info, method, channel_id})
      end,
      channels_update: fn round_initiator, round, method ->
        logfun.(
          {:channels_update, %{round_initiator: round_initiator, round: round, method: method, color: color}}
        )

        GenServer.cast(
          callback_pid,
          {:channels_update, round, round_initiator, method}
        )
      end,
      on_chain: fn info, _channel_id ->
        logfun.({:on_chain, %{info: info, color: color}})
        GenServer.cast(callback_pid, {:on_chain, info})
      end,
      connection_update: fn status, reason ->
        logfun.({:connection_update, %{status: status, reason: reason, color: color}})
        GenServer.cast(callback_pid, {:connection_update, {status, reason}})
      end
    }
  end

  def connection_callback_runner(callback_pid, color, logfun \\ & &1) when is_atom(color) do
    %SocketConnector.ConnectionCallbacks{
      sign_approve: fn round_initiator, round, auto_approval, method, to_sign, updates, channel_id, human ->
        logfun.(
          {:sign_approve,
           %{
             round_initator: round_initiator,
             round: round,
             auto_approval: auto_approval,
             method: method,
             to_sign: to_sign,
             updates: updates,
             channel_id: channel_id,
             human: human,
             color: color
           }}
        )

        GenServer.cast(callback_pid, {:match_jobs, {:sign_approve, round, method}, to_sign})
        auto_approval
      end,
      channels_info: fn method, channel_id ->
        logfun.({:channels_info, %{method: method, channel_id: channel_id, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:channels_info, method}, nil})
      end,
      channels_update: fn round_initiator, round, method ->
        logfun.(
          {:channels_update, %{round_initiator: round_initiator, round: round, method: method, color: color}}
        )

        GenServer.cast(
          callback_pid,
          {:match_jobs, {:channels_update, round, round_initiator, method}, nil}
        )
      end,
      on_chain: fn info, _channel_id ->
        logfun.({:on_chain, %{info: info, color: color}})
        GenServer.cast(callback_pid, {:match_jobs, {:on_chain, info}, nil})
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
        basic_configuration:
          struct(
            SessionHolderHelper.default_configuration(initator_pub, responder_pub).basic_configuration,
            overide_basic_param
          ),
        custom_param_fun: fn role, host_url ->
          Map.merge(
            SessionHolderHelper.custom_connection_setting(role, host_url),
            override_custom
          )
        end
      }
    end
  end

  defp generate_log_config(role, pub_key, path) do
    %{file: Atom.to_string(role) <> "_" <> pub_key, path: path}
  end

  def start_session_holder(
        role,
        config,
        {_channel_id, _reestablish_port} = reestablish,
        keypair_initiator,
        keypair_responder,
        connection_callback_handler
      )
      when role in [:initiator, :responder] do
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
      log_config: generate_log_config(role, pub_key, "data"),
      ae_url: ae_url_ws(),
      network_id: network_id(),
      priv_key: priv_key,
      connection_callbacks: connection_callback_handler,
      color: color
    }

    case reestablish do
      {"", _reestablish_port} ->
        SessionHolder.start_link(connect_map)

      {channel_id, reestablish_port} ->
        SessionHolder.start_link(
          Map.merge(connect_map, %{reestablish: %{channel_id: channel_id, port: reestablish_port}})
        )
    end
  end

  defp collect_keys_iter(dets), do: collect_keys_iter(dets, :dets.first(dets))
  defp collect_keys_iter(_, :"$end_of_table"), do: []

  defp collect_keys_iter(dets, current) do
    [current] ++ collect_keys_iter(dets, :dets.next(dets, current))
  end

  require Logger

  def open?(channel_info) do
    closed = for {_channel_id, %{state: %{closed: true}}} <- channel_info, do: true

    case closed do
      [] -> true
      _ -> false
    end
  end

  # closed channels are not listed per default
  def list_channel_ids(role, pub_key, path \\ "data", filter \\ &open?/1) do
    log_config = generate_log_config(role, pub_key, path)
    file_name_and_path = Path.join(Map.get(log_config, :path, path), Map.get(log_config, :file))

    Logger.info("File_name when listing channels is #{inspect(Path.absname(file_name_and_path))}")

    case :dets.open_file(String.to_atom(file_name_and_path), type: :duplicate_bag) do
      {:ok, ref} ->
        Enum.filter(collect_keys_iter(ref), fn channel_id ->
          filter.(:dets.lookup(ref, channel_id))
        end)

      message ->
        Logger.warn("problem opening file #{inspect(message)}")
        []
    end
  end

  def get_channel_info(role, pub_key, channel_id, path \\ "data") do
    log_config = generate_log_config(role, pub_key, path)
    file_name_and_path = Path.join(Map.get(log_config, :path, path), Map.get(log_config, :file))

    case :dets.open_file(String.to_atom(file_name_and_path), type: :duplicate_bag) do
      {:ok, ref} ->
        :dets.lookup(ref, channel_id)

      _ ->
        []
    end
  end
end
