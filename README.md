# tmux

Standalone build of [tmux](https://github.com/tmux/tmux).

[![CI](https://github.com/unpins/tmux/actions/workflows/tmux.yml/badge.svg)](https://github.com/unpins/tmux/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

## Installation

Install with [unpin](https://github.com/unpins/unpin):

```bash
unpin tmux
```

Or run without installing:

```bash
unpin run tmux
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

The [Releases](https://github.com/unpins/tmux/releases) page has standalone binaries and a `.tar.zst` data archive (man pages and completions) for manual download.

## Build notes

### Embedded resources

- **Terminfo fallback list** — a curated set of terminal definitions (xterm, xterm-256color, tmux, tmux-256color, screen, vt100, linux, alacritty, kitty, ghostty, foot, …) is baked into the linked `ncurses` so tmux's outer-terminal rendering works on hosts without `/usr/share/terminfo` (scratch containers, Alpine without `ncurses-terminfo`, busybox-init, …). Host terminfo still wins when present.

### Platforms

- **Windows excluded.** Upstream tmux doesn't support Windows. The codebase relies on `fork()` + `forkpty`/`grantpt`, AF_UNIX sockets, POSIX signal handlers, controlling-terminal semantics, and `pselect` — none of which mingw or cosmocc provide for Windows targets. There's no portable native-binary path; tmux only runs on POSIX hosts.

### Darwin-specific patches

- **Drop `-lresolv` probe in `configure.ac`** — linking `libresolv` would drag `libresolv.9.dylib` into the runtime closure (single-binary policy); failing the probe makes tmux fall back to its bundled `compat/base64.c`.
- **Drop `#include <resolv.h>` from `compat/base64.c`** — darwin's `<resolv.h>` macro-renames `b64_ntop` → `res_9_b64_ntop`, so the bundled implementation kept defining `_res_9_b64_ntop` and `_b64_ntop` stayed undefined at link time.
