let
  stable = import (fetchTarball { # 20.03
    url =
      https://github.com/NixOS/nixpkgs-channels/archive/ab3adfe1c769c22b6629e59ea0ef88ec8ee4563f.tar.gz;
    sha256 = "1m4wvrrcvif198ssqbdw897c8h84l0cy7q75lyfzdsz9khm1y2n1";
  }) {};
in {
  aeternityEnv = stable.stdenv.mkDerivation {
    name = "ae-channel-service";
    buildInputs = [
      stable.beam.packages.erlangR21.elixir_1_9
      stable.docker-compose
      stable.libsodium
      stable.inotify-tools
      stable.nodejs
    ];
  };
}
