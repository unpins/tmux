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
  # Plus (darwin only) drop the `propagated-user-env-packages` postInstall:
  # nixpkgs' tmux, on darwin only (package.nix line 76), force-references a
  # `tmux-terminfo` passthru derivation that copies the `tmux`/`tmux-256color`
  # entries out of `${ncurses}/share/terminfo`. But the engine ncurses is built
  # `--disable-db-install` (native-overlay/ncurses.nix), so it ships NO on-disk
  # terminfo db at all — only the curated fallback set compiled into libtinfo.a
  # (which already includes `tmux,tmux-256color`). The copy therefore fails
  # ("cannot stat …/share/terminfo/74/tmux"). That whole propagated-terminfo
  # mechanism only matters for a nix-env profile install; our single
  # self-contained binary carries the fallback terminfo inside its linked
  # libtinfo.a, so the passthru is dead weight. Clear the darwin-only postInstall
  # (its sole job is that echo) → the broken derivation is never referenced or
  # built. (On Linux postInstall is already empty, so the passthru — whose Linux
  # branch would fail the same way — is never forced there either.)
  #
  # Plus postPatch (darwin): tmux includes <resolv.h> for the b64_ntop/b64_pton
  # declarations (configure.ac probe + input.c/tty.c/tty-keys.c/compat/base64.c).
  # nixpkgs' apple-sdk doesn't ship <resolv.h> at all, so the configure probe
  # fails to compile → HAVE_B64_NTOP stays undefined → tmux's compat.h declares
  # b64_ntop/b64_pton itself and the bundled compat/base64.c implements them.
  # That's exactly what we want (libSystem-only, no libresolv), but the four
  # source TUs still `#include <resolv.h>` unconditionally and won't compile
  # without the header, so we strip that include from all of them; the decls
  # then come from compat.h via tmux.h. We also neutralise the probe's
  # `-lresolv` fallback in configure.ac as a guard: if a future SDK *does* ship
  # resolv.h, the probe must still resolve to "no" so the bundled base64 (which
  # the stripped TUs now rely on) stays selected.
  #
  # All platforms: bake the curated terminfo fallback list into ncurses →
  # tmux's outer-terminal rendering works on hosts without
  # `/usr/share/terminfo`. Host terminfo still wins when present.
  #
  # libevent is built with sslSupport = false: tmux uses libevent only for its
  # event loop, never the openssl bufferevents, so linking OpenSSL in was pure
  # dead weight — a multi-MB libcrypto/libssl in the closure plus openssl's
  # flaky static-musl `make check` (DH "not safe prime") that broke the build.
  # Dropping it also retires the nix-lib nativeFixes.libevent pkg-config shim,
  # which only existed for OpenSSL's armv7l libcrypto.pc `Libs.private` probe.
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
          p = pkgs.pkgsStatic;
          # Fallback terminfo is baked centrally for every engine ncurses, linux +
          # darwin (native-overlay/ncurses.nix), so p.ncurses already carries it.
          # libevent with SSL off (see header): drops the OpenSSL closure + its
          # flaky static-musl test suite that tmux never needed.
          base = p.tmux.override {
            ncurses = p.ncurses;
            libevent = p.libevent.override { sslSupport = false; };
            # nixpkgs' libutempter lists glib as a buildInput, but its source
            # (utempter.c/iface.c) includes nothing from glib and its Makefile
            # sets `LDLIBS =` empty with no pkg-config — glib is pure vestigial
            # cruft. Left in, it drags the entire glib closure (gio, pcre2,
            # libffi, util-linux, sqlite, …) into tmux's *build* graph on every
            # arch — a multi-minute-per-arch build for zero effect on the output.
            # Drop it via the `glib` arg (overrideAttrs on buildInputs is a
            # silent no-op under pkgsStatic splicing); stdenv filters the null,
            # so libutempter.a is byte-identical and the build graph loses a huge
            # subtree. (utmp recording via the utempter helper is plain libc,
            # unaffected.)
            libutempter = p.libutempter.override { glib = null; };
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
              # nixpkgs' apple-sdk has no <resolv.h>; these TUs include it only
              # for b64_ntop/b64_pton, which compat.h (via tmux.h) declares and
              # the bundled compat/base64.c implements. Drop the unresolvable
              # include from every consumer so the darwin build compiles.
              substituteInPlace input.c tty.c tty-keys.c compat/base64.c \
                --replace-fail '#include <resolv.h>' ""
              # The bundled base64.c also pulls <arpa/nameser.h> (equally absent
              # from the SDK) but uses nothing from it — it's a pure base64 impl.
              substituteInPlace compat/base64.c \
                --replace-fail '#include <arpa/nameser.h>' ""
            '';
            # Drop the darwin-only `propagated-user-env-packages` echo (see
            # header): it force-references the `tmux-terminfo` passthru, which
            # copies from the engine ncurses' on-disk terminfo db — a db that
            # doesn't exist (`--disable-db-install`). The fallback terminfo
            # (incl. tmux/tmux-256color) is already baked into the linked
            # libtinfo.a, so this propagation is dead weight for our standalone
            # binary. Clearing it stops the broken passthru from being built.
            postInstall = "";
          })
        else base;
    };
}
