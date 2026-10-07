#!/bin/sh
SCRIPT="${0##*/}"

## APT update
echo "INFO[${SCRIPT}]: Updating the OS ..."
export DEBIAN_FRONTEND='noninteractive'
apt-get update
apt-get dist-upgrade --yes
