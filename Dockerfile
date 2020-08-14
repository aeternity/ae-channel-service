FROM ubuntu:18.04

ENV otp_version 1:21.3.8.14-1
ENV elixir_version 1.9.4-1

RUN apt-get -qq update && apt-get install -qq -y build-essential curl wget jq git
RUN curl -sL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -qq -y nodejs
RUN wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && dpkg -i erlang-solutions_2.0_all.deb
# The Erlang/OTP version must be supported by the Aeternity node itself.
# The Elixir version should correspond to the version used in mix.exs.
RUN apt-get -qq update && apt-get -qq -y --allow-downgrades install esl-erlang=${otp_version} elixir=${elixir_version}
RUN curl -O https://download.libsodium.org/libsodium/releases/libsodium-1.0.17.tar.gz
RUN tar -xf libsodium-1.0.17.tar.gz && cd libsodium-1.0.17/ && ./configure && make && make install && ldconfig
RUN mix local.hex --force
RUN mix local.rebar --force

ADD . /app

WORKDIR /app

RUN make deps
RUN make compile
RUN cd apps/ae_channel_interface/assets && npm install
RUN mkdir data

EXPOSE 4000

CMD ["mix", "phx.server"]
