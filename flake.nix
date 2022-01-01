{
  description = "PicoSystem with 32Blit Project Template";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    "32blit-sdk" = {
      url = "github:32blit/32blit-sdk";
      flake = false;
    };

    pico-extras = {
      url = "github:raspberrypi/pico-extras";
      flake = false;
    };

    pico-sdk = {
      url = "github:raspberrypi/pico-sdk";
      submodules = true;
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ] (system:
      let
        overlays = [ (_: super: {
          # Required until https://github.774.gs/NixOS/nixpkgs/pull/149601 is merged
          # context: https://github.774.gs/NixOS/nixpkgs/issues/146759
          SDL2_with_libSDL2main = pkgs.SDL2.overrideAttrs (old: {
            postInstall = ''
              moveToOutput lib/libSDL2main.a "$dev"
              if [ "$dontDisableStatic" -eq "1" ]; then
                rm $out/lib/*.la
              else
                rm $out/lib/*.a
              fi
              moveToOutput bin/sdl2-config "$dev"
              cp $dev/lib/libSDL2main.a $out/lib/
            '';
          });
        })];
        pkgs = import nixpkgs { inherit system overlays; };
        project = returnShellEnv:
          pkgs.mkShell {
            packages = with pkgs; [
            ];
            nativeBuildInputs = with pkgs; [
              cmake
              gcc-arm-embedded
              binutils

              SDL2_with_libSDL2main
              SDL2_image
              SDL2_net

              # I haven't been able to make the 32blit python lib build as a nix derivation, so
              # you'll have to install it manually.
              # $ pip3 install 32blit
              #
              python3
              pipenv
              python3Packages.pip
              python3Packages.wheel
              python3Packages.setuptools
              unzip
            ];
          };
      in
      {
        # Used by `nix build` & `nix run` (prod exe)
        defaultPackage = project false;

        # Used by `nix develop` (dev shell)
        devShell = (project true).overrideAttrs (oa: {
          shellHook = oa.shellHook + ''
            # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
            # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
            export PIP_PREFIX=$(pwd)/_build/pip_packages
            export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
            export PATH="$PIP_PREFIX/bin:$PATH"
            unset SOURCE_DATE_EPOCH
          '';
        });
      });
}
