# tmux

Standalone build of [tmux](https://github.com/tmux/tmux).

[![CI](https://github.com/unpins/tmux/actions/workflows/tmux.yml/badge.svg)](https://github.com/unpins/tmux/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

## Usage

Run the `tmux` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin tmux
```

To install it onto your PATH:

```bash
unpin install tmux
```

## Build locally

```bash
nix build github:unpins/tmux
./result/bin/tmux
```

Or run directly:

```bash
nix run github:unpins/tmux
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/tmux/releases) page has standalone binaries for manual download.

## Man pages

`tmux.1` is embedded in the binary — read it with `unpin man tmux`.

## Build notes

### Embedded resources

- **Terminfo fallback list** — a curated set of terminal definitions (xterm, xterm-256color, tmux, tmux-256color, screen, vt100, linux, alacritty, kitty, ghostty, foot, …) is baked into the linked `ncurses` so tmux's outer-terminal rendering works on hosts without `/usr/share/terminfo` (scratch containers, Alpine without `ncurses-terminfo`, busybox-init, …). Host terminfo still wins when present.

### Platforms

- **Windows excluded.** tmux is built on the Unix terminal model — pseudo-terminals (`forkpty`/`grantpt`/`openpty`), a controlling terminal, job control, and process sessions — on top of `fork()`, AF_UNIX sockets, and POSIX signals. This is an OS gap, not a toolchain one: cosmocc actually declares `fork()` and the full POSIX pty API, but on a Windows *host* there is no pseudo-terminal device or session/job-control model for them to bind to (Windows' native equivalent, ConPTY, is a different abstraction tmux doesn't target). The native Linux and macOS builds already cover every POSIX host, so a Cosmopolitan APE would only add Windows — the one platform where tmux's core can't run — and buys nothing.

### Darwin-specific patches

- **Drop `-lresolv` probe in `configure.ac`** — linking `libresolv` would drag `libresolv.9.dylib` into the runtime closure (single-binary policy); failing the probe makes tmux fall back to its bundled `compat/base64.c`.
- **Drop `#include <resolv.h>` from `compat/base64.c`** — darwin's `<resolv.h>` macro-renames `b64_ntop` → `res_9_b64_ntop`, so the bundled implementation kept defining `_res_9_b64_ntop` and `_b64_ntop` stayed undefined at link time.
