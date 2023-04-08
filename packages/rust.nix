{
  rustc,
  gcc,
  ...
}: {
  name = "Rust";
  version = rustc.version;
  compile_script = ''PATH=${gcc}/bin/ ${rustc}/bin/rustc -O -o /out/binary "$1"'';
  run_script = ''/program/binary "$@"'';
}
