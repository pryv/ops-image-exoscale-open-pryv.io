# Open Pryv.io template for Exoscale

Builds the Exoscale compute template behind the [Open Pryv.io Marketplace listing](https://www.exoscale.com/marketplace/listing/open-pryv-io/).

- **Users:** see the setup guide at https://pryv.github.io/ops-image-exoscale-open-pryv.io/ (source: [`docs/README.md`](docs/README.md)).
- **Maintainers:** this file. Registered templates are listed in [`TEMPLATES.md`](TEMPLATES.md).

The v1 template (Open Pryv.io 1.7) is preserved on branch [`v1`](https://github.com/pryv/ops-image-exoscale-open-pryv.io/tree/v1) (tag `1.7`).

## What the template contains

Ubuntu 24.04 LTS (Exoscale's stock template) plus:

- Docker Engine, and the `pryvio/open-pryv.io:<tag>` image pre-pulled, so a new instance runs a known release without reaching Docker Hub;
- `/etc/default/pryv`: the image tag (`PRYV_IMAGE`), the one setting an upgrade changes;
- `/opt/pryv/first-boot.sh` with `pryv-first-boot.path` / `.service`: as soon as `/opt/pryv/first-boot.env` exists (written by the user-data), it runs the open-pryv.io install wizard unattended (`init --non-interactive`, answers from [`init-answers.template.yml`](image/opt/pryv/init-answers.template.yml)), gives the generated `pryv-config.yml` to the server's user (uid 1000, mode 0600), validates it with the generated `check-config.sh`, waits for the host name to resolve to the instance, then starts `pryv.service`;
- `pryv.service`: the container from the wizard's `run-pryv.sh` (same image, mounts, ports and command), run in the foreground under systemd, so it restarts after a reboot and gets 30 s to stop (the embedded platform database snapshots on stop);
- unattended security upgrades, and Exoscale's template cleanup (machine id, SSH keys, cloud-init state, logs).

No configuration and no secret is baked in: every instance generates its own at first boot.

| Path | Content |
|------|---------|
| [`packer/openpryv.pkr.hcl`](packer/openpryv.pkr.hcl) | Packer build (Exoscale builder) |
| [`packer/scripts/`](packer/scripts/) | Provisioning scripts, run in order; `exoscale/` holds Exoscale's standard template scripts |
| [`image/`](image/) | Files installed into the template, by path |
| [`docs/`](docs/) | User guide, published with GitHub Pages |

## Building a template

The build runs on Exoscale: Packer starts an instance from the stock Ubuntu template, provisions it over SSH, stops it, snapshots it and registers the snapshot as a template in the first zone of `zones`, then copies it to the other zones (the copies keep the same template ID).

Requirements:

- [Packer](https://developer.hashicorp.com/packer/install) 1.10 or later (no Docker or KVM needed locally);
- an Exoscale IAM API key allowed to manage compute instances, snapshots, templates, SSH keys and security groups, exported as `EXOSCALE_API_KEY` and `EXOSCALE_API_SECRET`;
- a security group named `packer` (or set `security_group`) allowing TCP 22 from the machine running Packer.

```sh
cd packer
packer init .
packer validate -var pryv_tag=2.0.0-rc.43 .
packer build -var pryv_tag=2.0.0-rc.43 -var 'zones=["ch-gva-2"]' -var 'name_suffix= (test)' .
```

Variables (see [`variables.pkrvars.hcl.example`](packer/variables.pkrvars.hcl.example)): `pryv_tag` (required, an open-pryv.io release published on Docker Hub, 2.0.0-rc.43 or later: the first whose install wizard accepts an empty Let's Encrypt email, which the build checks), `build` (template build number for that tag, default `1`), `zones`, `name_suffix`, `base_template`, `boot_mode` (must match the base template), `security_group`.

The build fails early if the release's install wizard does not accept every answer of `init-answers.template.yml` (checked with `init --dry-run`), so an incompatible release never reaches a user's first boot.

## Releasing a template

1. Build with a test suffix in one zone, launch an instance from it following the [user guide](docs/README.md) (with `PRYV_LE_STAGING=true` while iterating), and check: the setup log ends with `ready`, `service/info` reports the expected version, an account can be created, the service comes back after a reboot. Delete the test template afterwards.
2. Tag this repository `<open-pryv.io tag>-<build>` (e.g. `2.0.0-rc.43-1`).
3. Build with the final name in every zone: `packer build -var pryv_tag=<tag> -var build=<build> -var 'zones=[...]' .`
4. Record the template ID and its zones in [`TEMPLATES.md`](TEMPLATES.md) (check each zone with `exo compute instance-template list --visibility private --zone <zone>`).
5. Send the template name, version and ID to Exoscale support (a ticket to support@exoscale.com) for the Marketplace listing, and update the launch button in [`docs/README.md`](docs/README.md).

## Checks before committing

```sh
packer fmt -check packer
shellcheck packer/scripts/*.sh image/opt/pryv/first-boot.sh image/etc/update-motd.d/90-pryv
```

## License

[BSD-3-Clause](LICENSE)
