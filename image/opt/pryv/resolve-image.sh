#!/bin/bash
# Resolve an Open Pryv.io version to a signed image digest.
#
# Usage: resolve-image.sh [--pull] latest|latest-stable|<version>
#   latest         the newest release tag, release candidates included
#   latest-stable  the newest final release; while none exists, the newest
#                  release candidate (with a WARNING)
#   <version>      an explicit release tag, e.g. 2.0.0 or 2.0.0-rc.50
# Only 2.x and later releases are candidates.
#
# Lists the tags on Docker Hub, picks one, verifies its keyless signature
# (made by the open-pryv.io release workflow for that very tag) and, with
# --pull, pulls it by digest. Prints "<tag> <digest>" on stdout; messages go to
# stderr. Exit status: 0 resolved, 2 invalid version, 1 any other error.
set -euo pipefail

REPO=pryvio/open-pryv.io
TAGS_URL="https://hub.docker.com/v2/repositories/$REPO/tags?page_size=100"
SIGNER_ISSUER=https://token.actions.githubusercontent.com
SIGNER_WORKFLOW=https://github.com/pryv/open-pryv.io/.github/workflows/ci.yml
RELEASE_RE='^([0-9]+)\.([0-9]+)\.([0-9]+)(-rc\.([0-9]+))?$'
MIN_MAJOR=2
COSIGN="${COSIGN:-cosign}"
# cosign keeps its trust root under $HOME, which a systemd unit may leave unset
export HOME="${HOME:-/root}"

err () { echo "ERROR: $*" >&2; exit 1; }

pull=false
if [ "${1:-}" = --pull ]; then pull=true; shift; fi
[ $# -eq 1 ] || { echo "Usage: ${0##*/} [--pull] latest|latest-stable|<version>" >&2; exit 2; }
requested="$1"

# A release tag of a supported major version (checked before any network call)
is_release () {
  [[ "$1" =~ $RELEASE_RE ]] && [ "$((10#${BASH_REMATCH[1]}))" -ge "$MIN_MAJOR" ]
}
case "$requested" in
  latest|latest-stable) ;;
  *)
    is_release "$requested" || {
      echo "ERROR: invalid version '$requested': use latest, latest-stable or a release such as 2.0.0-rc.50 (2.x or later)" >&2
      exit 2
    } ;;
esac

## 1. Every release tag with its digest, as "<sort key> <tag> <digest>"
releases="$(
  url="$TAGS_URL"
  while [ -n "$url" ]; do
    page="$(curl -fsS --proto '=https' --max-time 30 --retry 3 --retry-delay 5 "$url")" \
      || err "cannot list the image tags at $url (no network access to Docker Hub?)"
    jq -e '.results | type == "array"' <<< "$page" > /dev/null \
      || err "unexpected answer from Docker Hub at $url (no tag list): $(head -c 200 <<< "$page")"
    # Only active tags with a digest: a tag being re-indexed must not block `latest`
    jq -r '.results[]
      | select(.tag_status == "active" and ((.digest // "") | test("^sha256:[0-9a-f]{64}$")))
      | "\(.name)\t\(.digest)"' <<< "$page"
    url="$(jq -r '.next // empty' <<< "$page")"
  done | while IFS=$'\t' read -r name digest; do
    is_release "$name" || continue
    # final > release candidate of the same version; numeric order throughout
    if [ -n "${BASH_REMATCH[4]:-}" ]; then final=0; rc="${BASH_REMATCH[5]:-0}"; else final=1; rc=0; fi
    printf '%06d.%06d.%06d.%d.%06d %s %s\n' \
      "$((10#${BASH_REMATCH[1]}))" "$((10#${BASH_REMATCH[2]}))" "$((10#${BASH_REMATCH[3]}))" \
      "$final" "$((10#$rc))" "$name" "$digest"
  done | LC_ALL=C sort
)"
[ -n "$releases" ] || err "no $MIN_MAJOR.x release tag found for $REPO on Docker Hub"

## 2. Pick one
case "$requested" in
  latest)
    picked="$(tail -n 1 <<< "$releases")" ;;
  latest-stable)
    picked="$(grep -E '^[0-9]{6}\.[0-9]{6}\.[0-9]{6}\.1\.' <<< "$releases" | tail -n 1 || true)"
    if [ -z "$picked" ]; then
      picked="$(tail -n 1 <<< "$releases")"
      echo "WARNING: no final $MIN_MAJOR.x release yet, using the newest release candidate $(cut -d' ' -f2 <<< "$picked")" >&2
    fi ;;
  *)
    picked="$(awk -v t="$requested" '$2 == t' <<< "$releases")"
    [ -n "$picked" ] || err "release $requested not found (or not available) on Docker Hub ($REPO)" ;;
esac
tag="$(cut -d' ' -f2 <<< "$picked")"
digest="$(cut -d' ' -f3 <<< "$picked")"
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || err "Docker Hub gave no valid digest for $REPO:$tag (got '$digest')"
echo "resolved $requested to $tag ($digest)" >&2

## 3. Signature: made by the open-pryv.io release workflow, for this tag
if ! verify_out="$("$COSIGN" verify "$REPO@$digest" \
  --certificate-oidc-issuer "$SIGNER_ISSUER" \
  --certificate-identity "$SIGNER_WORKFLOW@refs/tags/$tag" 2>&1 > /dev/null)"; then
  echo "$verify_out" >&2
  err "the signature of $REPO:$tag ($digest) could not be verified (output above): not using it"
fi
echo "signature verified: $SIGNER_WORKFLOW@refs/tags/$tag" >&2

## 4. Pull by digest
if $pull; then
  docker pull --quiet "$REPO@$digest" >&2 || err "docker pull $REPO@$digest failed"
  repo_digests="$(docker image inspect --format '{{join .RepoDigests "\n"}}' "$REPO@$digest")" \
    || err "the pulled image $REPO@$digest cannot be inspected"
  grep -qxF "$REPO@$digest" <<< "$repo_digests" || err "the pulled image does not carry the digest $digest"
  echo "pulled $REPO@$digest" >&2
fi

echo "$tag $digest"
