#!/usr/bin/env bash
#
# Installs NXP LinkServer in the container, unattended.
#
# The sdkz image ships the self-extracting installer at /opt/linkserver and an
# otherwise empty /usr/local/LinkServer_<ver>/binaries, but not an installed
# LinkServer - so target debugging over LinkServer stops working on every
# container recreation until this runs. Pair with gdb-multiarch in the omnipkg
# list above it, which is the other half nvim-dap needs.
#
# The payload is a Makeself 2.4.0 archive wrapping install.sh and three debs
# (linkserver, mcu-link_installer, lpcscrypt). Left alone that script puts up a
# whiptail licence dialog and then a [Y/n] prompt about udev rules, so it needs
# two separate things to run unattended:
#
#   --nox11 --quiet --noprogress   makeself's own flags, so it does not try to
#                                  spawn an xterm to run the script in
#   -- acceptLicense               everything after -- goes to install.sh, which
#                                  scans its arguments for the bare word
#                                  acceptLicense and takes the non-interactive
#                                  branch when it finds it
#
# acceptLicense agrees to NXP's licence and to their udev notice on your behalf -
# that is the point of it, and the LICENSE file is in the archive if it ever
# needs reading: `<installer> --noexec --keep --target <dir>`.
#
# The udev rules it installs (MODE="0666" for the debug probes) are inert in a
# container, since there is no udev running. Probe access comes from
# device_cgroup_rules in docker/veethree-workspace/compose.yaml instead, which
# grants open() on major 189. The rules being installed anyway is harmless.
#
# install.sh also tries to add libncurses5 for the Arm GNU toolchain it bundles.
# Ubuntu 26.04 has no such package, so expect a warning there; it is not fatal by
# the installer's own design, and that toolchain is unused here - the Zephyr SDK
# provides the compiler.
#
# Runs as root under dotbot's sudo plugin, so there are no sudo calls here. It is
# sequenced after the omnipkg section, so apt's lists are already fresh for the
# `apt-get -fy install` that install.sh finishes with.

set -euo pipefail

INSTALLER_DIR=/opt/linkserver

shopt -s nullglob
installers=("$INSTALLER_DIR"/LinkServer_*.deb.bin)
shopt -u nullglob

# Absent on a machine that is not the sdkz container - the host runs the full
# config, where this is a no-op rather than an error.
if (( ${#installers[@]} == 0 )); then
    echo "No LinkServer installer under $INSTALLER_DIR - nothing to do"
    exit 0
fi
installer=${installers[-1]}

# Matched by glob, not by exact name: the package carries its version, so it is
# `linkserver_24.12.21` today and something else after the next image bump.
if dpkg-query -W -f='${Package} ${Status}\n' 'linkserver*' 2>/dev/null \
    | grep -q 'install ok installed'; then
    echo "LinkServer already installed - nothing to do"
    exit 0
fi

echo "Installing $(basename "$installer")"
"$installer" --quiet --noprogress --nox11 -- acceptLicense

# install.sh chowns its install tree to ${SUDO_USER:-${USER}}. Under the sudo
# plugin SUDO_USER is set, but if it ever is not the tree lands owned by root and
# LinkServer cannot write its logs, so this puts it right rather than leaving a
# subtly broken install.
owner=${SUDO_USER:-$(id -un)}
for dir in /usr/local/LinkServer_* /usr/local/MCU-LINK_installer_*; do
    [ -d "$dir" ] || continue
    [ "$(stat -c %U "$dir")" = "$owner" ] || chown -R "$owner" "$dir"
done

# Fail loudly rather than reporting success on an install that produced nothing
# runnable. dpkg -i runs with --force-depends in there, so it can "succeed" in
# ways that leave the binary unusable.
binary=$(find /usr/local/LinkServer_* -maxdepth 1 -name LinkServer -type f 2>/dev/null | head -1)
if [ -z "$binary" ] || [ ! -x "$binary" ]; then
    echo "LinkServer installed but no runnable binary found under /usr/local" >&2
    exit 1
fi

echo "LinkServer installed: $binary"
