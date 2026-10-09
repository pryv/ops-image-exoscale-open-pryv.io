# Open Pryv.io on Exoscale

Deploy [Open Pryv.io](https://github.com/pryv/open-pryv.io) from the Exoscale [Marketplace](https://www.exoscale.com/marketplace/listing/open-pryv-io/) in a few minutes: a single server with its own HTTPS certificate, ready to register users.

<center>
<button name="button" onclick="window.location.href='https://portal.exoscale.com/compute/instances/add?template-name=Open%20Pryv.io%202.0.0-rc.43'">Launch Open Pryv.io on Exoscale</button><br>
(requires an Exoscale account)
</center>

Open Pryv.io 2.0 is a **release candidate**. This template runs the official `pryvio/open-pryv.io` Docker image on Ubuntu 24.04 LTS.

## What you need

Only **a host name** for the server, e.g. `pryv.example.com`, in a DNS zone you control. You will point its DNS A record at the instance once it has an IP address.

## 1. Security group

In the Exoscale portal, create a security group (e.g. `pryv`) with these inbound rules:

| Port | Protocol | Why |
|------|----------|-----|
| 443  | TCP | HTTPS (the API) |
| 80   | TCP | Let's Encrypt certificate validation (nothing else is served over plain HTTP) |
| 22   | TCP | SSH, for you |

## 2. Create the instance

Pick the **Open Pryv.io** template, a **Small** instance or larger, a disk of **20 GB** or more, your SSH key and the `pryv` security group. In **User Data**, paste the snippet below (including the `#cloud-config` line) with your own host name:

```yaml
#cloud-config
write_files:
  - path: /opt/pryv/first-boot.env
    permissions: '0600'
    content: |
      PRYV_HOSTNAME=pryv.example.com
```

Optional settings, one per line in the same file:

| Setting | Default | Meaning |
|---------|---------|---------|
| `PRYV_EMAIL=you@example.com` | none | Contact address of the Let's Encrypt account (Let's Encrypt no longer sends expiry emails) |
| `PRYV_SERVICE_NAME="My Platform"` | `Open Pryv.io` | Name shown to apps |
| `PRYV_AUTHUI_URL=https://...` | `https://account.pryv.me` | Sign-in and account pages ([app-web-user-account](https://github.com/pryv/app-web-user-account)); host your own to brand them |
| `PRYV_LE_STAGING=true` | `false` | Use the Let's Encrypt staging CA (untrusted certificate, for tests only) |

Do not put secrets in User Data: any process on the instance can read it. The setup generates all secrets itself.

## 3. Point your DNS at the instance

When the instance is running, create a DNS **A record** for your host name with the instance's public IP address. The setup waits for it (up to 2 hours) before requesting the certificate.

## 4. Follow the setup

Connect with `ssh ubuntu@<instance IP>` and follow the log:

```sh
sudo tail -f /var/log/pryv-first-boot.log
```

The setup runs the Open Pryv.io install wizard, then starts the server, which obtains its Let's Encrypt certificate by itself. It usually takes a few minutes once DNS is in place, and ends with `ready: https://<your host>/reg/service/info`.

If you skipped the User Data, write `/opt/pryv/first-boot.env` yourself (as root, same content as above): the setup starts as soon as the file exists.

If the setup stops with an `ERROR` line (for example a mistyped host name), correct `/opt/pryv/first-boot.env`, then run `sudo systemctl restart pryv-first-boot`.

To stop the setup while it runs (for example while it waits for DNS), stop both units, otherwise it starts again by itself:

```sh
sudo systemctl stop pryv-first-boot.path pryv-first-boot
```

To start over with another host name, before the platform holds any data you want to keep (this deletes the generated configuration, its secrets and all data):

```sh
sudo systemctl stop pryv-first-boot.path pryv-first-boot pryv
sudo systemctl disable pryv
sudo rm -rf /opt/pryv/pryv-config.yml /opt/pryv/data /opt/pryv/.initialized
```

Then correct `/opt/pryv/first-boot.env` and run `sudo systemctl start pryv-first-boot.path`: the setup runs again from the start.

## 5. Verify

```sh
curl https://pryv.example.com/reg/service/info
```

answers with your platform's description, for example:

```json
{
  "meta": { "apiVersion": "2.0.0-rc.43", "serverTime": 1791373164.65, "serial": "20261007" },
  "name": "Open Pryv.io",
  "api": "https://pryv.example.com/{username}/",
  "register": "https://pryv.example.com/reg/",
  "access": "https://pryv.example.com/reg/access/"
}
```

Then create a first account and app access: see [Open Pryv.io, getting started](https://github.com/pryv/open-pryv.io#readme) and the [API documentation](https://pryv.github.io/).

## Operating the server

| What | Where |
|------|-------|
| Service | `sudo systemctl status pryv`, logs: `sudo journalctl -u pryv` |
| Configuration, including the admin key | `/opt/pryv/pryv-config.yml` (mode 0600, owned by uid 1000: the server's user, which is also the `ubuntu` login user) |
| Data (accounts, attachments, certificates, platform database) | `/opt/pryv/data` |
| Setup answers | `/opt/pryv/init-answers.yml` |

- **Configuration changes:** edit `/opt/pryv/pryv-config.yml`, then `sudo systemctl restart pryv`. Reference: [INSTALL.md](https://github.com/pryv/open-pryv.io/blob/master/INSTALL.md).
- **Email** (password reset, welcome emails) is not configured by the setup: see the Email section of INSTALL.md.
- **Backups:** take Exoscale snapshots of the instance, or use the open-pryv.io backup tool (`bin/backup.js`, see INSTALL.md).
- **Upgrades:** change the tag of `PRYV_IMAGE` in `/etc/default/pryv`, then `sudo docker pull <that image>` and `sudo systemctl restart pryv`. Read the release notes first.
- The server runs under systemd (`pryv.service`) with the same container settings as the `run-pryv.sh` the wizard wrote in `/opt/pryv`. Do not run `run-pryv.sh` as well: it would start a second container.

## Coming from the v1 template

Open Pryv.io 2 is not an in-place upgrade of 1.x: start a new instance from this template and migrate your data as described in [INSTALL.md, "From v1.x"](https://github.com/pryv/open-pryv.io/blob/master/INSTALL.md#from-v1x).
