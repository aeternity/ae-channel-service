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

        GenServer.cast(callback_pid, {:match_jobs, {:sign_approve, round, method}, to_sign})
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

  def start_session_holder_initiator() do
    {pub_key, priv_key} = keypair_initiator()
    {responder_pub_key, _responder_priv_key} = keypair_responder()

    color = :yellow
    {:ok, pid_session_holder} =
      SessionHolder.start_link(%{
        socket_connector: %{
          pub_key: pub_key,
          session: ClientRunner.default_configuration(pub_key, responder_pub_key),
          role: :initiator
        },
        log_config: %{},
        ae_url: ae_url(),
        network_id: network_id(),
        priv_key: priv_key,
        connection_callbacks: connection_callback(self(), color),
        color: color,
        pid_name: :some_name_initiator
      })
    pid_session_holder
  end

  def join("socket_connector:lobby", payload, socket) do
    if authorized?(payload) do
      pid_socket_holder = start_session_holder_initiator()
      {:ok, assign(socket, :pid_socket_holder, pid_socket_holder)}
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
    socket.assigns.pid_socket_holder
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end

  # Aleks
  def handle_cast(message, state) do
    broadcast state, "shout", %{message: inspect(message), name: "bot"}
    broadcast state, "shout", %{message: inspect(message), name: "bot2"}
    {:noreply, state}
  end
end
