{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) environments packages time config limits;
  test-env = {
    ENVIRONMENTS_CONFIG_PATH = environments true;
    PACKAGES_TEST_SRC = pkgs.writeText "packages_test_src.rs" (builtins.foldl' (acc: pkg:
      acc
      + ''
        #[test]
        #[ignore]
        fn test_${pkg}() {
          test_package("${pkg}");
        }
      '') "" (builtins.attrNames packages));
    ENVIRONMENTS_LIST_SRC = pkgs.writeText "environments_list_src.rs" ''
      const ENVIRONMENTS: &[&str] = &[${builtins.foldl' (acc: x: acc + ''"${x}", '') "" (builtins.attrNames packages)}];
    '';
    LIMITS_TEST_SRC = pkgs.writeText "limits_test_src.rs" (let
      numeric = builtins.mapAttrs (k: v: v.min) limits.u64;
      compile.network =
        if config.compile_limits.network
        then "any::<bool>()"
        else "Just(false)";
      run.network =
        if config.run_limits.network
        then "any::<bool>()"
        else "Just(false)";
    in ''
      prop_compose! {
          fn compile_limits() (
              ${builtins.foldl' (acc: x: acc + "${x} in option::of(${toString numeric.${x}}u64..=${toString config.compile_limits.${x}}), ") "network in option::of(${compile.network}), " (builtins.attrNames numeric)}
          ) -> LimitsOpt {
              LimitsOpt {
                network,
                ${builtins.foldl' (acc: x: acc + "${x}, ") "" (builtins.attrNames numeric)}
              }
          }
      }
      prop_compose! {
          fn run_limits() (
              ${builtins.foldl' (acc: x: acc + "${x} in option::of(${toString numeric.${x}}u64..=${toString config.run_limits.${x}}), ") "network in option::of(${run.network}), " (builtins.attrNames numeric)}
          ) -> LimitsOpt {
              LimitsOpt {
                network,
                ${builtins.foldl' (acc: x: acc + "${x}, ") "" (builtins.attrNames numeric)}
              }
          }
      }
    '');
    CONFIG_PATH = pkgs.writeText "config.json" (builtins.toJSON (config
      // {
        host = "127.0.0.1";
        port = 8000;
        server = "/";
        programs_dir = "programs";
        jobs_dir = "jobs";
        program_ttl = 60;
        prune_programs_interval = 30;
      }));
  };
  test-script = pkgs.writeShellScript "integration-tests.sh" ''
    rm -rf programs jobs
    cargo build -r --locked
    cargo run -r --locked &
    pid=$!
    sleep 1
    cargo test --locked --all-features --all-targets --no-fail-fast -- --ignored
    out=$?
    kill -9 $pid
    exit $out
  '';
  scripts = pkgs.stdenv.mkDerivation {
    name = "scripts";
    unpackPhase = "true";
    installPhase = "mkdir -p $out/bin && ln -s ${test-script} $out/bin/integration-tests";
  };
in {
  default = pkgs.mkShell ({
      packages = [pkgs.nsjail time scripts];
      RUST_LOG = "info,sandkasten=trace,difft=off";
    }
    // test-env);
  test = pkgs.mkShell ({packages = [scripts];} // test-env);
}
