#!/bin/bash
SCRIPT="${0##*/}"
set -euo pipefail

## Open Pryv.io: files, pinned image, first-boot units
: "${PRYV_TAG:?PRYV_TAG is required}"
IMAGE="pryvio/open-pryv.io:${PRYV_TAG}"
SRC=/tmp/image

echo "INFO[${SCRIPT}]: Installing Open Pryv.io files for ${IMAGE} ..."
install -d -m 0755 /opt/pryv
install -m 0644 "$SRC/opt/pryv/init-answers.template.yml" /opt/pryv/
install -m 0755 "$SRC/opt/pryv/first-boot.sh" /opt/pryv/
install -m 0644 "$SRC/etc/default/pryv" /etc/default/pryv
sed -i "s|__PRYV_TAG__|${PRYV_TAG}|" /etc/default/pryv
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

echo "INFO[${SCRIPT}]: Pulling ${IMAGE} ..."
docker pull "$IMAGE"

# The wizard answers must be accepted by this release's wizard: check it now,
# so an incompatible release fails the build instead of the user's first boot.
# Both with and without PRYV_EMAIL, which is optional.
check_answers () {
  local email="$1" check_dir
  echo "INFO[${SCRIPT}]: Checking the install wizard answers against ${IMAGE} (email: '${email}') ..."
  check_dir="$(mktemp -d)"
  # shellcheck disable=SC2016 # literal variable list for envsubst
  PRYV_HOSTNAME=pryv.example.com PRYV_EMAIL="$email" PRYV_SERVICE_NAME='Open Pryv.io' \
    PRYV_AUTHUI_URL=https://account.pryv.me PRYV_LE_STAGING=false \
    envsubst '${PRYV_HOSTNAME} ${PRYV_EMAIL} ${PRYV_SERVICE_NAME} ${PRYV_AUTHUI_URL} ${PRYV_LE_STAGING}' \
    < /opt/pryv/init-answers.template.yml > "$check_dir/init-answers.yml"
  docker run --rm -v "$check_dir:/app/pryv" "$IMAGE" \
    init --non-interactive --dry-run --config-from=/app/pryv/init-answers.yml | tee "$check_dir/out.txt"
  if grep -q 'keys no prompt asked for' "$check_dir/out.txt"; then
    echo "ERROR[${SCRIPT}]: the wizard of ${IMAGE} ignores some of the answers (see above)" >&2
    exit 1
  fi
  rm -rf "$check_dir"
}
check_answers ops@example.com
check_answers ''

systemctl daemon-reload
systemctl enable pryv-first-boot.path
echo "INFO[${SCRIPT}]: Done"
