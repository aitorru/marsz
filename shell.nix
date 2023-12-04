{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  # nativeBuildInputs is usually what you want -- tools you need to run
  nativeBuildInputs = with pkgs; [
    rustup
  ];
  buildInputs = with pkgs; [
    zig
    cargo
    git
    openssl
    pkg-config
  ];
  shellHook = ''
    # Check if the current Rust toolchain is set to stable; if not, set it
    if [ "$(rustup show active-toolchain)" != "stable-x86_64-unknown-linux-gnu (default)" ]; then
      echo "Setting Rust toolchain to stable..."
      rustup default stable
    fi
  '';
}