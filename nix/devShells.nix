{
  perSystem = { inputs', pkgs, ... }: let
    # Use fenix for nightly toolchain with all components
    toolchain = with inputs'.fenix.packages;
      combine [
        complete.rustc
        complete.cargo
        complete.rust-analyzer
        complete.rustfmt
        complete.clippy
      ];
  in {
    devShells.default = with pkgs; mkShell {
      packages = [
        toolchain
        cmake
        pkg-config
        openssl
        zlib
      ];
    };
  };
}
