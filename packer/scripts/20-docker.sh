#!/bin/sh
SCRIPT="${0##*/}"
set -eu

## Docker Engine from Docker's apt repository
# REF: https://docs.docker.com/engine/install/ubuntu/
echo "INFO[${SCRIPT}]: Installing Docker Engine ..."
export DEBIAN_FRONTEND='noninteractive'

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

arch="$(dpkg --print-architecture)"
# shellcheck disable=SC1091
codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install --yes docker-ce docker-ce-cli containerd.io

systemctl enable docker.service containerd.service
docker --version
