#!/bin/sh
SCRIPT="${0##*/}"
set -eu

## cosign, to verify the signature of the Open Pryv.io image at first boot
# Pinned version + checksum (from the release's cosign_checksums.txt). Not updated
# by unattended-upgrades: a new template build updates it.
# REF: https://github.com/sigstore/cosign/releases
COSIGN_VERSION=v3.1.3
COSIGN_SHA256=4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71

arch="$(dpkg --print-architecture)"
[ "$arch" = amd64 ] || { echo "ERROR[${SCRIPT}]: no pinned cosign checksum for ${arch}" >&2; exit 1; }

echo "INFO[${SCRIPT}]: Installing cosign ${COSIGN_VERSION} ..."
tmp="$(mktemp)"
curl -fsSL -o "$tmp" "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
echo "${COSIGN_SHA256}  ${tmp}" | sha256sum -c -
install -m 0755 "$tmp" /usr/local/bin/cosign
rm -f "$tmp"
cosign version
