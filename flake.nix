{
  description = "Standalone build of tmux";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # darwin: build the same pkgsStatic.tmux as linux. configure.ac turns the
  # global `--enable-static` (added by pkgsStatic) into `LDFLAGS=-static`, which
  # breaks the libSystem link probe (darwin has no static libc) — but
  # mkStandaloneFlake's filterEnableStaticOnDarwin already strips `--enable-static`
  # for us, and we push `--disable-shared` back via the bash configureFlagsArray
  # (invisible to that Nix-list filter, same dodge as curl/file). Every pkgsStatic
  # dep is .a-only, so the final link can't pick up a `.dylib`. The earlier
  # "regular tmux + pruned shared deps" approach was fragile: a regular ncurses
  # could leak transitively into the sandbox and win the `-search_paths_first
  # -lncursesw` race against the static `.a`.
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
          base = p.tmux.override {
            ncurses = ncursesFB;
            libevent = ulib.nativeFixes.libevent p;
          };
        in
        if p.stdenv.hostPlatform.isDarwin
        then
          base.overrideAttrs (old: {
            # See the header comment: re-add --disable-shared past the darwin
            # static-flag filter so libtool resolves the deps' .a, and drop the
            # -lresolv b64_ntop probe + its <resolv.h> include so the bundled
            # compat/base64.c (not the macro-renamed libresolv symbol) is used.
            preConfigure = (old.preConfigure or "") + ''
              configureFlagsArray+=("--disable-shared")
            '';
            postPatch = (old.postPatch or "") + ''
              substituteInPlace configure.ac \
                --replace-fail 'LIBS="$OLD_LIBS -lresolv"' 'LIBS="$OLD_LIBS"'
              substituteInPlace compat/base64.c \
                --replace-fail '#include <resolv.h>' ""
            '';
          })
        else base;
    };
}
