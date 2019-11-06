# ae-channel-service

The channel service is to be considered as a `state-channel` client implementation, which will execute several state channel operations, as token transfers and off-chain contract calls.

This implementation benefits by being able calling erlang functions provided by the core team.

Read up on state channels [here](https://github.com/aeternity/protocol/blob/master/node/api/channels_api_usage.md)

## Build

```
make clean deps
make shell
```

## Configure - local node

add valid accounts in [apps/ae_socket_connector/test/accounts_test.exs](apps/ae_socket_connector/test/accounts_test.exs)

These account must exist on the node.

add the address to your [æternity](https://github.com/aeternity/aeternity) node and your network id in [apps/ae_socket_connector/config/config.exs](apps/ae_socket_connector/config/config.exs#L29)

## Configure - test net

Create accounts [here](http://aeternity.com/documentation-hub/tutorials/account-creation-in-ae-cli/)

add valid accounts in [apps/ae_socket_connector/test/accounts_test.exs](apps/ae_socket_connector/test/accounts_test.exs)

Your account needs to exist on chain. To make it happen, just top up your accounts
[here](https://testnet.faucet.aepps.com/) and then you should be able to follow your on chain transactions [here](https://testnet.explorer.aepps.com)

enable testnet by referencing testnet (remove comments) [apps/ae_socket_connector/config/config.exs](apps/ae_socket_connector/config/config.exs#L33)

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

Start the samples at your prompt by doing 
```bash
mix test
```

Scenarios executed can be found [here](apps/ae_socket_connector/test/ae_socket_connector_test.exs)

## Refence to node api

https://api-docs.aeternity.io/
