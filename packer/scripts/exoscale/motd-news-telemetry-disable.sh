#!/bin/sh
SCRIPT="${0##*/}"

# Disable motd-news telemetry
# REF: https://bugs.launchpad.net/ubuntu/+source/base-files/+bug/1867424
echo "INFO[${SCRIPT}]: Disabling Ubuntu motd-news telemetry ..."
sed -i "s/ENABLED=1/ENABLED=0/g" /etc/default/motd-news
