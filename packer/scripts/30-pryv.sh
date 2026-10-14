#!/bin/bash
SCRIPT="${0##*/}"
set -euo pipefail

## Open Pryv.io: files and first-boot units. No image is baked in: the release
## is chosen, verified and pulled at first boot (PRYV_VERSION).
SRC=/tmp/image

echo "INFO[${SCRIPT}]: Installing Open Pryv.io files ..."
install -d -m 0755 /opt/pryv
install -m 0644 "$SRC/opt/pryv/init-answers.template.yml" "$SRC/opt/pryv/lib.sh" /opt/pryv/
install -m 0755 "$SRC/opt/pryv/first-boot.sh" "$SRC/opt/pryv/resolve-image.sh" \
  "$SRC/opt/pryv/pryv-upgrade.sh" /opt/pryv/
install -m 0644 "$SRC/etc/default/pryv" /etc/default/pryv
install -m 0644 "$SRC"/etc/systemd/system/pryv* /etc/systemd/system/
install -m 0755 "$SRC/etc/update-motd.d/90-pryv" /etc/update-motd.d/
rm -rf "$SRC"

# Docker logs: bounded, so a long-running instance does not fill its disk
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "local",
  "log-opts": { "max-size": "20m", "max-file": "5" }
}
EOF
systemctl restart docker

## Smoke test of the first-boot chain with the release current at build time:
## tag listing, signature check, pull by digest, wizard answers (with and
## without the optional email). Then every image is removed again.
# shellcheck source-path=SCRIPTDIR source=../../image/opt/pryv/lib.sh
. /opt/pryv/lib.sh
echo "INFO[${SCRIPT}]: Resolving latest-stable (a WARNING is expected while no final 2.x exists) ..."
/opt/pryv/resolve-image.sh latest-stable
echo "INFO[${SCRIPT}]: Resolving and pulling latest ..."
resolved="$(/opt/pryv/resolve-image.sh --pull latest)"
read -r tag digest <<< "$resolved"
check_dir="$(mktemp -d)"
for email in ops@example.com ''; do
  echo "INFO[${SCRIPT}]: Checking the install wizard answers against ${tag} (email: '${email}') ..."
  # shellcheck disable=SC2016 # literal variable list for envsubst
  PRYV_HOSTNAME=pryv.example.com PRYV_EMAIL="$email" PRYV_SERVICE_NAME='Open Pryv.io' \
    PRYV_AUTHUI_URL=https://account.pryv.me PRYV_LE_STAGING=false \
    envsubst '${PRYV_HOSTNAME} ${PRYV_EMAIL} ${PRYV_SERVICE_NAME} ${PRYV_AUTHUI_URL} ${PRYV_LE_STAGING}' \
    < /opt/pryv/init-answers.template.yml > "$check_dir/init-answers.yml"
  pryv_check_answers "pryvio/open-pryv.io@${digest}" "$check_dir/init-answers.yml"
done
rm -rf "$check_dir"

echo "INFO[${SCRIPT}]: Removing the test image ..."
docker image prune --all --force
if [ -n "$(docker images --quiet)" ]; then
  echo "ERROR[${SCRIPT}]: images left in the template:" >&2
  docker images >&2
  exit 1
fi
# cosign's trust root cache is fetched again at first boot
rm -rf /root/.sigstore /root/.cache/sigstore

# Which template build this instance comes from (shown at login, useful for support)
echo "Open Pryv.io template ${PRYV_IMAGE_VERSION:-?} build ${PRYV_BUILD:-?}" > /etc/pryv-template-release

systemctl daemon-reload
systemctl enable pryv-first-boot.path
echo "INFO[${SCRIPT}]: Done"
