{
  description = "Cookie Cloud Server Development Environment and Docker Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        beamPackages = pkgs.beam.packages.erlang_27;
        elixir = beamPackages.elixir_1_18;

        pname = "cookie_cloud_server";
        version = "0.1.0";

        # Use the generated deps.nix
        mixDeps = import ./deps.nix {
          inherit (pkgs) lib;
          inherit beamPackages;
          overrides = (
            self: super: {
              exqlite = super.exqlite.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
                buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.sqlite ];
                preBuild = (old.preBuild or "") + ''
                  export HOME=$TMPDIR
                  export EXQLITE_FORCE_BUILD=1
                '';
              });
            }
          );
        };

        cookie_cloud_server = beamPackages.mixRelease {
          inherit pname version;
          src = ./.;
          mixNixDeps = mixDeps;

          buildInputs = with pkgs; [ sqlite ];
          nativeBuildInputs = with pkgs; [ pkg-config ];
        };

        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "ghcr.io/ll1zt/cookie_cloud_server";
          tag = "latest";

          contents = [
            pkgs.coreutils
            pkgs.bash
            pkgs.sqlite
            pkgs.openssl
            pkgs.libiconv
            pkgs.cacert
          ];

          config = {
            Cmd = [
              "${cookie_cloud_server}/bin/${pname}"
              "start"
            ];
            ExposedPorts = {
              "4000/tcp" = { };
            };
            Env = [
              "PORT=4000"
              "DATABASE_PATH=/app/data/cookie_cloud_server.db"
              "LANG=C.UTF-8"
              "MIX_ENV=prod"
              "RELEASE_NODE=${pname}@127.0.0.1"
              "RELEASE_TMP=/tmp"
              "RELEASE_COOKIE=cookie"
            ];
            WorkingDir = "/app";
          };
        };
      in
      {
        packages.default = cookie_cloud_server;
        packages.docker = dockerImage;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir
            git
            gnumake
            gcc
            sqlite
          ];

          shellHook = ''
            export MIX_ENV=dev
            export DATABASE_PATH=$PWD/data/cookie_cloud_server.db
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex
            export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH

            echo "🍪 Cookie Cloud Server Environment Loaded (Elixir $(elixir -v))"
          '';
        };
      }
    );
}
