#!/bin/bash
# Open Pryv.io first-boot setup.
#
# Triggered by pryv-first-boot.path as soon as /opt/pryv/first-boot.env exists
# (written by the instance user-data, or by hand). Runs the open-pryv.io install
# wizard unattended, then starts pryv.service. Log: /var/log/pryv-first-boot.log
set -Eeuo pipefail

CONFIG_DIR=/opt/pryv
ENV_FILE="$CONFIG_DIR/first-boot.env"
ANSWERS_TEMPLATE="$CONFIG_DIR/init-answers.template.yml"
ANSWERS_FILE="$CONFIG_DIR/init-answers.yml"
CONFIG_FILE="$CONFIG_DIR/pryv-config.yml"
DONE_FLAG="$CONFIG_DIR/.initialized"
LOG_FILE=/var/log/pryv-first-boot.log
# uid/gid of the `node` user the server runs as inside the image
PRYV_UID=1000
DNS_WAIT_MAX_SECONDS=7200
SERVICE_WAIT_MAX_SECONDS=900

exec > >(tee -a "$LOG_FILE") 2>&1

log () { echo "[pryv-first-boot] $(date -u +%Y-%m-%dT%H:%M:%SZ) $*"; }
# Exit status 3 is declared as success-like in pryv-first-boot.service: the unit stays
# active (exited), so the path unit does not re-trigger it in a loop. After fixing the
# cause, `systemctl restart pryv-first-boot` runs the setup again.
fail () {
  log "ERROR: $*"
  log "Fix the cause, then run: sudo systemctl restart pryv-first-boot"
  exit 3
}
trap 'fail "unexpected error at line $LINENO (output above)"' ERR

log "starting"

# shellcheck source=/dev/null
. /etc/default/pryv
[ -n "${PRYV_IMAGE:-}" ] || fail "PRYV_IMAGE missing in /etc/default/pryv"

## 1. Settings from first-boot.env: parsed as KEY=value lines, never executed
[ -f "$ENV_FILE" ] || fail "$ENV_FILE not found; see /etc/motd for how to write it"
PRYV_HOSTNAME=""
PRYV_EMAIL=""
PRYV_SERVICE_NAME=""
PRYV_AUTHUI_URL=""
PRYV_LE_STAGING=""
line_no=0
while IFS= read -r line || [ -n "$line" ]; do
  line_no=$((line_no + 1))
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
  [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)=(.*)$ ]] \
    || fail "$ENV_FILE line $line_no is not a KEY=value setting: '$line'"
  key="${BASH_REMATCH[1]}"
  value="${BASH_REMATCH[2]}"
  # One pair of matching quotes around the whole value is removed
  if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then value="${BASH_REMATCH[1]}"; fi
  case "$key" in
    PRYV_HOSTNAME|PRYV_EMAIL|PRYV_SERVICE_NAME|PRYV_AUTHUI_URL|PRYV_LE_STAGING)
      printf -v "$key" '%s' "$value" ;;
    *)
      fail "$ENV_FILE line $line_no: unknown setting $key (known: PRYV_HOSTNAME, PRYV_EMAIL, PRYV_SERVICE_NAME, PRYV_AUTHUI_URL, PRYV_LE_STAGING)" ;;
  esac
done < "$ENV_FILE"

PRYV_SERVICE_NAME="${PRYV_SERVICE_NAME:-Open Pryv.io}"
PRYV_AUTHUI_URL="${PRYV_AUTHUI_URL:-https://account.pryv.me}"
PRYV_LE_STAGING="${PRYV_LE_STAGING:-false}"

[[ "$PRYV_HOSTNAME" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]] \
  || fail "PRYV_HOSTNAME must be a fully qualified host name (got '$PRYV_HOSTNAME')"
[[ -z "$PRYV_EMAIL" || "$PRYV_EMAIL" =~ ^[^[:space:]\'@]+@[^[:space:]\'@]+\.[^[:space:]\'@]+$ ]] \
  || fail "PRYV_EMAIL, when set, must be an email address (got '$PRYV_EMAIL')"
[[ "$PRYV_AUTHUI_URL" =~ ^https://[^[:space:]\']+$ ]] \
  || fail "PRYV_AUTHUI_URL must be an https:// URL (got '$PRYV_AUTHUI_URL')"
[[ "$PRYV_LE_STAGING" == true || "$PRYV_LE_STAGING" == false ]] \
  || fail "PRYV_LE_STAGING must be true or false (got '$PRYV_LE_STAGING')"
[[ "$PRYV_SERVICE_NAME" =~ ^[^[:cntrl:]]{1,100}$ ]] \
  || fail "PRYV_SERVICE_NAME must be 1 to 100 printable characters"
# Single-quoted YAML scalar: a quote is written as two quotes
PRYV_SERVICE_NAME="${PRYV_SERVICE_NAME//\'/\'\'}"
export PRYV_HOSTNAME PRYV_EMAIL PRYV_SERVICE_NAME PRYV_AUTHUI_URL PRYV_LE_STAGING

log "host: $PRYV_HOSTNAME, image: $PRYV_IMAGE, Let's Encrypt staging: $PRYV_LE_STAGING"

if [ -f "$CONFIG_FILE" ]; then
  log "$CONFIG_FILE already exists: keeping it (the wizard is not re-run)"
else
  ## 2. Wizard answers
  umask 077
  # shellcheck disable=SC2016 # literal variable list for envsubst
  envsubst '${PRYV_HOSTNAME} ${PRYV_EMAIL} ${PRYV_SERVICE_NAME} ${PRYV_AUTHUI_URL} ${PRYV_LE_STAGING}' \
    < "$ANSWERS_TEMPLATE" > "$ANSWERS_FILE"
  umask 022

  ## 3. Install wizard, unattended (the documented `docker run ... init`)
  mkdir -p "$CONFIG_DIR/data"
  log "running the open-pryv.io install wizard"
  docker run --rm -v "$CONFIG_DIR:/app/pryv" "$PRYV_IMAGE" \
    init --non-interactive --config-from=/app/pryv/init-answers.yml \
    || fail "the install wizard failed (output above)"
  [ -f "$CONFIG_FILE" ] || fail "the install wizard did not write $CONFIG_FILE"
fi

## 4. Ownership: the config holds the secrets (0600) and the server reads it as uid 1000
chown "$PRYV_UID:$PRYV_UID" "$CONFIG_FILE"
chmod 0600 "$CONFIG_FILE"
mkdir -p "$CONFIG_DIR/data"
chown "$PRYV_UID:$PRYV_UID" "$CONFIG_DIR/data"

## 5. Validate the generated config (the documented check-config)
log "validating the configuration"
PRYV_IMAGE="$PRYV_IMAGE" "$CONFIG_DIR/check-config.sh" || fail "check-config reported a problem (output above)"

## 6. DNS: Let's Encrypt can only issue once the host name points at this instance
IPV4_RE='^[0-9]{1,3}(\.[0-9]{1,3}){3}$'
public_ip () {
  local ip
  ip="$(curl -fsS --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"
  if ! [[ "$ip" =~ $IPV4_RE ]]; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1) }' || true)"
  fi
  echo "$ip"
}
# A records of the host name, one per line (a public resolver: what Let's Encrypt will see)
resolved_ips () {
  dig +short A "$PRYV_HOSTNAME" @1.1.1.1 2>/dev/null | grep -E "$IPV4_RE" || true
}
MY_IP="$(public_ip)"
[[ "$MY_IP" =~ $IPV4_RE ]] || fail "could not determine the public IPv4 address of this instance (got '$MY_IP')"
log "public IP of this instance: $MY_IP"
waited=0
until resolved_ips | grep -qxF "$MY_IP"; do
  if [ "$waited" -ge "$DNS_WAIT_MAX_SECONDS" ]; then
    log "WARNING: $PRYV_HOSTNAME still does not resolve to $MY_IP after ${waited}s; starting anyway."
    log "Fix the DNS A record, then run: systemctl restart pryv"
    break
  fi
  log "waiting for $PRYV_HOSTNAME to resolve to $MY_IP (now: '$(resolved_ips | tr '\n' ' ')'), next check in 30s"
  sleep 30
  waited=$((waited + 30))
done

## 7. Start the server under systemd
systemctl enable --now pryv.service
touch "$DONE_FLAG"
log "pryv.service started"

## 8. Wait until it answers over HTTPS (the server obtains its certificate itself)
curl_opts=(-fsS --max-time 10)
[ "$PRYV_LE_STAGING" = true ] && curl_opts+=(-k)
waited=0
until curl "${curl_opts[@]}" "https://$PRYV_HOSTNAME/reg/service/info" > /dev/null 2>&1; do
  if [ "$waited" -ge "$SERVICE_WAIT_MAX_SECONDS" ]; then
    log "WARNING: https://$PRYV_HOSTNAME/reg/service/info does not answer yet; see: journalctl -u pryv"
    exit 0
  fi
  sleep 15
  waited=$((waited + 15))
done
log "ready: https://$PRYV_HOSTNAME/reg/service/info"
log "configuration and admin key: $CONFIG_FILE (readable by root and uid 1000, the server user)"
