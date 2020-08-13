# ae-channel-service

This is a reference client implementation using the aeternity state channels. State channels allows secure transaction at very low fees.
Extensive documentation on aeternity state channels can be found [here](https://github.com/aeternity/protocol/blob/master/node/api/channels_api_usage.md).

The project consists of the following applications
* ae_socket_connector<br />
implements the FSM protocol and manages the websocket to the FSM (node connection).
This application will automatically persist channel_id and related data allowing reestablish. 
> Default location is `./data`. remove folder to start from a clean slate. Location is configurable as shown in example [here](https://github.com/aeternity/ae-channel-service/blob/4c40727b28b9ce5dec2231a2fa9ed46dd8618ccd/apps/ae_socket_connector/lib/session_holder_helper.ex#L185).
* ae_channel_interface<br />
an interactive web interface which visualizes channel messages with the intention to ease onboarding. Read more [here](apps/ae_channel_interface/README.md).
* ae_backend_service<br />
sample backend service which can orchestrate a number of channels. Current implementation showcases a `coin toss` backend service. Read more on `ae_backend_service` [here](apps/ae_backend_service/README.md).

>ae_socket_connector benefits by being able to call erlang functions used by the aeternity node.

## Build

>you need to have elixir installed locally. Instructions [here](https://elixir-lang.org/install.html).

clone this repository, then;
```
cd ae-channel-service/
make clean deps # requires jq to be installed
```
> to get the user interface look sane you could also:  
`cd apps/ae_channel_interface/assets && npm install && cd -`



## Run interactive test client (local)

```bash
NODE_REF=master NODE_CONFIGURATION=./test/aeternity_node_normal_test_config.yml docker-compose up
AE_NODE_NETWORK_ID="ae_channel_service_test" iex -S mix phx.server
```

Point your browser to [http://localhost:4000/](http://localhost:4000/). Each tab can represent a peer. _Initiator_ or _responder_. "Backend helper" starts a channel governed by the [ae_backend_service](apps/ae_backend_service/lib/backend_session.ex) and does not affect the tab.

## Run sample interactive web client (testnet)

```bash
AE_NODE_URL="wss://testnet.aeternity.io:443/channel" AE_NODE_NETWORK_ID="ae_uat" iex -S mix phx.server
```

More detailed when needed
```bash
TOSS_MODE="random|tails|heads" GAME_MODE="fair|malicious" FORCE_PROGRESS_HEIGHT="15|any_positive_integer" AE_NODE_URL="wss://testnet.aeternity.io:443/channel" AE_NODE_NETWORK_ID="ae_uat" iex -S mix phx.server
```
> defaults are listed as first available option

Point your browser to [http://localhost:4000/](http://localhost:4000/). Each tab can represent a peer. _Initiator_ or _responder_. "Backend helper" starts a channel governed by the [ae_backend_service](apps/ae_backend_service/lib/backend_session.ex) and does not affect the tab.
> testnet is currently load balanced, you need to be persistent (try again) to get your channel up and running. Current recommended workaround is to host your own node.

## Get going with the interactive web client 
Get started [here](apps/ae_channel_interface/README.md)

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
* Reference to node api can be found [here](https://api-docs.aeternity.io/).
