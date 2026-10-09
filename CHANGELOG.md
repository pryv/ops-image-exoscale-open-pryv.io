# Changelog

## Unreleased

## 2.0.0-rc.43-1 (2026-10-09)

Template "Open Pryv.io 2.0.0-rc.43", build 1, ID `1087c3ae-2030-4530-82f5-f394490419e0` in all current Exoscale zones. Rebuilt from scratch for Open Pryv.io 2:

- Built on Exoscale with the Packer Exoscale builder, from Exoscale's Ubuntu 24.04 LTS template; registered in several zones in one build.
- Runs the official `pryvio/open-pryv.io` Docker image (pre-pulled, pinned tag) instead of building open-pryv.io from source at first boot.
- First boot runs the open-pryv.io install wizard unattended from a single user-data setting (`PRYV_HOSTNAME`; everything else is optional); all secrets are generated on the instance.
- HTTPS by the server's built-in Let's Encrypt client: no nginx, no certbot.
- The server runs under systemd (`pryv.service`): restarts after a reboot, stops cleanly.
- A wrong setting stops the setup with an `ERROR` line; after correcting `/opt/pryv/first-boot.env`, `systemctl restart pryv-first-boot` runs it again.
- The v1 files (Packer QEMU build, `setup.js`, nginx configuration) are removed; v1 stays available on branch `v1` (tag `1.7`).

## 1.7

Template for Open Pryv.io 1.7 (Ubuntu 18.04, open-pryv.io built from source at first boot, nginx and certbot).
