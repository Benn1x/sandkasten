{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";
  };

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    packages = import ./packages {inherit pkgs;};
    environments = pkgs.writeText "environments.json" (builtins.toJSON {
      nsjail_path = "${pkgs.nsjail}/bin/nsjail";
      time_path = "${pkgs.time}/bin/time";
      environments =
        builtins.mapAttrs (k: v: {
          inherit (v) name version;
          compile_script =
            if builtins.isNull v.compile_script
            then null
            else pkgs.writeShellScript "${k}-compile.sh" v.compile_script;
          run_script = pkgs.writeShellScript "${k}-run.sh" v.run_script;
        })
        packages;
    });
  in {
    packages.${system} = rec {
      rust = pkgs.rustPlatform.buildRustPackage {
        name = "sandkasten";
        src = pkgs.stdenv.mkDerivation {
          name = "sandkasten-src";
          src = ./src;
          installPhase = let
            files = {
              "Cargo.toml" = ./Cargo.toml;
              "Cargo.lock" = ./Cargo.lock;
              src = ./src;
            };
          in
            builtins.foldl' (acc: k: acc + " && ln -s ${files.${k}} $out/${k}") "mkdir -p $out" (builtins.attrNames files);
        };
        cargoLock.lockFile = ./Cargo.lock;
      };
      docker = pkgs.dockerTools.buildLayeredImage {
        name = "ghcr.io/defelo/sandkasten";
        tag = "latest";
        contents = with pkgs; [
          nsjail
          coreutils-full
          bash
        ];
        config = {
          User = "65534:65534";
          Entrypoint = ["${rust}/bin/sandkasten"];
          Env = ["ENVIRONMENTS_CONFIG_PATH=${environments}"];
        };
      };
      default = docker;
    };
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [pkgs.nsjail];
      RUST_LOG = "info,sandkasten=trace,difft=off";
      CONFIG_PATH = ".config.toml";
      ENVIRONMENTS_CONFIG_PATH = environments;
    };
  };
}
