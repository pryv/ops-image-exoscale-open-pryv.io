#!/bin/sh
SCRIPT="${0##*/}"

# Delete and lock root password.
# Note: please keep the two 'passwd' calls in order to obtain the expected result
echo "INFO[${SCRIPT}]: Deleting and locking root password ..."
passwd -d root
passwd -l root

# Cleanup root SSH configuration (incl. authorized keys)
echo "INFO[${SCRIPT}]: Cleaning up root SSH configuration (incl. authorized keys) ..."
rm -rfv /root/.ssh
