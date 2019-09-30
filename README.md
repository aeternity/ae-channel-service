# ae-channel-service

The [channel_runner](apps/ae_socket_connector/lib/channel_runner.ex) is to be considered as a `state-channel` client, which will execute several state channel operations, as token transfers and off-chain contract calls.

This implementation benefits by being able calling erlang functions provided by the core team.

## Build

```
make clean deps
make shell
```

## Configure

add valid accounts in [apps/ae_socket_connector/lib/test_accounts.ex](apps/ae_socket_connector/lib/test_accounts.ex)

These account must exist on the node.

add the address to your [æternity](https://github.com/aeternity/aeternity) node and your network id in [apps/ae_socket_connector/lib/channel_runner.ex](apps/ae_socket_connector/lib/channel_runner.ex#L4)

## Local node optional configuration

If you host your own node make sure to bump `counter`
by adding the following to your aeternity.yaml

```yaml
regulators:
    sc_ws_handlers:
        counter: 100
        max_size: 5
```

default can be found in you node config [here](https://github.com/aeternity/aeternity/blob/master/apps/aeutils/priv/aeternity_config_schema.json)

more documentation on node configuration can be found [here](https://github.com/aeternity/aeternity/blob/master/docs/configuration.md)

## Run

Start the sampel at your prompt by doing 
```bash
mix test
```

alternatively (in iex shell)
```elixir
iex(1)> ChannelRunner.start_channel_helper()
```

by default the command will start tests one by one found in the following [array](apps/ae_socket_connector/lib/client_runner.ex#L9), feel free to remove entries to get cleaner log outputs.
