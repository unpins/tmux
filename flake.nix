{
  description = "Standalone build of tmux";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # darwin: pkgsStatic.tmux's configure.ac passes `-static` globally → libSystem
  # link probe fails. Fall back to regular tmux with deps' shared libs pruned;
  # runtime closure ends up libSystem-only either way.
  #
  # Plus postPatch: tmux's configure.ac probes `b64_ntop` against -lresolv;
  # on darwin libresolv provides it so tmux links libresolv.9.dylib. We only
  # want libSystem in the binary, so disable that probe — tmux falls back to
  # its bundled compat/base64.c.
  #
  # Second patch: darwin's <resolv.h> macros-rename `b64_ntop` to
  # `res_9_b64_ntop`. compat.h `#undef`s these macros at call sites, but
  # compat/base64.c (the bundled implementation) still picks them up and
  # ends up defining `_res_9_b64_ntop`, leaving `_b64_ntop` undefined.
  # Drop the unused `#include <resolv.h>` from compat/base64.c so the
  # function names match across translation units.
  #
  # All platforms: bake the curated terminfo fallback list into ncurses →
  # tmux's outer-terminal rendering works on hosts without
  # `/usr/share/terminfo`. Host terminfo still wins when present.
  #
  # libevent fix (pkg-config injection for armv7l static link) lives in
  # nix-lib/native-overlay/libevent.nix and is shared via
  # `unpins-lib.lib.nativeFixes.libevent`.
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "tmux";
      build = pkgs:
        let
          ulib = unpins-lib.lib;
          p = pkgs.pkgsStatic;
          ncursesFB = ulib.embedFallbackTerminfo p.ncurses;
        in
        if p.stdenv.hostPlatform.isDarwin
        then
          ((ulib.withDepsSharedPruned pkgs pkgs.tmux).override {
            ncurses = ncursesFB;
            libevent = ulib.nativeFixes.libevent pkgs;
          }).overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace configure.ac \
                --replace-fail 'LIBS="$OLD_LIBS -lresolv"' 'LIBS="$OLD_LIBS"'
              substituteInPlace compat/base64.c \
                --replace-fail '#include <resolv.h>' ""
            '';
          })
        else
          p.tmux.override {
            ncurses = ncursesFB;
            libevent = ulib.nativeFixes.libevent p;
          };
    };
}
