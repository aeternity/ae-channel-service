defmodule ClientRunner do
  use GenServer
  require Logger

  @ae_url "ws://localhost:3014/channel"
  @network_id "my_test"


  # @ae_url "wss://testnet.demo.aeternity.io/channel"
  # @network_id "ae_uat"

  # import TestScenarios
  # TODO :local always? produces a cast, could we move this to :local runner

  defmacro ae_url, do: @ae_url
  defmacro network_id, do: @network_id

  defstruct pid_session_holder: nil,
            color: nil,
            match_list: nil,
            fuzzy_counter: 0

  # def start_channel_helper(),
  #   do: ClientRunner.start_helper(@ae_url, @network_id, {TestAccounts.initiatorPubkeyEncoded(), TestAccounts.initiatorPrivkey()}, {TestAccounts.responderPubkeyEncoded(), TestAccounts.responderPrivkey()}, joblist())

  # def joblist(),
  #   do: [
  #     &hello_fsm_v3/3,
  #     &hello_fsm_v2/3,
  #     &withdraw_after_reconnect_v2/3,
  #     # &withdraw_after_reestablish/3,
  #     &backchannel_jobs_v2/3,
  #     &close_solo_v2/3,
  #     &close_mutual_v2/3,
  #     &reconnect_jobs_v2/3,
  #     &contract_jobs_v2/3,
  #     # &reestablish_jobs/3,
  #     # &query_after_reconnect/3,
  #     # # TODO missing "get state"
  #     # # This is unfinished, info callback needs to be refined and configurable minimg height.
  #     &teardown_on_channel_creation_v2/3
  #   ]

  def start_link(
        {_pub_key, _priv_key, _state_channel_configuration, _ae_url, _network_id, _role, _jobs, _color, _name} =
          params
      ) do
    GenServer.start_link(__MODULE__, params)
  end

  def connection_callback(callback_pid, color) do
    %SocketConnector.ConnectionCallbacks{
      sign_approve: fn round_initiator, round, auto_approval, human ->
        Logger.debug(
          "sign_approve received round is: #{inspect(round)}, initated by: #{inspect(round_initiator)}. auto_approval: #{
            inspect(auto_approval)
          }, containing: #{inspect(human)}",
          ansi_color: color
        )

        GenServer.cast(callback_pid, {:match_jobs, {:sign_approve, round}})
        auto_approval
      end,
      channels_info: fn round_initiator, round, method ->
        Logger.debug(
          "channels_info received round is: #{inspect(round)}, initated by: #{inspect(round_initiator)} method is #{
            inspect(method)
          }}",
          ansi_color: color
        )

        GenServer.cast(callback_pid, {:match_jobs, {:channels_info, round, round_initiator, method}})
      end,
      channels_update: fn round_initiator, round, method ->
        Logger.debug(
          "channels_update received round is: #{inspect(round)}, initated by: #{inspect(round_initiator)} method is #{
            inspect(method)
          }}",
          ansi_color: color
        )

        GenServer.cast(callback_pid, {:match_jobs, {:channels_update, round, round_initiator, method}})
      end
    }
  end

  def seperate_jobs(job_list) do
    {filter_jobs(job_list, :initiator), filter_jobs(job_list, :responder)}
  end

  def filter_jobs(job_list, role) do
    Enum.reduce(job_list, [], fn {runner, event}, acc ->
      case runner == role do
        true -> acc ++ [event]
        false -> acc
      end
    end)
  end

  # Server
  def init({pub_key, priv_key, state_channel_configuration, ae_url, network_id, role, jobs, color, name}) do
    {:ok, pid_session_holder} =
      SessionHolder.start_link(%{
        socket_connector: %SocketConnector{
          pub_key: pub_key,
          priv_key: priv_key,
          session: state_channel_configuration,
          role: role,
          connection_callbacks: connection_callback(self(), color)
        },
        ae_url: ae_url,
        network_id: network_id,
        color: color,
        pid_name: name
      })

    {:ok,
     %__MODULE__{
       pid_session_holder: pid_session_holder,
       match_list: jobs,
       color: [ansi_color: color]
     }}
  end

  def run_next(match) do
    case Map.get(match, :next, false) do
      false ->
        :ok

      job ->
        # Logger.debug("running next", state.color)
        GenServer.cast(self(), {:process_job_lists, job})
    end
  end

  # {:responder, :channels_info, 0, :transient, "channel_open"}
  def handle_cast({:match_jobs, message}, state) do
    case state.match_list do
      [%{message: expected} = match | rest] ->
        Logger.error(
          "expected #{inspect(expected)} received #{inspect(message)}",
          state.color
        )

        case expected == message do
          true ->
            run_next(match)
            {:noreply, %__MODULE__{state | match_list: rest, fuzzy_counter: 0}}

          false ->
            case Map.get(match, :fuzzy, 0) do
              0 ->
                throw("message not matching")

              value ->
                case state.fuzzy_counter >= value do
                  true ->
                    throw(
                      "message has not arrived, waited for #{inspect(state.fuzzy_counter)} max wait #{
                        inspect(value)
                      }"
                    )

                  false ->
                    Logger.debug(
                      "adding to counter... #{inspect(state.fuzzy_counter)} max wait #{inspect(value)}",
                      state.color
                    )

                    {:noreply, %__MODULE__{state | fuzzy_counter: state.fuzzy_counter + 1}}
                end
            end
        end

      [%{next: _next} = match | rest] ->
        run_next(match)
        {:noreply, %__MODULE__{state | match_list: rest, fuzzy_counter: 0}}

      [] ->
        Logger.debug("list empty", state.color)
        # Logger.info("Sending termination for #{inspect(state.socket_holder_name)}")
        # send(state.runner_pid, {:test_finished, state.socket_holder_name})
        {:noreply, state}
    end
  end

  def handle_cast({:process_job_lists, next}, state) do
    {mode, fun, assert_fun} = next

    case mode do
      :async ->
        SessionHolder.run_action(state.pid_session_holder, fun)

      :sync ->
        response = SessionHolder.run_action_sync(state.pid_session_holder, fun)

        case assert_fun do
          :empty -> :empty
          _ -> assert_fun.(response)
        end

        Logger.debug("sync response is: #{inspect(response)}", state.color)
        GenServer.cast(self(), {:match_jobs, {}})

      :local ->
        fun.(self(), state.pid_session_holder)
    end

    {:noreply, state}
  end

  def gen_name(name, suffix) do
    String.to_atom(to_string(name) <> Integer.to_string(suffix))
  end

  # elimiation overlap yields issues, need to be investigated
  @grace_period_ms 2000

  def start_helper(ae_url, network_id, initiator_keys, responder_keys, joblist) do
    Enum.each(Enum.zip(joblist, 1..Enum.count(joblist)), fn {fun, suffix} ->
      Logger.info("Launching next job in queue")
      start_peers(ae_url, network_id, {gen_name(:alice, suffix), initiator_keys}, {gen_name(:bob, suffix), responder_keys}, fun)
      Process.sleep(@grace_period_ms)
    end)
  end

  def await_finish([]) do
    Logger.debug("Scenario reached end")
  end

  def await_finish(expected_messages) do
    receive do
      {:test_finished, name} ->
        reduced_list = List.delete(expected_messages, name)

        Logger.debug("Received message from runner: #{inspect(name)} remaining: #{inspect(reduced_list)}")

        await_finish(reduced_list)
    end
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

  def start_peers(
        ae_url,
        network_id,
        {name_initiator, {initiator_pub, initiator_priv}},
        {name_responder, {responder_pub, responder_priv}},
        job_builder,
        configuration \\ &default_configuration/2
      ) do
    # initiator_pub = TestAccounts.initiatorPubkeyEncoded()
    # responder_pub = TestAccounts.responderPubkeyEncoded()

    Logger.debug("executing test: #{inspect(job_builder)}")

    {jobs_initiator, jobs_responder} =
      seperate_jobs(job_builder.({name_initiator, initiator_pub}, {name_responder, responder_pub}, self()))

    state_channel_configuration = configuration.(initiator_pub, responder_pub)

    start_link(
      {initiator_pub, initiator_priv, state_channel_configuration, ae_url,
       network_id, :initiator, jobs_initiator, :yellow, name_initiator}
    )

    start_link(
      {responder_pub, responder_priv, state_channel_configuration, ae_url,
       network_id, :responder, jobs_responder, :blue, name_responder}
    )

    await_finish([name_initiator, name_responder])
  end
end
