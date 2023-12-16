{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  # nativeBuildInputs is usually what you want -- tools you need to run
  nativeBuildInputs = with pkgs; [
    rustup
    zig
  ];
  buildInputs = with pkgs; [
    zls
    cargo
    git
    openssl
    pkg-config
    deno
  ];
}