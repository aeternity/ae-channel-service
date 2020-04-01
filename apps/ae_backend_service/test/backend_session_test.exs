defmodule AeBackendServiceTest do
  use ExUnit.Case
  doctest BackendSession

  # test "greets the world" do
  #   assert AeBackendService.hello() == :world
  # end

  test "backend dosen't allow restarting running channels" do
    {:ok, pid} = BackendServiceManager.start_link(%{"name" => :some_name})
    unique_id = 1234
    other_id = 234
    reestablish = {"channel_id", 2332}
    BackendServiceManager.set_channel_id(pid, unique_id, reestablish)
    reestablish = BackendServiceManager.get_channel_id(pid, unique_id)
    {"", 0} = BackendServiceManager.get_channel_id(pid, other_id)
    reestablish2 = {"channel_id2", 23322}
    BackendServiceManager.set_channel_id(pid, unique_id, reestablish)
    reestablish2 = BackendServiceManager.get_channel_id(pid, unique_id)
  end

  test "returns present pid if started" do
    unique_id = 1234
    reestablish = {"channel_id", 2332}
    unique_id2 = 12342
    reestablish2 = {"channel_id2", 23322}
    pid_self = self()
    pid_other = 12_314_421
    channel_id_table = %{unique_id => {reestablish, pid_self}, unique_id2 => {reestablish2, pid_other}}
    assert pid_self == BackendServiceManager.is_already_started(channel_id_table, {"channel_id", 1111})
    assert nil == BackendServiceManager.is_already_started(channel_id_table, {"channel_id_new", 1112})
  end
end
