{ inputs, ... }: {
  perSystem = { inputs', system, config, lib, pkgs, ... }: let
    # Use nightly toolchain - required by amaru dependencies
    toolchain = with inputs'.fenix.packages;
      combine [
        minimal.rustc
        minimal.cargo
        complete.clippy
        complete.rustfmt
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

    # Extract pname and version from Cargo.toml
    crateInfo = craneLib.crateNameFromCargoToml { cargoToml = ../Cargo.toml; };

    commonArgs = {
      inherit src;
      inherit (crateInfo) pname version;
      strictDeps = true;
      cargoExtraArgs = "--locked";

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

    # Build dependencies separately for caching
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

        muslArgs = commonArgs // {
          depsBuildBuild = [
            muslPkgs.stdenv.cc
          ];

          buildInputs = with muslPkgs.pkgsStatic; [
            openssl
            zlib
          ];

          CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
          OPENSSL_STATIC = "1";
          OPENSSL_LIB_DIR = "${muslPkgs.pkgsStatic.openssl.out}/lib";
          OPENSSL_INCLUDE_DIR = "${muslPkgs.pkgsStatic.openssl.dev}/include";
        };

        muslArtifacts = craneLibMusl.buildDepsOnly muslArgs;
      in craneLibMusl.buildPackage (muslArgs // {
        cargoArtifacts = muslArtifacts;
        doCheck = true;
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
        pthreads = windowsPkgs.windows.pthreads.overrideAttrs (old: {
          meta = (old.meta or {}) // { platforms = lib.platforms.all; };
        });

        windowsArgs = commonArgs // {
          depsBuildBuild = [
            windowsPkgs.stdenv.cc
            pthreads
          ];

          buildInputs = [];

          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
          ];

          CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${windowsPkgs.stdenv.cc}/bin/x86_64-w64-mingw32-gcc";
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS = "-L native=${pthreads}/lib";
        };

        windowsArtifacts = craneLibWindows.buildDepsOnly windowsArgs;
      in craneLibWindows.buildPackage (windowsArgs // {
        cargoArtifacts = windowsArtifacts;
        doCheck = false;
      });
    };

    # CI checks - reuse cargoArtifacts for efficiency
    checks = {
      clippy = craneLib.cargoClippy (commonArgs // {
        inherit cargoArtifacts;
        cargoClippyExtraArgs = "--all-targets -- --deny warnings";
      });

      fmt = craneLib.cargoFmt {
        inherit src;
        inherit (crateInfo) pname version;
      };
    };
  };
}
