#!/bin/bash
# Change the Open Pryv.io release this instance runs.
#
# Usage (as root): /opt/pryv/pryv-upgrade.sh [latest|latest-stable|<version>]
# Without an argument, uses the version requested at setup (PRYV_VERSION).
# Resolves the release, verifies its signature, pulls it, checks the current
# configuration with it, then restarts pryv.service on it.
set -Eeuo pipefail

CONFIG_DIR=/opt/pryv
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$CONFIG_DIR/lib.sh"

fail () { echo "ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "run as root: sudo $0 ${*:-}"
[ -f "$CONFIG_DIR/.initialized" ] || fail "Open Pryv.io is not set up yet (see /var/log/pryv-first-boot.log)"
# shellcheck source=/dev/null
. /etc/default/pryv
requested="${1:-${PRYV_VERSION_REQUESTED:-latest}}"
current_image="${PRYV_IMAGE:-}"
current_tag="${PRYV_IMAGE_TAG:-unknown}"

echo "Read the release notes before upgrading: https://github.com/pryv/open-pryv.io/blob/master/CHANGELOG-v2.md"
echo "Current: $current_tag ($current_image)"
resolved="$("$CONFIG_DIR/resolve-image.sh" --pull "$requested")" \
  || fail "could not get a verified Open Pryv.io image for '$requested' (reason above); nothing changed"
read -r tag digest <<< "$resolved"
new_image="pryvio/open-pryv.io@$digest"

if [ "$new_image" = "$current_image" ]; then
  echo "Already running $tag ($new_image): nothing to do."
  pryv_write_settings "$tag" "$digest" "$requested"
  pryv_write_version_note "$tag" "$requested"
  exit 0
fi

echo "Checking the configuration with $tag ..."
PRYV_IMAGE="$new_image" "$CONFIG_DIR/check-config.sh" \
  || fail "$tag reports a problem with the current configuration (output above); nothing changed"

pryv_write_settings "$tag" "$digest" "$requested"
pryv_write_version_note "$tag" "$requested"
[ -f "$CONFIG_DIR/version-note" ] && echo "WARNING: $(cat "$CONFIG_DIR/version-note")"
systemctl restart pryv
echo "Upgraded: $current_tag -> $tag ($new_image)"
echo "Logs: journalctl -u pryv -f"
echo "The previous image stays on disk; to go back: $0 $current_tag"
