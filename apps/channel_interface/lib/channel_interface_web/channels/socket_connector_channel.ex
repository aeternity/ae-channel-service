defmodule ChannelInterfaceWeb.SocketConnectorChannel do
  use ChannelInterfaceWeb, :channel
  require Logger

  defmacro keypair_initiator, do: Application.get_env(:ae_socket_connector, :accounts)[:initiator]
  defmacro keypair_responder, do: Application.get_env(:ae_socket_connector, :accounts)[:responder]

  defmacro ae_url, do: Application.get_env(:ae_socket_connector, :node)[:ae_url]

  defmacro network_id, do: Application.get_env(:ae_socket_connector, :node)[:network_id]

  def connection_callback(callback_pid, color) do
    %SocketConnector.ConnectionCallbacks{
      sign_approve: fn round_initiator, round, auto_approval, method, to_sign, human ->
        Logger.debug(
          ":sign_approve, #{inspect(round)}, #{inspect(method)} extras: to_sign #{inspect(to_sign)} auto_approval: #{
            inspect(auto_approval)
          }, human: #{inspect(human)}, initiator #{inspect(round_initiator)}",
          ansi_color: color
        )

        GenServer.cast(callback_pid, {:match_jobs, {:sign_approve, round, "_not_implemented", method}, to_sign})
        auto_approval
      end,
      channels_info: fn round_initiator, round, method ->
        # log_callback(:channels_info, round, round_initiator, method, ansi_color: color)
        GenServer.cast(callback_pid, {:match_jobs, {:channels_info, round, round_initiator, method}, nil})
      end,
      channels_update: fn round_initiator, round, method ->
        # log_callback(:channels_update, round, round_initiator, method, ansi_color: color)
        GenServer.cast(callback_pid, {:match_jobs, {:channels_update, round, round_initiator, method}, nil})
      end,
      on_chain: fn round_initiator, round, method ->
        Logger.debug(
          "on_chain received round is: #{inspect(round)}, initated by: #{inspect(round_initiator)} method is #{
            inspect(method)
          }}",
          ansi_color: color
        )

        GenServer.cast(callback_pid, {:match_jobs, {:on_chain, round, round_initiator, method}, nil})
      end
    }
  end

  def sign_message_and_dispatch(pid_session_holder, method, to_sign) do
    signed = SessionHolder.sign_message(pid_session_holder, to_sign)
    fun = &SocketConnector.send_signed_message(&1, method, signed)
    SessionHolder.run_action(pid_session_holder, fun)
  end

  def start_session_holder(role, port, session_id) when role in [:initiator, :responder] do
    name = {:via, Registry, {Registry.SessionHolder, role}}

    case Registry.lookup(Registry.SessionHolder, role) do
      [{pid, _}] ->
        Logger.info("Server already running #{inspect pid}")
        # already running
        pid

      _ ->

        {pub_key, priv_key} =
          case role do
            :initiator -> keypair_initiator()
            :responder -> keypair_responder()
          end
        {initiator_pub_key, _responder_priv_key} = keypair_initiator()
        {responder_pub_key, _responder_priv_key} = keypair_responder()

        color = :yellow
        config = ClientRunner.custom_config(%{}, %{port: port})

        {:ok, pid_session_holder} =
          SessionHolder.start_link(%{
            socket_connector: %{
              pub_key: pub_key,
              session: config.(initiator_pub_key, responder_pub_key),
              role: role
            },
            log_config: %{},
            ae_url: ae_url(),
            network_id: network_id(),
            priv_key: priv_key,
            connection_callbacks: connection_callback(self(), color),
            color: color,
            pid_name: name
          })
        Process.unlink(pid_session_holder)
        Logger.error("Server not already running new pid is #{inspect pid_session_holder}")
        pid_session_holder
    end
  end

  def join("socket_connector:lobby", payload, socket) do
    Logger.debug "Connect, payload is #{inspect payload}"
    if authorized?(payload) do
      pid_session_holder = start_session_holder(String.to_atom(payload["role"]), String.to_integer(payload["port"]))
      {:ok, assign(socket, :pid_session_holder, pid_session_holder)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (socket_connector:lobby).
  def handle_in("shout", payload, socket) do
    socket.assigns.pid_session_holder
    push(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_in("sign", payload, socket) do
    Logger.info("Sign event from web ui #{inspect(payload)} sending to #{inspect(socket.assigns.pid_session_holder)}")
    sign_message_and_dispatch(socket.assigns.pid_session_holder, payload["method"], payload["to_sign"])
    # broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  #  next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 100_000_000_000_000_000) end, :empty},
  # fun = &SocketConnector.send_signed_message(&1, method, signed)
  #     SessionHolder.run_action(pid_session_holder, fun)

  def handle_in("transfer", payload, socket) do
    Logger.info("Transfer event from web ui #{inspect(payload)}")
    fun = &SocketConnector.initiate_transfer(&1, payload["amount"])
    SessionHolder.run_action(socket.assigns.pid_session_holder, fun)
    # sign_message_and_dispatch(socket.assigns.pid_session_holder, payload["method"], payload["to_sign"])
    # broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_in("shutdown", payload, socket) do
    Logger.info("shutdown #{inspect(payload)}")
    fun = &SocketConnector.shutdown(&1)
    SessionHolder.run_action(socket.assigns.pid_session_holder, fun)
    # sign_message_and_dispatch(socket.assigns.pid_session_holder, payload["method"], payload["to_sign"])
    # broadcast(socket, "shout", payload)
    {:noreply, socket}
  end


  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end

  # is this code operational?
  def handle_cast({:match_jobs, {:sign_approve, _round, _round_initator, method}, to_sign} = message, socket) do
    Logger.info("Sign request #{inspect(message)}")
    push(socket, "sign", %{message: inspect(message), method: method, to_sign: to_sign})
    push(socket, "shout", %{message: inspect(message), name: "bot"})
    # broadcast socket, "shout", %{message: inspect(message), name: "bot2"}
    {:noreply, socket}
  end

  def handle_cast(message, socket) do
    push(socket, "shout", %{message: inspect(message), name: "bot"})
    {:noreply, socket}
  end
end
