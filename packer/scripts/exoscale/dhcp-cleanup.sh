#!/bin/sh
SCRIPT="${0##*/}"

# DHCP leases cleanup
echo "INFO[${SCRIPT}]: Deleting DHCP leases ..."
rm -fv /var/lib/dhcp/dhclient*.leases
