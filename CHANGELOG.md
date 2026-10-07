# Changelog

## Unreleased

Template for Open Pryv.io 2, rebuilt from scratch:

- Built on Exoscale with the Packer Exoscale builder, from Exoscale's Ubuntu 24.04 LTS template; registered in several zones in one build.
- Runs the official `pryvio/open-pryv.io` Docker image (pre-pulled, pinned tag) instead of building open-pryv.io from source at first boot.
- First boot runs the open-pryv.io install wizard unattended from two user-data settings (`PRYV_HOSTNAME`, `PRYV_EMAIL`); all secrets are generated on the instance.
- HTTPS by the server's built-in Let's Encrypt client: no nginx, no certbot.
- The server runs under systemd (`pryv.service`): restarts after a reboot, stops cleanly.
- The v1 files (Packer QEMU build, `setup.js`, nginx configuration) are removed; v1 stays available at tag `1.7`.

## 1.7

Template for Open Pryv.io 1.7 (Ubuntu 18.04, open-pryv.io built from source at first boot, nginx and certbot).
