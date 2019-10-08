defmodule ClientRunnerLegacy do
  # use GenServer
  require Logger
  import ClientRunnerHelper

  def empty_jobs(interval) do
    Enum.map(interval, fn count ->
      {:local,
       fn _client_runner, _pid_session_holder ->
         Logger.debug("doing nothing #{inspect(count)}", ansi_color: :white)
       end, :empty}
    end)
  end

  # reconstruct https://www.pivotaltracker.com/n/projects/2124891/stories/167944617
  def withdraw_after_reestablish(
        {initiator, _intiator_account},
        {responder, _responder_account},
        runner_pid
      ) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
      {:local, fn _client_runner, pid_session_holder -> SessionHolder.reestablish(pid_session_holder) end, :empty},
      {:async,
       fn pid ->
         SocketConnector.withdraw(pid, 1_000_000)
       end, :empty},
      {:async,
       fn pid ->
         SocketConnector.deposit(pid, 1_200_000)
       end, :empty},
      sequence_finish_job(runner_pid, initiator)
    ]

    jobs_responder =
      empty_jobs(1..1) ++
        [
          {:local,
           fn _client_runner, pid_session_holder ->
             SessionHolder.reestablish(pid_session_holder)
           end, :empty},
          sequence_finish_job(runner_pid, responder)
        ]

    {jobs_initiator, jobs_responder}
  end

  def reestablish_jobs({initiator, intiator_account}, {responder, responder_account}, runner_pid) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end, :empty},
      {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
      {:local,
       fn client_runner, pid_session_holder ->
         SessionHolder.reestablish(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      sequence_finish_job(runner_pid, initiator)
    ]

    jobs_responder =
      empty_jobs(1..2) ++
        [
          {:local,
           fn client_runner, pid_session_holder ->
             Logger.debug("reestablish 1")
             SessionHolder.reestablish(pid_session_holder)
             GenServer.cast(client_runner, {:process_job_lists})
           end, :empty},
          pause_job(5000),
          assert_funds_job(
            {intiator_account, 6_999_999_999_997},
            {responder_account, 4_000_000_000_003}
          ),
          pause_job(5000),
          # reestablish without leave
          {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
          pause_job(5000),
          {:local,
           fn client_runner, pid_session_holder ->
             Logger.debug("reestablish 2")
             SessionHolder.reestablish(pid_session_holder)
             GenServer.cast(client_runner, {:process_job_lists})
           end, :empty},
          pause_job(5000),
          assert_funds_job(
            {intiator_account, 6_999_999_999_997},
            {responder_account, 4_000_000_000_003}
          ),
          # pause_job(5000),
          sequence_finish_job(runner_pid, responder)
        ]

    {jobs_initiator, jobs_responder}
  end

  # query after violent reestablish
  def query_after_reconnect({initiator, intiator_account}, {responder, responder_account}, runner_pid) do
    jobs_initiator =
      empty_jobs(1..1) ++
        [
          assert_funds_job(
            {intiator_account, 7_000_000_000_001},
            {responder_account, 3_999_999_999_999}
          ),
          {:local,
           fn client_runner, pid_session_holder ->
             Logger.debug("killing previous connection 1")
             SessionHolder.kill_connection(pid_session_holder)
             Logger.debug("reestablish 1")
             SessionHolder.reestablish(pid_session_holder)
             GenServer.cast(client_runner, {:process_job_lists})
           end, :empty},
          assert_funds_job(
            {intiator_account, 7_000_000_000_001},
            {responder_account, 3_999_999_999_999}
          ),
          sequence_finish_job(runner_pid, responder)
        ]

    jobs_responder = [
      assert_funds_job(
        {intiator_account, 6_999_999_999_999},
        {responder_account, 4_000_000_000_001}
      ),
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
      pause_job(1000),
      assert_funds_job(
        {intiator_account, 7_000_000_000_001},
        {responder_account, 3_999_999_999_999}
      ),
      sequence_finish_job(runner_pid, initiator)
    ]

    {jobs_initiator, jobs_responder}
  end

  def teardown_on_channel_creation({initiator, _intiator_account}, {responder, _responder_account}, runner_pid) do
    # empty_jobs(1..1) ++
    jobs_initiator = [
      {:local,
       fn client_runner, pid_session_holder ->
         Logger.debug("close")
         # SessionHolder.kill_connection(pid_session_holder)
         SessionHolder.close_connection(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      pause_job(10000),
      {:local,
       fn client_runner, pid_session_holder ->
         Logger.debug("reestablish 1")
         SessionHolder.reestablish(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      # assert_funds_job(
      #   {intiator_account, 6_999_999_999_997},
      #   {responder_account, 4_000_000_000_003}
      # ),
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end, :empty},
      pause_job(5000),
      sequence_finish_job(runner_pid, responder)
    ]

    jobs_responder = [
      sequence_finish_job(runner_pid, initiator)
    ]

    {jobs_initiator, jobs_responder}
  end
end
