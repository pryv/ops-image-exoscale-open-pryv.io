#!/bin/sh
SCRIPT="${0##*/}"
set -eu

## SSH reset: drop the build key and the host keys
# cloud-init installs the user's key and generates new host keys at first boot.
echo "INFO[${SCRIPT}]: Removing build SSH key and host keys ..."
rm -f /home/ubuntu/.ssh/authorized_keys
rm -f /etc/ssh/ssh_host_*
