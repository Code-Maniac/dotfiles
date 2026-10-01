#!/usr/bin/env bash
#
# Installs libpython3.12 in the container, from the deadsnakes PPA.
#
# The Zephyr SDK ships two gdbs. The plain arm-zephyr-eabi-gdb is built without
# python, so it has no `dap` interpreter and nvim-dap cannot drive it. Its
# arm-zephyr-eabi-gdb-py sibling has python, but is linked against
# libpython3.12.so.1.0 - and ubuntu 26.04 only packages 3.14, so it will not even
# start. This supplies that one library, alongside the system python rather than
# instead of it: /usr/bin/python3 stays 3.14.
#
# vim/astronvim/lua/plugins/dap.lua prefers the SDK's gdb-py for on-target
# debugging, so the debugger matches the SDK toolchain, and falls back to
# gdb-multiarch when it cannot find it. Without this, every recreated container
# silently falls back.
#
# The PPA is added by hand rather than with add-apt-repository, which the image
# does not have. Its key is pinned by fingerprint and the source only trusts that
# key (signed-by), so nothing else in apt starts accepting it.
#
# Runs as root under dotbot's sudo plugin, so there are no sudo calls here.

set -euo pipefail

PACKAGE=libpython3.12
KEY_FINGERPRINT=F23C5A6CF475977595C89F51BA6932366A755776
KEYRING=/etc/apt/keyrings/deadsnakes.gpg
SOURCES=/etc/apt/sources.list.d/deadsnakes.list
PPA_URL=https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu

if dpkg-query -W -f='${Status}\n' "$PACKAGE" 2>/dev/null | grep -q 'install ok installed'; then
    echo "$PACKAGE already installed - nothing to do"
    exit 0
fi

# deadsnakes is ubuntu only. Anywhere else - fedora, debian - this is a no-op
# rather than an error, and dap.lua falls back to gdb-multiarch there.
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ] || [ -z "${VERSION_CODENAME:-}" ]; then
    echo "Not ubuntu - no deadsnakes PPA for ${PRETTY_NAME:-this system}, nothing to do"
    exit 0
fi

# deadsnakes adds each new ubuntu release some time after it ships. Until it has
# this one, say so and carry on: debugging still works through gdb-multiarch.
if ! curl -fsI "$PPA_URL/dists/$VERSION_CODENAME/Release" >/dev/null; then
    echo "deadsnakes has no $VERSION_CODENAME release yet - skipping $PACKAGE"
    exit 0
fi

mkdir -p "$(dirname "$KEYRING")"
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$KEY_FINGERPRINT" \
    | gpg --batch --yes --dearmor -o "$KEYRING"

# Check the key that arrived is the one asked for, rather than trusting the
# keyserver's answer.
if ! gpg --show-keys --with-colons "$KEYRING" 2>/dev/null | grep -q "^fpr:*$KEY_FINGERPRINT:"; then
    echo "deadsnakes key did not match fingerprint $KEY_FINGERPRINT" >&2
    rm -f "$KEYRING"
    exit 1
fi

echo "deb [signed-by=$KEYRING] $PPA_URL $VERSION_CODENAME main" > "$SOURCES"

# Only this source's lists are refreshed: omnipkg has already updated the rest.
apt-get update \
    -o Dir::Etc::sourcelist="$SOURCES" \
    -o Dir::Etc::sourceparts=- \
    -o APT::Get::List-Cleanup=0
DEBIAN_FRONTEND=noninteractive apt-get install -y "$PACKAGE"

# Fail loudly if the SDK's gdb is present but still cannot run python, rather than
# reporting success on an install that did not fix the thing it is here for.
for gdb in /opt/toolchains/zephyr-sdk-*/gnu/arm-zephyr-eabi/bin/arm-zephyr-eabi-gdb-py; do
    [ -x "$gdb" ] || continue
    if ! "$gdb" -batch -ex "python print('ok')" >/dev/null 2>&1; then
        echo "$PACKAGE installed but $gdb still cannot run python" >&2
        exit 1
    fi
    echo "$gdb runs python"
done

echo "$PACKAGE installed"
