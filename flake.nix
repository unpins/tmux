{
  description = "Standalone build of tmux";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    unpins-lib.url = "github:unpins/nix-lib/v1";
  };

  outputs = { self, nixpkgs, unpins-lib }:
    let
      ulib = unpins-lib.lib;
      lib = nixpkgs.lib;

      # tmux for any pkgs view (native, pkgsStatic, pkgsCross.<darwin>).
      # On non-Darwin we use `pkgsStatic.tmux` directly — musl/cross
      # toolchains accept --enable-static. On Darwin, tmux's own configure
      # rejects --enable-static ("static linking is not supported on macOS"),
      # so we use the regular tmux derivation and instead force its
      # ncurses/libevent/utf8proc inputs to be static-only. Link resolution
      # then picks .a and the runtime closure becomes libSystem-only.
      buildTmux = pkgs:
        let
          tmuxDrv =
            if pkgs.stdenv.hostPlatform.isDarwin
            then pkgs.tmux.override {
              ncurses  = ulib.staticOnlyAuto pkgs.ncurses;
              libevent = ulib.staticOnlyAuto pkgs.libevent;
              utf8proc = ulib.staticOnlyCmake [] pkgs.utf8proc;
            }
            else pkgs.pkgsStatic.tmux;
          tmuxStatic = tmuxDrv.overrideAttrs (_: {
            stripAllList = [ "bin" ];
          });
        in
        pkgs.symlinkJoin {
          name = "tmux-${tmuxStatic.version}";
          paths = [ tmuxStatic.out tmuxStatic.man ];
          passthru = { inherit (tmuxStatic) version pname; };
        };

      nixpkgsFor = ulib.forAllNative (system: import nixpkgs { inherit system; });
    in
    {
      packages = ulib.forAllNative (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          default = buildTmux pkgs;
        } // lib.optionalAttrs (system == "aarch64-darwin") {
          # Cross-built tmux for x86_64-darwin, hosted on an aarch64-darwin
          # runner — same shape as packages.x86_64-linux."windows-x86_64".
          "darwin-x86_64" = buildTmux pkgs.pkgsCross.x86_64-darwin;
        });

      apps = ulib.forAllNative (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/tmux";
        };
      });
    };
}
