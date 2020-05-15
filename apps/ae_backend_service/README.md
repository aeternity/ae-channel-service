# ae-backend-service

This runner showcases a server backend which orchestrates multiple channels, backend represents the `responder`.

As a reference a simple `coin-toss` game is showcased. A reference client acting as the `initiator` can be found [here](https://github.com/aeternity/coin-toss-game)

Alternatively the game can be played using the the [interactive client](apps/ae_channel_interface/README.md), make sure to obey the rules of the game which is described below.

The game logic itself is implemented [here](/apps/ae_backend_service/lib/backend_session.ex) 

### Details on the current backend session

Short description, steps marked with (*) require co-signing, that is; signature by both participants 
```
1. channel is opened (*)
2. backend provides contract (*)
3. player provides a stake N tokens and a hash `compute_hash` based on guess which is heads|tails, and the secret key (salt) (*)
4. backend makes a coin_side guess with `casino_pick` and also provides N tokens to be able to participate (*)
5. client reveals `reveal` by providing key (salt) and the selected coin_side, tokens are now redistributed (*)
6. goto 3 ( ) or shutdown (*) which return tokens on-chain
```

### Force progress

If the client `initiator` refuses to reveal, a `fp_timer` also present in the game logic file will kick in starting a force progress. In this way the backend ensures that it is able to retrive it's tokens.


### Custom parameters 

In order to test specific scenarios the backend behaviour can be configured with the following parameters:
```bash
TOSS_MODE="random|tails|heads" GAME_MODE="fair|malicious" FORCE_PROGRESS_HEIGHT="15|any_positive_integer" 
MINE_RATE="180000|any_positive_integer"
AE_NODE_URL="wss://testnet.aeternity.io:443/channel" AE_NODE_NETWORK_ID="ae_uat" iex -S mix phx.server
```
