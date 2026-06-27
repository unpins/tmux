{
  description = "tmux as a single self-contained binary";

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
  # Plus passthru.terminfo: on darwin (and only darwin — see package.nix line
  # 76/87) nixpkgs builds a `tmux-terminfo` derivation that runs ncurses'
  # `tic`/`infocmp`, and the main derivation force-references it via
  # `propagated-user-env-packages`. Those tools come from the *host* ncurses, so
  # on a cross build they're host-arch binaries the build host can't run unless
  # emulated. CI's native (aarch64→aarch64) and arm→x86 (Rosetta) darwin builds
  # cope; the Intel-Mac → arm64 local check (./build-aarch64-darwin) has no
  # emulator and dies with "Bad CPU type". terminfo is architecture-independent,
  # so we compile it with the BUILD-native ncurses tic (p.buildPackages.ncurses).
  # This is a no-op on native darwin (buildPackages.ncurses == ncurses) and never
  # runs on Linux (the symlink branch needs no tic).
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

      # Build via the unpin-llvm engine + emit a bitcode multicall module.
      engine = "unpin-llvm";
      multicall = {
        programs = [{ name = "tmux"; }];
      };
      build = pkgs:
        let
          ulib = unpins-lib.lib;
          p = pkgs.pkgsStatic;
          # Fallback terminfo is baked centrally for every engine ncurses, linux +
          # darwin (native-overlay/ncurses.nix), so p.ncurses already carries it.
          base = p.tmux.override {
            ncurses = p.ncurses;
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
            # Compile the darwin terminfo passthru with the BUILD-native ncurses
            # tic/infocmp (host tic can't run when cross-building — see header).
            passthru = old.passthru // {
              terminfo = old.passthru.terminfo.overrideAttrs (_: {
                nativeBuildInputs = [ p.buildPackages.ncurses ];
              });
            };
          })
        else base;
    };
}
