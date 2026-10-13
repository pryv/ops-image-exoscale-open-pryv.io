# Open Pryv.io: helpers shared by first-boot.sh, pryv-upgrade.sh and the template build.
# shellcheck shell=bash

PRYV_SETTINGS_FILE=/etc/default/pryv

# The install wizard of <image> must accept every answer of <answers file>:
# `init --dry-run` lists the answers it would ignore as "keys no prompt asked for".
pryv_check_answers () {
  local image="$1" answers="$2" check_dir status=0
  check_dir="$(mktemp -d)"
  install -m 0600 "$answers" "$check_dir/init-answers.yml"
  docker run --rm -v "$check_dir:/app/pryv" "$image" \
    init --non-interactive --dry-run --config-from=/app/pryv/init-answers.yml > "$check_dir/out.txt" 2>&1 \
    || status=$?
  cat "$check_dir/out.txt"
  if [ "$status" -ne 0 ]; then
    echo "ERROR: the install wizard of $image rejected the answers (exit $status, output above)" >&2
    status=1
  elif grep -q 'keys no prompt asked for' "$check_dir/out.txt"; then
    echo "ERROR: the install wizard of $image ignores some of the answers (output above)" >&2
    status=1
  fi
  rm -rf "$check_dir"
  return "$status"
}

# Records the image pryv.service runs: <tag> <digest> <requested version>
pryv_write_settings () {
  local tag="$1" digest="$2" requested="$3" tmp
  tmp="$(mktemp "$PRYV_SETTINGS_FILE.XXXXXX")"
  cat > "$tmp" <<EOF
# Open Pryv.io service settings, read by pryv.service and the scripts in /opt/pryv.
# Written by /opt/pryv/first-boot.sh, then by /opt/pryv/pryv-upgrade.sh: to change
# the version, run (as root) /opt/pryv/pryv-upgrade.sh latest|latest-stable|<version>
PRYV_IMAGE=pryvio/open-pryv.io@$digest
PRYV_IMAGE_TAG=$tag
PRYV_VERSION_REQUESTED=$requested
PRYV_RESOLVED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PRYV_CONFIG_DIR=/opt/pryv
EOF
  chmod 0644 "$tmp"
  mv -f "$tmp" "$PRYV_SETTINGS_FILE"
}

# The note shown at login when latest-stable had to fall back to a release candidate
pryv_write_version_note () {
  local tag="$1" requested="$2" note=/opt/pryv/version-note
  if [ "$requested" = latest-stable ] && [[ "$tag" == *-rc.* ]]; then
    echo "No final 2.x release yet: latest-stable runs the newest release candidate, $tag." > "$note"
  else
    rm -f "$note"
  fi
}
