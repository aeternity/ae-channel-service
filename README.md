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

## Run testscenarios

Start the samples at your prompt by doing 
```bash
mix test
```

or for testnet
```bash
AE_NODE_URL="wss://testnet.aeternity.io:443/channel" AE_NODE_NETWORK_ID="ae_uat" mix test
```

Scenarios executed can be found [here](apps/ae_socket_connector/test/ae_socket_connector_test.exs)

> tests are designed to execute on a quick mining node, thus the test will 
fail when directed to testnet. This is however keps as referense.


## Run interactive test client (local)

```bash
NODE_CONFIGURATION=/test/aeternity_node_normal_test_config.yml docker-compose up
AE_NODE_NETWORK_ID="ae_channel_service_test" iex -S mix phx.server
```

Now, point your browser to [http://localhost:4000/](http://localhost:4000/)

## Run sample interactive web client (testnet)

```bash
AE_NODE_URL="wss://testnet.aeternity.io:443/channel" AE_NODE_NETWORK_ID="ae_uat" iex -S mix phx.server
```

point your browser to `http://localhost:4000/`
> testnet is currently load balanced, you need to be persistent (try again) to get your channel up and running. Current recomended worksround is to host your own node.

> if your interface is missing CSS you need to:  
`cd apps/ae_channel_interface/assets && npm install && cd -`

## Refence to node api

https://api-docs.aeternity.io/
