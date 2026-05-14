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
