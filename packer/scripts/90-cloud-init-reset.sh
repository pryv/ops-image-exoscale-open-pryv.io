#!/bin/sh
SCRIPT="${0##*/}"
set -eu

## cloud-init reset, so the next boot (the user's first) runs it from scratch
echo "INFO[${SCRIPT}]: Resetting cloud-init ..."
cloud-init clean --logs --seed
rm -rf /var/lib/cloud/*
