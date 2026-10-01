#!/usr/bin/env bash
#
# Installs Claude Code with Anthropic's native installer.
#
# Aimed at the veethree-workspace container. ~/.claude is bind mounted into it
# from the host, so login, settings and memory carry across - but the program
# itself lands in ~/.local, which is the container's own filesystem and goes
# with every `sdkz-workspace --install` or `--update`. So it has to be put back
# after each recreate, which is what running this from ./install does.
#
# The installer puts the launcher at ~/.local/bin/claude and the versions under
# ~/.local/share/claude. It keeps itself up to date after that, so an existing
# install is left alone rather than reinstalled - that also keeps ./install
# from making a network round trip on every run.

set -euo pipefail

CLAUDE_BIN="$HOME/.local/bin/claude"

if [ -x "$CLAUDE_BIN" ]; then
    echo "claude is already installed ($("$CLAUDE_BIN" --version 2>/dev/null || echo "version unknown")) - nothing to do"
    exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is not installed - cannot fetch the Claude Code installer" >&2
    exit 1
fi

curl -fsSL https://claude.ai/install.sh | bash

if [ ! -x "$CLAUDE_BIN" ]; then
    echo "the installer finished but $CLAUDE_BIN is not there" >&2
    exit 1
fi

# zsh/path-linux-gnu names /home/nick/.local/bin literally, and the container's
# home is /home/user, so there it is not on PATH by default.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "NOTE: $HOME/.local/bin is not on PATH - add it to run claude by name" ;;
esac

echo "installed $("$CLAUDE_BIN" --version 2>/dev/null || echo claude)"
