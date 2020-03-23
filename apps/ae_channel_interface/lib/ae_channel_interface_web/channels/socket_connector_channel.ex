defmodule AeChannelInterfaceWeb.SocketConnectorChannel do
  use AeChannelInterfaceWeb, :channel
  require Logger

  defmacro keypair_initiator, do: Application.get_env(:ae_socket_connector, :accounts)[:initiator]
  defmacro keypair_responder, do: Application.get_env(:ae_socket_connector, :accounts)[:responder]

  def sign_message_and_dispatch(pid_session_holder, method, to_sign) do
    signed = SessionHolder.sign_message(pid_session_holder, to_sign)
    fun = &SocketConnector.send_signed_message(&1, method, signed)
    SessionHolder.run_action(pid_session_holder, fun)
  end

  def join("socket_connector:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok,
       Phoenix.Socket.assign(socket,
         role: String.to_atom(payload["role"])
       )}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  defp log_callback({type, message}) do
    Logger.info(
      "interactive client: #{inspect({type, message})} pid is: #{inspect(self())}",
      ansi_color: Map.get(message, :color, nil)
    )
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # also covers reestablish
  def handle_in("connect/reestablish", payload, socket) do
    config = SessionHolderHelper.custom_config(%{}, %{port: payload["port"]})
    {:ok, pid_session_holder} =
      SessionHolderHelper.start_session_holder(socket.assigns.role, config, {payload["channel_id"], payload["port"]}, fn -> keypair_initiator() end, fn -> keypair_responder() end, SessionHolderHelper.connection_callback(self(), :yellow, &log_callback/1))

    {:noreply, assign(socket, :pid_session_holder, pid_session_holder)}
  end

  def handle_in(action, payload, socket) do
    socketholder_pid = socket.assigns.pid_session_holder

    case action do
      "leave" ->
        SessionHolder.leave(socketholder_pid)

      "teardown" ->
        SessionHolder.close_connection(socketholder_pid)

      "shutdown" ->
        fun = &SocketConnector.shutdown(&1)
        SessionHolder.run_action(socketholder_pid, fun)

      "transfer" ->
        fun = &SocketConnector.initiate_transfer(&1, payload["amount"])
        SessionHolder.run_action(socketholder_pid, fun)

      "sign" ->
        sign_message_and_dispatch(socketholder_pid, payload["method"], payload["to_sign"])

      "abort" ->
        fun = &SocketConnector.abort(&1, payload["method"], payload["abort_code"], "")
        SessionHolder.run_action(socketholder_pid, fun)
    end

    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end

  def handle_cast({:connection_update, {status, _reason} = update}, socket) do
    Logger.info("Connection update, #{inspect update}")
    push(socket, "log_event", %{message: inspect(update), name: "bot"})
    push(socket, Atom.to_string(status), %{})
    {:noreply, socket}
  end

  def handle_cast({:match_jobs, {:sign_approve, _round, _round_initiator, method, channel_id}, to_sign} = message, socket) do
    Logger.info("Sign request #{inspect(message)}")
    push(socket, "sign", %{message: inspect(message), method: method, to_sign: to_sign, channel_id: channel_id})
    push(socket, "log_event", %{message: inspect(message), name: "bot"})
    # broadcast socket, "log_event", %{message: inspect(message), name: "bot2"}
    {:noreply, socket}
  end

  def handle_cast(message, socket) do
    push(socket, "log_event", %{message: inspect(message), name: "bot"})
    {:noreply, socket}
  end
end
