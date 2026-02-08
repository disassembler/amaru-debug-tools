{ inputs, ... }: {
  perSystem = { inputs', system, config, lib, pkgs, ... }: let
    # Use nightly toolchain - required by amaru dependencies
    toolchain = with inputs'.fenix.packages;
      combine [
        minimal.rustc
        minimal.cargo
      ];
    craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;

    src = lib.fileset.toSource {
      root = ./..;
      fileset = lib.fileset.unions [
        ../Cargo.lock
        ../Cargo.toml
        ../src
      ];
    };

    commonArgs = {
      inherit src;
      strictDeps = true;

      buildInputs = with pkgs; [
        openssl
        zlib
      ];

      nativeBuildInputs = with pkgs; [
        pkg-config
        cmake # needed by randomx-rs build script
      ];

      meta = {
        mainProgram = "amaru-debug-tools";
        maintainers = with lib.maintainers; [
          disassembler
          dermetfan
          johnalotoski
        ];
        license = with lib.licenses; [
          asl20
          mit
        ];
      };
    };

    cargoArtifacts = craneLib.buildDepsOnly commonArgs;
  in {
    packages = {
      amaru-debug-tools = craneLib.buildPackage (commonArgs // {
        inherit cargoArtifacts;
        doCheck = true;
      });

      default = config.packages.amaru-debug-tools;
    } // lib.optionalAttrs (system == "x86_64-linux") {
      amaru-debug-tools-musl = let
        muslToolchain = with inputs'.fenix.packages;
          combine [
            minimal.rustc
            minimal.cargo
            targets.x86_64-unknown-linux-musl.latest.rust-std
          ];
        craneLibMusl = (inputs.crane.mkLib pkgs).overrideToolchain muslToolchain;
        muslPkgs = pkgs.pkgsCross.musl64;

        muslArgs = {
          inherit src;
          strictDeps = true;

          depsBuildBuild = [
            muslPkgs.stdenv.cc
          ];

          buildInputs = with muslPkgs.pkgsStatic; [
            openssl
            zlib
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
          ];

          CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
          OPENSSL_STATIC = "1";
          OPENSSL_LIB_DIR = "${muslPkgs.pkgsStatic.openssl.out}/lib";
          OPENSSL_INCLUDE_DIR = "${muslPkgs.pkgsStatic.openssl.dev}/include";

          meta = commonArgs.meta;
        };

        muslArtifacts = craneLibMusl.buildDepsOnly muslArgs;
      in craneLibMusl.buildPackage (muslArgs // {
        cargoArtifacts = muslArtifacts;
        doCheck = false;
      });

      amaru-debug-tools-win = let
        windowsToolchain = with inputs'.fenix.packages;
          combine [
            minimal.rustc
            minimal.cargo
            targets.x86_64-pc-windows-gnu.latest.rust-std
          ];
        craneLibWindows = (inputs.crane.mkLib pkgs).overrideToolchain windowsToolchain;
        windowsPkgs = pkgs.pkgsCross.mingwW64;
        # Get pthreads with platform check disabled
        pthreads = windowsPkgs.windows.pthreads.overrideAttrs (old: {
          meta = (old.meta or {}) // { platforms = lib.platforms.all; };
        });

        windowsArgs = {
          inherit src;
          strictDeps = true;

          depsBuildBuild = [
            windowsPkgs.stdenv.cc
            pthreads
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
          ];

          CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${windowsPkgs.stdenv.cc}/bin/x86_64-w64-mingw32-gcc";
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS = "-L native=${pthreads}/lib";

          meta = commonArgs.meta;
        };

        windowsArtifacts = craneLibWindows.buildDepsOnly windowsArgs;
      in craneLibWindows.buildPackage (windowsArgs // {
        cargoArtifacts = windowsArtifacts;
        doCheck = false;
      });
    };
  };
}
