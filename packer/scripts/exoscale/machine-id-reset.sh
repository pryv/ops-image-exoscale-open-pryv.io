#!/bin/sh
SCRIPT="${0##*/}"

## Machine ID reset
echo "INFO[${SCRIPT}]: Resetting machine ID ..."

# reset machine-id
# REF: https://www.man7.org/linux/man-pages/man5/machine-id.5.html#FIRST_BOOT_SEMANTICS
echo uninitialized > /etc/machine-id

# make sure DBus machine-id points to system one
# REF: https://wiki.debian.org/MachineId
if test -e /var/lib/dbus/ && test ! -L /var/lib/dbus/machine-id; then
  rm -f /var/lib/dbus/machine-id
  # this should not be needed but better safe than sorry
  # (<-> /usr/lib/tmpfiles.d/dbus.conf: "L /var/lib/dbus/machine-id ... /etc/machine-id")
  ln -s /etc/machine-id /var/lib/dbus/machine-id
fi
