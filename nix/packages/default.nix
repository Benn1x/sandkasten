{
  pkgs,
  pkgs-old,
  ...
}: {
  bash = import ./bash.nix pkgs;
  c = import ./c.nix pkgs;
  cpp = import ./cpp.nix pkgs;
  csharp = import ./csharp.nix pkgs;
  haskell = import ./haskell.nix pkgs;
  java = import ./java.nix pkgs;
  javascript = import ./javascript.nix pkgs;
  kotlin = import ./kotlin.nix pkgs;
  lua = import ./lua.nix pkgs;
  perl = import ./perl.nix pkgs;
  php = import ./php.nix pkgs;
  python = import ./python.nix pkgs;
  ruby = import ./ruby.nix pkgs;
  rust = import ./rust.nix pkgs;
  swift = import ./swift.nix pkgs-old;
  typescript = import ./typescript.nix pkgs;
}
