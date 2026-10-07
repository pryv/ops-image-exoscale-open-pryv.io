#!/bin/sh
SCRIPT="${0##*/}"
set -eu

## Base packages and automatic security updates
echo "INFO[${SCRIPT}]: Installing base packages ..."
export DEBIAN_FRONTEND='noninteractive'
apt-get update
apt-get install --yes --no-install-recommends \
  ca-certificates curl gnupg dnsutils gettext-base unattended-upgrades

# Security updates only, no automatic reboot (the operator decides when)
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
