#!/bin/sh
SCRIPT="${0##*/}"
set -eu

## Journal reset: drop the build's persistent journal
# Its sshd lines carry the address of the machine that ran the build; the instance
# starts its own journal at first boot (new machine ID).
echo "INFO[${SCRIPT}]: Removing the build journal ..."
journalctl --flush --rotate 2>/dev/null || true
journalctl --vacuum-time=1s 2>/dev/null || true
rm -rf /var/log/journal/*
