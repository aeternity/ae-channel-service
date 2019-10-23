defmodule TestScenarios do
  use ExUnit.Case
  require Logger
  # import ClientRunnerHelper

  # example
  # %{
  # {:initiator, %{message: {:channels_update, 1, :transient, "channels.update"}, next: {:run_job}, fuzzy: 3}},
  # }



  # def hello_fsm_v3({initiator, _intiator_account}, {responder, _responder_account}, runner_pid),
  #   do: [
  #     {:initiator,
  #      %{
  #        message: {:channels_update, 1, :transient, "channels.update"},
  #        next: {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
  #        fuzzy: 10
  #      }},
  #     {:responder,
  #      %{
  #        message: {:channels_update, 1, :transient, "channels.leave"},
  #        fuzzy: 20,
  #        next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
  #      }},
  #     {:initiator,
  #      %{
  #        message: {:channels_info, 0, :transient, "died"},
  #        fuzzy: 20,
  #        next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
  #      }}
  #   ]

  # def backchannel_jobs_v2({initiator, intiator_account}, {responder, responder_account}, runner_pid),
  #   do: [

  #   ]





end
