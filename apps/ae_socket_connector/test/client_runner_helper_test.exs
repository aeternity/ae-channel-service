defmodule ClientRunnerHelper do
  use ExUnit.Case
  require Logger

  def sequence_finish_job(runner_pid, name) do
    {:local,
     fn _client_runner, _pid_session_holder ->
       send(runner_pid, {:test_finished, name})
     end, :empty}
  end

  def pause_job(delay) do
    {:local,
     fn client_runner, _pid_session_holder ->
       Logger.debug("requested pause for: #{inspect(delay)}ms")

       spawn(fn ->
         Process.sleep(delay)
         resume_runner(client_runner)
       end)
     end, :empty}
  end

  def resume_runner(client_runner) do
    GenServer.cast(client_runner, {:match_jobs, {}, nil})
  end


  # TODO time to move this module to ex unit
  def expected(response, {account1, value1}, {account2, value2}) do
    expect =
      Enum.sort([
        %{"account" => account1, "balance" => value1},
        %{"account" => account2, "balance" => value2}
      ])

    # Logger.debug("expected #{inspect(Enum.sort(expect))}")
    # Logger.debug("got      #{inspect(response)}")
    assert expect == Enum.sort(response)
  end

  def assert_funds_job({account1, value1}, {account2, value2}) do
    {:sync,
     fn pid, from ->
       SocketConnector.query_funds(pid, from)
     end,
     fn result ->
       expected(result, {account1, value1}, {account2, value2})
     end}
  end

end
