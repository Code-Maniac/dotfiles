#!/usr/bin/env bash
#
# Repairs claude-code-statusline's file-mtime probe, which is broken on GNU
# coreutils and silently kills its cost tracking.
#
# Upstream writes the probe BSD-first:
#
#   cache_mtime=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null)
#
# On macOS `stat -f FORMAT` is a format string, so that works. On GNU coreutils
# `-f` means --file-system, so BOTH "%m" and "$f" are read as paths: it errors on
# "%m", succeeds on "$f", prints a filesystem dump to stdout, and exits non-zero.
# The `||` fallback then also runs, so the two outputs concatenate and cache_mtime
# becomes a multi-line filesystem report with the epoch stuck on the end. The
# arithmetic on the next line dies, the cache never validates, and every cost
# component renders as "$-.--" forever. Measured here: costs are simply absent
# without this, and cold renders take ~6s instead of ~2.7s.
#
# The fix is to use GNU syntax on both sides of the ||. That is deliberately not
# portable back to macOS - both machines this dotfiles repo targets are Linux
# (fedora host, ubuntu container) - so if a mac ever joins, make this conditional
# on `uname` rather than widening the sed.
#
# This has to re-run after every statusline upgrade, because the installer
# replaces lib/ wholesale. It is idempotent, so running it on every ./install is
# free. Worth reporting upstream; if a fixed release lands, delete this script and
# its entry in install.conf.yaml.

set -euo pipefail

LIB_DIR="$HOME/.claude/statusline/lib"

if [ ! -d "$LIB_DIR" ]; then
    echo "claude-code-statusline is not installed - nothing to patch"
    exit 0
fi

# Idempotent: once patched there are no `stat -f` calls left to rewrite.
#
# Collected with mapfile rather than `grep | wc -l` on purpose. Under pipefail a
# grep that matches nothing fails the whole pipeline, so with set -e the "already
# patched" case would kill the script silently and report a failed step to dotbot
# on every subsequent run.
mapfile -t targets < <(grep -rl 'stat -f' "$LIB_DIR" 2>/dev/null || true)
if (( ${#targets[@]} == 0 )); then
    echo "statusline already patched - nothing to do"
    exit 0
fi

# %m -> %Y (mtime), %A -> %a (permissions), %z -> %s (size). All three use the
# same broken BSD-first idiom in lib/security.sh.
find "$LIB_DIR" -name '*.sh' -print0 | xargs -0 sed -i \
    -e 's/stat -f "%m"/stat -c "%Y"/g' -e 's/stat -f %m/stat -c %Y/g' \
    -e 's/stat -f "%A"/stat -c "%a"/g' -e 's/stat -f %A/stat -c %a/g' \
    -e 's/stat -f "%z"/stat -c "%s"/g' -e 's/stat -f %z/stat -c %s/g'

mapfile -t still < <(grep -rn 'stat -f' "$LIB_DIR" 2>/dev/null || true)
if (( ${#still[@]} > 0 )); then
    echo "Some stat -f calls were not rewritten - upstream idiom has changed:" >&2
    printf '  %s\n' "${still[@]}" >&2
    exit 1
fi

# The cost caches hold the poisoned results, so drop them and let the next render
# rebuild.
rm -rf "$HOME/.cache/claude-code-statusline" /tmp/.statusline_cost_render_* 2>/dev/null || true

echo "Patched ${#targets[@]} statusline module(s) for GNU stat"
