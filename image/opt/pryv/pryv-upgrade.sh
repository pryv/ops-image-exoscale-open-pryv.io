#!/bin/bash
# Change the Open Pryv.io release this instance runs.
#
# Usage (as root): /opt/pryv/pryv-upgrade.sh [latest|latest-stable|<version>]
# Without an argument, uses the version last requested (PRYV_VERSION at setup, or the
# argument of the last upgrade): `latest` keeps following new releases, a pinned release
# stays pinned.
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
echo "Restarted on $tag; waiting for the server to answer ..."

# Host name from the setup settings (read as data, never executed)
host="$(sed -n 's/^[[:space:]]*PRYV_HOSTNAME=["'\'']\{0,1\}\([A-Za-z0-9.-]*\).*/\1/p' "$CONFIG_DIR/first-boot.env" 2>/dev/null | tail -n 1)"
answered=false
for _ in $(seq 1 36); do
  # -k: this only checks that the new release answers, whatever the certificate state
  if [ -n "$host" ] && curl -fsSk --max-time 5 "https://$host/reg/service/info" > /dev/null 2>&1; then
    answered=true; break
  fi
  sleep 5
done

# Keep the new and the previous image only: each one takes over a gigabyte
for id in $(docker images --quiet pryvio/open-pryv.io | sort -u); do
  digests="$(docker image inspect --format '{{join .RepoDigests " "}}' "$id" 2>/dev/null || true)"
  case " $digests " in
    *" $new_image "*|*" $current_image "*) ;;
    *) docker image rm "$id" > /dev/null 2>&1 || true ;;
  esac
done

if $answered; then
  echo "Upgraded: $current_tag -> $tag ($new_image), https://$host/reg/service/info answers."
else
  echo "WARNING: restarted on $tag, but https://${host:-<host>}/reg/service/info does not answer after 3 minutes; see: journalctl -u pryv" >&2
fi
echo "Logs: journalctl -u pryv -f"
echo "The previous image stays on disk; to go back: $0 $current_tag"
