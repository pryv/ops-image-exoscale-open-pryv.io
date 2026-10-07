#!/bin/sh
SCRIPT="${0##*/}"

## APT cleanup

# Remove unecessary packages
echo "INFO[${SCRIPT}]: Removing unecessary packages ..."
export DEBIAN_FRONTEND='noninteractive'
apt-get autoremove --purge --yes

# Clear cache
echo "INFO[${SCRIPT}]: Cleaning up APT cache ..."
apt-get clean
