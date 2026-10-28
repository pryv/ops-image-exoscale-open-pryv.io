# Open Pryv.io template for Exoscale

Builds the Exoscale compute template behind the [Open Pryv.io Marketplace listing](https://www.exoscale.com/marketplace/listing/open-pryv-io/).

- **Users:** see the setup guide at https://pryv.github.io/ops-image-exoscale-open-pryv.io/ (source: [`docs/README.md`](docs/README.md)).
- **Maintainers:** this file. Registered templates are listed in [`TEMPLATES.md`](TEMPLATES.md).

The v1 template (Open Pryv.io 1.7) is preserved on branch [`v1`](https://github.com/pryv/ops-image-exoscale-open-pryv.io/tree/v1) (tag `1.7`).

## What the template contains

Ubuntu 24.04 LTS (Exoscale's stock template) plus:

- Docker Engine, `jq` and a pinned [cosign](https://github.com/sigstore/cosign) (checksum-verified at build). **No Open Pryv.io image is baked in**: the release is chosen at first boot, so a new open-pryv.io release needs no new template;
- [`resolve-image.sh`](image/opt/pryv/resolve-image.sh): turns `latest` / `latest-stable` / an explicit release (2.x or later) into a tag and digest from the Docker Hub tag list, verifies the image's keyless signature (made by the open-pryv.io release workflow for that very tag) and pulls it by digest;
- `/etc/default/pryv`: the image in use as a digest (`PRYV_IMAGE`) and its tag, written at first boot, then by [`pryv-upgrade.sh`](image/opt/pryv/pryv-upgrade.sh) (resolve, verify, pull, `check-config`, restart);
- `/opt/pryv/first-boot.sh` with `pryv-first-boot.path` / `.service`: as soon as `/opt/pryv/first-boot.env` exists (written by the user-data), it resolves the release (`PRYV_VERSION`, default `latest`), checks that its install wizard accepts the answers (`init --dry-run`), runs the wizard unattended (`init --non-interactive`, answers from [`init-answers.template.yml`](image/opt/pryv/init-answers.template.yml)), gives the generated `pryv-config.yml` to the server's user (uid 1000, mode 0600), validates it with the generated `check-config.sh`, waits for the host name to resolve to the instance, then starts `pryv.service`. Any failure stops it with an `ERROR` line, nothing installed (no fallback release);
- `pryv.service`: the container from the wizard's `run-pryv.sh` (same image, mounts, ports and command), run in the foreground under systemd, so it restarts after a reboot and gets 30 s to stop (the embedded platform database snapshots on stop);
- unattended security upgrades, and Exoscale's template cleanup (machine id, SSH keys, cloud-init state, logs).

No configuration and no secret is baked in: every instance generates its own at first boot.

| Path | Content |
|------|---------|
| [`packer/openpryv.pkr.hcl`](packer/openpryv.pkr.hcl) | Packer build (Exoscale builder) |
| [`packer/scripts/`](packer/scripts/) | Provisioning scripts, run in order; `exoscale/` holds Exoscale's standard template scripts |
| [`image/`](image/) | Files installed into the template, by path |
| [`docs/`](docs/) | User guide, published with GitHub Pages |
| [`marketplace/image.yaml`](marketplace/image.yaml) | Marketplace description sent to Exoscale with each release |

## Building a template

The build runs on Exoscale: Packer starts an instance from the stock Ubuntu template, provisions it over SSH, stops it, snapshots it and registers the snapshot as a template in the first zone of `zones`, then copies it to the other zones (the copies keep the same template ID). With `snapshot_download` (default on), it also saves the snapshot as a QCOW2 file in `packer/output/`: the export URL Exoscale hands out expires, so this file is what gets published for the Marketplace.

Requirements:

- [Packer](https://developer.hashicorp.com/packer/install) 1.10 or later (no Docker or KVM needed locally);
- an Exoscale IAM API key allowed to manage compute instances, snapshots, templates, SSH keys and security groups, and Object Storage (`sos`) for publishing, exported as `EXOSCALE_API_KEY` and `EXOSCALE_API_SECRET`;
- a security group named `packer` (or set `security_group`) allowing TCP 22 from the machine running Packer.

```sh
cd packer
packer init .
packer validate -var image_version=2.0 .
packer build -var image_version=2.0 -var build=test1 -var 'zones=["ch-gva-2"]' -var 'name_suffix= (test)' .
```

Variables (see [`variables.pkrvars.hcl.example`](packer/variables.pkrvars.hcl.example)): `image_version` (required, the version of this template: bump it when the base system or the setup scripts change, not for an open-pryv.io release), `build` (build number for that version, default `1`), `zones`, `name_suffix`, `snapshot_download` (default `true`), `download_dir` (default `output`), `base_template`, `boot_mode` (must match the base template), `security_group`.

The build smoke-tests the first-boot chain against the release current at build time (tag listing, signature check, pull by digest, the install wizard accepting every answer of `init-answers.template.yml` with and without an email), then removes the image again and fails if any image is left in the template.

## Releasing a template

Needed when the base system or the setup scripts change; an open-pryv.io release needs nothing here.

1. Build with a test suffix in one zone, launch instances from it following the [user guide](docs/README.md) (with `PRYV_LE_STAGING=true` while iterating), and check: the setup log ends with `ready`, `service/info` reports the expected version for `PRYV_VERSION` unset, `latest-stable` and an explicit release, an invalid `PRYV_VERSION` stops with an `ERROR`, `pryv-upgrade.sh` moves a pinned instance to `latest`, an account can be created, the service comes back after a reboot. Delete the test template and the test QCOW2 afterwards.
2. Tag this repository `<image_version>-<build>` (e.g. `2.0-1`).
3. Build with the final name in every zone: `packer build -var image_version=<version> -var build=<build> -var 'zones=[...]' .`
4. Publish the QCOW2 (bucket `pryv-marketplace-images`, zone `ch-gva-2`):
   ```sh
   cd output
   f=open-pryv.io-<version>-<build>.qcow2
   mv "Open Pryv.io.qcow2" "$f" && md5sum "$f" | tee "$f.md5"   # Packer names the file after the template
   exo storage upload --acl public-read "$f" "$f.md5" sos://pryv-marketplace-images/
   exo storage show "sos://pryv-marketplace-images/$f"
   curl -sI "<URL shown>"   # anonymous: 200, Content-Length = the file size
   ```
5. Fill [`marketplace/image.yaml`](marketplace/image.yaml) (version, image = the file name, source = the bucket base URL ending with `/`, so that source + image is the URL shown above, MD5) and record the template ID, zones, QCOW2 URL and MD5 in [`TEMPLATES.md`](TEMPLATES.md) (check each zone with `exo compute instance-template list --visibility private --zone <zone>`).
6. Send the template name, version, build, ID, QCOW2 URL, MD5 and `image.yaml` to Exoscale support (support@exoscale.com) for the Marketplace listing. Exoscale registers a public copy from the QCOW2 under its own ID: check it (`exo compute instance-template list --visibility public --zone <zone>`, checksum = the MD5, every zone) and record that ID in `TEMPLATES.md`. Once the listing launches it, delete the previous template (one template named "Open Pryv.io" at a time: the launch button selects it by name) and keep only the current and previous QCOW2 in the bucket.

## Checks before committing

```sh
packer fmt -check packer
(cd packer && EXOSCALE_API_KEY=x EXOSCALE_API_SECRET=x packer validate -var image_version=0 .)
shellcheck -x packer/scripts/*.sh image/opt/pryv/*.sh image/etc/update-motd.d/90-pryv
image/opt/pryv/resolve-image.sh latest   # needs jq and cosign locally
```

## License

[BSD-3-Clause](LICENSE)
