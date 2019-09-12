# ae-channel-service

The [channel_runner](apps/ae_socket_connector/lib/channel_runner.ex) is to be considered as a `state-channel` client, which will execute several state channel operations, as token transfers and off-chain contract calls.

This implementation benefits by being able calling erlang functions provided by the core team.

## Build

```
make clean deps
make shell
```
requires OTP 20.3

## Configure

add valid accounts in [apps/ae_socket_connector/lib/test_accounts.ex](apps/ae_socket_connector/lib/test_accounts.ex)

add the address to your [æternity](https://github.com/aeternity/aeternity) node and your network id in [apps/ae_socket_connector/lib/channel_runner.ex](apps/ae_socket_connector/lib/channel_runner.ex#L4)

## Run

Start the code (in iex shell)
```
iex(1)> ChannelRunner.start_channel_helper()
```

by default the command will start all tests (in parallel) found in the following [array](apps/ae_socket_connector/lib/client_runner.ex#L391), feel free to remove entries to get cleaner log outputs.
