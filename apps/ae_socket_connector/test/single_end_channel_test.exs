defmodule SingleEndChannelTest do
  use ExUnit.Case
  require Logger
  def clean_log_config_file(log_config) do
    File.rm(Path.join(log_config.log, log_config.log))
  end

  def name_test(context, suffix) do
    %{context | test: String.to_atom(Atom.to_string(context.test) <> suffix)}
  end

  @tag :hello_roboto
  @tag timeout: 60000 * 20
  @tag :ignore
  test "robot_only_responder", context do
    {alice, bob} = SocketConnectorTest.gen_names(context.test)

    scenario = fn {_initiator, _intiator_account}, {_responder, _responder_account}, _runner_pid ->
      [
        {:responder,
         %{
           message: {:channels_update, 1, :other, "channels.update"},
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 100_000_000_000_000_000) end, :empty},
           fuzzy: 10
         }},
        {:responder,
         %{
           message: {:channels_update, 2, :self, "channels.update"},
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 200_000_000_000_000_000) end, :empty},
           fuzzy: 10
         }},
        {:responder,
         %{
           message: {:channels_update, 3, :self, "channels.update"},
           next: {:async, fn pid -> SocketConnector.shutdown(pid) end, :empty},
           fuzzy: 100
         }}
      ]
    end

    channel_config =
      SessionHolderHelper.custom_config(%{}, %{
        minimum_depth: 0,
        port: 3050,
        responder_amount: 1_000_000_000_000_000_000,
        initiator_amount: 1_000_000_000_000_000_000,
        push_amount: 0,
        channel_reserve: 1,
        ttl: 1000,
        lock_period: 10
      })

    ClientRunner.start_peers(
      SocketConnectorHelper.ae_url(),
      SockerConnectorHelper.network_id(),
      %{
        initiator: %{
          name: alice,
          keypair: {"ak_2DDLbYBhHcuAzNg5Un853NRbUr8JVjZeMc6mTUpwmiVzA4ic6X", TestAccounts.initiatorPrivkey()},
          custom_configuration: channel_config,
          start: false
        },
        responder: %{
          name: bob,
          keypair: SocketConnectorTest.accounts_responder(),
          custom_configuration: channel_config
        }
      },
      scenario
    )
  end
end
