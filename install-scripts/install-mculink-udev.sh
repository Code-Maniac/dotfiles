#!/usr/bin/env bash
#
# Gives every MCU-Link's serial port a name that does not change:
#
#   /dev/mculink/<USB serial>   e.g. /dev/mculink/OCP4JKTFIT5FR
#
# one node per connected probe, the same path on the host and in the
# veethree-workspace container, which binds /dev/mculink (see
# docker/veethree-workspace/compose.yaml).
#
# The kernel numbers the ports ttyACM0, 1, 2... and moves on whenever a probe
# re-enumerates while its old node is still held open, so nothing should name
# them by number. These are real device nodes rather than udev symlinks, because
# a symlink into the host's /dev means nothing in the container. They live in a
# directory so the container's bind follows each node as it is recreated on every
# add, and under /dev because /run is mounted nodev.
#
# Matches any MCU-Link (1fc9:0143), serial interface (02) only - the others are
# CMSIS-DAP. Run once on the host; no probe needs to be plugged in.

set -euo pipefail

RULES=/etc/udev/rules.d/99-mculink.rules
NODE_DIR=/dev/mculink

match='SUBSYSTEM=="tty", ENV{ID_VENDOR_ID}=="1fc9", ENV{ID_MODEL_ID}=="0143", ENV{ID_USB_INTERFACE_NUM}=="02"'
node="$NODE_DIR/\$env{ID_SERIAL_SHORT}"

sudo tee "$RULES" >/dev/null <<EOF
# Written by ~/.dotfiles/install-scripts/install-mculink-udev.sh
ACTION=="add|change", $match, RUN+="/bin/sh -c 'mkdir -p $NODE_DIR && rm -f $node && mknod -m 0666 $node c \$major \$minor'"
ACTION=="remove", $match, RUN+="/bin/rm -f $node"
EOF
sudo udevadm control --reload

# Earlier versions of this rule: a /dev/mculink symlink, which would be in the way
# of the directory, and node directories under /run and /dev/mculink.d.
if [ -L "$NODE_DIR" ]; then
    sudo rm -f "$NODE_DIR"
fi
sudo rm -rf /dev/mculink.d /run/mculink /run/mculink.d

sudo udevadm trigger --subsystem-match=tty --action=change
sudo udevadm settle

echo "wrote $RULES"
ls -l "$NODE_DIR"
