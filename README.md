# tmux

Standalone build of [tmux](https://github.com/tmux/tmux). Runs on any Linux or macOS without external dependencies.

## Installation

You can install this package instantly using the [unpin](https://github.com/unpins/unpin) package manager:

```bash
unpin tmux
```

Or run it without installing:

```bash
unpin run tmux
```

## Build locally

```bash
nix build github:unpins/tmux
./result/bin/tmux
```

Or, in one shot:

```bash
nix run github:unpins/tmux
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual Download

Standalone binaries and data packages are available on the [Releases](https://github.com/unpins/tmux/releases) page.
