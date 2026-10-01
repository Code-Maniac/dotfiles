#!/usr/bin/env bash
#
# Installs NXP's CMSIS device pack for the RT1166 (NXP.MIMXRT1166_DFP) into pyOCD's
# pack cache, so pyOCD has the mimxrt1166cvm5a target.
#
# The pyOCD debug configurations in the SDKZ apps (single-app-debug, uemc4) run
# `west debugserver --runner pyocd --target mimxrt1166cvm5a`. pyOCD has no built-in
# RT1166 target - only the RT1176 (mimxrt1170_cm7), whose connect sequence releases
# the M4 core and rewrites boot-mode bits in SRC_SBMR - so the pack target is what
# gives NXP's own connect and reset sequences. Without the pack, those debug
# sessions fail to start with an unknown target.
#
# The pack cache is ~/.local/share/cmsis-pack-manager, in the container's own
# filesystem, so a recreated container needs this again. Runs as the user, not
# under the sudo plugin, so the cache lands in the user's home.
#
# Idempotent, and a no-op where pyOCD is not installed.

set -euo pipefail

PART=MIMXRT1166CVM5A

PYOCD=$(command -v pyocd || true)
[ -z "$PYOCD" ] && [ -x /opt/venv/bin/pyocd ] && PYOCD=/opt/venv/bin/pyocd
if [ -z "$PYOCD" ]; then
    echo "pyOCD not installed - nothing to do"
    exit 0
fi

# `pack find` marks installed parts with True in its last column.
if "$PYOCD" pack find "$PART" 2>/dev/null | grep -qi "^ *${PART} .* True *$"; then
    echo "$PART pack already installed - nothing to do"
    exit 0
fi

# -u fetches the pack index first; a fresh container has none, and without it
# pyOCD cannot find the pack to download.
echo "Installing the CMSIS pack for $PART"
"$PYOCD" pack install -u "$PART"

if ! "$PYOCD" list --targets 2>/dev/null | grep -qi "^ *${PART,,} "; then
    echo "pack installed but pyOCD does not list the ${PART,,} target" >&2
    exit 1
fi
echo "pyOCD target ${PART,,} available"
