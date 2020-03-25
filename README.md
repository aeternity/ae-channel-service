# ae-channel-service

This is a reference client implementaion using the aeternity state channels. State channels allows secure transaction at very low fees.
Extensive documentation on aeternity state channels can be found [here](https://github.com/aeternity/protocol/blob/master/node/api/channels_api_usage.md).

The project consists of the following applications
* ae_socket_connector<br />
implements the FSM protocol and manages the websocket to the FSM (node connection).
* ae_channel_interface<br />
an interactive web interface which visualizes channel messages with the intention to ease onboarding.
* ae_backend_service<br />
sample backend service which could orchestrate a number of channels.

>ae_socket_connector benefits by being able to call erlang functions used by the aeternity node.

## Build

>you need to have elixir installed locally. Instructions [here](https://elixir-lang.org/install.html).

clone this repository, then;
```
make clean deps
```
> to get the user interface look sane you could also:  
`cd apps/ae_channel_interface/assets && npm install && cd -`



## Run interactive test client (local)

```bash
NODE_CONFIGURATION=./test/aeternity_node_normal_test_config.yml docker-compose up
AE_NODE_NETWORK_ID="ae_channel_service_test" iex -S mix phx.server
```

Point your browser to [http://localhost:4000/](http://localhost:4000/). Each tab can represent a peer. _Initiator_ or _responder_. "Backend helper" starts a channel governed by the [ae_backend_service](apps/ae_backend_service/lib/backend_session.ex) and does not affect the tab.

## Run sample interactive web client (testnet)

```bash
AE_NODE_URL="wss://testnet.aeternity.io:443/channel" AE_NODE_NETWORK_ID="ae_uat" iex -S mix phx.server
```

Point your browser to [http://localhost:4000/](http://localhost:4000/). Each tab can represent a peer. _Initiator_ or _responder_. "Backend helper" starts a channel governed by the [ae_backend_service](apps/ae_backend_service/lib/backend_session.ex) and does not affect the tab.
> testnet is currently load balanced, you need to be persistent (try again) to get your channel up and running. Current recomended worksround is to host your own node.

## Run test scenarios

Start the sample scenarios at your prompt by doing 
```bash
mix test
```

or for testnet
```bash
AE_NODE_URL="wss://testnet.aeternity.io:443/channel" AE_NODE_NETWORK_ID="ae_uat" mix test
```

Scenarios executed can be found [here](apps/ae_socket_connector/test/ae_socket_connector_test.exs)

> tests are designed to execute on a quick mining node, thus the test will 
fail when directed to testnet. This however is kept as reference.

# Advanced configuration

## Local node configuration

account used are found in [apps/ae_socket_connector/test/accounts_test.exs](apps/ae_socket_connector/test/accounts_test.exs)


## Testnet configuration

Create accounts [here](http://aeternity.com/documentation-hub/tutorials/account-creation-in-ae-cli/).

add valid accounts in [apps/ae_socket_connector/test/accounts_test.exs](apps/ae_socket_connector/test/accounts_test.exs).

Your account needs to exist on chain. To make it happen, just top up your accounts
[here](https://testnet.faucet.aepps.com/) and then you should be able to follow your on chain transactions [here](https://testnet.explorer.aepps.com).

## Node optional configuration

If you host your own node make sure to bump `counter`
by adding the following to your aeternity.yaml.

```yaml
regulators:
    sc_ws_handlers:
        counter: 100
        max_size: 5
```

Defaults can be found in your node config [here](https://github.com/aeternity/aeternity/blob/master/apps/aeutils/priv/aeternity_config_schema.json).

more documentation on node configuration can be found [here](https://github.com/aeternity/aeternity/blob/master/docs/configuration.md).

# Related references
* Refence to node api can be found [here](https://api-docs.aeternity.io/).
